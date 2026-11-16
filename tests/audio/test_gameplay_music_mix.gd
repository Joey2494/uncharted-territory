extends SceneTree
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
	PROFILE.override_path = "user://gameplay-mix-profile-%d.cfg" % Time.get_ticks_usec()
	CAMPAIGN.override_path = "user://gameplay-mix-campaign-%d.cfg" % Time.get_ticks_usec()
	music = root.get_node("MusicManager")
	music.fade_seconds = 0.03
	voice = music.get_node("BackgroundMusic")
	var voice_id := voice.get_instance_id()
	music.track_started.connect(func(source: AudioStream) -> void: starts.append(source))
	change_scene_to_file("res://Main.tscn")
	await frames(10)
	await delay(0.12)
	host = current_scene
	var navigation: Node = host.get_node("MenuNavigation")
	check(starts.size() == 1 and starts.back() == music.playlist.menu and is_equal_approx(voice.volume_db,-8.0),"main menu starts the original song once at its existing gain")
	var position := voice.get_playback_position()
	navigation._open_characters()
	await frames(3)
	check(navigation.character_select.visible and starts.size() == 1 and music.current_context == &"menu","actual character selection retains menu music")
	navigation._character_confirmed(&"knight")
	await frames(3)
	check(navigation.level_select.visible and starts.size() == 1 and voice.get_playback_position() > position,"actual level selection retains the original playback position")
	navigation._launch(&"level1")
	await frames(6)
	host.get_node("RunBindings").tutorial.skip()
	await delay(0.12)
	var source: AudioStreamWAV = music.playlist.level_1
	check(host.get_run_state() == host.RunState.PLAYING and starts.size() == 2 and starts.back() == source,"only actual gameplay switches to Hidden Grove, exactly once")
	check(source.resource_path == "res://assets/audio/bgm/2. The Hidden Grove.wav" and source.get_length() > 50.0,"the requested WAV decodes with its real full duration")
	check(voice.stream != source and source.loop_mode == AudioStreamWAV.LOOP_DISABLED and voice.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,"WAV loops on a runtime copy without altering its imported asset")
	check(is_equal_approx(voice.volume_db,-4.0),"gameplay music uses the increased baseline independent of the saved Music bus preference")
	# WAV playback does not expose MP3's native loop counter. Observe the actual
	# wrap and absence of a finished signal (which would invoke fallback replay).
	var endings: Array[int] = [0]
	voice.finished.connect(func() -> void: endings[0] += 1)
	voice.seek(voice.stream.get_length()-0.08)
	await delay(0.35)
	check(voice.playing and voice.get_playback_position() < 1.0 and endings[0] == 0 and starts.size() == 2,"real WAV playback wraps naturally without finishing, fallback replay or a second voice")
	position = voice.get_playback_position()
	for i in 6:
		music.play_level(1)
		music.play_level(2)
	music.play_level(1)
	await delay(0.12)
	check(starts.size() == 2 and voice.get_playback_position() > position,"repeated level requests preserve the shared gameplay song's progress")
	music.play_context(&"menu")
	music.play_level(1)
	await delay(0.12)
	check(starts.size() == 2 and is_equal_approx(voice.volume_db,music.gameplay_volume_db),"superseded menu request cancels cleanly and restores full gameplay gain")
	position = voice.get_playback_position()
	check(host.request_scene_change("res://scenes/dungeon/Level02Run.tscn",{"character_id":host._player.character_id,"start_run":true}),"direct second-level scene handoff is accepted")
	await frames(12)
	await delay(0.12)
	host = current_scene
	host._player._invulnerability_remaining = 100000.0
	check(host.level_id == 2 and host.get_run_state() == host.RunState.PLAYING and music.current_context == &"level_2","direct scene handoff starts the real second-level run")
	check(starts.size() == 2 and voice.get_instance_id() == voice_id and voice.get_playback_position() > position,"same-song scene handoff neither restarts music nor inserts a menu song")
	check(not host.has_node("Level02Ambience"),"migration keeps independent environmental audio excluded")
	var original_sfx: Node = host.get_node("GameSfx")
	check(original_sfx.get_child_count() == 6 and not original_sfx._players.has(&"final_boss_death"),"second level retains the team's six original effect voices")
	var priority := Node.new()
	priority.process_mode = Node.PROCESS_MODE_PAUSABLE
	host.add_child(priority)
	position = voice.get_playback_position()
	music.set_ambience_duck(priority,true)
	await delay(0.12)
	check(is_equal_approx(voice.volume_db,music.gameplay_volume_db+music.AMBIENCE_DUCK_DB),"BGM priority API applies the configured five-decibel reduction")
	check(starts.size() == 2 and voice.get_playback_position() > position,"priority mixing changes gain without restarting the music")
	host.set_paused(true)
	position = voice.get_playback_position()
	await delay(0.5)
	check(voice.get_playback_position() > position and is_equal_approx(voice.volume_db,music.gameplay_volume_db),"paused priority owners allow uninterrupted BGM to recover")
	host.set_paused(false)
	await delay(0.12)
	check(is_equal_approx(voice.volume_db,music.gameplay_volume_db+music.AMBIENCE_DUCK_DB),"resuming a priority owner reapplies BGM reduction")
	music.set_ambience_duck(priority,false)
	priority.free()
	await delay(0.55)
	check(is_equal_approx(voice.volume_db,music.gameplay_volume_db),"releasing priority restores the original music gain")
	await test_owner_cleanup()
	host.get_node("RunBindings").return_to_menu()
	await frames(12)
	await delay(0.55)
	host = current_scene
	check(host.level_id == 1 and host.get_run_state() == host.RunState.MENU,"return to menu retains the original menu landing state")
	check(starts.size() == 3 and starts.back() == music.playlist.menu and is_equal_approx(voice.volume_db,music.base_volume_db),"return switches to the original menu song once and clears the duck")
	check(voice.get_instance_id() == voice_id and music.get_child_count() == 1 and voice.max_polyphony == 1,"all scene changes retain exactly one bounded background music player")
	paused = false
	music.stop_music()
	current_scene.queue_free()
	await frames(3)
	print("GAMEPLAY_MUSIC_MIX_RESULT %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func test_owner_cleanup() -> void:
	var first := Node.new()
	var second := Node.new()
	root.add_child(first)
	root.add_child(second)
	music.set_ambience_duck(first,true)
	music.set_ambience_duck(second,true)
	music.set_ambience_duck(first,false)
	first.free()
	await delay(0.12)
	check(is_equal_approx(voice.volume_db,music.gameplay_volume_db+music.AMBIENCE_DUCK_DB),"releasing an old ambience owner cannot cancel another live owner's priority")
	second.free()
	await delay(0.55)
	check(is_equal_approx(voice.volume_db,music.gameplay_volume_db) and music._duck_owners.is_empty(),"unexpected owner removal restores music and leaves no stale scene references")

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
