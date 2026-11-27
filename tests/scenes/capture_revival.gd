extends SceneTree
## Real viewport captures with isolated profile and deterministic demonstration funds.
const Profile = preload("res://scripts/integration/player_profile.gd")
const Progress = preload("res://scripts/integration/campaign_progress.gd")
const Catalog = preload("res://data/item_catalog.gd")
var host
var output := "res://docs/revival-evidence/"
func _initialize() -> void: run.call_deferred()
func frames(n := 5) -> void:
	for i in n: await physics_frame
func capture(label: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + label + ".png")
	print("CAPTURE ", label)
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	Profile.override_path = "user://revival-visual-" + str(Time.get_ticks_usec()) + ".cfg"
	Progress.override_path = "user://revival-visual-progress-" + str(Time.get_ticks_usec()) + ".cfg"
	Profile.ensure_loaded()
	Profile.coins = 1500
	Profile.inventory = {Catalog.REVIVAL_CARD:1, Catalog.HEALTH_POTION:2, Catalog.ENERGY_POTION:1}
	Profile.save()
	change_scene_to_file("res://scenes/dungeon/Level03Run.tscn")
	await frames(12)
	host = current_scene
	host._on_run_started()
	host._commerce.open_shop()
	await capture("shop")
	host._commerce.close_all()
	host._commerce.open_backpack()
	host._commerce.backpack._select_item(&"revival_card")
	await capture("backpack")
	host._commerce.close_all()
	host._player.take_damage(999)
	while host._run_state == host.RunState.DYING: await physics_frame
	await capture("revival-choice")
	DisplayServer.window_set_size(Vector2i(720, 720))
	await capture("revival-choice-square")
	host._use_revival_card()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await frames()
	var level = host._dungeon
	level._revival_revealed = true
	level._refresh_world()
	host._player.global_position = Vector3(-46, 0.05, -24)
	level.get_node("Camera3D").reset_follow()
	var card: Node3D = level.get_node("Supplies/ServiceRevivalCard")
	card.set_process(false)
	card.get_node("Visuals").rotation.y = 0.55
	await capture("third-card")
	card.get_node("Visuals").rotation.y = 1.1
	await capture("third-card-edge")
	change_scene_to_file("res://scenes/dungeon/Level04Run.tscn")
	await frames(12)
	host = current_scene
	host._on_run_started()
	level = host._dungeon
	level.combat._cleared["B"] = true
	level.combat._cleared["D"] = true
	host._player.global_position = level.layout.room_center("G") + Vector3(0, 0.05, 1)
	level.get_node("Camera3D").reset_follow()
	await frames(50)
	await capture("fourth-mail-choice")
	paused = false
	host.queue_free()
	root.get_node("MusicManager").stop_music()
	await frames()
	quit()
