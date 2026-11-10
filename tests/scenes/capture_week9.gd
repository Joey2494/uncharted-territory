extends SceneTree
## Deterministic visual QA, not a human playtest.


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var prototype := args.has("prototype")
	var small := args.has("small")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(720, 720) if small else Vector2i(1280, 720))
	var scene: Node3D = load("res://scenes/dungeon/LevelTwoCombat.tscn" if prototype else "res://Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in range(5):
		await physics_frame
	if prototype:
		var boss := scene.get_node("World/RuinColossus")
		var player := scene.get_node("World/Player")
		scene.get_node("World/Sentinel").set_physics_process(false)
		scene.get_node("World/MeleeEnemy").set_physics_process(false)
		boss.set_physics_process(false)
		player.global_position = Vector3(0, 0.05, -3)
		boss.state = boss.State.CHASE
		boss.begin_attack(boss.Attack.SHOCKWAVE)
	else:
		scene._on_run_started()
		var inventory := scene.get_node("DungeonTest/Player/ItemInventory")
		inventory.grant_reward("visual_qa", {2: 1, 3: 1}, 52)
		inventory.try_use_guard()
		inventory.try_equip(3)
	for i in range(60):
		await process_frame
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("WEEK9_CAPTURE_DIR")
	if directory.is_empty():
		directory = ProjectSettings.globalize_path("user://week9-captures")
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("%s-%s.png" % [
		"prototype" if prototype else "main", "small" if small else "wide"]
	)
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	print("CAPTURE ", path, " ", image.get_size(), " status=", error)
	quit(0 if error == OK else 1)
