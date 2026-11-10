extends SceneTree
## 实际 GL 渲染核验：固定机位记录中庭南侧门下降、封闭、上升及完全开放。
var output := "user://progression_review"
var size := Vector2i(1280,720)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--full-hd": size = Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(output)
	run.call_deferred()
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
func run() -> void:
	var g = load("res://Main.tscn").instantiate()
	root.add_child(g)
	root.size = size
	g._on_run_started()
	# 让 HUD 完成本次尺寸适配，再固定镜头以免安全框重新定位相机。
	await process_frame
	await process_frame
	var d = g.get_node("DungeonTest")
	d.get_node("MeleeEnemy").set_physics_process(false)
	var p = d.get_node("Player")
	var camera: Camera3D = d.get_node("Camera3D")
	camera.set_process(false)
	camera.position = Vector3(3.2, 5.8, -24.0)
	camera.look_at(Vector3(0.0, 2.0, -16.0))
	p.position = Vector3(0.0, 0.05, -20.0)
	await create_timer(0.36).timeout
	await shot("01_descending")
	await create_timer(0.65).timeout
	await shot("02_sealed")
	d.get_node("MeleeEnemy").take_damage(999)
	await create_timer(0.42).timeout
	await shot("03_rising")
	await create_timer(0.75).timeout
	await shot("04_open")
	# 回到实际跟随视角，记录 Boss 大厅的入口与出口走廊边界同时封闭。
	d.get_node("RuinGatekeeper").set_physics_process(false)
	p.position = Vector3(25.0, 0.05, -28.5)
	camera.set_process(true)
	camera.reset_follow()
	await create_timer(1.15).timeout
	await shot("05_boss_boundary")
	print("GATE_CAPTURE_COMPLETE ",output)
	g.queue_free()
	await process_frame
	quit()
