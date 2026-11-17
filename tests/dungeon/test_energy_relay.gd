extends SceneTree
## 通过真实 E 输入、玩家移动、门体和背包验证档案室全流程。

const MAP := preload("res://scenes/dungeon/level02/Level02.tscn")
var checks := 0
var failures := 0
var feedback_text := ""
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
	var map := MAP.instantiate()
	root.add_child(map)
	map.begin_run()
	map.feedback.connect(func(message: String) -> void: feedback_text = message)
	return map

func settle(frames: int = 3) -> void:
	for frame in frames:
		await physics_frame

func go(player: CharacterBody3D, point: Vector3) -> void:
	player.global_position = point
	await settle()

func press_e() -> void:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)

func use_control(puzzle: Node3D, player: CharacterBody3D, id: String, offset := Vector3(0, 0.05, 1.25)) -> void:
	var control := puzzle.get_node(id) as Node3D
	await go(player, control.global_position + offset)
	press_e()

func crosses(player: CharacterBody3D, puzzle: Node3D, z: float, eastward: bool) -> bool:
	var start_x := -6.1 if eastward else -1.3
	await go(player, puzzle.to_global(Vector3(start_x, 0.05, z)))
	var direction := &"move_right" if eastward else &"move_left"
	await move(direction, 66)
	var finish_x := puzzle.to_local(player.global_position).x
	return finish_x > -2.0 if eastward else finish_x < -5.5

func move(direction: StringName, frames: int) -> void:
	Input.action_press(direction)
	await settle(frames)
	Input.action_release(direction)
	await settle(2)

func enable_supply(map: Node3D, player: CharacterBody3D) -> void:
	await go(player, map.get_node("Regions/Hub").global_position + Vector3(0, 0.05, 0))
	for id in ["Hub1", "Hub2"]:
		check(map.get_node("Enemies/" + id).take_damage(999), "清除中庭守卫 " + id)
	await go(player, map.get_node("Regions/Relay").global_position + Vector3(0, 0.05, 0))
	for id in ["Relay1", "Relay2"]:
		check(map.get_node("Enemies/" + id).take_damage(999), "清除回廊守卫 " + id)
	await use_control(map.get_node("Devices"), player, "Relay")

func fill_gate(puzzle: Node3D, player: CharacterBody3D) -> void:
	await use_control(puzzle, player, "CoreRack")
	await use_control(puzzle, player, "ReceiverA")
	await use_control(puzzle, player, "ReceiverB")

func run() -> void:
	var map := new_map()
	var puzzle = map.get_node("EnergyRelayPuzzle")
	var player = map.get_node("Player")
	var inventory = player.get_node("ItemInventory")
	var gate = map.get_node("Gates/Vault")
	for name in ["CoreRack", "BridgeSocket", "Lever", "ReceiverA", "ReceiverB", "ResetConsole", "Inspect", "Hints", "Reward"]:
		check(puzzle.has_node(name), "档案室有可交互设施 " + name)
	check(puzzle.has_method("get_core_count"), "可核对任一托架、手持和插槽中的能源数量")
	if failures > 0:
		finish()
		return
	check(puzzle.get_state() == puzzle.State.SUPPLY_OFF and puzzle.get_objective().contains("回廊"), "档案室通电前给出供能来源")
	await use_control(puzzle, player, "CoreRack")
	await use_control(puzzle, player, "BridgeSocket", Vector3(1.25, 0.05, 0))
	check(puzzle.get_core_count(&"rack") == 2 and feedback_text.contains("回廊"), "断电时可检查但两枚能源不移动")
	check(not await crosses(player, puzzle, -0.4, false), "断电临时桥实体阻挡玩家")
	check(not await crosses(player, puzzle, 4.1, false), "未卡合侧步道实体阻挡玩家")
	for z in [-6.5, 2.12, 6.45]:
		check(not await crosses(player, puzzle, z, false), "隔断在墙边和通路间不可绕过")
	await go(player, puzzle.to_global(Vector3(-1.75, 0.05, -1.9)))
	check(not puzzle.get_node("Lever").can_interact(player), "无法在前台隔空拉动检修手柄")
	await enable_supply(map, player)
	check(map.relay_activated and puzzle.get_state() == puzzle.State.READY, "真实 C 导能开启 G 支线")
	await use_control(map.get_node("Devices"), player, "Relay")
	check(feedback_text.contains("撤回") and puzzle.get_state() == puzzle.State.READY, "C 教学演示撤回能源且主供能仍然保持")

	await use_control(puzzle, player, "Inspect")
	check(feedback_text.contains("两个接收器"), "前台可主动检查读出门锁规则")
	await use_control(puzzle, player, "Hints")
	check(feedback_text.contains("步道") and not feedback_text.contains("撤回"), "一级提示指向机械步道")
	await use_control(puzzle, player, "Hints")
	check(feedback_text.contains("撤回"), "二级提示说明能源回收")
	await use_control(puzzle, player, "Hints")
	check(feedback_text.contains("手柄") and feedback_text.contains("接收器"), "三级提示由玩家主动查看")

	var hp: int = player.hp
	await fill_gate(puzzle, player)
	check(puzzle.get_core_count(&"rack") == 0 and puzzle.get_core_count(&"a") == 1 and puzzle.get_core_count(&"b") == 1, "两枚能源能提前分配到门锁")
	check(not gate.is_open() and puzzle.get_objective().contains("2/2") and puzzle.get_objective().contains("断开"), "双能源缺检修线路时门保持关闭且有反馈")
	check(player.hp == hp and inventory.rune_count == 0, "尝试错误分配无伤害和库存变化")
	await use_control(puzzle, player, "ResetConsole")
	check(puzzle.get_core_count(&"a") == 1 and feedback_text.contains("确认"), "重置必须在前台连续确认")
	await go(player, puzzle.to_global(Vector3(7, 0.05, 0)))
	await use_control(puzzle, player, "ResetConsole")
	check(puzzle.get_core_count(&"a") == 1, "离开前台重置点撤销确认")
	await use_control(puzzle, player, "ResetConsole")
	check(map.relay_activated and puzzle.get_core_count(&"rack") == 2 and puzzle.get_core_count(&"a") == 0, "重置只还原谜题并保留主供能")

	await use_control(puzzle, player, "CoreRack")
	check(puzzle.get_core_count(&"carried") == 2, "两枚能源在托架与手持之间转移")
	await go(player, puzzle.to_global(Vector3(10, 0.05, 0)))
	check(puzzle.get_core_count(&"rack") == 2 and puzzle.get_core_count(&"carried") == 0, "离开档案室自动归还手持能源")
	await use_control(puzzle, player, "CoreRack")
	await use_control(puzzle, player, "BridgeSocket", Vector3(1.25, 0.05, 0))
	check(puzzle.get_core_count(&"bridge") == 1 and puzzle.get_core_count(&"carried") == 1, "桥只占用一枚能源")
	await use_control(puzzle, player, "BridgeSocket", Vector3(-1.2, 0.05, 0))
	check(puzzle.get_core_count(&"bridge") == 1 and feedback_text.contains("离开桥面"), "玩家位于桥面不能撤回能源")
	check(await crosses(player, puzzle, -0.4, false), "通电后用真实移动跨过临时桥")
	check(not await crosses(player, puzzle, 4.1, true), "临时桥通电不会替代侧步道")
	await use_control(puzzle, player, "Lever")
	check(feedback_text.contains("检修线") and puzzle.get_objective().contains("接通"), "手柄同时卡合步道与检修线路")
	check(await crosses(player, puzzle, 4.1, true), "用真实移动经机械步道返回前台")
	await use_control(puzzle, player, "BridgeSocket", Vector3(1.25, 0.05, 0))
	check(puzzle.get_core_count(&"bridge") == 0 and puzzle.get_core_count(&"carried") == 2, "离开桥面可回收供能")
	check(not await crosses(player, puzzle, -0.4, false) and await crosses(player, puzzle, 4.1, false), "桥收回后实体阻挡恢复，步道仍可通行")
	await use_control(puzzle, player, "ReceiverA")
	await use_control(puzzle, player, "ReceiverB")
	check(puzzle.get_state() == puzzle.State.OPENING and not gate.is_open(), "两个接收器接通后开始升起档案门")
	check(not puzzle.get_node("Reward").can_interact(player), "门完全打开前奖励不可交互")
	var height: float = gate.get_node("Visuals").position.y
	paused = true
	await create_timer(0.3).timeout
	check(is_equal_approx(gate.get_node("Visuals").position.y, height), "暂停冻结开门动画")
	paused = false
	await create_timer(1.02).timeout
	check(gate.is_open() and puzzle.get_state() == puzzle.State.OPEN, "真实门体开放后才开放领奖")
	await go(player, gate.global_position + Vector3(0, 0.05, 1.5))
	await move(&"move_forward", 40)
	check(player.global_position.z < gate.global_position.z - 1.0, "档案门全开后玩家可实际穿越门洞")
	puzzle.reward_claimed.connect(func() -> void: reward_events += 1)
	var reward = puzzle.get_node("Reward")
	inventory.process_mode = Node.PROCESS_MODE_DISABLED
	await use_control(puzzle, player, "Reward")
	check(reward.can_interact(player) and not reward.try_interact(player) and reward_events == 0, "背包拒绝入包时奖励可重试")
	inventory.process_mode = Node.PROCESS_MODE_INHERIT
	inventory.inventory_changed.connect(func(_p: int, _r: int) -> void: reentrant_claim = reward.try_interact(player))
	press_e()
	press_e()
	check(puzzle.get_state() == puzzle.State.CLAIMED and inventory.rune_count == 1 and reward_events == 1 and not reentrant_claim, "真实 E 发放一次奖励并拒绝同步重入")
	await use_control(puzzle, player, "ResetConsole")
	await use_control(puzzle, player, "ResetConsole")
	check(puzzle.get_core_count(&"rack") == 2 and not gate.is_open(), "领奖后可复位机关与实体门")
	await use_control(puzzle, player, "CoreRack")
	await use_control(puzzle, player, "BridgeSocket", Vector3(1.25, 0.05, 0))
	await use_control(puzzle, player, "Lever")
	await use_control(puzzle, player, "BridgeSocket", Vector3(1.25, 0.05, 0))
	await use_control(puzzle, player, "ReceiverA")
	await use_control(puzzle, player, "ReceiverB")
	await use_control(puzzle, player, "ResetConsole")
	await use_control(puzzle, player, "ResetConsole")
	await create_timer(1.02).timeout
	check(puzzle.get_state() == puzzle.State.READY and not gate.is_open(), "开门途中确认复位能废弃旧开门信号")
	await use_control(puzzle, player, "CoreRack")
	await use_control(puzzle, player, "BridgeSocket", Vector3(1.25, 0.05, 0))
	await use_control(puzzle, player, "Lever")
	await use_control(puzzle, player, "BridgeSocket", Vector3(1.25, 0.05, 0))
	await use_control(puzzle, player, "ReceiverA")
	await use_control(puzzle, player, "ReceiverB")
	check(puzzle.get_state() == puzzle.State.OPENING, "复位后可再次启动同一个档案门")
	await create_timer(1.02).timeout
	await use_control(puzzle, player, "Reward")
	check(gate.is_open() and inventory.rune_count == 1 and reward_events == 1 and not reward.visible, "重复解谜仍只发放一份奖励")
	map.queue_free()
	await process_frame

	map = new_map()
	puzzle = map.get_node("EnergyRelayPuzzle")
	player = map.get_node("Player")
	gate = map.get_node("Gates/Vault")
	check(puzzle.get_state() == puzzle.State.SUPPLY_OFF and puzzle.get_core_count(&"rack") == 2, "新一局恢复断电初态")
	await enable_supply(map, player)
	await use_control(puzzle, player, "CoreRack")
	await use_control(puzzle, player, "BridgeSocket", Vector3(1.25, 0.05, 0))
	await use_control(puzzle, player, "Lever")
	await use_control(puzzle, player, "BridgeSocket", Vector3(1.25, 0.05, 0))
	await use_control(puzzle, player, "ReceiverA")
	await use_control(puzzle, player, "ReceiverB")
	await create_timer(0.16).timeout
	check(player.take_damage(999), "开门中发生真实死亡")
	height = gate.get_node("Visuals").position.y
	await create_timer(1.02).timeout
	check(puzzle.get_state() == puzzle.State.OPENING and not gate.is_open() and is_equal_approx(gate.get_node("Visuals").position.y, height), "死亡废弃开门确认并冻结门体")
	check(not puzzle.get_node("ReceiverB").can_interact(player), "终局停止机关交互")
	map.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("ENERGY_RELAY: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
