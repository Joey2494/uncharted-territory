extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1440,1000))
	root.size=Vector2i(1440,1000)
	DirAccess.make_dir_recursive_absolute("res://addons/ziyuan_level03/evidence/models")
	for name in ["BoneAxe","BoneSpike","TombSword","ChainJailer","SandKing"]:
		change_scene_to_file("res://addons/ziyuan_level03/previews/"+name+"Preview.tscn")
		for i in 24: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://addons/ziyuan_level03/evidence/models/"+name+".png")
		print("MODEL_CAPTURE ",name)
	quit()
