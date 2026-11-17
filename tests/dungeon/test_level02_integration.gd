extends SceneTree
## 从正式菜单到真实出口的主线回归。以定点移动和伤害隔离战斗难度。

const LEVEL := "res://scenes/dungeon/Level02Run.tscn"
const START := "UILayer/StartScreen/%StartButton"
const PROFILE := preload("res://scripts/integration/player_profile.gd")
const PROGRESS := preload("res://scripts/integration/campaign_progress.gd")
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

func floor_point(map: Node3D, path: String, offset := Vector3.ZERO) -> Vector3:
	var point: Vector3 = map.get_node(path).global_position + offset
	point.y = 0.05
	return point

func press(host: Node, path: String) -> void:
	var button := host.get_node_or_null(path) as Button
	var available := button != null and button.is_visible_in_tree() and not button.disabled
	check(available, "可操作按钮 " + path)
	if available:
		button.pressed.emit()
		if path == START:
			var nav: Node = host.get_node("MenuNavigation")
			nav.character_select.get_node("%ConfirmButton").pressed.emit()
			nav.level_select.get_level_button(&"level2").pressed.emit()

func reload_finished() -> void:
	for i in 4:
		await process_frame

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
	var run_id := str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())
	PROFILE.override_path = "user://level02-test-profile-" + run_id + ".cfg"
	PROGRESS.override_path = "user://level02-test-progress-" + run_id + ".cfg"
	PROGRESS.new().complete(1)
	change_scene_to_file(LEVEL)
	await reload_finished()
	var host := current_scene
	var map = host.get_node("DungeonTest")
	var player: CharacterBody3D = map.get_node("Player")
	var inv = player.get_node("ItemInventory")
	var hub = map.get_node("Enemies/Hub1")
	var boss = map.get_node("Boss")
	var hub_gates := ["HubSouth", "HubEast", "HubWest", "HubNorth"]
	var relay_gates := ["RelayWest", "RelayNorth"]
	var antechamber_gates := ["AntechamberSouth", "AntechamberNorth", "AntechamberWest"]
	var boss_gates := ["BossSouth", "BossNorth"]
	map.exit_reached.connect(func() -> void: exit_events += 1)
	check(host.get_run_state() == host.RunState.MENU and not map.is_run_active(), "菜单等待玩家开始")
	press(host, START)
	check(host.get_run_state() == host.RunState.PLAYING and map.is_run_active(), "开始按钮实际启动一局")
	check(map.is_room_complete(map.ARRIVAL) and map.get_visited_count() == 1, "开局记录到达平台")
	await go(player, floor_point(map, "Supplies/ArrivalPotion", Vector3.BACK * 1.15))
	action("interact")
	check(inv.potion_count == 1, "真实 E 键通过背包拾取到达药剂")
	var exit_point := floor_point(map, "ExitArea")
	var relay_control := floor_point(map, "Devices/Relay", Vector3.BACK * 1.35)
	var shortcut_control := floor_point(map, "Devices/Shortcut", Vector3.BACK * 1.35)
	var antechamber := floor_point(map, "Regions/Antechamber")
	await go(player, exit_point)
	check(exit_events == 0 and host.get_run_state() == host.RunState.PLAYING, "提前进入实体出口不结算")
	await go(player, floor_point(map, "Regions/Boss"))
	check(not boss.can_process() and not boss.take_damage(999), "跳过前厅不能提前激活 Boss")
	await go(player, relay_control)
	action("interact")
	check(not map.relay_activated and not map.get_node("Enemies/Relay1").can_process(), "跳过中庭或未清敌不能启动导能")
	await go(player, shortcut_control)
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
	check(host.get_run_state() == host.RunState.PAUSED and paused, "ESC 暂停世界")
	await create_timer(0.35).timeout
	check(is_equal_approx(opening_mesh.position.y, height) and hub.position == hub_position, "暂停同时冻结关门动画与敌人")
	action("pause")
	check(host.get_run_state() == host.RunState.PLAYING and not paused, "ESC 恢复探索")
	await go(player, Vector3(-7.9, 0.05, -22))
	var start_distance: float = hub.global_position.distance_to(player.global_position)
	await create_timer(0.72).timeout
	check(hub.global_position.distance_to(player.global_position) < start_distance - 0.7, "实体守卫沿掩体西侧向真实玩家追击")
	check(host.open_guide(), "共享宿主打开探索指引")
	check(host.get_run_state() == host.RunState.GUIDE and paused, "区域指引暂停世界")
	action("pause")
	check(host.get_run_state() == host.RunState.PLAYING and not paused, "关闭指引恢复探索")
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
	await go(player, floor_point(map, "Regions/Relay"))
	check_seals(map, relay_gates, true)
	await defeat(map, ["Enemies/Relay1", "Enemies/Relay2"])
	check(map.is_room_complete(map.RELAY) and not map.relay_activated, "回廊清敌与导能是独立状态")
	await create_timer(1.03).timeout
	check_seals(map, ["RelayWest"], false)
	check_seals(map, ["RelayNorth"], true)
	await go(player, antechamber)
	check(not map.get_node("Enemies/Antechamber1").can_process(), "回廊清敌未导能时不能启动前厅")
	await go(player, relay_control)
	action("interact")
	check(map.relay_activated and not map.get_node("Gates/RelayNorth").is_open(), "导能 E 启动门体升起")
	await create_timer(1.03).timeout
	check_seals(map, ["RelayNorth"], false)
	await go(player, antechamber)
	check_seals(map, antechamber_gates, true)
	await defeat(map, ["Enemies/Antechamber1", "Enemies/Antechamber2", "Enemies/Antechamber3"])
	await create_timer(1.03).timeout
	check_seals(map, ["AntechamberSouth", "AntechamberNorth"], false)
	check_seals(map, ["HubNorth", "AntechamberWest"], true)
	await go(player, shortcut_control)
	action("interact")
	check(map.shortcut_unlocked and not map.get_node("Gates/HubNorth").is_open(), "前厅清敌后用 E 同时释放回环两端")
	action("interact")
	await create_timer(1.03).timeout
	check_seals(map, ["HubNorth", "AntechamberWest"], false)
	await go(player, floor_point(map, "Regions/Boss", Vector3.BACK * 4.0))
	check_seals(map, boss_gates, true)
	check(boss.can_process() and not boss.is_dead(), "真实 Boss 已唤醒")
	await process_frame
	var boss_bar: Control = host.get_node("UILayer/BossHealthBar")
	check(boss_bar.visible, "Boss 战开始后显示血条")
	await defeat(map, ["Boss"])
	check(map.is_room_complete(map.BOSS) and exit_events == 0, "击败守门者只开放路线")
	await go(player, exit_point)
	check(exit_events == 0, "出口门仍在打开时不结算")
	await go(player, floor_point(map, "Regions/ExitPass"))
	await create_timer(1.1).timeout
	check(not is_instance_valid(boss) or boss.is_dead(), "巨蝎死亡后无法继续战斗")
	check(boss_bar.is_defeated(), "正式 HUD 显示 Boss 已击败")
	var archive = map.get_node("EnergyRelayPuzzle")
	check(archive.get_state() == archive.State.READY and archive.get_core_count(&"rack") == 2, "主线通关时档案室已供电，仍可完全跳过解谜")
	check_seals(map, boss_gates, false)
	await go(player, exit_point)
	# Area3D 的物理重叠先写入下一次同步，再由地图的物理帧消费。
	await frames(12)
	check(exit_events == 1 and host.get_run_state() == host.RunState.VICTORY and not map.is_run_active(), "只有实际抵达出口触发一次胜利")
	if exit_events != 1:
		finish()
		return
	action("pause")
	check(not host.close_guide() and not host.set_paused(false), "胜利后暂停键和关闭指引不能继续")
	await frames(6)
	check(exit_events == 1, "停留在出口不重复结算")
	press(host._hud.get_result_screen(), "%RestartButton")
	check(not host.restart_run(), "同一帧拒绝重复重开")
	await reload_finished()
	host = current_scene
	map = host.get_node("DungeonTest")
	check(host.get_run_state() == host.RunState.PLAYING and not paused and map.is_run_active(), "胜利重开直接开始干净新局")
	check(not map.relay_activated and not map.shortcut_unlocked and map.get_visited_count() == 1, "重开仅记录新的到达进度")
	check(not map.get_node("Enemies/Hub1").can_process() and not map.get_node("Gates/BossNorth").is_open(), "重开恢复敌人休眠及顺序锁")

	player = map.get_node("Player")
	await go(player, Vector3(0, 0.05, -26))
	map.get_node("Enemies/Hub1").queue_free()
	await process_frame
	await defeat(map, ["Enemies/Hub2"])
	check(not map.is_room_complete(map.HUB) and not map.get_node("Gates/HubEast").is_open(), "单纯移除守卫不能代替真实击杀")
	await go(player, Vector3(0, 0.05, -26))
	check(player.take_damage(999), "活跃战斗中发生真实死亡")
	height = map.get_node("Gates/HubSouth/Visuals").position.y
	await create_timer(2.0).timeout
	check(host.get_run_state() == host.RunState.DEAD and not map.is_run_active(), "玩家死亡进入终局")
	check(is_equal_approx(height, map.get_node("Gates/HubSouth/Visuals").position.y), "死亡冻结战斗门")
	check_seals(map, ["HubSouth", "HubEast"], true)
	action("pause")
	check(not host.set_paused(false) and not host.open_guide(), "终局不能被暂停或指引恢复")
	press(host._hud.get_result_screen(), "%RestartButton")
	await reload_finished()
	host = current_scene
	check(host.get_run_state() == host.RunState.MENU, "死亡界面按钮实际重开")
	finish()

func finish() -> void:
	paused = false
	root.get_node("MusicManager").stop_music()
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames(3)
	print("LEVEL02_INTEGRATION: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
