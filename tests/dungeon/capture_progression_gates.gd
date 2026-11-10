extends SceneTree
## 实际GL渲染核验：固定机位展示锁门、开门中和已开放，不模拟HUD通关。
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
	var d = g.get_node("DungeonTest")
	d.get_node("MeleeEnemy").set_physics_process(false)
	var p = d.get_node("Player")
	p.position = Vector3(5,0.05,-23)
	d.get_node("Camera3D").reset_follow()
	await create_timer(0.3).timeout
	await shot("01_locked")
	d.get_node("MeleeEnemy").take_damage(999)
	await create_timer(0.45).timeout
	await shot("02_opening")
	await create_timer(0.75).timeout
	await shot("03_open")
	print("GATE_CAPTURE_COMPLETE ",output)
	g.queue_free()
	await process_frame
	quit()
