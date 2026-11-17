extends SceneTree
## Inject invalid PackedScenes into this process only; real scene files stay intact.
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const CAMPAIGN = preload("res://scripts/integration/campaign_progress.gd")
const CHARACTERS = preload("res://scenes/player/character_catalog.gd")
const NAVIGATION = preload("res://scripts/integration/menu_navigation.gd")
const FIRST := "res://Main.tscn"
const SECOND := "res://scenes/dungeon/Level02Run.tscn"
const MISSING := "res://tests/scenes/__missing_recovery_fixture__.tscn"
var host: Node
var checks := 0
var failures := 0
var scene_changes := 0

func _initialize() -> void: run.call_deferred()
func run() -> void:
	PROFILE.override_path = "user://load-failure-profile-%d.cfg" % Time.get_ticks_usec()
	CAMPAIGN.override_path = "user://load-failure-campaign-%d.cfg" % Time.get_ticks_usec()
	PROFILE.set_coins(1000)
	PROFILE.unlock_character("lan")
	scene_changed.connect(func() -> void: scene_changes += 1)
	if "--baseline" in OS.get_cmdline_user_args():
		await launch_failure("cross-level", true)
	else:
		for entry in ["cross-level", "character-reload", "continue"]:
			await launch_failure(entry)
		await missing_resource_failure()
		await cancel_and_navigate()
		await paused_failure()
		await result_failure()
	paused = false
	root.get_node("MusicManager").stop_music()
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames(3)
	print("LOAD_FAILURE_RECOVERY_RESULT %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func fresh() -> void:
	paused = false
	PROFILE.set_selected_character("knight")
	CHARACTERS.selected_id = "knight"
	CHARACTERS.start_pending = false
	NAVIGATION.pending_level_select = false
	change_scene_to_file(FIRST)
	await frames(8)
	host = current_scene
	var progress: RefCounted = host.get_node("MenuNavigation").progress
	progress.complete(1)
	progress.mark_played(2)

func confirm_lan() -> void:
	var nav: Node = host.get_node("MenuNavigation")
	host._start_screen.start_button.pressed.emit()
	nav.character_select.show_selection("lan")
	nav.character_select.get_node("%ConfirmButton").pressed.emit()

func launch_failure(entry: String, baseline: bool = false) -> void:
	await fresh()
	var nav: Node = host.get_node("MenuNavigation")
	if entry != "continue": confirm_lan()
	var target := FIRST if entry == "character-reload" else SECOND
	var original: PackedScene = load(target)
	var broken := PackedScene.new()
	broken.take_over_path(target)
	var before := scene_changes
	var campaign_before := FileAccess.get_file_as_string(CAMPAIGN.override_path)
	var wallet_before: int = PROFILE.coins
	print("EXPECTED_LOAD_FAILURE_BEGIN ", entry)
	for i in 8:
		if entry == "continue": host._start_screen.get_node("%ContinueButton").pressed.emit()
		else: nav.level_select.get_level_button(&"level1" if target == FIRST else &"level2").pressed.emit()
	check(host._transition_queued, entry+": first request locks before deferred loading")
	check(not host.request_scene_change(SECOND, {"character_id":"knight", "show_levels":true}), entry+": duplicate cannot replace the request")
	await frames(8)
	print("EXPECTED_LOAD_FAILURE_END ", entry)
	check(current_scene == host and scene_changes == before, entry+": failed scene creation retains the live host")
	check(not host._transition_queued and not host._transition_executing and host._transition_snapshot.is_empty(), entry+": both locks and transition snapshot are released")
	check(not CHARACTERS.start_pending and not NAVIGATION.pending_level_select, entry+": no stale auto-start or arrival flags remain")
	check(host.get_run_state() == host.RunState.MENU and not paused and not host._dungeon._run_started, entry+": gameplay was not started on failure")
	check(nav.level_select.visible if entry != "continue" else host._start_screen.visible, entry+": the launching navigation page becomes visible again")
	check(FileAccess.get_file_as_string(CAMPAIGN.override_path) == campaign_before and PROFILE.coins == wallet_before, entry+": failed load does not mark progress or alter wallet")
	if baseline:
		original.take_over_path(target)
		return
	var panel: Control = nav.get("load_error")
	check(panel != null and panel.is_visible_in_tree(), entry+": a visible error offers retry and return actions")
	if panel == null:
		original.take_over_path(target)
		return
	check(panel.get_node("%RetryButton").is_visible_in_tree() and not panel.get_node("%RetryButton").disabled, entry+": retry is usable")
	check(panel.get_node("%ErrorMessage").text.contains("无法载入"), entry+": failure message is shown on the visible panel")
	check(root.gui_get_focus_owner() == panel.get_node("%RetryButton"), entry+": keyboard focus moves to retry")
	check(root.get_visible_rect().encloses(panel.get_node("%BackButton").get_global_rect()), entry+": recovery actions fit within the viewport")
	if "--capture" in OS.get_cmdline_user_args() and entry == "cross-level":
		await capture_panel(panel)
	if entry == "cross-level":
		print("EXPECTED_LOAD_FAILURE_BEGIN retry-again")
		for i in 8: panel.get_node("%RetryButton").pressed.emit()
		await frames(8)
		print("EXPECTED_LOAD_FAILURE_END retry-again")
		check(panel.visible and not host._transition_queued and not CHARACTERS.start_pending and scene_changes == before, "a repeated failure restores the retry panel without leaving stale state")
	original.take_over_path(target)
	for i in 8: panel.get_node("%RetryButton").pressed.emit()
	check(host._transition_queued and not panel.visible, entry+": retry owns one transition and dismisses its error")
	await frames(10)
	host = current_scene
	check(scene_changes == before+1 and host.level_id == (1 if target == FIRST else 2), entry+": repeated retry clicks perform exactly one successful replacement")
	check(host.get_run_state() == host.RunState.PLAYING and host._player.character_id == ("knight" if entry == "continue" else "lan"), entry+": retry preserves destination, chosen role and auto-start")
	check(not CHARACTERS.start_pending and not NAVIGATION.pending_level_select and not host._transition_queued, entry+": successful retry consumes startup flags once")
	check(not host.get_node("MenuNavigation").load_error.visible and not host.get_node("MenuNavigation").level_select.visible and not host._start_screen.visible, entry+": successful retry leaves only gameplay visible")
	one_host()

func missing_resource_failure() -> void:
	await fresh()
	var nav: Node = host.get_node("MenuNavigation")
	var before := scene_changes
	# Even pre-existing arrival flags must not survive a failed attempt.
	CHARACTERS.start_pending = true
	NAVIGATION.pending_level_select = true
	print("EXPECTED_LOAD_FAILURE_BEGIN missing-resource")
	check(host.request_scene_change(MISSING, {"start_run":true}), "missing resource request enters the common transition path")
	await frames(8)
	print("EXPECTED_LOAD_FAILURE_END missing-resource")
	check(scene_changes == before and host._start_screen.visible and nav.load_error.visible, "resource-not-found failure restores home and the retry panel")
	check(not host._transition_queued and not host._transition_executing and not CHARACTERS.start_pending and not NAVIGATION.pending_level_select, "resource-not-found failure clears locks and any stale arrival flags")
	# Populate only the process-local resource cache, without creating a scene file.
	var restored: PackedScene = load(SECOND)
	restored.take_over_path(MISSING)
	nav.load_error.get_node("%RetryButton").pressed.emit()
	await frames(10)
	restored.take_over_path(SECOND)
	host = current_scene
	check(scene_changes == before+1 and host.level_id == 2 and host.get_run_state() == host.RunState.PLAYING, "retry succeeds when the previously missing resource becomes available")
	check(not host.get_node("MenuNavigation").level_select.visible and not CHARACTERS.start_pending and not NAVIGATION.pending_level_select, "retry after missing resource has no leftover navigation or startup state")
	one_host()

func cancel_and_navigate() -> void:
	await fresh()
	confirm_lan()
	var nav: Node = host.get_node("MenuNavigation")
	var original: PackedScene = load(SECOND)
	var broken := PackedScene.new()
	broken.take_over_path(SECOND)
	print("EXPECTED_LOAD_FAILURE_BEGIN cancel")
	nav.level_select.get_level_button(&"level2").pressed.emit()
	await frames(8)
	print("EXPECTED_LOAD_FAILURE_END cancel")
	original.take_over_path(SECOND)
	var panel: Control = nav.load_error
	panel.get_node("%BackButton").pressed.emit()
	await frames(2)
	check(not panel.visible and nav.level_select.is_visible_in_tree(), "dismissing error leaves a usable level picker")
	check(root.gui_get_focus_owner() != null and root.gui_get_focus_owner().is_visible_in_tree(), "dismissing error restores keyboard focus to visible navigation")
	check(nav.level_select.status_label.text.contains("无法载入"), "level picker retains a readable failure status")
	var before := scene_changes
	panel.get_node("%RetryButton").pressed.emit()
	await frames(3)
	check(scene_changes == before and not host._transition_queued, "dismissed retry callback cannot relaunch an abandoned request")
	nav.level_select.start_button.pressed.emit()
	check(nav.character_select.visible, "back from restored picker retains the original character-selection route")
	nav.character_select.back_requested.emit()
	check(host._start_screen.visible, "restored navigation can return to the main menu")
	host._start_screen.start_button.pressed.emit()
	nav.character_select.get_node("%ConfirmButton").pressed.emit()
	nav.level_select.get_level_button(&"level1").pressed.emit()
	await frames(10)
	host = current_scene
	check(host.get_run_state() == host.RunState.PLAYING and host._player.character_id == "lan" and host.level_id == 1, "player can choose a different level after cancelling the failed request")
	one_host()

func paused_failure() -> void:
	await fresh()
	host.get_node("MenuNavigation")._launch(&"level1")
	host.get_node("RunBindings").tutorial.skip()
	host.set_paused(true)
	var nav: Node = host.get_node("MenuNavigation")
	var original: PackedScene = load(FIRST)
	var broken := PackedScene.new()
	broken.take_over_path(FIRST)
	var before := scene_changes
	print("EXPECTED_LOAD_FAILURE_BEGIN paused-return")
	host._commerce.pause_menu.get_node("%MainMenuButton").pressed.emit()
	await frames(8)
	print("EXPECTED_LOAD_FAILURE_END paused-return")
	original.take_over_path(FIRST)
	check(paused and host.get_run_state() == host.RunState.PAUSED and host._commerce.pause_menu.is_visible_in_tree(), "failed return restores the pause menu and pause state")
	check(nav.load_error.is_visible_in_tree() and not host._transition_queued, "paused failure exposes retry while the scene lock is released")
	var pause_event := InputEventAction.new()
	pause_event.action = &"pause"
	pause_event.pressed = true
	Input.parse_input_event(pause_event)
	await frames(2)
	check(paused and nav.load_error.visible, "pause shortcut cannot resume gameplay behind the failure panel")
	var cancel_event := InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	Input.parse_input_event(cancel_event)
	await frames(2)
	check(not nav.load_error.visible and paused and root.gui_get_focus_owner() == host._commerce.pause_menu.get_node("%ResumeButton"), "keyboard cancel returns focus to the restored pause menu")
	host._commerce.pause_menu.get_node("%ResumeButton").pressed.emit()
	check(not paused and host.get_run_state() == host.RunState.PLAYING, "player can resume after dismissing a failed return")
	host.set_paused(true)
	host._commerce.pause_menu.get_node("%MainMenuButton").pressed.emit()
	await frames(10)
	host = current_scene
	check(scene_changes == before+1 and host._start_screen.visible and not paused, "pause menu can successfully return home after recovery")
	one_host()

func result_failure() -> void:
	await fresh()
	# Present the real settlement UI without repeating unrelated combat in this suite.
	host._run_state = host.RunState.VICTORY
	host._dungeon.process_mode = Node.PROCESS_MODE_DISABLED
	host._hud.show()
	host._start_screen.hide()
	host._hud.show_win_screen({}, true)
	var nav: Node = host.get_node("MenuNavigation")
	var original: PackedScene = load(SECOND)
	var broken := PackedScene.new()
	broken.take_over_path(SECOND)
	var before := scene_changes
	print("EXPECTED_LOAD_FAILURE_BEGIN settlement-next")
	host._hud.get_result_screen().get_node("%NextLevelButton").pressed.emit()
	await frames(8)
	print("EXPECTED_LOAD_FAILURE_END settlement-next")
	original.take_over_path(SECOND)
	check(host.get_run_state() == host.RunState.VICTORY and host._hud.get_result_screen().is_visible_in_tree() and nav.load_error.is_visible_in_tree(), "failed next-level request retains settlement and exposes retry above it")
	for i in 8: nav.load_error.get_node("%RetryButton").pressed.emit()
	await frames(10)
	host = current_scene
	check(scene_changes == before+1 and host.level_id == 2 and not host._start_screen.visible and host.get_run_state() == host.RunState.PLAYING, "settlement retry directly starts the next level without a menu detour")
	check(not host._transition_queued and not CHARACTERS.start_pending and not NAVIGATION.pending_level_select, "settlement retry leaves no stale startup or navigation state")
	one_host()

func one_host() -> void:
	check(root.get_children().filter(func(n: Node) -> bool: return n.has_method("get_run_state")).size() == 1, "only one live game host remains")
func capture_panel(panel: Control) -> void:
	for size in [Vector2i(1280,720), Vector2i(720,720)]:
		root.mode = Window.MODE_WINDOWED
		root.size = size
		await frames(5)
		await RenderingServer.frame_post_draw
		var path := "D:/My File/Game/Team Game/output/load-failure-recovery-2026-11-12/recovery-%dx%d.png" % [size.x,size.y]
		check(root.get_texture().get_image().save_png(path) == OK, "recovery screenshot saved at %dx%d" % [size.x,size.y])
		check(root.get_visible_rect().encloses(panel.get_node("%RetryButton").get_global_rect()) and root.get_visible_rect().encloses(panel.get_node("%BackButton").get_global_rect()), "both recovery actions fit at %dx%d" % [size.x,size.y])
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
