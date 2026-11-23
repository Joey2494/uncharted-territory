extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1440,1000))
	root.size=Vector2i(1440,1000)
	var output := OS.get_environment("GODOT_TEST_OUTPUT_DIR")
	if output.is_empty(): output = "res://addons/ziyuan_level03/evidence/models"
	DirAccess.make_dir_recursive_absolute(output)
	for name in ["BoneAxe","BoneSpike","TombSword","ChainJailer","SandKing"]:
		change_scene_to_file("res://addons/ziyuan_level03/previews/"+name+"Preview.tscn")
		for i in 24: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(name+".png"))
		print("MODEL_CAPTURE ",name)
	quit()
