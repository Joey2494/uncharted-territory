extends SceneTree
const CATALOG = preload("res://scenes/player/character_catalog.gd")

func _initialize() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	run.call_deferred()

func run() -> void:
	for id in CATALOG.IDS:
		CATALOG.selected_id = id
		var main := load("res://Main.tscn").instantiate() as Node3D
		root.add_child(main)
		for i in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/character_menu_%s.png" % id)
		main._on_run_started()
		for i in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/character_game_%s.png" % id)
		main.get_node("DungeonTest/Player/CharacterAbility").try_activate()
		for i in 25:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/character_ability_%s.png" % id)
		main.free()
		await process_frame
	quit()
