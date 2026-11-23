extends SceneTree
## Separate write/resume engine processes share only these isolated test saves.
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const CHARACTERS = preload("res://scenes/player/character_catalog.gd")
const CAMPAIGN_PATH := "user://continue-recent-campaign.cfg"
const PROFILE_PATH := "user://continue-recent-profile.cfg"
const EXPECTED_PATH := "user://continue-recent-expected.cfg"
var checks := 0
var failures := 0
var host: Node

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var phase := "unit"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
	if phase=="unit":
		test_records()
	else:
		PROGRESS.override_path = CAMPAIGN_PATH
		PROFILE.override_path = PROFILE_PATH
		if phase=="write": await write_phase()
		elif phase=="resume": await resume_phase()
		else: check(false,"unknown test phase: "+phase)
	paused = false
	root.get_node("MusicManager").stop_music()
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames(3)
	print("CONTINUE_PROGRESS_RESULT phase=%s %d checks, %d failures" % [phase,checks,failures])
	quit(1 if failures else 0)

func test_records() -> void:
	var prefix := "user://recent-unit-%d-" % Time.get_ticks_usec()
	var fresh := PROGRESS.new(prefix+"fresh.cfg")
	check(fresh.get_last_played_level().is_empty() and fresh.played.is_empty(),"new save has no continue target")
	fresh.complete(1)
	check(fresh.get_last_played_level().is_empty() and fresh.is_unlocked(&"level2"),"completion unlocks the next level without claiming a gameplay entry")
	fresh.mark_played(1)
	fresh.mark_played(2)
	fresh.mark_played(1)
	check(fresh.get_last_played_level()==&"level1","re-entering level one replaces the recent target")
	check(fresh.played==["level1","level2"],"first-visit history remains intact and contains no duplicates")
	var reloaded := PROGRESS.new(fresh.path)
	check(reloaded.get_last_played_level()==&"level1","recent level survives a fresh progress instance")
	check(reloaded.completed==["level1"] and reloaded.is_unlocked(&"level2"),"changing recency preserves completion and unlocks")
	var disk := ConfigFile.new()
	disk.load(fresh.path)
	check(disk.get_value("campaign","last_played")=="level1","recent target is explicitly written to disk")
	var legacy := ConfigFile.new()
	legacy.set_value("campaign","completed",["level1"])
	legacy.set_value("campaign","played",["level1","level2"])
	legacy.set_value("campaign","selected_character","lan")
	legacy.set_value("character_data","cosmetic","green")
	legacy.save(prefix+"legacy.cfg")
	var migrated := PROGRESS.new(prefix+"legacy.cfg")
	check(migrated.get_last_played_level()==&"level2","old save without a recent field retains its previous continue target")
	migrated.mark_played(1)
	disk.load(migrated.path)
	check(disk.get_value("campaign","last_played")=="level1" and migrated.is_unlocked(&"level2"),"next actual entry upgrades an old save without relocking levels")
	check(disk.get_value("campaign","selected_character")=="lan" and disk.get_value("character_data","cosmetic")=="green","saving recency retains unrelated character metadata")
	var three_levels := ConfigFile.new()
	three_levels.set_value("campaign", "completed", ["level1", "level2"])
	three_levels.set_value("campaign", "played", ["level1", "level3"])
	three_levels.set_value("campaign", "last_played", "level3")
	three_levels.set_value("metadata", "kept", "week10")
	var old_path := prefix + "three-levels.cfg"
	three_levels.save(old_path)
	var original_digest := FileAccess.get_sha256(old_path)
	var expanded := PROGRESS.new(old_path)
	check(expanded.is_unlocked(&"level4") and expanded.get_last_played_level() == &"level3" and not expanded.has_played(&"level4"), "fourth level is available without changing the old continue target")
	check(FileAccess.get_sha256(old_path) == original_digest, "reading the previous three-level save does not rewrite it")
	expanded.mark_played(4)
	expanded.complete(4)
	disk.load(old_path)
	check(disk.get_value("campaign", "played") == ["level1", "level3", "level4"] and disk.get_value("campaign", "last_played") == "level4", "fourth-level play appends to the old history and persists the actual continue target")
	check(disk.get_value("campaign", "completed") == ["level1", "level2", "level4"] and disk.get_value("metadata", "kept") == "week10", "fourth-level completion preserves older progress and unrelated fields")
	legacy.set_value("campaign","last_played","level1")
	legacy.save(prefix+"explicit.cfg")
	var explicit := PROGRESS.new(prefix+"explicit.cfg")
	check(explicit.get_last_played_level()==&"level1" and explicit.played.back()=="level2","explicit recent level takes precedence over first-visit order")
	for invalid in ["level99",73]:
		legacy.set_value("campaign","last_played",invalid)
		var invalid_path := prefix+"invalid-%d.cfg" % typeof(invalid)
		legacy.save(invalid_path)
		var recovered := PROGRESS.new(invalid_path)
		check(recovered.get_last_played_level()==&"level2","invalid recent data falls back to a valid played level")
	legacy.set_value("campaign","completed",[])
	legacy.set_value("campaign","played",["level1"])
	legacy.set_value("campaign","last_played","level2")
	legacy.save(prefix+"unplayed.cfg")
	var unplayed := PROGRESS.new(prefix+"unplayed.cfg")
	check(unplayed.get_last_played_level()==&"level1" and not unplayed.has_played(&"level2") and unplayed.is_unlocked(&"level2"),"test access does not fabricate recent play from unplayed metadata")
	unplayed.mark_played(0)
	unplayed.mark_played(99)
	check(unplayed.played==["level1"] and unplayed.get_last_played_level()==&"level1","invalid gameplay level IDs cannot corrupt recency or unlocks")
	PROFILE.override_path = prefix+"profile.cfg"
	PROFILE.set_coins(300)
	PROFILE.unlock_character("lan")
	var character_before := FileAccess.get_file_as_string(PROFILE.override_path)
	CHARACTERS.selected_id = "lan"
	unplayed.mark_played(1)
	unplayed.complete(1)
	check(FileAccess.get_file_as_string(PROFILE.override_path)==character_before and CHARACTERS.selected_id=="lan","progress writes do not alter the character profile or selected character")

func write_phase() -> void:
	var profile := ConfigFile.new()
	profile.set_value("profile","coins",321)
	profile.set_value("profile","characters",["lan","astra"])
	check(profile.save(PROFILE_PATH)==OK,"isolated character fixture saved")
	var campaign := ConfigFile.new()
	campaign.set_value("campaign","completed",[])
	campaign.set_value("campaign","played",[])
	check(campaign.save(CAMPAIGN_PATH)==OK,"isolated new campaign fixture saved")
	await boot()
	check(host.get_node("MenuNavigation").progress.get_last_played_level().is_empty() and host._start_screen.get_node("%ContinueButton").disabled,"new campaign has no continue button target")
	# Unlock fixture lets this navigation regression enter both existing levels.
	host.get_node("MenuNavigation").progress.complete(1)
	for level in [&"level1",&"level2",&"level1"]:
		await enter_level(level)
		var nav: Node = host.get_node("MenuNavigation")
		check(host.get_run_state()==host.RunState.PLAYING and host.level_id==(2 if level==&"level2" else 1),"actual gameplay entered "+String(level))
		check(nav.progress.get_last_played_level()==level,"actual start updates recent target to "+String(level))
		check(host._player.character_id=="lan" and CHARACTERS.selected_id=="lan","re-entered level preserves the confirmed character")
		var disk := ConfigFile.new()
		disk.load(CAMPAIGN_PATH)
		check(disk.get_value("campaign","last_played")==String(level),"actual start persists recent target immediately")
		host.get_node("RunBindings").return_to_menu()
		await frames(10)
		host = current_scene
		check(host.get_node("MenuNavigation").progress.get_last_played_level()==level,"loading the first-level menu does not count as playing it")
		print("PLAYED_SEQUENCE_ENTRY ",level," recent=",host.get_node("MenuNavigation").progress.get_last_played_level())
	var progress: RefCounted = host.get_node("MenuNavigation").progress
	check(progress.played==["level1","level2"] and progress.get_last_played_level()==&"level1","one -> two -> one stores recency separately from unchanged visit history")
	check(host._start_screen.status_label.text=="上次探索：第1关","home caption uses the same recent target as Continue")
	var expected := ConfigFile.new()
	expected.set_value("profile","coins",PROFILE.coins)
	expected.set_value("profile","characters",PROFILE.unlocked)
	expected.set_value("campaign","completed",progress.completed)
	check(expected.save(EXPECTED_PATH)==OK,"restart expectations saved for the second process")
	print("WRITE_PHASE_READY_FOR_PROCESS_RESTART recent=level1")

func resume_phase() -> void:
	check(FileAccess.file_exists(EXPECTED_PATH),"write-phase fixture is present from the previous process")
	await boot()
	var nav: Node = host.get_node("MenuNavigation")
	var expected := ConfigFile.new()
	expected.load(EXPECTED_PATH)
	check(nav.progress.played==["level1","level2"] and nav.progress.get_last_played_level()==&"level1","fresh process reads level one despite history ending in level two")
	check(nav.progress.completed==expected.get_value("campaign","completed") and nav.progress.is_unlocked(&"level2"),"restart preserves completion and the unlocked second level")
	check(PROFILE.coins==expected.get_value("profile","coins") and PROFILE.unlocked==expected.get_value("profile","characters"),"restart preserves the existing wallet and unlocked characters")
	check(not host._start_screen.get_node("%ContinueButton").disabled and host._start_screen.status_label.text=="上次探索：第1关","fresh home screen enables Continue with the correct level caption")
	var selected: String = host._start_screen.selected_character_id
	host._start_screen.get_node("%ContinueButton").pressed.emit()
	await frames(10)
	host = current_scene
	check(host.level_id==1 and host.get_run_state()==host.RunState.PLAYING,"Continue after a real process restart enters level one")
	check(host._player.character_id==selected,"Continue retains the current character-selection behavior")
	var current_nav: Node = host.get_node("MenuNavigation")
	check(not host._start_screen.visible and not current_nav.character_select.visible and not current_nav.level_select.visible,"Continue starts gameplay without leftover navigation pages")
	check(current_nav.progress.is_unlocked(&"level2") and PROFILE.owns("lan") and PROFILE.owns("astra"),"continuing the recent level leaves unlock and character ownership intact")
	print("RESUME_AFTER_PROCESS_RESTART actual_level=",host.level_id," state=",host.RunState.keys()[host.get_run_state()])

func boot() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(8)
	host = current_scene
func enter_level(level: StringName) -> void:
	var nav: Node = host.get_node("MenuNavigation")
	var recent_before: StringName = nav.progress.get_last_played_level()
	host._start_screen.start_button.pressed.emit()
	nav.character_select.show_selection("lan")
	nav.character_select.get_node("%ConfirmButton").pressed.emit()
	check(nav.progress.get_last_played_level()==recent_before,"character confirmation alone does not record a new level entry")
	nav.level_select.get_level_button(level).pressed.emit()
	await frames(10)
	host = current_scene
	if host.level_id==1: host.get_node("RunBindings").tutorial.skip()
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
