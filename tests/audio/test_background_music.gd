extends SceneTree
const SETTINGS = preload("res://scripts/settings/game_settings.gd")
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const CAMPAIGN = preload("res://scripts/integration/campaign_progress.gd")
var checks := 0
var failures := 0
var starts: Array[AudioStream] = []
var music: Node
var voice: AudioStreamPlayer
var host: Node

func _initialize() -> void: run.call_deferred()

func run() -> void:
	PROFILE.override_path = "user://music-profile-%d.cfg" % Time.get_ticks_usec()
	CAMPAIGN.override_path = "user://music-campaign-%d.cfg" % Time.get_ticks_usec()
	music = root.get_node("MusicManager")
	music.fade_seconds = 0.02
	voice = music.get_node("BackgroundMusic")
	music.track_started.connect(func(source: AudioStream) -> void: starts.append(source))
	await test_player()
	test_settings()
	await test_game_flow()
	paused = false
	music.stop_music()
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames(3)
	print("BACKGROUND_MUSIC_RESULT %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func test_player() -> void:
	var playlist: Resource = music.playlist
	var source: AudioStreamMP3 = playlist.menu
	check(playlist.level_1.resource_path == "res://assets/audio/bgm/2. The Hidden Grove.wav" and playlist.level_2 == playlist.level_1,"both gameplay contexts use the requested Hidden Grove WAV")
	check(playlist.victory == source and source.resource_path.ends_with("the-hall-of-the-kingdom-ii_8702604f.mp3"),"menu and settlement retain the original song")
	var shared := playlist.duplicate()
	shared.level_1 = source
	shared.level_2 = source
	shared.victory = source
	music.playlist = shared
	check(source.get_length()>1.0,"provided MP3 decodes with a valid duration")
	music.play_context(&"menu")
	await delay(0.12)
	check(voice.playing and voice.stream!=source and voice.stream.loop and not source.loop,"runtime copy loops without changing the imported source")
	check(music.get_child_count()==1 and voice.max_polyphony==1 and voice.bus==&"Music","one bounded music voice on its dedicated bus")
	var first_position := voice.get_playback_position()
	for context in [&"menu",&"level_1",&"level_2",&"victory",&"menu"]:
		for repeat in 4: music.play_context(context)
	await delay(0.12)
	check(starts.size()==1 and voice.get_playback_position()>first_position,"shared-track context changes do not restart or stack music")
	paused = true
	first_position = voice.get_playback_position()
	await delay(0.12)
	check(voice.playing and not voice.stream_paused and voice.get_playback_position()>first_position,"persistent music continues while the scene tree is paused")
	paused = false
	var playback := voice.get_stream_playback()
	var loops := playback.get_loop_count()
	voice.seek(voice.stream.get_length()-0.08)
	await delay(0.35)
	check(voice.playing and voice.get_stream_playback().get_loop_count()>loops and starts.size()==1,"real MP3 playback wraps at the end without starting a second voice")
	# Distinct fixtures also exercise rapid requests that supersede a pending fade.
	var fixtures := playlist.duplicate()
	fixtures.level_1 = silent_track(0.40)
	fixtures.level_2 = silent_track(0.50)
	fixtures.victory = silent_track(0.60)
	music.playlist = fixtures
	music.play_level(1)
	music.play_level(2)
	music.play_context(&"menu")
	await delay(0.12)
	check(starts.size()==1 and is_equal_approx(voice.volume_db,music.base_volume_db),"rapid switch back cancels pending tracks and restores the playing song")
	music.play_level(1)
	await delay(0.12)
	check(starts.size()==2 and starts.back()==fixtures.level_1 and voice.stream is AudioStreamWAV and voice.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"a different track fades in with native WAV looping")
	music.play_context(&"victory")
	music.play_level(2)
	await delay(0.12)
	check(starts.size()==3 and starts.back()==fixtures.level_2 and not starts.has(fixtures.victory),"latest scene request wins without playing an obsolete victory cue")
	music.playlist = playlist
	music.play_context(&"menu")
	await delay(0.12)

func test_settings() -> void:
	var legacy := ConfigFile.new()
	legacy.set_value("audio","volume",0.37)
	legacy.save("user://music-legacy-settings.cfg")
	var settings := SETTINGS.new("user://music-legacy-settings.cfg")
	settings.load_settings()
	check(is_equal_approx(settings.volume,0.37) and is_equal_approx(settings.music_volume,0.65),"old settings preserve master volume and gain the default music volume")
	settings.music_volume = 0.0
	settings.apply(root)
	var bus := AudioServer.get_bus_index(&"Music")
	check(AudioServer.is_bus_mute(bus) and not AudioServer.is_bus_mute(0) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)),0.37),"music mute leaves effects' master level unchanged")
	check(voice.playing,"muting music preserves its playback state")
	settings.music_volume = 0.71
	settings.apply(root)
	check(not AudioServer.is_bus_mute(bus) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(bus)),0.71),"music gain restores independently of Master")
	check(settings.save_settings(),"independent audio settings save successfully")
	var restored := SETTINGS.new(settings.path)
	restored.load_settings()
	check(is_equal_approx(restored.volume,0.37) and is_equal_approx(restored.music_volume,0.71),"both audio controls persist across settings instances")
	legacy.set_value("audio","music_volume",99.0)
	legacy.save("user://music-invalid-settings.cfg")
	var invalid := SETTINGS.new("user://music-invalid-settings.cfg")
	invalid.load_settings()
	check(invalid.music_volume==1.0,"out-of-range saved music volume is clamped")
	legacy.set_value("audio","music_volume","invalid")
	legacy.save("user://music-invalid-settings.cfg")
	invalid = SETTINGS.new("user://music-invalid-settings.cfg")
	invalid.load_settings()
	check(is_equal_approx(invalid.music_volume,0.65),"invalid saved music volume falls back safely")

func test_game_flow() -> void:
	var voice_id := voice.get_instance_id()
	var start_count := starts.size()
	change_scene_to_file("res://Main.tscn")
	await frames(10)
	host = current_scene
	check(music.current_context==&"menu" and starts.size()==start_count,"actual main menu reuses the persistent song")
	var navigation: Node = host.get_node("MenuNavigation")
	navigation.open_settings()
	var screen: Control = navigation.settings_screen
	screen.get_node("%MusicVolumeSlider").value = 0
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")) and not AudioServer.is_bus_mute(0),"settings slider mutes only background music")
	screen.get_node("%MusicVolumeSlider").value = 35
	check(is_equal_approx(navigation.settings.music_volume,0.35) and screen.get_node("%MusicVolumeLabel").text.contains("35%"),"settings slider updates the live mix and percentage")
	for dimensions in [Vector2i(1280,720),Vector2i(800,800),Vector2i(480,800),Vector2i(640,360)]:
		root.size = dimensions
		await frames(4)
		check(screen.get_global_rect().grow(1).encloses(screen.get_node("%Card").get_global_rect()),"expanded settings card fits %s" % dimensions)
	screen.go_back()
	host._on_run_started()
	host.get_node("RunBindings").tutorial.skip()
	await frames(4)
	check(music.current_context==&"level_1" and starts.size()==start_count+1,"starting level one switches from menu to gameplay music exactly once")
	host._on_exit_reached()
	check(music.current_context==&"level_1","unconfirmed exits cannot trigger victory music")
	var sfx: Node = host.get_node("GameSfx")
	var cues: Array[StringName] = []
	sfx.cue_played.connect(func(cue: StringName) -> void: cues.append(cue))
	var unchanged := sfx.get_child_count()==6
	for player: AudioStreamPlayer in sfx.get_children():
		unchanged = unchanged and player.bus==&"Master" and player.max_polyphony==2
	check(unchanged,"all six existing effects retain their bus and polyphony")
	check(host._player.get_node("EnergyShock").try_cast() and cues.count(&"spell")==1,"real spell still triggers its original sound once")
	check(not host._player.get_node("EnergyShock").try_cast() and cues.count(&"spell")==1,"rejected spell still cannot duplicate its sound")
	check(host._player.take_damage(host._player.shield + 1) and host._player.hp == host._player.max_hp - 1 and cues.count(&"hurt")==1,"accepted damage still plays the original hurt cue")
	host._items.potion_count = 1
	check(host._items.try_use_potion() and host._player.hp == host._player.max_hp and cues.count(&"item_use")==1,"successful healing retains its gameplay and sound")
	check(host.set_paused(true),"existing pause state remains available")
	await delay(0.12)
	check(not sfx.can_process() and voice.can_process() and not voice.stream_paused,"paused effects and continuous music keep independent lifecycles")
	host.set_paused(false)
	host._player._invulnerability_remaining = 1000.0
	await go(Vector3(0,0.05,-23))
	host._dungeon.get_node("MeleeEnemy").take_damage(999)
	await delay(1.2)
	await go(Vector3(22,0.05,-23))
	host._boss.take_damage(999)
	await delay(1.2)
	check(host._run_state==host.RunState.PLAYING and music.current_context==&"level_1","Boss death alone preserves the level theme until the real exit")
	await go(Vector3(30,0.05,-45))
	await delay(0.12)
	check(host._run_state==host.RunState.VICTORY and music.current_context==&"victory","physical level-one exit selects victory music")
	host._on_exit_reached()
	check(starts.size()==start_count+2,"repeated terminal events cannot replay the victory song")
	host.advance_to_level02()
	await frames(10)
	host = current_scene
	check(host.level_id==2 and host._run_state==host.RunState.PLAYING and music.current_context==&"level_2","next-level settlement action starts gameplay and its level music directly")
	check(starts.size()==start_count+3 and starts.back()==music.playlist.level_2,"next-level handoff switches once without an intermediate menu track")
	check(voice.get_instance_id()==voice_id and is_equal_approx(host.get_node("MenuNavigation").settings.music_volume,0.35),"scene reload keeps one voice and restores the independent music preference")
	host._player._invulnerability_remaining = 1000.0
	check(music.current_context==&"level_2","actual level two selects its own music context")
	await go(Vector3(0,0.05,-26))
	for id in ["Hub1","Hub2"]: host._dungeon.get_node("Enemies/"+id).take_damage(999)
	await delay(1.2)
	await go(host._dungeon.get_node("Regions/Relay").global_position + Vector3.UP * 0.05)
	for id in ["Relay1","Relay2"]: host._dungeon.get_node("Enemies/"+id).take_damage(999)
	await go(host._dungeon.get_node("Devices/Relay").global_position + Vector3(0,0.05,1.35))
	host._items.try_interact_nearest()
	await delay(1.2)
	await go(host._dungeon.get_node("Regions/Antechamber").global_position + Vector3.UP * 0.05)
	for id in ["Antechamber1","Antechamber2","Antechamber3"]: host._dungeon.get_node("Enemies/"+id).take_damage(999)
	await delay(1.2)
	await go(host._dungeon.get_node("Regions/Boss").global_position + Vector3(0,0.05,4))
	host._boss.take_damage(999)
	await delay(1.2)
	await go(host._dungeon.get_node("ExitArea").global_position * Vector3(1,0,1) + Vector3.UP * 0.05)
	await delay(0.12)
	check(host._run_state==host.RunState.VICTORY and music.current_context==&"victory","physical level-two exit selects victory music")
	host.get_node("RunBindings").return_to_menu()
	await frames(10)
	host = current_scene
	check(host.level_id==1 and music.current_context==&"menu" and voice.get_instance_id()==voice_id and starts.size()==start_count+4,"return to main menu reuses settlement music on the same persistent voice")

func silent_track(seconds: float) -> AudioStreamWAV:
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 44100
	var samples := PackedByteArray()
	samples.resize(roundi(seconds*wave.mix_rate)*2)
	samples.fill(0)
	wave.data = samples
	return wave
func go(point: Vector3) -> void:
	host._player.global_position = point
	host._player.velocity = Vector3.ZERO
	await frames(6)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func delay(seconds: float) -> void:
	await create_timer(seconds).timeout
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
