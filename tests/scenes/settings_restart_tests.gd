extends SceneTree
## Writer and reader MUST run in separate engine processes sharing an isolated APPDATA.
const Profile = preload("res://scripts/integration/player_profile.gd")
const Progress = preload("res://scripts/integration/campaign_progress.gd")
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL "+label)
func run() -> void:
	Profile.override_path = "user://restart-profile.cfg"
	Progress.override_path = "user://restart-progress.cfg"
	var settings: RefCounted = root.get_node("GameSettings").data
	var writing := "--write" in OS.get_cmdline_user_args()
	if not writing:
		check(settings.fullscreen and not settings.vsync and settings.resolution == Vector2i(960,540) and settings.quality == "high" and is_equal_approx(settings.volume,0.23) and is_equal_approx(settings.music_volume,0.41),"autoload reads all saved fields before the loading entry or main menu exists")
		check(root.msaa_3d == Viewport.MSAA_4X and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)),0.23),"startup applies quality and audio before gameplay")
		if DisplayServer.get_name() != "headless": check(root.mode == Window.MODE_FULLSCREEN,"startup restores native fullscreen")
	change_scene_to_file("res://scenes/ui/LoadingEntry.tscn")
	var deadline := Time.get_ticks_msec()+45000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://Main.tscn" and root.get_node_or_null("LoadingScreen") == null: break
	var navigation: Node = current_scene.get_node("MenuNavigation")
	navigation.open_settings()
	var screen: Control = navigation.settings_screen
	if writing:
		for index in screen.get_node("%ResolutionOption").item_count:
			if screen.get_node("%ResolutionOption").get_item_metadata(index) == Vector2i(960,540):
				screen.get_node("%ResolutionOption").select(index)
				screen.get_node("%ResolutionOption").item_selected.emit(index)
				break
		screen.get_node("%VolumeSlider").value = 23
		screen.get_node("%MusicVolumeSlider").value = 41
		screen.get_node("%VsyncButton").button_pressed = false
		screen.get_node("%QualityOption").select(2)
		screen.get_node("%QualityOption").item_selected.emit(2)
		screen.get_node("%FullscreenButton").button_pressed = true
		check(settings.last_save_error == OK and FileAccess.file_exists(settings.path),"UI changes save before process exit")
	else:
		check(screen.get_node("%FullscreenButton").button_pressed and not screen.get_node("%VsyncButton").button_pressed and screen.get_node("%QualityOption").selected == 2,"recreated main-menu controls display saved settings")
		check(screen.get_node("%ResolutionOption").get_selected_metadata() == Vector2i(960,540) and screen.get_node("%VolumeSlider").value == 23 and screen.get_node("%MusicVolumeSlider").value == 41,"recreated resolution and volume controls display saved values")
		screen.go_back()
		current_scene._on_run_started()
		current_scene.get_node("RunBindings").tutorial.skip()
		current_scene.set_paused(true)
		navigation.open_settings()
		check(paused and screen.get_node("%VolumeSlider").value == 23 and screen.get_node("%QualityOption").selected == 2,"pause settings also retain values after an actual process restart")
	for i in 10: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("GODOT_TEST_OUTPUT_DIR").path_join("restart-"+("write" if writing else "read")+".png"))
	var output := FileAccess.open(OS.get_environment("GODOT_TEST_OUTPUT_DIR").path_join("restart-"+("write" if writing else "read")+".json"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"settings":settings.snapshot(),"window_mode":root.mode,"window_size":root.size,"msaa":root.msaa_3d,"checks":checks,"failures":failures},"\t"))
	output.close()
	root.get_node("MusicManager").stop_music()
	paused = false
	current_scene.queue_free()
	await process_frame
	print("SETTINGS_RESTART_RESULT ","writer" if writing else "reader"," ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
