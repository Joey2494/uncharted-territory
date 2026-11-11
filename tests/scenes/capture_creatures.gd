extends SceneTree
## Actual render captures, including the untouched opening combat state.


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var kind := args[0] if args.size() > 0 else "boss"
	var small := args.has("small")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(720, 720) if small else Vector2i(1280, 720))
	var paths := {
		"boss": "res://scenes/bosses/RuinColossusPreview.tscn",
		"crawler": "res://scenes/enemies/RuinCrawlerPreview.tscn",
		"sentinel": "res://scenes/enemies/RuinSentinelPreview.tscn",
		"combat": "res://scenes/dungeon/LevelTwoCombat.tscn",
	}
	var scene: Node3D = load(paths[kind]).instantiate()
	root.add_child(scene)
	current_scene = scene
	if kind == "combat":
		# Do not teleport actors or activate the Boss for the initial-state proof.
		for actor in ["Player", "RuinColossus", "Sentinel", "MeleeEnemy"]:
			scene.get_node("World/" + actor).set_physics_process(false)
	for i in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	var folder := "res://docs/creature-evidence"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var suffix := "small" if small else "wide"
	var path := folder.path_join("%s-%s.png" % [kind, suffix])
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	print("CREATURE_CAPTURE ", path, " ", image.get_size(), " status=", error)
	quit(0 if error == OK else 1)
