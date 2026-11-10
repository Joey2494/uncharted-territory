extends "res://tests/dungeon/test_campaign_flow.gd"
## 用可见渲染器和回归测试的同一条路线采集实机画面。

var output := "user://campaign_review"
var resolution := Vector2i(1280, 720)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		if arg == "--full-hd":
			resolution = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(output)
	start_capture.call_deferred()


func start_capture() -> void:
	root.size = resolution
	await run()


func checkpoint(label: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	check(shot.get_size() == resolution, "%s 实际渲染尺寸 %s" % [label, shot.get_size()])
	check(shot.save_png(output.path_join(label + ".png")) == OK, "保存 %s" % label)
