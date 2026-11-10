extends SceneTree
## 双关主线回归。定位玩家以隔离移动距离，用真实伤害、交互与物理出口推进。

const FIRST := "res://Main.tscn"
const SECOND := "res://tests/scenes/Level02Preview.tscn"
const START := "UILayer/StartScreen/Center/Card/Padding/Content/StartButton"
const CORNER := "UILayer/RunOverlay/Corner/"
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
	return true

func action(name: String) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	root.push_input(event)
	var released := event.duplicate() as InputEventAction
	released.pressed = false
	root.push_input(released)

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
	change_scene_to_file(FIRST)
	await scene_ready()
	var first := current_scene
	var dungeon := first.get_node("DungeonTest")
	var player := dungeon.get_node("Player") as CharacterBody3D
	var hud := first.get_node("UILayer/HUD")
	var tutorial: Node = dungeon.get_tutorial()
	await checkpoint("01_first_menu")
	if not press(first, START):
		finish()
		return
	check(tutorial.is_active(), "菜单通过真实按钮启动入口教学")
	await checkpoint("02_first_tutorial")
	if press(first, CORNER + "GuideButton"):
		check(paused and not dungeon.can_process(), "指引冻结第一关世界")
		check(not dungeon.request_tutorial_skip(), "打开指引不能跳过教学")
		await checkpoint("03_first_guide")
		action("pause")
		check(not paused and tutorial.is_active(), "ESC 关闭指引恢复原步骤")
	if press(first, CORNER + "PauseButton"):
		await checkpoint("04_first_paused")
		var seconds: float = first._elapsed_seconds
		var tutorial_text: String = first.get_node("UILayer/TutorialOverlay/Card/Stack/Top/Progress").text
		var position := player.position
		hud.show_item_message("测试暂停提示")
		Input.action_press("move_forward")
		await create_timer(0.22).timeout
		Input.action_release("move_forward")
		check(paused and first._elapsed_seconds == seconds and player.position == position, "暂停冻结世界和通关计时")
		check(first.get_node("UILayer/TutorialOverlay/Card/Stack/Top/Progress").text == tutorial_text and hud._message_remaining == 3.0, "教学步骤和反馈计时同时冻结")
		action("pause")
		check(not paused, "ESC 关闭暂停")
	check(not first.has_method("advance_to_level02") or not first.advance_to_level02(), "游戏中拒绝直接跨关")
	# 第一关携带真实拾取的药剂，才能验证切关初始化会清空背包。
	Input.action_press("move_left")
	for i in 45:
		await physics_frame
	Input.action_release("move_left")
	await go(player, Vector3(-4, 0.05, 2))
	action("interact")
	check(player.get_node("ItemInventory").potion_count == 1, "第一关实际拾取药剂")
	check(dungeon.request_tutorial_skip(), "使用入口教学真实跳过 API")
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
	check(not is_instance_valid(first) and not is_instance_valid(tutorial), "旧地图和教学均被释放")
	var second := current_scene
	check(second.scene_file_path == SECOND and not paused, "胜利按钮打开第二关菜单且树未暂停")
	if second.scene_file_path != SECOND:
		finish()
		return
	var map := second.get_node("Level02")
	player = map.get_node("Player")
	check(second.get_run_state() == second.State.MENU and not map.is_run_active(), "第二关等待开始")
	check(player.hp == player.max_hp and player.get_node("ItemInventory").potion_count == 0, "第二关重置生命和背包")
	await checkpoint("06_second_menu")
	press(second, "%Primary")
	await go(player, Vector3(0, 0.05, -26))
	defeat(map, ["Enemies/Hub1", "Enemies/Hub2"])
	await create_timer(1.1).timeout
	await go(player, Vector3(34, 0.05, -26))
	defeat(map, ["Enemies/Relay1", "Enemies/Relay2"])
	await go(player, Vector3(34, 0.05, -27.65))
	action("interact")
	check(map.relay_activated, "按 E 真正启动导能核心")
	await create_timer(1.1).timeout
	await go(player, Vector3(34, 0.05, -56))
	defeat(map, ["Enemies/Antechamber1", "Enemies/Antechamber2", "Enemies/Antechamber3"])
	await create_timer(1.1).timeout
	await go(player, Vector3(34, 0.05, -80))
	defeat(map, ["Boss"])
	check(second.get_run_state() == second.State.PLAYING, "第二关击败 Boss 后仍需抵达出口")
	await create_timer(1.1).timeout
	check(map.get_node("Gates/BossNorth").is_open(), "第二关真实出口门开放")
	await go(player, Vector3(34, 0.05, -111))
	check(second.get_run_state() == second.State.VICTORY, "第二关实际出口触发胜利")
	action("pause")
	check(not second.open_guide() and not second.set_paused(false) and not paused, "第二关终局拒绝恢复")
	await checkpoint("07_second_victory")
	if press(second, "%ReturnToFirst"):
		check(not second.return_to_first() and not second.restart_run(), "同帧返回或重开只接收一次")
		await scene_ready()
		check(current_scene.scene_file_path == FIRST and not paused, "返回第一关干净菜单")
	await verify_restarts()
	await verify_tutorial_layout()
	finish()

func verify_restarts() -> void:
	var first := current_scene
	if first.scene_file_path != FIRST or not press(first, START):
		return
	if press(first, CORNER + "PauseButton") and press(first, "UILayer/RunOverlay/Modal/Center/Card/Content/RestartButton"):
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
	check(not first.get_node("UILayer/TutorialOverlay").visible, "终局关闭教学提示")

	change_scene_to_file(SECOND)
	await scene_ready()
	var second := current_scene
	check(not second.return_to_first(), "第二关菜单拒绝无效返回请求")
	press(second, "%Primary")
	press(second, "%PauseButton")
	if press(second, "%Restart"):
		await scene_ready()
		check(not paused and current_scene.get_run_state() == current_scene.State.MENU, "第二关暂停中重开清除树暂停")
	second = current_scene
	press(second, "%Primary")
	press(second, "%PauseButton")
	if press(second, "%ReturnToFirst"):
		await scene_ready()
		check(current_scene.scene_file_path == FIRST and not paused, "第二关暂停中返回第一关并恢复树")
	change_scene_to_file(SECOND)
	await scene_ready()
	second = current_scene
	press(second, "%Primary")
	check(second.get_node("Level02/Player").take_damage(999), "第二关真实死亡")
	if press(second, "%ReturnToFirst"):
		await scene_ready()
		check(current_scene.scene_file_path == FIRST and not paused, "第二关死亡后返回第一关")

## 教学卡片在窄窗口共享未启用的 Boss 行，宽窗口恢复右上角。
func verify_tutorial_layout() -> void:
	var first := current_scene
	if first.scene_file_path != FIRST or not press(first, START):
		return
	var original_size := root.size
	var original_mode := root.mode
	root.mode = Window.MODE_WINDOWED
	var layer := first.get_node("UILayer")
	var card := layer.get_node("TutorialOverlay/Card") as Control
	for dimensions in [Vector2i(720, 720), Vector2i(800, 720), Vector2i(1280, 720)]:
		root.size = dimensions
		await scene_ready()
		var rect := card.get_global_rect()
		var viewport_size := root.get_visible_rect().size
		var compact: bool = dimensions.x < 960
		check(is_equal_approx(viewport_size.x, float(dimensions.x)), "测试窗口实际宽度 %s" % dimensions)
		for path in ["HUD/Panel", "HUD/CooldownBar", "HUD/ItemsPanel"]:
			var panel := layer.get_node(path) as Control
			check(not rect.intersects(panel.get_global_rect()), "%s 教学卡不遮挡 %s" % [dimensions, path])
		check(is_equal_approx(rect.position.x, 24.0) if compact else is_equal_approx(rect.end.x, viewport_size.x - 24.0) and is_equal_approx(rect.position.y, 24.0), "%s 教学卡放在预定位置" % dimensions)
	root.size = original_size
	root.mode = original_mode

func finish() -> void:
	print("CAMPAIGN_FLOW: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
