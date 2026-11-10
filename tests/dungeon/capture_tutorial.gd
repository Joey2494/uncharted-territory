extends "res://tests/dungeon/test_tutorial.gd"
## 使用正常跟随镜头，在真实动作推进时记录两种分辨率的教学状态。

var output := "user://tutorial_review"
var resolution := Vector2i(1280, 720)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		if arg == "--full-hd":
			resolution = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(output)
	capture.call_deferred()


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	check(error == OK, "截图保存 %s" % label)


func start_from_button(main: Node) -> void:
	var start := main.get_node("UILayer/StartScreen/Center/Card/Padding/Content/StartButton") as Button
	start.pressed.emit()


func capture() -> void:
	root.size = resolution
	var main := game()
	var map := main.get_node("DungeonTest")
	var tutor := map.get_node(LAYOUT)
	var p := map.get_node("Player") as CharacterBody3D
	await frames(20)
	await shot("01_menu")
	start_from_button(main)
	await frames(20)
	await shot("02_movement")
	await walk("move_left", 45)
	await place(p, Vector3(-4, 0.05, 2))
	await frames(14)
	await shot("03_pickup")
	press("interact")
	await frames(10)
	await shot("04_healing")
	press("use_health_potion")
	await place(p, Vector3(-5, 0.05, -0.9))
	await walk("move_forward", 14)
	await frames(14)
	await shot("05_melee")
	press("attack")
	await frames(12)
	await place(p, Vector3(5, 0.05, 1.2))
	await walk("move_forward", 15)
	await frames(14)
	await shot("06_spell")
	press("skill_1")
	await frames(26)
	await place(p, Vector3(2.2, 0.05, 3))
	await frames(14)
	await shot("07_dodge")
	Input.action_press("move_right")
	press("dodge")
	await frames(13)
	Input.action_release("move_right")
	await place(p, Vector3(7, 0.05, 2.5))
	press("interact")
	await frames()
	press("use_attack_rune")
	check(not tutor.is_active() and map.get_node("RoomProgress").is_complete(&"l1_entrance"), "真实流程完成")
	await place(p, Vector3(0, 0.05, -4.8))
	await frames(72)
	await shot("08_complete")
	main.queue_free()
	await process_frame

	main = game()
	map = main.get_node("DungeonTest")
	p = map.get_node("Player")
	start_from_button(main)
	await place(p, Vector3(0, 0.05, -4.8))
	var skip := main.get_node("UILayer/TutorialOverlay/Card/Stack/Top/Skip") as Button
	skip.pressed.emit()
	check(map.get_node("RoomProgress").is_complete(&"l1_entrance"), "跳过按钮完成实际目标")
	await frames(72)
	await shot("09_skip")
	print("TUTORIAL_CAPTURE ", resolution, " ", output)
	main.queue_free()
	await process_frame
	finish()
