extends SceneTree
func _initialize() -> void:
	var profile = preload("res://scripts/integration/player_profile.gd")
	profile.override_path = "res://.godot/fixture_integration_capture.cfg"
	if FileAccess.file_exists(profile.override_path): DirAccess.remove_absolute(profile.override_path)
	profile.ensure_loaded()
	run.call_deferred()
func frames(n: int = 8) -> void:
	for i in n: await process_frame
func capture(label: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/integrated_%s.png" % label)
func run() -> void:
	preload("res://scripts/integration/campaign_progress.gd").override_path = "res://.godot/visual_progress.cfg"
	change_scene_to_file("res://Main.tscn")
	await frames()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await capture("menu")
	var main := current_scene
	main._start_screen.select_character("astra")
	await capture("locked_character")
	main._start_screen.select_character("knight")
	main._on_run_started()
	await capture("tutorial")
	main.get_node("RunBindings/TutorialController").skip()
	await capture("hud")
	main.set_paused(true)
	await capture("pause")
	main._commerce.open_shop()
	await capture("shop")
	main._commerce.close_panel()
	main.get_node("MenuNavigation").open_settings()
	await capture("settings")
	main.get_node("MenuNavigation")._close_settings()
	main.set_paused(false)
	change_scene_to_file("res://scenes/dungeon/Level02Run.tscn")
	await frames()
	main = current_scene
	main._on_run_started()
	await capture("level2")
	quit()
