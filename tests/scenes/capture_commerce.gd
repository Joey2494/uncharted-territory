extends SceneTree
## Controlled test funds are granted only here, never in the first-level game.


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var kind := args[0] if args.size() > 0 else "shop"
	var small := args.has("small")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(720, 720) if small else Vector2i(1280, 720))
	var path := "res://scenes/dungeon/LevelTwoCombat.tscn" if kind == "combat" else "res://Main.tscn"
	var scene: Node3D = load(path).instantiate()
	root.add_child(scene)
	current_scene = scene
	var ui := scene.get_node("CommerceLayer")
	if kind in ["hud", "shop", "backpack", "pause"]:
		scene._on_run_started()
		var world := scene.get_node("DungeonTest")
		for actor in ["Player", "RuinGatekeeper", "MeleeEnemy"]:
			world.get_node(actor).set_physics_process(false)
		var inventory := world.get_node("Player/ItemInventory")
		if kind != "hud":
			inventory.add_gold(120, "capture_only")
			ui.open_shop()
			ui.shop.purchase_requested.emit(&"health_potion")
			ui.shop.purchase_requested.emit(&"guard_rune")
		if kind == "backpack":
			ui.close_all()
			ui.open_backpack()
		elif kind == "pause":
			ui.close_all()
			ui.open_pause()
	elif kind == "title_shop":
		ui.open_menu_shop()
	elif kind == "combat":
		for actor in ["Player", "RuinColossus", "Sentinel", "MeleeEnemy"]:
			scene.get_node("World/" + actor).set_physics_process(false)
	for i in range(30):
		await process_frame
	if args.has("bottom"):
		ui.shop.get_node("Center/Card/Padding/Content/ProductsScroll").scroll_vertical = 10000
		for i in range(5):
			await process_frame
	await RenderingServer.frame_post_draw
	var folder := "res://docs/commerce-evidence"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var suffix := "small" if small else "wide"
	if args.has("bottom"):
		suffix += "-bottom"
	var destination := folder.path_join("%s-%s.png" % [kind, suffix])
	var image := root.get_texture().get_image()
	var error := image.save_png(destination)
	print("COMMERCE_CAPTURE ", destination, " ", image.get_size(), " status=", error)
	ui.close_all()
	await process_frame
	scene.queue_free()
	for i in range(3):
		await process_frame
	quit(0 if error == OK else 1)
