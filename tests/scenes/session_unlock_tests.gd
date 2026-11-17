extends SceneTree
## All failed writes target a missing directory inside the isolated test user data.
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const CAMPAIGN_PATH := "user://session-unlock-flow/unavailable/campaign.cfg"
const PROFILE_PATH := "user://session-unlock-profile.cfg"
var checks := 0
var failures := 0
var host: Node

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var phase := "unit"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
	match phase:
		"unit": test_session_state()
		"flow": await test_scene_flow()
		"resume": await test_restart()
		_: check(false, "unknown phase: "+phase)
	paused = false
	root.get_node("MusicManager").stop_music()
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames(3)
	print("SESSION_UNLOCK_RESULT phase=%s %d checks, %d failures" % [phase, checks, failures])
	quit(1 if failures else 0)

func test_session_state() -> void:
	var prefix := "user://session-unlock-unit-%d/" % Time.get_ticks_usec()
	var path := prefix+"missing/campaign.cfg"
	var original: RefCounted = PROGRESS.new(path)
	var earlier: RefCounted = PROGRESS.new(path)
	check(not original.is_unlocked(&"level2"), "new session keeps level two locked")
	original.mark_played(1)
	original.complete(1)
	check(not original.message.is_empty() and not FileAccess.file_exists(path), "fixture produces a real save failure")
	check(original.is_unlocked(&"level2"), "save failure does not roll back the current completion")
	check(earlier.is_unlocked(&"level2") and earlier.get_last_played_level() == &"level1", "an instance created before completion shares the current session progress")
	original = null
	earlier = null
	var restored: RefCounted = PROGRESS.new(path)
	check(restored.is_unlocked(&"level2") and restored.completed == ["level1"], "progress survives releasing every old progress wrapper")
	check(restored.played == ["level1"] and restored.get_last_played_level() == &"level1" and not restored.message.is_empty(), "new instances retain recent play and the unsaved warning")
	var separate: RefCounted = PROGRESS.new(prefix+"separate.cfg")
	check(not separate.is_unlocked(&"level2") and separate.played.is_empty() and separate.message.is_empty(), "different save paths cannot inherit session unlocks")
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())) == OK, "test storage becomes writable")
	var stale := ConfigFile.new()
	stale.set_value("campaign", "completed", [])
	stale.set_value("campaign", "played", ["level1"])
	stale.set_value("campaign", "last_played", "level1")
	stale.set_value("metadata", "kept", "legacy")
	check(stale.save(path) == OK, "older disk snapshot is available without the unsaved unlock")
	var next_scene: RefCounted = PROGRESS.new(path)
	check(next_scene.is_unlocked(&"level2") and not next_scene.message.is_empty(), "stale disk data cannot relock a level in the active session")
	next_scene.mark_played(2)
	var disk := ConfigFile.new()
	check(disk.load(path) == OK and disk.get_value("campaign", "completed") == ["level1"] and disk.get_value("campaign", "played") == ["level1", "level2"], "next successful save persists all previously unsaved progress")
	check(disk.get_value("campaign", "last_played") == "level2" and disk.get_value("metadata", "kept") == "legacy", "successful retry retains recent level and unrelated save fields")
	check(restored.message.is_empty() and restored.get_last_played_level() == &"level2", "successful save updates all existing instances and clears their warning")
	restored.complete(2)
	next_scene.mark_played(1)
	disk.load(path)
	check(disk.get_value("campaign", "completed") == ["level1", "level2"] and disk.get_value("campaign", "last_played") == "level1", "writes from older instances cannot overwrite newer completion or recency")
	var alias: RefCounted = PROGRESS.new(ProjectSettings.globalize_path(path))
	check(alias.is_completed(&"level2") and alias.get_last_played_level() == &"level1", "relative user path and absolute path refer to the same progress")

func test_scene_flow() -> void:
	PROFILE.override_path = PROFILE_PATH
	PROGRESS.override_path = CAMPAIGN_PATH
	PROFILE.set_coins(300)
	PROFILE.unlock_character("lan")
	await boot()
	var nav: Node = host.get_node("MenuNavigation")
	check(not nav.progress.is_unlocked(&"level2"), "fresh campaign does not bypass the level unlock rule")
	await select_level(&"level1")
	check(host._player.character_id == "lan" and host.get_run_state() == host.RunState.PLAYING, "selected Lan starts the first level normally despite failed progress saving")
	host._player._invulnerability_remaining = 1000.0
	await go(Vector3(0,0.05,-23))
	host._dungeon.get_node("MeleeEnemy").take_damage(999)
	await create_timer(1.2).timeout
	await go(Vector3(22,0.05,-23))
	host._boss.take_damage(999)
	await create_timer(1.2).timeout
	await go(Vector3(30,0.05,-45))
	nav = host.get_node("MenuNavigation")
	check(host.get_run_state() == host.RunState.VICTORY and nav.progress.is_completed(&"level1"), "real victory records completion and unlocks level two")
	check(not nav.progress.message.is_empty() and not FileAccess.file_exists(CAMPAIGN_PATH), "completion write fails while the session still owns the unlock")
	var old_progress: WeakRef = weakref(nav.progress)
	host._hud.get_result_screen().get_node("%LevelSelectButton").pressed.emit()
	await frames(10)
	host = current_scene
	nav = host.get_node("MenuNavigation")
	check(old_progress.get_ref() == null, "scene replacement releases the old scene's progress object")
	check(nav.level_select.visible and nav.progress.is_unlocked(&"level2") and not nav.level_select.get_level_button(&"level2").disabled, "new scene keeps the level-two tile unlocked and usable")
	check(nav.level_select.status_label.text.contains("保存失败"), "new level picker keeps the unsaved-progress warning")
	if not nav.progress.is_unlocked(&"level2"): return
	nav.level_select.get_level_button(&"level2").pressed.emit()
	await frames(10)
	host = current_scene
	nav = host.get_node("MenuNavigation")
	check(host.level_id == 2 and host.get_run_state() == host.RunState.PLAYING and host._player.character_id == "lan", "unlocked second level can actually launch after the scene replacement")
	check(nav.progress.is_completed(&"level1") and nav.progress.get_last_played_level() == &"level2" and not nav.progress.message.is_empty(), "cross-level load retains completion and updates recent play during continued write failure")
	host.get_node("RunBindings").return_to_menu()
	await frames(10)
	host = current_scene
	nav = host.get_node("MenuNavigation")
	check(host._start_screen.visible and nav.progress.is_unlocked(&"level2") and not host._start_screen.get_node("%ContinueButton").disabled, "returning home preserves session unlocks and Continue availability")
	check(host._start_screen.status_label.text.contains("保存失败"), "home screen retains the storage warning")
	host._start_screen.get_node("%ContinueButton").pressed.emit()
	await frames(10)
	host = current_scene
	check(host.level_id == 2 and host.get_run_state() == host.RunState.PLAYING, "Continue can enter the unsaved but session-unlocked level")
	host.set_paused(true)
	host.restart_run()
	await frames(10)
	host = current_scene
	nav = host.get_node("MenuNavigation")
	check(host.level_id == 2 and host.get_run_state() == host.RunState.MENU and nav.progress.is_unlocked(&"level2") and not paused, "restarting the scene also retains the session unlock")
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAMPAIGN_PATH.get_base_dir())) == OK, "test storage becomes writable after several scene switches")
	var disk := ConfigFile.new()
	disk.set_value("metadata", "kept", "flow")
	disk.save(CAMPAIGN_PATH)
	await select_level(&"level2")
	check(host.get_run_state() == host.RunState.PLAYING and host.get_node("MenuNavigation").progress.message.is_empty(), "next real start retries the progress save and clears the failure warning")
	disk.load(CAMPAIGN_PATH)
	check(disk.get_value("campaign", "completed") == ["level1"] and disk.get_value("campaign", "played") == ["level1", "level2"] and disk.get_value("campaign", "last_played") == "level2", "recovered storage receives the full session completion, visits and recent level")
	check(disk.get_value("metadata", "kept") == "flow" and PROFILE.get_selected_character() == "lan" and PROFILE.owns("lan"), "recovered save preserves unrelated metadata and character selection")
	check(root.get_children().filter(func(n: Node) -> bool: return n.has_method("get_run_state")).size() == 1, "only one live campaign host remains")
	print("SESSION_UNLOCK_READY_FOR_RESTART level2=true recent=level2 character=lan")

func test_restart() -> void:
	PROFILE.override_path = PROFILE_PATH
	PROGRESS.override_path = CAMPAIGN_PATH
	check(FileAccess.file_exists(CAMPAIGN_PATH), "previous process saved recovered progress")
	await boot()
	var nav: Node = host.get_node("MenuNavigation")
	check(nav.progress.is_completed(&"level1") and nav.progress.is_unlocked(&"level2") and nav.progress.message.is_empty(), "fresh process restores the unlock from the recovered save")
	check(nav.progress.get_last_played_level() == &"level2" and host._start_screen.selected_character_id == "lan", "fresh process retains the recent level and selected role")
	host._start_screen.get_node("%ContinueButton").pressed.emit()
	await frames(10)
	host = current_scene
	check(host.level_id == 2 and host.get_run_state() == host.RunState.PLAYING and host._player.character_id == "lan", "Continue after process restart enters level two as Lan")

func boot() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(8)
	host = current_scene
func select_level(id: StringName) -> void:
	var nav: Node = host.get_node("MenuNavigation")
	host._start_screen.start_button.pressed.emit()
	nav.character_select.show_selection("lan")
	nav.character_select.get_node("%ConfirmButton").pressed.emit()
	nav.level_select.get_level_button(id).pressed.emit()
	await frames(10)
	host = current_scene
	if host.level_id == 1: host.get_node("RunBindings").tutorial.skip()
func go(point: Vector3) -> void:
	host._player.global_position = point
	host._player.velocity = Vector3.ZERO
	await frames(6)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
