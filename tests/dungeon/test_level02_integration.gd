extends SceneTree
## 从预览开始按钮到真实出口的主线回归。以定点移动和伤害隔离战斗难度。

const PREVIEW := "res://tests/scenes/Level02Preview.tscn"
var checks := 0
var failures := 0
var exit_events := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func frames(count: int = 3) -> void:
	for i in count:
		await physics_frame

func go(player: CharacterBody3D, point: Vector3) -> void:
	player.global_position = point
	await frames()

func action(name: String) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	root.push_input(event)
	var released := event.duplicate() as InputEventAction
	released.pressed = false
	root.push_input(released)

func new_preview() -> Node3D:
	var preview: Node3D = load(PREVIEW).instantiate()
	root.add_child(preview)
	current_scene = preview
	return preview

func gate_is_solid(gate: Node3D) -> bool:
	var axis := gate.global_basis.z
	var center := gate.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(center - axis, center + axis, 1)
	return gate.get_world_3d().direct_space_state.intersect_ray(query).get("collider") == gate

func check_seals(map: Node3D, names: Array, sealed: bool) -> void:
	for name in names:
		var gate = map.get_node("Gates/" + name)
		check(gate.is_open() != sealed and gate_is_solid(gate) == sealed, name + (" 封锁实际门洞" if sealed else " 允许实际通行"))

func defeat(map: Node3D, enemies: Array) -> void:
	for name in enemies:
		check(map.get_node(name).take_damage(999), name + " 真实死亡")

func run() -> void:
	check(ResourceLoader.exists(PREVIEW), "第二关拥有独立可运行的预览场景")
	if failures:
		finish()
		return
	var preview := new_preview()
	var map = preview.get_node("Level02")
	var player: CharacterBody3D = map.get_node("Player")
	var inv = player.get_node("ItemInventory")
	var hub = map.get_node("Enemies/Hub1")
	var boss = map.get_node("Boss")
	var hub_gates := ["HubSouth", "HubEast", "HubWest", "HubNorth"]
	var relay_gates := ["RelayWest", "RelayNorth"]
	var antechamber_gates := ["AntechamberSouth", "AntechamberNorth", "AntechamberWest"]
	var boss_gates := ["BossSouth", "BossNorth"]
	map.exit_reached.connect(func() -> void: exit_events += 1)
	check(preview.get_run_state() == preview.State.MENU and not map.is_run_active(), "菜单等待玩家开始")
	preview.get_node("%Primary").pressed.emit()
	check(preview.get_run_state() == preview.State.PLAYING and map.is_run_active(), "开始按钮实际启动一局")
	check(map.is_room_complete(map.ARRIVAL) and map.get_visited_count() == 1, "开局记录到达平台")
	await go(player, Vector3(-2, 0.05, 2.15))
	action("interact")
	check(inv.potion_count == 1, "真实 E 键通过背包拾取到达药剂")
	await go(player, Vector3(34, 0.05, -111))
	check(exit_events == 0 and preview.get_run_state() == preview.State.PLAYING, "提前进入实体出口不结算")
	await go(player, Vector3(34, 0.05, -86))
	check(not boss.can_process() and not boss.take_damage(999), "跳过前厅不能提前激活 Boss")
	await go(player, Vector3(34, 0.05, -27.65))
	action("interact")
	check(not map.relay_activated and not map.get_node("Enemies/Relay1").can_process(), "跳过中庭或未清敌不能启动导能")
	await go(player, Vector3(28, 0.05, -52.65))
	action("interact")
	check(not map.shortcut_unlocked and not map.get_node("Enemies/Antechamber1").can_process(), "前厅未清敌不能开启回环")
	await go(player, Vector3(0, 0.05, -18.24))
	check(not hub.can_process() and not hub.take_damage(1), "门槛 1.24 米内守卫保持休眠")
	await go(player, Vector3(0, 0.05, -18.26))
	check(hub.can_process() and map.progress.get_room_state(map.HUB) == map.progress.RoomState.ACTIVE, "完全进入后封场并唤醒中庭守卫")
	check_seals(map, hub_gates, true)
	var opening_mesh: Node3D = map.get_node("Gates/HubSouth/Visuals")
	var height := opening_mesh.position.y
	var hub_position: Vector3 = hub.position
	action("pause")
	check(preview.get_run_state() == preview.State.PAUSED and paused, "ESC 暂停世界")
	await create_timer(0.35).timeout
	check(is_equal_approx(opening_mesh.position.y, height) and hub.position == hub_position, "暂停同时冻结关门动画与敌人")
	action("pause")
	check(preview.get_run_state() == preview.State.PLAYING and not paused, "ESC 恢复探索")
	await go(player, Vector3(-7.9, 0.05, -22))
	var start_distance: float = hub.global_position.distance_to(player.global_position)
	await create_timer(0.72).timeout
	check(hub.global_position.distance_to(player.global_position) < start_distance - 0.7, "实体守卫沿掩体西侧向真实玩家追击")
	preview.get_node("%GuideButton").pressed.emit()
	check(preview.get_run_state() == preview.State.GUIDE and paused, "区域指引暂停世界")
	action("pause")
	check(preview.get_run_state() == preview.State.PLAYING and not paused, "关闭指引恢复探索")
	await defeat(map, ["Enemies/Hub1"])
	check(not map.is_room_complete(map.HUB), "中庭仍有守卫时保持封场")
	await defeat(map, ["Enemies/Hub2"])
	check(map.is_room_complete(map.HUB), "中庭全部真实死亡完成房间")
	await create_timer(1.03).timeout
	check_seals(map, ["HubSouth", "HubWest", "HubEast"], false)
	check_seals(map, ["HubNorth"], true)
	await go(player, Vector3(0, 0.05, -33.7))
	action("interact")
	check(not map.shortcut_unlocked and gate_is_solid(map.get_node("Gates/HubNorth")), "中庭一侧没有可提前启用的回环控制")
	await go(player, Vector3(34, 0.05, -26))
	check_seals(map, relay_gates, true)
	await defeat(map, ["Enemies/Relay1", "Enemies/Relay2"])
	check(map.is_room_complete(map.RELAY) and not map.relay_activated, "回廊清敌与导能是独立状态")
	await create_timer(1.03).timeout
	check_seals(map, ["RelayWest"], false)
	check_seals(map, ["RelayNorth"], true)
	await go(player, Vector3(34, 0.05, -56))
	check(not map.get_node("Enemies/Antechamber1").can_process(), "回廊清敌未导能时不能启动前厅")
	await go(player, Vector3(34, 0.05, -27.65))
	action("interact")
	check(map.relay_activated and not map.get_node("Gates/RelayNorth").is_open(), "导能 E 启动门体升起")
	await create_timer(1.03).timeout
	check_seals(map, ["RelayNorth"], false)
	await go(player, Vector3(34, 0.05, -56))
	check_seals(map, antechamber_gates, true)
	await defeat(map, ["Enemies/Antechamber1", "Enemies/Antechamber2", "Enemies/Antechamber3"])
	await create_timer(1.03).timeout
	check_seals(map, ["AntechamberSouth", "AntechamberNorth"], false)
	check_seals(map, ["HubNorth", "AntechamberWest"], true)
	await go(player, Vector3(28, 0.05, -52.65))
	action("interact")
	check(map.shortcut_unlocked and not map.get_node("Gates/HubNorth").is_open(), "前厅清敌后用 E 同时释放回环两端")
	action("interact")
	await create_timer(1.03).timeout
	check_seals(map, ["HubNorth", "AntechamberWest"], false)
	await go(player, Vector3(34, 0.05, -80))
	check_seals(map, boss_gates, true)
	check(boss.can_process() and not boss.is_dead(), "真实 Boss 已唤醒")
	await process_frame
	check(preview.get_node("%BossPanel").visible, "Boss 战开始后显示血条")
	await defeat(map, ["Boss"])
	check(map.is_room_complete(map.BOSS) and exit_events == 0, "击败守门者只开放路线")
	await go(player, Vector3(34, 0.05, -111))
	check(exit_events == 0, "出口门仍在打开时不结算")
	await go(player, Vector3(34, 0.05, -105))
	await create_timer(1.1).timeout
	check(not is_instance_valid(boss), "守门者死亡动画完成后释放实体")
	check(not preview.get_node("%BossPanel").visible, "Boss 实体释放后血条保持隐藏")
	check(map.get_node("EnergyRelayPuzzle").get_state() == map.get_node("EnergyRelayPuzzle").State.CALIBRATION, "可选机关保持未解")
	check_seals(map, boss_gates, false)
	await go(player, Vector3(34, 0.05, -111))
	# Area3D 的物理重叠先写入下一次同步，再由地图的物理帧消费。
	await frames(12)
	check(exit_events == 1 and preview.get_run_state() == preview.State.VICTORY and not map.is_run_active(), "只有实际抵达出口触发一次胜利")
	if exit_events != 1:
		preview.queue_free()
		await process_frame
		finish()
		return
	action("pause")
	check(not preview.close_guide() and not preview.set_paused(false), "胜利后暂停键和关闭指引不能继续")
	await frames(6)
	check(exit_events == 1, "停留在出口不重复结算")
	preview.get_node("%Primary").pressed.emit()
	check(not preview.restart_run(), "同一帧拒绝重复重开")
	await process_frame
	await process_frame
	preview = current_scene
	map = preview.get_node("Level02")
	check(preview.get_run_state() == preview.State.MENU and not paused and not map.is_run_active(), "真实重开返回干净菜单")
	check(not map.relay_activated and not map.shortcut_unlocked and map.get_visited_count() == 0, "重开重置所有进度")
	check(not map.get_node("Enemies/Hub1").can_process() and not map.get_node("Gates/BossNorth").is_open(), "重开恢复敌人休眠及顺序锁")

	preview.start_run()
	player = map.get_node("Player")
	await go(player, Vector3(0, 0.05, -26))
	map.get_node("Enemies/Hub1").queue_free()
	await process_frame
	await defeat(map, ["Enemies/Hub2"])
	check(not map.is_room_complete(map.HUB) and not map.get_node("Gates/HubEast").is_open(), "单纯移除守卫不能代替真实击杀")
	await go(player, Vector3(0, 0.05, -26))
	check(player.take_damage(999), "活跃战斗中发生真实死亡")
	height = map.get_node("Gates/HubSouth/Visuals").position.y
	await create_timer(1.03).timeout
	check(preview.get_run_state() == preview.State.DEAD and not map.is_run_active(), "玩家死亡进入终局")
	check(is_equal_approx(height, map.get_node("Gates/HubSouth/Visuals").position.y), "死亡冻结战斗门")
	check_seals(map, ["HubSouth", "HubEast"], true)
	action("pause")
	check(not preview.set_paused(false) and not preview.open_guide(), "终局不能被暂停或指引恢复")
	preview.get_node("%Primary").pressed.emit()
	await process_frame
	await process_frame
	preview = current_scene
	check(preview.get_run_state() == preview.State.MENU, "死亡界面按钮实际重开")
	preview.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("LEVEL02_INTEGRATION: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
