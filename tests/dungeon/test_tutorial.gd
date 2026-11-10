extends SceneTree
## 实际主场景的教学验收，使用玩家输入、实物碰撞和库存事务推进。
const LAYOUT := "Regions/EntranceHall/TutorialLayout"
var checks := 0
var failures := 0
var completions: Array[bool] = []

func _initialize() -> void:
	if "--missing-config" in OS.get_cmdline_user_args():
		missing_config.call_deferred()
	else:
		run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", description)

func frames(count: int = 3) -> void:
	for i in count:
		await physics_frame

func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)

func walk(action: String, ticks: int) -> void:
	Input.action_press(action)
	await frames(ticks)
	Input.action_release(action)
	await frames(2)

func game() -> Node:
	var instance: Node = load("res://Main.tscn").instantiate()
	root.add_child(instance)
	current_scene = instance
	return instance

func place(p: CharacterBody3D, at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	await frames(4)

func blocks(gate: Node3D) -> bool:
	var center := gate.global_position + Vector3.UP
	var ray := PhysicsRayQueryParameters3D.create(center + Vector3.BACK, center + Vector3.FORWARD, 1)
	return gate.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == gate

func run() -> void:
	var main := game()
	var map := main.get_node("DungeonTest")
	var tutor := map.get_node_or_null(LAYOUT)
	check(tutor != null, "入口大厅需具备实物教学场景与控制器")
	if tutor == null:
		main._on_run_started()
		await frames(70)
		check(not map.get_node("Gates/EntranceGate").is_open(), "入口门等待完成教学或主动跳过")
		finish()
		return
	tutor.completed.connect(func(skipped: bool) -> void: completions.append(skipped))
	var player := map.get_node("Player") as CharacterBody3D
	var entry := map.get_node("Gates/EntranceGate")
	var progress := map.get_node("RoomProgress")
	var items := player.get_node("ItemInventory")
	var overlay := main.get_node("UILayer/TutorialOverlay") as Control
	check(not tutor.is_active() and not overlay.visible and not tutor.request_skip(), "菜单不能推进或跳过教学")
	await walk("move_forward", 42)
	check(not progress.is_complete(&"l1_entrance") and blocks(entry), "菜单移动输入不能开门")
	main._on_run_started()
	await frames()
	check(tutor.is_active() and tutor.get_step() == 0 and overlay.visible, "开始后激活教学第一步与界面")
	check(blocks(entry), "教学中入口门仍有碰撞")
	await place(player, Vector3(0, 0.05, -1))
	check(tutor.get_step() == 0, "传送无效")
	paused = true
	await walk("move_right", 42)
	check(tutor.get_step() == 0 and not tutor.request_skip(), "暂停不推进也不能跳过")
	paused = false
	await walk("move_right", 43)
	check(tutor.get_step() == 1, "真实步行推进到拾取药剂")
	press("interact")
	check(tutor.get_step() == 1 and items.potion_count == 0, "远处空按 E 无效")
	await place(player, Vector3(-4, 0.05, 2))
	press("interact")
	await frames()
	check(tutor.get_step() == 2 and items.potion_count == 1 and player.hp == player.max_hp - 1, "拾取后安全扣一点血供使用")
	press("use_health_potion")
	await frames()
	check(tutor.get_step() == 3 and items.potion_count == 0 and player.hp == player.max_hp, "真实用药消耗库存并恢复生命")
	press("attack")
	await frames(32)
	check(tutor.get_step() == 3, "空挥不能通过近战")
	await place(player, Vector3(-5, 0.05, -0.9))
	await walk("move_forward", 14)
	press("attack")
	await frames(10)
	check(tutor.get_step() == 4, "近战实体接触通过")
	await place(player, Vector3(5, 0.05, -2.4))
	await walk("move_forward", 13)
	press("attack")
	await frames(32)
	check(tutor.get_step() == 4, "近战命中法术靶也不能通过法术")
	var impacts: Array[Node] = []
	player.get_node("EnergyShock").released.connect(
		func(bolt: Node) -> void:
			bolt.impacted.connect(func(collider: Node) -> void: impacts.append(collider)),
		CONNECT_ONE_SHOT
	)
	await place(player, Vector3(4, 0.05, 1))
	await walk("move_forward", 14)
	press("skill_1")
	await frames(121)
	check(tutor.get_step() == 4, "法术未命中指定靶不能通过")
	check(impacts == [tutor.get_node("SpellTargetPoint/Backstop")], "擦过靶边的真实弹体撞上后挡板")
	await place(player, Vector3(5, 0.05, 1.2))
	await walk("move_forward", 15)
	press("skill_1")
	await frames(25)
	check(tutor.get_step() == 5, "真实能量弹命中法术靶通过")
	await place(player, Vector3(2, 0.05, 3))
	Input.action_press("move_right")
	press("dodge")
	check(tutor.get_step() == 5 and player.is_dodging(), "开始闪避时仍等待动作结束")
	await frames(14)
	Input.action_release("move_right")
	check(tutor.get_step() == 6, "真实闪避完成通过")
	await place(player, Vector3(7, 0.05, 2.5))
	press("interact")
	await frames()
	check(tutor.get_step() == 7 and items.rune_count == 1, "拾取实体符文成功")
	press("use_attack_rune")
	await frames()
	check(items.rune_count == 0 and items.get_multiplier() > 1, "使用符文真实消耗与强化")
	check(completions == [false] and not tutor.is_active() and not overlay.visible, "完成通知仅一次，停止教学与提示")
	check(blocks(entry), "开门动画保留碰撞")
	await frames(74)
	check(entry.is_open() and not blocks(entry), "动画完成后北门实际可通行")
	check(not tutor.request_skip() and completions == [false], "完成后无法重复发送跳过")
	check(tutor.get_node("MeleeTargetPoint/Target").collision_layer == 0 and tutor.get_node("SpellTargetPoint/Target").collision_layer == 0, "完成后训练靶无碰撞")
	# 重开由暂停或结算界面发起，教学结束后先打开暂停。
	main.get_node("UILayer/RunOverlay/Corner/PauseButton").pressed.emit()
	main.get_node("UILayer/RunOverlay/Modal/Center/Card/Content/RestartButton").pressed.emit()
	await process_frame
	await process_frame
	main = current_scene
	map = main.get_node("DungeonTest")
	tutor = map.get_node(LAYOUT)
	entry = map.get_node("Gates/EntranceGate")
	check(not tutor.is_active() and tutor.get_step() == 0 and blocks(entry), "重开恢复菜单、教学与锁门")
	main._on_run_started()
	var skip := main.get_node("UILayer/TutorialOverlay/Card/Stack/Top/Skip") as Button
	skip.pressed.emit()
	check(not tutor.is_active(), "跳过按钮可在第一步结束教学")
	await frames(74)
	check(entry.is_open(), "跳过走真实开门链路")
	main.queue_free()
	await process_frame
	await edge_cases()
	await standalone()
	finish()

func edge_cases() -> void:
	for variant in ["normal", "low", "one", "death"]:
		var main := game()
		var map := main.get_node("DungeonTest")
		var tutor := map.get_node(LAYOUT)
		var player := map.get_node("Player") as CharacterBody3D
		var items := player.get_node("ItemInventory")
		var start_hp: int = player.hp
		if variant == "one":
			player.max_hp = 1
			player.hp = 1
			start_hp = 1
		main._on_run_started()
		if variant == "low":
			check(player.take_damage(start_hp - 1), "正常受伤可留下 1 点生命")
			start_hp = 1
		await walk("move_right", 43)
		await place(player, Vector3(-4, 0.05, 2))
		press("interact")
		await frames()
		if variant == "death":
			await frames(43)
			check(player.take_damage(999), "真实死亡打断待完成的药剂步骤")
			check(not tutor.is_active() and not tutor.request_skip(), "死亡后教学终止")
			await frames(75)
			check(blocks(map.get_node("Gates/EntranceGate")), "死亡后待完成步骤不开放北门")
		elif variant == "one":
			check(tutor.get_step() == 3 and player.hp == 1 and items.potion_count == 1, "满血上限 1 自动越过无法安全演示的用药步骤")
		else:
			check(tutor.get_step() == 2 and player.hp == (1 if variant == "low" else start_hp - 1), "药剂步骤仅对满血角色造成一次安全演示伤害")
			check(tutor.request_skip() and player.hp == start_hp and items.potion_count == 1, "跳过只归还演示伤害并保留已拾物品")
		main.queue_free()
		await process_frame

func standalone() -> void:
	var map: Node = load("res://scenes/dungeon/DungeonTest.tscn").instantiate()
	root.add_child(map)
	current_scene = map
	await frames(6)
	var tutor := map.get_node(LAYOUT)
	var player := map.get_node("Player") as CharacterBody3D
	check(tutor.is_active() and not map.get_node("Gates/EntranceGate").is_open(), "F6 独立入口同样先开始教学并锁门")
	var safe := true
	for index in 8:
		var direction := Vector3(cos(index * TAU / 8.0), 0, sin(index * TAU / 8.0))
		var ray := PhysicsRayQueryParameters3D.create(
			player.global_position + Vector3.UP, player.global_position + Vector3.UP + direction * 3.0, 5
		)
		if not player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			safe = false
	check(safe, "出生点八方向 3 米无障碍")
	Input.action_press("sprint")
	await walk("move_left", 26)
	Input.action_release("sprint")
	check(tutor.get_step() == 1, "F6 独立入口接受 Shift 与方向键的真实疾跑")
	check(map.request_tutorial_skip(), "F6 独立入口复用相同跳过链路")
	await frames(74)
	check(map.get_node("Gates/EntranceGate").is_open(), "F6 实体北门可打开")
	map.queue_free()
	await process_frame


func missing_config() -> void:
	# 此故障用例有意触发地图的一次配置报错，独立于常规无错误运行。
	var map: Node = load("res://scenes/dungeon/DungeonTest.tscn").instantiate()
	var tutor := map.get_node(LAYOUT)
	tutor.free()
	root.add_child(map)
	current_scene = map
	await frames(75)
	check(map.get_tutorial() == null and not map.request_tutorial_skip(), "缺少控制器时无法绕过教程")
	check(not map.get_node("RoomProgress").is_complete(&"l1_entrance") and blocks(map.get_node("Gates/EntranceGate")), "错误配置保持实体北门封闭")
	map.queue_free()
	await process_frame
	finish()


func finish() -> void:
	print("TUTORIAL: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
