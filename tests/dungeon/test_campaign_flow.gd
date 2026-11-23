extends SceneTree
## 前两关衔接回归。定位玩家以隔离移动距离，用真实伤害、交互与物理出口推进。

const FIRST := "res://Main.tscn"
const SECOND := "res://scenes/dungeon/Level02Run.tscn"
const START := "UILayer/StartScreen/%StartButton"
const PROFILE := preload("res://scripts/integration/player_profile.gd")
const PROGRESS := preload("res://scripts/integration/campaign_progress.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func press(owner: Node, path: String) -> bool:
	var button := owner.get_node_or_null(path) as Button
	if button == null or not button.is_visible_in_tree() or button.disabled:
		check(false, "可操作按钮缺失：" + path)
		return false
	button.pressed.emit()
	if path == START:
		var nav: Node = owner.get_node("MenuNavigation")
		nav.character_select.get_node("%ConfirmButton").pressed.emit()
		nav.level_select.get_level_button(StringName("level%d" % owner.level_id)).pressed.emit()
	return true

func action(name: String) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	root.push_input(event)
	var released := event.duplicate() as InputEventAction
	released.pressed = false
	root.push_input(released)

func pause_host(host: Node) -> bool:
	action("pause")
	var opened: bool = host.get_run_state() == host.RunState.PAUSED
	check(opened, "ESC 打开共享暂停菜单")
	return opened

func go(player: CharacterBody3D, point: Vector3) -> void:
	player.global_position = point
	for i in 6:
		await physics_frame

func defeat(map: Node, paths: Array) -> void:
	for path in paths:
		check(map.get_node(path).take_damage(999), path + " 实际死亡")

func scene_ready() -> void:
	for i in 4:
		await process_frame

## 可见窗口采集复用同一条测试主线。
func checkpoint(_label: String) -> void:
	pass

func run() -> void:
	var run_id := str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())
	PROFILE.override_path = "user://campaign-test-profile-" + run_id + ".cfg"
	PROGRESS.override_path = "user://campaign-test-progress-" + run_id + ".cfg"
	change_scene_to_file(FIRST)
	await scene_ready()
	var first := current_scene
	var dungeon := first.get_node("DungeonTest")
	var player := dungeon.get_node("Player") as CharacterBody3D
	var hud := first.get_node("UILayer/HUD")
	await checkpoint("01_first_menu")
	if not press(first, START):
		finish()
		return
	check(dungeon.get_node("RoomProgress").is_complete(&"l1_entrance"), "菜单开始后完成入口目标")
	await checkpoint("02_first_entrance")
	if first.open_guide():
		check(paused and not dungeon.can_process(), "指引冻结第一关世界")
		await checkpoint("03_first_guide")
		action("pause")
		check(not paused and dungeon.can_process(), "ESC 关闭指引恢复探索")
	if pause_host(first):
		await checkpoint("04_first_paused")
		var seconds: float = first._elapsed_seconds
		var position := player.position
		hud.show_item_message("测试暂停提示")
		Input.action_press("move_forward")
		await create_timer(0.22).timeout
		Input.action_release("move_forward")
		check(paused and first._elapsed_seconds == seconds and player.position == position, "暂停冻结世界和通关计时")
		check(hud._message_remaining == 3.0, "暂停冻结反馈计时")
		action("pause")
		check(not paused, "ESC 关闭暂停")
	check(not first.has_method("advance_to_level02") or not first.advance_to_level02(), "游戏中拒绝直接跨关")
	# 第一关携带补给房间的真实药剂，验证切关初始化清空背包。
	await go(player, dungeon.get_node("SupplyPotion").global_position + Vector3(0, 0, 1))
	action("interact")
	check(player.get_node("ItemInventory").potion_count == 1, "第一关实际拾取药剂")
	await create_timer(1.1).timeout
	check(dungeon.get_node("Gates/EntranceGate").is_open(), "入口门实际打开")
	await go(player, Vector3(0, 0.05, -23))
	defeat(dungeon, ["MeleeEnemy"])
	await create_timer(1.1).timeout
	await go(player, Vector3(22, 0.05, -23))
	defeat(dungeon, ["RuinGatekeeper"])
	check(hud.get_result_screen() == null, "只击败 Boss 不显示通关按钮")
	await create_timer(1.1).timeout
	check(dungeon.is_exit_open(), "第一关出口实际开门")
	await go(player, Vector3(30, 0.05, -45))
	var result: Control = hud.get_result_screen()
	check(is_instance_valid(result) and first._run_state == first.RunState.VICTORY, "实体出口触发第一关胜利")
	if result == null:
		finish()
		return
	action("pause")
	check(not paused and first._run_state == first.RunState.VICTORY, "第一关终局拒绝 ESC")
	await checkpoint("05_first_victory")
	if not press(result, "%NextLevelButton"):
		finish()
		return
	check(not first.advance_to_level02() and not first.restart_run(), "同帧跨关或重开只接收一次")
	await scene_ready()
	check(not is_instance_valid(first), "旧地图已被释放")
	var second := current_scene
	check(second.scene_file_path == SECOND and not paused, "胜利按钮直接进入第二关且树未暂停")
	if second.scene_file_path != SECOND:
		finish()
		return
	var map := second.get_node("DungeonTest")
	player = map.get_node("Player")
	check(second.get_run_state() == second.RunState.PLAYING and map.is_run_active(), "第二关直接开始")
	check(player.hp == player.max_hp and player.get_node("ItemInventory").potion_count == 0, "第二关重置生命和背包")
	await checkpoint("06_second_started")
	await go(player, map.get_node("Regions/Hub").global_position + Vector3.UP * 0.05)
	defeat(map, ["Enemies/Hub1", "Enemies/Hub2"])
	await create_timer(1.1).timeout
	await go(player, map.get_node("Regions/Relay").global_position + Vector3.UP * 0.05)
	defeat(map, ["Enemies/Relay1", "Enemies/Relay2"])
	await go(player, map.get_node("Devices/Relay").global_position + Vector3(0, 0.05, 1.35))
	action("interact")
	check(map.relay_activated, "按 E 真正启动导能核心")
	await create_timer(1.1).timeout
	await go(player, map.get_node("Regions/Antechamber").global_position + Vector3.UP * 0.05)
	defeat(map, ["Enemies/Antechamber1", "Enemies/Antechamber2", "Enemies/Antechamber3"])
	await create_timer(1.1).timeout
	await go(player, map.get_node("Regions/Boss").global_position + Vector3(0, 0.05, 4))
	defeat(map, ["Boss"])
	check(second.get_run_state() == second.RunState.PLAYING, "第二关击败 Boss 后仍需抵达出口")
	await create_timer(1.1).timeout
	check(map.get_node("Gates/BossNorth").is_open(), "第二关真实出口门开放")
	var exit_point: Vector3 = map.get_node("ExitArea").global_position
	exit_point.y = 0.05
	await go(player, exit_point)
	check(second.get_run_state() == second.RunState.VICTORY, "第二关实际出口触发胜利")
	var second_result: Control = second._hud.get_result_screen()
	check(is_instance_valid(second_result) and second_result.next_level_button.visible, "第二关结束显示正式第三关入口")
	action("pause")
	check(not second.open_guide() and not second.set_paused(false) and not paused, "第二关终局拒绝恢复")
	await checkpoint("07_second_victory")
	if second_result != null and press(second_result, "%RestartButton"):
		check(not second.restart_run(), "第二关结算同帧只接收一次重开")
		await scene_ready()
		check(current_scene.scene_file_path == SECOND and current_scene.get_run_state() == current_scene.RunState.PLAYING and not paused, "第二关结算重开直接开始干净新局")
	await verify_restarts()
	finish()

func verify_restarts() -> void:
	change_scene_to_file(FIRST)
	await scene_ready()
	var first := current_scene
	if first.scene_file_path != FIRST or not press(first, START):
		return
	if pause_host(first) and press(first._commerce.pause_menu, "%RestartButton"):
		await scene_ready()
		check(not paused and current_scene._run_state == current_scene.RunState.MENU, "第一关暂停中重开清除树暂停")
	first = current_scene
	press(first, START)
	var player = first.get_node("DungeonTest/Player")
	check(player.take_damage(999), "第一关真实死亡")
	action("pause")
	check(first._run_state == first.RunState.DYING and not paused, "死亡动画期间不能暂停")
	await create_timer(2.0).timeout
	check(first._run_state == first.RunState.DEAD and not first.open_guide() and not first.set_paused(false), "死亡界面不能恢复探索")

	change_scene_to_file(SECOND)
	await scene_ready()
	var second := current_scene
	check(not second.restart_run(), "第二关菜单拒绝无效重开")
	press(second, START)
	pause_host(second)
	if press(second._commerce.pause_menu, "%RestartButton"):
		await scene_ready()
		check(not paused and current_scene.get_run_state() == current_scene.RunState.MENU, "第二关暂停中重开清除树暂停")
	second = current_scene
	press(second, START)
	pause_host(second)
	if press(second._commerce.pause_menu, "%MainMenuButton"):
		await scene_ready()
		check(current_scene.scene_file_path == FIRST and not paused, "第二关暂停中返回第一关并恢复树")
	change_scene_to_file(SECOND)
	await scene_ready()
	second = current_scene
	press(second, START)
	check(second.get_node("DungeonTest/Player").take_damage(999), "第二关真实死亡")
	await create_timer(2.0).timeout
	check(second.get_run_state() == second.RunState.DEAD, "第二关死亡动画后进入结算")
	var death_result: Control = second._hud.get_result_screen()
	if death_result != null and press(death_result, "%RestartButton"):
		await scene_ready()
		check(current_scene.scene_file_path == SECOND and not paused, "第二关死亡后重开本关")

func finish() -> void:
	print("CAMPAIGN_FLOW: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
