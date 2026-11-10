extends SceneTree
## 真实玩家背包、视线和密室门的双阶段机关测试。

const MAP := "res://scenes/dungeon/level02/Level02.tscn"
var checks := 0
var failures := 0
var reward_events := 0
var reentrant_claim := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func new_map() -> Node3D:
	var map = load(MAP).instantiate()
	root.add_child(map)
	map.begin_run()
	return map

func interact(map: Node3D, name: String) -> bool:
	var player = map.get_node("Player")
	var control := map.get_node("EnergyRelayPuzzle/" + name) as Node3D
	player.global_position = control.global_position + Vector3(0, 0.05, 1.35)
	await physics_frame
	await physics_frame
	return player.get_node("ItemInventory").try_interact_nearest()

func calibrate(map: Node3D) -> void:
	for name in ["RuneSun", "RuneMoon", "RuneStar"]:
		check(await interact(map, name), "背包选中实体符文 " + name)

func route(map: Node3D) -> void:
	for name in ["SwitchA", "SwitchB", "SwitchB"]:
		check(await interact(map, name), "切换档位 " + name)

func run() -> void:
	var path := "res://scenes/puzzles/energy_relay/EnergyRelayPuzzle.tscn"
	check(ResourceLoader.exists(path), "支线机关拥有独立可配置场景")
	if failures:
		finish()
		return
	var map := new_map()
	var puzzle = map.get_node("EnergyRelayPuzzle")
	var player = map.get_node("Player")
	var inventory = player.get_node("ItemInventory")
	var sun = puzzle.get_node("RuneSun")
	var gate = map.get_node("Gates/Vault")
	check(puzzle.get_state() == puzzle.State.CALIBRATION, "初始为符文校准")
	check(not await interact(map, "Confirm") and not await interact(map, "SwitchA"), "校准前禁用分流及确认")
	player.global_position = sun.global_position + Vector3(0, 0.05, 1.81)
	check(not sun.can_interact(player), "超出 1.8 米拒绝交互")
	player.global_position = sun.global_position + Vector3(0, 2.01, 1.1)
	check(not sun.can_interact(player), "高差超过 2 米拒绝交互")
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.8, 0.24)
	shape.shape = box
	blocker.add_child(shape)
	map.add_child(blocker)
	blocker.global_position = sun.global_position + Vector3(0, 0.9, 0.8)
	check(not await interact(map, "RuneSun") and puzzle.get_rune_progress() == 0, "实体遮挡拒绝背包交互")
	blocker.queue_free()
	await process_frame
	check(await interact(map, "RuneSun") and puzzle.get_rune_progress() == 1, "移除遮挡可校准")
	check(await interact(map, "RuneStar"), "错误第二个符文给出反馈")
	check(puzzle.get_rune_progress() == 1 and not sun.can_interact(player), "错误期间保留进度等待重置")
	paused = true
	await create_timer(0.8).timeout
	check(puzzle.get_rune_progress() == 1, "世界暂停时错误重置计时冻结")
	paused = false
	await create_timer(0.75).timeout
	check(puzzle.get_rune_progress() == 0, "恢复后 0.7 秒内完成重置")
	await calibrate(map)
	check(puzzle.get_state() == puzzle.State.ROUTING, "正确序列进入分流")
	check(not await interact(map, "RuneSun"), "已校准符文不可再交互")
	check(await interact(map, "SwitchA") and await interact(map, "SwitchB"), "两路均接受档位切换")
	var hp: int = player.hp
	check(await interact(map, "Confirm"), "错误确认给出反馈")
	check(puzzle.get_state() == puzzle.State.ROUTING and puzzle.get_rune_progress() == 3 and puzzle.get_settings() == Vector2i(1, 1), "错误确认保留校准和设置")
	check(player.hp == hp and inventory.potion_count == 0 and inventory.rune_count == 0 and not gate.is_open(), "错误确认无代价且不打开门")
	player.global_position = Vector3.ZERO
	await physics_frame
	check(puzzle.get_settings() == Vector2i(1, 1), "离开区域保留档位")
	check(await interact(map, "SwitchB") and puzzle.get_settings() == Vector2i(1, 2), "返回后完成目标档位 A1/B2")
	check(await interact(map, "Confirm") and puzzle.get_state() == puzzle.State.OPENING, "正确确认开始开门")
	check(not await interact(map, "Confirm") and not gate.is_open(), "开门中拒绝重复确认且保持实体锁")
	check(not await interact(map, "Reward"), "未完全开门不能领取")
	var height: float = gate.get_node("Visuals").position.y
	paused = true
	await create_timer(1.0).timeout
	check(is_equal_approx(gate.get_node("Visuals").position.y, height) and puzzle.get_state() == puzzle.State.OPENING, "暂停冻结支线开门")
	paused = false
	await create_timer(1.0).timeout
	check(gate.is_open() and puzzle.get_state() == puzzle.State.OPEN, "等实体门 opened 事件才开放")
	puzzle.reward_claimed.connect(func() -> void: reward_events += 1)
	var reward = puzzle.get_node("Reward")
	inventory.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = reward.global_position + Vector3(0, 0.05, 1.35)
	await physics_frame
	check(reward.can_interact(player) and not reward.try_interact(player), "真实背包拒绝入包时返回失败")
	check(puzzle.get_state() == puzzle.State.OPEN and reward_events == 0 and inventory.rune_count == 0, "入包失败保留奖励并允许重试")
	inventory.process_mode = Node.PROCESS_MODE_INHERIT
	inventory.inventory_changed.connect(func(_p: int, _r: int) -> void: reentrant_claim = reward.try_interact(player))
	check(await interact(map, "Reward"), "恢复背包后通过最近目标领取")
	check(puzzle.get_state() == puzzle.State.CLAIMED and inventory.rune_count == 1 and reward_events == 1, "只提交一个符文与一次成功信号")
	check(not reentrant_claim and not await interact(map, "Reward"), "同步重入和后续重复领取均被拒绝")
	map.queue_free()
	await process_frame

	map = new_map()
	puzzle = map.get_node("EnergyRelayPuzzle")
	player = map.get_node("Player")
	check(puzzle.get_state() == puzzle.State.CALIBRATION and puzzle.get_settings() == Vector2i.ZERO, "新实例清空两阶段进度")
	check(await interact(map, "RuneSun") and await interact(map, "RuneStar"), "新局创建等待中的错误重置")
	check(player.take_damage(999), "错误重置中发生真实死亡")
	await create_timer(0.78).timeout
	check(puzzle.get_rune_progress() == 1 and not await interact(map, "RuneMoon"), "死亡废弃错误重置并停止交互")
	map.queue_free()
	await process_frame

	map = new_map()
	puzzle = map.get_node("EnergyRelayPuzzle")
	player = map.get_node("Player")
	gate = map.get_node("Gates/Vault")
	await calibrate(map)
	await route(map)
	check(await interact(map, "Confirm"), "开启过程中测试死亡")
	await create_timer(0.16).timeout
	check(player.take_damage(999), "开门中发生真实死亡")
	height = gate.get_node("Visuals").position.y
	await create_timer(1.0).timeout
	check(puzzle.get_state() == puzzle.State.OPENING and not gate.is_open() and is_equal_approx(gate.get_node("Visuals").position.y, height), "死亡后密室门和未完成状态均冻结")
	map.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("ENERGY_RELAY: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
