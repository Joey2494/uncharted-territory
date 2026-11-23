extends SceneTree
const Model = preload("res://scripts/settings/game_settings.gd")
const Screen = preload("res://scenes/ui/settings_screen.tscn")
const Profile = preload("res://scripts/integration/player_profile.gd")
const Progress = preload("res://scripts/integration/campaign_progress.gd")
var checks := 0
var failures := 0
var live: RefCounted
func _initialize() -> void: run.call_deferred()
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int = 4) -> void:
	for i in count: await process_frame
func wait_scene(path: String) -> void:
	var deadline := Time.get_ticks_msec()+45000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path and root.get_node_or_null("LoadingScreen") == null:
			await frames()
			return
	check(false,"real scene handoff completes: "+path)
func model_checks() -> void:
	var path := "user://settings-contract.cfg"
	var legacy := ConfigFile.new()
	legacy.set_value("audio","volume",0.37)
	legacy.set_value("future","keep",123)
	legacy.save(path)
	var model := Model.new(path)
	model.load_settings()
	check(model.volume == 0.37 and model.music_volume == 0.65 and model.resolution == Vector2i(1280,720) and model.quality == "medium","legacy config retains preferences and supplies new defaults")
	check(model.update({"volume":0.29,"music_volume":0.61,"resolution":Vector2i(960,540),"quality":"high","fullscreen":true,"vsync":false}),"all settings save atomically")
	var restored := Model.new(path)
	restored.load_settings()
	check(restored.snapshot() == model.snapshot(),"every display/audio/quality field round-trips")
	var config := ConfigFile.new()
	config.load(path)
	check(config.get_value("future","keep") == 123,"save preserves unrelated future config keys")
	check(not FileAccess.file_exists(path+".tmp") and FileAccess.file_exists(path+".bak"),"atomic replacement leaves no temp file and retains last valid config")
	model.update({"volume":2.0,"music_volume":NAN,"resolution":Vector2(-1,INF),"quality":"ultra-invalid","fullscreen":"yes","vsync":99})
	check(model.volume == 1.0 and model.music_volume == 0.65 and model.resolution == Vector2i(1280,720) and model.quality == "medium" and not model.fullscreen and model.vsync,"invalid types, NaN and out-of-range values normalize safely")
	var broken := FileAccess.open(path,FileAccess.WRITE)
	broken.store_string("[broken\nnot=config")
	broken.close()
	model.load_settings()
	check(model.recovered_from_backup and model.volume == 0.29 and model.quality == "high","corrupt primary recovers last valid backup")
	var missing := Model.new("user://no-such-directory/settings.cfg")
	check(not missing.update({"volume":0.3}) and missing.last_save_error != OK and missing.status_message.contains("未能保存"),"write failure is reported and never claims the change was saved")
	missing.volume = 0.2
	missing.load_settings()
	check(missing.volume == 0.8,"missing config resets an existing model to safe defaults")
func actual_checks(screen: Control) -> void:
	check(screen.get_node("%VolumeSlider").value == live.volume*100 and screen.get_node("%MusicVolumeSlider").value == live.music_volume*100,"both sliders reflect the shared live model")
	check(screen.get_node("%FullscreenButton").button_pressed == live.fullscreen and screen.get_node("%VsyncButton").button_pressed == live.vsync,"display toggles reflect shared state")
	check(screen.get_node("%ResolutionOption").get_selected_metadata() == live.resolution and screen.get_node("%QualityOption").selected == ["low","medium","high"].find(live.quality),"resolution/quality selections synchronize without writing back")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master"))),maxf(live.volume,0.0001)),"Master gain applies immediately")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music"))),maxf(live.music_volume,0.0001)),"Music gain applies immediately")
func run() -> void:
	Profile.override_path = "user://settings-flow-profile.cfg"
	Progress.override_path = "user://settings-flow-progress.cfg"
	model_checks()
	live = root.get_node("GameSettings").data
	live.update({"fullscreen":false,"vsync":true,"resolution":Vector2i(1280,720),"quality":"medium","volume":0.8,"music_volume":0.65})
	change_scene_to_file("res://scenes/ui/LoadingEntry.tscn")
	await wait_scene("res://Main.tscn")
	var host: Node = current_scene
	var navigation: Node = host.get_node("MenuNavigation")
	check(navigation.settings == live,"main menu uses the persistent service instance")
	navigation.open_settings()
	var screen: Control = navigation.settings_screen
	var mirror := Screen.instantiate()
	root.add_child(mirror)
	mirror.hide()
	mirror.configure(live)
	screen.get_node("%VolumeSlider").value = 36
	screen.get_node("%MusicVolumeSlider").value = 47
	screen.get_node("%VsyncButton").button_pressed = false
	for index in screen.get_node("%ResolutionOption").item_count:
		if screen.get_node("%ResolutionOption").get_item_metadata(index) == Vector2i(960,540):
			screen.get_node("%ResolutionOption").select(index)
			screen.get_node("%ResolutionOption").item_selected.emit(index)
			break
	await frames()
	check(live.resolution == Vector2i(960,540),"main-menu resolution selection updates the model")
	if DisplayServer.get_name() != "headless":
		check(root.size == live.resolution,"resolution immediately resizes the native window")
		root.size = Vector2i(1000,600)
		await frames()
		live.update({"resolution":live.resolution})
		await frames()
		check(root.size == live.resolution,"re-selecting a resolution restores it after an external window resize")
	screen.get_node("%QualityOption").select(0)
	screen.get_node("%QualityOption").item_selected.emit(0)
	check(root.msaa_3d == Viewport.MSAA_DISABLED and root.positional_shadow_atlas_size <= 1024 and root.mesh_lod_threshold >= 4,"low quality changes actual renderer properties")
	actual_checks(screen)
	actual_checks(mirror)
	var new_view := SubViewport.new()
	new_view.msaa_3d = Viewport.MSAA_2X
	root.add_child(new_view)
	await frames()
	check(new_view.msaa_3d == Viewport.MSAA_DISABLED,"new viewport inherits the current quality")
	screen.go_back()
	host._on_run_started()
	host.get_node("RunBindings").tutorial.skip()
	host.set_paused(true)
	navigation.open_settings()
	check(paused and screen.visible and screen.get_node("%BackButton").text == "返回暂停菜单","pause settings remain usable without resuming gameplay")
	screen.get_node("%VolumeSlider").value = 0
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")),"muting while paused takes effect immediately")
	screen.get_node("%VolumeSlider").value = 63
	screen.get_node("%MusicVolumeSlider").value = 0
	check(not AudioServer.is_bus_mute(0) and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")),"music mute remains independent")
	screen.get_node("%MusicVolumeSlider").value = 41
	var real_path: String = live.path
	live.path = "user://no-such-directory/settings.cfg"
	screen.get_node("%VolumeSlider").value = 65
	check(screen.get_node("%StatusLabel").text.contains("未能保存") and mirror.get_node("%StatusLabel").text.contains("未能保存") and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)),0.65),"save failure still applies audio and synchronizes an honest error to every view")
	live.path = real_path
	screen.get_node("%VolumeSlider").value = 63
	screen.get_node("%QualityOption").select(2)
	screen.get_node("%QualityOption").item_selected.emit(2)
	check(root.msaa_3d == Viewport.MSAA_4X and new_view.msaa_3d == Viewport.MSAA_4X,"high quality reaches existing root/preview viewports while paused")
	live.update({"quality":"medium"})
	check(root.msaa_3d == root.get_meta("_settings_quality_base").msaa and new_view.msaa_3d == Viewport.MSAA_2X,"medium restores each viewport's authored quality instead of retaining the previous preset")
	live.update({"quality":"high"})
	actual_checks(mirror)
	if DisplayServer.get_name() != "headless":
		screen.get_node("%FullscreenButton").button_pressed = true
		await frames(8)
		check(root.mode == Window.MODE_FULLSCREEN and screen.get_node("%ResolutionOption").disabled,"fullscreen applies and clearly uses desktop resolution")
		screen.get_node("%FullscreenButton").button_pressed = false
		await frames(8)
		check(root.mode == Window.MODE_WINDOWED and root.size == live.resolution,"windowed dimensions restore after fullscreen")
		check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED,"vsync change reaches DisplayServer")
	for dimensions in [Vector2i(1280,720),Vector2i(960,540),Vector2i(720,720),Vector2i(480,800),Vector2i(640,360)]:
		root.size = dimensions
		await frames(6)
		check(screen.get_global_rect().grow(1).encloses(screen.get_node("%Card").get_global_rect()),"settings card fits "+str(dimensions))
		check(screen.get_node("%BackButton").is_visible_in_tree(),"back action remains outside the scrolling options")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("GODOT_TEST_OUTPUT_DIR").path_join("pause-%dx%d.png" % [dimensions.x,dimensions.y]))
	root.size = Vector2i(1280,720)
	screen.go_back()
	check(paused and host.get_run_state() == host.RunState.PAUSED,"closing settings returns to pause without resuming")
	host.set_paused(false)
	new_view.queue_free()
	for level in [2,3,1]:
		var destination: String = current_scene.LEVEL_PATHS[level]
		current_scene.request_scene_change(destination,{"start_run":level != 1})
		await wait_scene(destination)
		navigation = current_scene.get_node("MenuNavigation")
		check(navigation.settings == live,"level %d retains the same settings object" % level)
		actual_checks(navigation.settings_screen)
		check(root.msaa_3d == Viewport.MSAA_4X,"quality survives scene replacement")
		for viewport in current_scene.find_children("*","SubViewport",true,false): check(viewport.msaa_3d == Viewport.MSAA_4X,"new menu preview inherits persisted quality")
	navigation.open_settings()
	actual_checks(navigation.settings_screen)
	var restored := Model.new(live.path)
	restored.load_settings()
	check(restored.snapshot() == live.snapshot(),"latest values from pause survive a fresh config read")
	mirror.queue_free()
	root.get_node("MusicManager").stop_music()
	current_scene.queue_free()
	await frames()
	print("SETTINGS_SYNC_RESULT ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
