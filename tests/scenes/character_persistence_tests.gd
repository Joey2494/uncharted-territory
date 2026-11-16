extends SceneTree
## write/resume are separate engine processes using the same isolated test directory.
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
const CHARACTERS = preload("res://scenes/player/character_catalog.gd")
const PROFILE_PATH := "user://selected-character-profile.cfg"
const CAMPAIGN_PATH := "user://selected-character-campaign.cfg"
const EXPECTED_PATH := "user://selected-character-expected.cfg"
var host: Node
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var phase := "unit"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
	match phase:
		"unit": test_profile()
		"write", "resume":
			PROFILE.override_path = PROFILE_PATH
			PROGRESS.override_path = CAMPAIGN_PATH
			if phase=="write": await write_phase()
			else: await resume_phase()
		"failure": await confirmation_failure()
		_: check(false,"unknown test phase: "+phase)
	paused = false
	root.get_node("MusicManager").stop_music()
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames(3)
	print("CHARACTER_PERSISTENCE_RESULT phase=%s %d checks, %d failures" % [phase,checks,failures])
	quit(1 if failures else 0)

func test_profile() -> void:
	var prefix := "user://selection-unit-%d-" % Time.get_ticks_usec()
	load_profile(prefix+"fresh.cfg")
	check(PROFILE.get_selected_character()=="knight" and PROFILE.unlocked==["knight"],"new profile defaults to the free Knight")
	write_profile(prefix+"legacy.cfg",["lan","astra"],"",false)
	load_profile(prefix+"legacy.cfg")
	check(PROFILE.get_selected_character()=="knight" and PROFILE.coins==400 and PROFILE.owns("lan") and PROFILE.owns("astra"),"old profile without a selection preserves wallet and ownership")
	check(PROFILE.set_selected_character("lan"),"an owned character can be confirmed")
	var disk := ConfigFile.new()
	disk.load(PROFILE.override_path)
	check(disk.get_value("profile","selected_character")=="lan","confirmed choice is immediately persisted")
	check(disk.get_value("profile","coins")==400 and disk.get_value("cosmetics","cape")=="jade","selection save preserves currency and unrelated profile fields")
	var before := FileAccess.get_file_as_string(PROFILE.override_path)
	check(not PROFILE.set_selected_character("iron") and PROFILE.get_selected_character()=="lan","locked selection cannot replace the confirmed role")
	check(not PROFILE.set_selected_character("invalid") and FileAccess.get_file_as_string(PROFILE.override_path)==before,"invalid selection cannot change the profile file")
	PROFILE.set_coins(450)
	PROFILE.unlock_character("iron")
	disk.load(PROFILE.override_path)
	check(PROFILE.get_selected_character()=="lan" and disk.get_value("profile","selected_character")=="lan" and PROFILE.coins==300,"wallet updates and purchases retain the confirmed role")
	for id in ["knight","lan","iron","astra"]:
		check(PROFILE.set_selected_character(id) and PROFILE.get_selected_character()==id,"owned role can be selected and saved: "+id)
	var campaign := PROGRESS.new(prefix+"campaign.cfg")
	campaign.complete(1)
	campaign.mark_played(1)
	var campaign_before := FileAccess.get_file_as_string(campaign.path)
	PROFILE.set_selected_character("lan")
	check(FileAccess.get_file_as_string(campaign.path)==campaign_before and campaign.is_unlocked(&"level2"),"character selection does not alter campaign recency or unlock data")
	for sample in [
		{"name":"unknown","selected":"invalid","owned":["lan"]},
		{"name":"wrong-type","selected":73,"owned":["lan"]},
		{"name":"locked","selected":"iron","owned":["lan"]},
		{"name":"missing-owner","selected":"lan","owned":[]},
	]:
		var path := prefix+String(sample.name)+".cfg"
		write_profile(path,sample.owned,sample.selected)
		var saved_before := FileAccess.get_file_as_string(path)
		load_profile(path)
		check(PROFILE.get_selected_character()=="knight" and PROFILE.owns("knight"),"invalid or unavailable saved role falls back safely: "+String(sample.name))
		check(FileAccess.get_file_as_string(path)==saved_before and PROFILE.coins==400,"loading fallback leaves saved ownership and currency untouched")
	write_profile(prefix+"valid.cfg",["lan"],"lan")
	load_profile(prefix+"valid.cfg")
	check(PROFILE.get_selected_character()=="lan","valid persisted role is read back from a fresh profile path")

func write_phase() -> void:
	write_profile(PROFILE_PATH,[],"",false)
	var campaign := ConfigFile.new()
	campaign.set_value("campaign","completed",["level1"])
	campaign.set_value("campaign","played",[])
	check(campaign.save(CAMPAIGN_PATH)==OK,"isolated campaign fixture saved")
	await boot()
	check(host._player.character_id=="knight" and host._start_screen.selected_character_id=="knight","legacy startup uses Knight before any confirmed selection")
	host._start_screen.start_button.pressed.emit()
	var nav: Node = host.get_node("MenuNavigation")
	var selector: Control = nav.character_select
	selector.show_selection("lan")
	selector.get_node("%ConfirmButton").pressed.emit()
	check(selector.visible and PROFILE.get_selected_character()=="knight","browsing and attempting a locked character cannot persist it")
	selector.get_node("%UnlockButton").pressed.emit()
	check(PROFILE.owns("lan") and PROFILE.coins==300 and PROFILE.get_selected_character()=="knight","existing unlock transaction charges once without auto-selecting")
	selector.back_requested.emit()
	check(host._start_screen.visible and PROFILE.get_selected_character()=="knight","cancelling character browsing keeps the saved choice")
	host._start_screen.start_button.pressed.emit()
	selector.show_selection("lan")
	for i in 3: selector.get_node("%ConfirmButton").pressed.emit()
	check(nav.level_select.visible and not selector.visible and PROFILE.get_selected_character()=="lan","confirmation saves Lan and opens the existing level picker once")
	var disk := ConfigFile.new()
	disk.load(PROFILE_PATH)
	check(disk.get_value("profile","selected_character")=="lan" and disk.get_value("cosmetics","cape")=="jade","Lan is durable before gameplay and unrelated profile data remains intact")
	nav.level_select.get_level_button(&"level1").pressed.emit()
	await frames(10)
	host = current_scene
	host.get_node("RunBindings").tutorial.skip()
	check(host.get_run_state()==host.RunState.PLAYING and host._player.character_id=="lan" and CHARACTERS.selected_id=="lan","confirmed Lan enters actual gameplay")
	check(is_lan_model() and host._player.max_hp==5 and host._player.max_shield==1 and is_equal_approx(host._player.max_energy,50),"Lan model and base stats agree with the selected role")
	var expected := ConfigFile.new()
	expected.set_value("profile","coins",PROFILE.coins)
	expected.set_value("profile","characters",PROFILE.unlocked)
	check(expected.save(EXPECTED_PATH)==OK,"expectations saved before closing the first process")
	print("WRITE_PHASE_READY_FOR_RESTART selected=lan actual_level=",host.level_id)

func resume_phase() -> void:
	check(FileAccess.file_exists(EXPECTED_PATH),"previous process completed the write phase")
	check(CHARACTERS.selected_id=="knight","second engine process begins with fresh in-memory character defaults")
	check(PROFILE.get_selected_character()=="lan","startup reads the saved Lan choice")
	await boot()
	check(host._player.character_id=="lan" and host._start_screen.selected_character_id=="lan" and CHARACTERS.selected_id=="lan","startup restores Lan before player creation and menu initialization")
	check(is_lan_model() and host._player.max_shield==1 and is_equal_approx(host._player.max_energy,50),"restored player uses Lan's model and stats before Continue")
	var expected := ConfigFile.new()
	expected.load(EXPECTED_PATH)
	check(PROFILE.coins==expected.get_value("profile","coins") and PROFILE.unlocked==expected.get_value("profile","characters"),"restart retains wallet and character ownership")
	var nav: Node = host.get_node("MenuNavigation")
	check(nav.progress.get_last_played_level()==&"level1" and nav.progress.is_unlocked(&"level2"),"restoring the character preserves recent level and level unlocks")
	var actor_id: int = host._player.get_instance_id()
	host._start_screen.get_node("%ContinueButton").pressed.emit()
	await frames(10)
	host = current_scene
	check(host.level_id==1 and host.get_run_state()==host.RunState.PLAYING and host._player.character_id=="lan","Continue after a real process restart still plays Lan")
	check(host._player.get_instance_id()==actor_id and is_lan_model(),"Continue uses the already restored Lan without replacing it with Knight")
	host.get_node("RunBindings").return_to_menu()
	await frames(10)
	host = current_scene
	host._start_screen.start_button.pressed.emit()
	nav = host.get_node("MenuNavigation")
	check(nav.character_select.get_selected_id()=="lan","reopened character page highlights the restored choice")
	nav.character_select.show_selection("knight")
	nav.character_select.back_requested.emit()
	check(PROFILE.get_selected_character()=="lan" and host._start_screen.selected_character_id=="lan","previewing Knight and cancelling cannot erase the saved Lan choice")
	print("RESUME_AFTER_PROCESS_RESTART selected=",PROFILE.get_selected_character()," continued_role=lan")

func confirmation_failure() -> void:
	PROFILE.override_path = "user://missing-selection-folder/profile.cfg"
	PROGRESS.override_path = "user://selection-failure-campaign.cfg"
	await boot()
	host._start_screen.start_button.pressed.emit()
	var nav: Node = host.get_node("MenuNavigation")
	var selector: Control = nav.character_select
	selector.get_node("%ConfirmButton").pressed.emit()
	check(selector.visible and not nav.level_select.visible and not selector._confirm_sent,"failed save leaves the character page available for retry")
	check(selector.get_node("%StatusLabel").text.contains("存档失败") and PROFILE.get_selected_character()=="knight","failed save reports its error and preserves the previous choice")
	PROFILE.override_path = "user://selection-retry-profile-%d.cfg" % Time.get_ticks_usec()
	selector.get_node("%ConfirmButton").pressed.emit()
	check(nav.level_select.visible and not selector.visible and FileAccess.file_exists(PROFILE.override_path),"retry proceeds normally once a writable profile path is available")

func load_profile(path: String) -> void:
	PROFILE.override_path = path
	PROFILE.ensure_loaded()
func write_profile(path: String, owned: Array, selected: Variant, include_selection: bool = true) -> void:
	var config := ConfigFile.new()
	config.set_value("profile","coins",400)
	config.set_value("profile","characters",owned)
	config.set_value("cosmetics","cape","jade")
	if include_selection: config.set_value("profile","selected_character",selected)
	check(config.save(path)==OK,"profile fixture saved")
func boot() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(8)
	host = current_scene
func is_lan_model() -> bool:
	return not host._player.get_node("Visuals/Model/Knight").find_children("Rogue_*","MeshInstance3D",true,false).is_empty()
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
