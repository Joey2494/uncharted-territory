extends SceneTree
const Profile = preload("res://scripts/integration/player_profile.gd")
const Progress = preload("res://scripts/integration/campaign_progress.gd")
const Catalog = preload("res://data/enemy_codex.gd")
var host
var controller
func _initialize() -> void: run.call_deferred()
func frames(n := 8) -> void:
	for i in n: await physics_frame
func capture(name: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/enemy-codex-evidence/" + name + ".png")
	print("CAPTURE ", name)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/enemy-codex-evidence"))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	Profile.override_path = "user://codex-capture-" + str(Time.get_ticks_usec()) + ".cfg"
	Progress.override_path = Profile.override_path + ".progress"
	Profile.ensure_loaded()
	Profile.save()
	change_scene_to_file("res://Main.tscn")
	await frames(15)
	host = current_scene
	controller = host.get_node("EnemyCodexController")
	await capture("menu-entry")
	controller.open_library()
	controller.screen.select_enemy("witch")
	await capture("locked-entry")
	controller.close()
	host._on_run_started()
	host._player.global_position = host._dungeon.get_node("Regions/Crossroads").global_position + Vector3(0, 0.05, 0)
	await frames()
	await capture("first-encounter")
	controller.close()
	Profile.discovered_enemies.assign(Catalog.IDS)
	controller.open_library()
	controller.screen.select_enemy("witch")
	await capture("witch-dossier")
	controller.screen._filter(2)
	controller.screen.select_enemy("scorpion")
	await capture("scorpion-dossier")
	DisplayServer.window_set_size(Vector2i(720, 720))
	controller.screen._filter(4)
	controller.screen.select_enemy("witch")
	await capture("square-dossier")
	DisplayServer.window_set_size(Vector2i(720, 1080))
	await capture("portrait-dossier")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for id in ["bone_axe", "dawn_shade", "raven_roost", "broodling"]:
		controller.screen.select_enemy(id)
		await capture(id)
	controller.close()
	host.set_paused(true)
	await capture("pause-entry")
	paused = false
	host.queue_free()
	root.get_node("MusicManager").stop_music()
	await frames()
	quit()
