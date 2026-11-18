extends SceneTree
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
const CHARACTERS = preload("res://scenes/player/character_catalog.gd")
const NAVIGATION = preload("res://scripts/integration/menu_navigation.gd")
const FIRST := "res://Main.tscn"
const SECOND := "res://scenes/dungeon/Level02Run.tscn"
const THIRD := "res://scenes/dungeon/Level03Run.tscn"
var host: Node
var checks := 0
var failures := 0
var scene_changes := 0

func _initialize() -> void: run.call_deferred()
func run() -> void:
	PROFILE.override_path = "user://victory-profile-%d.cfg" % Time.get_ticks_usec()
	PROFILE.set_coins(1000)
	for id in ["lan", "iron", "astra"]: PROFILE.unlock_character(id)
	scene_changed.connect(func() -> void: scene_changes += 1)
	await real_victory_next()
	if "--baseline" not in OS.get_cmdline_user_args():
		for id in CHARACTERS.IDS: await replay_current(id)
		await next_without_completion()
		for action in ["levels", "menu"]: await final_level(action)
		await unsaved_unlock()
		for action in ["next", "replay"]: await load_failure_retry(action)
	paused = false
	root.get_node("MusicManager").stop_music()
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames(3)
	print("VICTORY_CONTINUATION_RESULT %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func boot(role: String, level: int = 1, writable: bool = true) -> void:
	paused = false
	PROFILE.set_selected_character(role)
	CHARACTERS.selected_id = role
	CHARACTERS.start_pending = false
	NAVIGATION.pending_level_select = false
	PROGRESS.override_path = "user://victory-campaign-%d.cfg" % Time.get_ticks_usec() if writable else "user://victory-missing-%d/campaign.cfg" % Time.get_ticks_usec()
	change_scene_to_file({1: FIRST, 2: SECOND, 3: THIRD}[level])
	await frames(8)
	host = current_scene
	host._on_run_started()
	if level == 1: host.get_node("RunBindings").tutorial.skip()

func settle(complete: bool = true) -> void:
	host._run_state = host.RunState.VICTORY
	host._dungeon.stop_run()
	host._dungeon.process_mode = Node.PROCESS_MODE_DISABLED
	host._commerce.finish_run()
	if complete: host.get_node("MenuNavigation").progress.complete(host.level_id)
	host._hud.show_win_screen({"level_id":host.level_id}, host.LEVEL_PATHS.has(host.level_id + 1))

func real_victory_next() -> void:
	await boot("lan")
	host._player._invulnerability_remaining = 1000.0
	await go(Vector3(0,0.05,-23))
	host._dungeon.get_node("MeleeEnemy").take_damage(999)
	await create_timer(1.2).timeout
	await go(Vector3(22,0.05,-23))
	host._boss.take_damage(999)
	await create_timer(1.2).timeout
	await go(Vector3(30,0.05,-45))
	check(host.get_run_state() == host.RunState.VICTORY and host.get_node("MenuNavigation").progress.is_unlocked(&"level2"), "real first-level victory unlocks the next level before settlement")
	check(host.get_node("MenuNavigation").progress.is_unlocked(&"level3") and not host.get_node("MenuNavigation").progress.is_completed(&"level2"), "test build opens the third level without fabricating second-level completion")
	var before := scene_changes
	var profile_before := FileAccess.get_file_as_string(PROFILE.override_path)
	var screen: Control = host._hud.get_result_screen()
	for i in 8: screen.get_node("%NextLevelButton").pressed.emit()
	screen.get_node("%RestartButton").pressed.emit()
	screen.get_node("%MainMenuButton").pressed.emit()
	check(host._transition_queued and CHARACTERS.start_pending, "Next immediately reserves one direct-start transition")
	await frames(10)
	host = current_scene
	check(scene_changes == before+1 and host.level_id == 2 and host.get_run_state() == host.RunState.PLAYING, "Next enters the second level directly despite repeated and conflicting clicks")
	check_direct("lan")
	check(host.get_node("MenuNavigation").progress.is_completed(&"level1") and host.get_node("MenuNavigation").progress.get_last_played_level() == &"level2", "direct next-level start preserves completion and records the actual recent level")
	check(FileAccess.get_file_as_string(PROFILE.override_path) == profile_before, "next-level start preserves the wallet, ownership and saved character")

func replay_current(role: String) -> void:
	var level := 1 if role in ["knight", "lan"] else 2
	await boot(role, level)
	host._player.hp = 1
	host._player.energy = 0
	host._items.potion_count = 2
	host._elapsed_seconds = 120.0
	settle()
	var before := scene_changes
	var profile_before := FileAccess.get_file_as_string(PROFILE.override_path)
	# The live player is authoritative even if an old global handoff is stale.
	CHARACTERS.selected_id = "knight"
	var screen: Control = host._hud.get_result_screen()
	for i in 8: screen.get_node("%RestartButton").pressed.emit()
	screen.get_node("%NextLevelButton").pressed.emit()
	screen.get_node("%LevelSelectButton").pressed.emit()
	await frames(10)
	host = current_scene
	check(scene_changes == before+1 and host.level_id == level and host.get_run_state() == host.RunState.PLAYING, role+": Again directly restarts the current level exactly once")
	check_direct(role)
	check(host._player.hp == host._player.max_hp and host._items.potion_count == 0 and host._elapsed_seconds < 2 and not host._boss_defeated, role+": new run resets health, supplies, timer and victory state")
	check(host.get_node("MenuNavigation").progress.is_completed(StringName("level%d" % level)) and FileAccess.get_file_as_string(PROFILE.override_path) == profile_before, role+": Again retains completion, unlocks and persistent character data")

func next_without_completion() -> void:
	await boot("lan")
	settle(false)
	var before := scene_changes
	var screen: Control = host._hud.get_result_screen()
	for i in 8: screen.get_node("%NextLevelButton").pressed.emit()
	await frames(10)
	host = current_scene
	var nav: Node = host.get_node("MenuNavigation")
	check(scene_changes == before+1 and host.level_id == 2 and host.get_run_state() == host.RunState.PLAYING, "test build accepts Next once without previous completion")
	check(nav.progress.completed.is_empty(), "unrestricted Next does not fabricate completed levels")
	check_direct("lan")

func final_level(action: String) -> void:
	await boot("astra", 3)
	settle()
	var before := scene_changes
	var screen: Control = host._hud.get_result_screen()
	check(not screen.get_node("%NextLevelButton").visible and screen.get_node("%ProgressLabel").text.contains("全部关卡"), "last-level settlement explains campaign completion and hides unavailable Next")
	check(not host.advance_to_level02() and not host._transition_queued and not CHARACTERS.start_pending, "last level cannot accidentally loop back into itself")
	if "--capture" in OS.get_cmdline_user_args() and action == "levels": await capture_final(screen)
	screen.get_node("%LevelSelectButton" if action == "levels" else "%MainMenuButton").pressed.emit()
	await frames(10)
	host = current_scene
	check(scene_changes == before+1 and host.get_run_state() == host.RunState.MENU and host._player.character_id == "astra", "last-level return preserves the character and returns to a navigation page")
	check(host.get_node("MenuNavigation").level_select.visible if action == "levels" else host._start_screen.visible, "last-level "+action+" return action remains usable")

func unsaved_unlock() -> void:
	await boot("lan", 1, false)
	settle()
	check(host.get_node("MenuNavigation").progress.is_unlocked(&"level2") and not host.get_node("MenuNavigation").progress.message.is_empty(), "failed progress write still unlocks Next in this session")
	host._hud.get_result_screen().get_node("%NextLevelButton").pressed.emit()
	await frames(10)
	host = current_scene
	check(host.level_id == 2 and host.get_run_state() == host.RunState.PLAYING and host.get_node("MenuNavigation").progress.is_completed(&"level1"), "Next can directly enter a session-unlocked level while writing still fails")
	check_direct("lan")

func load_failure_retry(action: String) -> void:
	await boot("iron")
	settle()
	var target := SECOND if action == "next" else FIRST
	var original: PackedScene = load(target)
	var broken := PackedScene.new()
	broken.take_over_path(target)
	var before := scene_changes
	print("EXPECTED_LOAD_FAILURE_BEGIN settlement-", action)
	host._hud.get_result_screen().get_node("%NextLevelButton" if action == "next" else "%RestartButton").pressed.emit()
	await frames(8)
	print("EXPECTED_LOAD_FAILURE_END settlement-", action)
	original.take_over_path(target)
	var nav: Node = host.get_node("MenuNavigation")
	check(host.get_run_state() == host.RunState.VICTORY and not host._transition_queued and not CHARACTERS.start_pending and nav.load_error.visible, action+": load failure retains settlement, releases state and offers retry")
	for i in 8: nav.load_error.get_node("%RetryButton").pressed.emit()
	await frames(10)
	host = current_scene
	check(scene_changes == before+1 and host.level_id == (2 if action == "next" else 1) and host.get_run_state() == host.RunState.PLAYING, action+": retry still directly starts the intended level exactly once")
	check_direct("iron")

func check_direct(role: String) -> void:
	var nav: Node = host.get_node("MenuNavigation")
	check(host._player.character_id == role and CHARACTERS.selected_id == role and host._player.max_hp == CHARACTERS.definition(role).hp, "direct arrival uses the current role and matching player stats: "+role)
	check(not host._start_screen.visible and not nav.character_select.visible and not nav.level_select.visible and not nav.load_error.visible and host._hud.get_result_screen() == null, "direct arrival leaves no menu, selection or settlement overlay")
	check(not paused and not host._transition_queued and not CHARACTERS.start_pending and not NAVIGATION.pending_level_select, "direct arrival consumes its flags and enables gameplay")
	check(root.get_children().filter(func(n: Node) -> bool: return n.has_method("get_run_state")).size() == 1, "only one live game host remains")

func capture_final(screen: Control) -> void:
	for dimensions in [Vector2i(1280,720), Vector2i(720,720)]:
		root.mode = Window.MODE_WINDOWED
		root.size = dimensions
		await create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		var path := "D:/My File/Game/Team Game/output/victory-continuation-2026-11-13/final-%dx%d.png" % [dimensions.x,dimensions.y]
		check(root.get_texture().get_image().save_png(path) == OK, "last-level settlement screenshot saved")
		check(root.get_visible_rect().encloses(screen.get_node("%MainMenuButton").get_global_rect()), "last-level return action fits within the viewport")
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
