extends SceneTree
## Run with -- --failure to separately exercise an intentionally invalid PackedScene.
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const CAMPAIGN = preload("res://scripts/integration/campaign_progress.gd")
const CHARACTERS = preload("res://scenes/player/character_catalog.gd")
const NAVIGATION = preload("res://scripts/integration/menu_navigation.gd")
const FIRST := "res://Main.tscn"
const SECOND := "res://scenes/dungeon/Level02Run.tscn"
var host: Node
var checks := 0
var failures := 0
var scene_changes := 0

func _initialize() -> void: run.call_deferred()
func run() -> void:
	PROFILE.override_path = "user://transition-profile-%d.cfg" % Time.get_ticks_usec()
	CAMPAIGN.override_path = "user://transition-campaign-%d.cfg" % Time.get_ticks_usec()
	PROFILE.set_coins(1000)
	for id in ["lan", "astra"]: PROFILE.unlock_character(id)
	scene_changed.connect(func() -> void: scene_changes += 1)
	if "--failure" in OS.get_cmdline_user_args():
		await failure_and_retry()
	else:
		await repeated_cross_level()
		await repeated_character_reload()
		await repeated_in_place_start()
		await repeated_pause_actions()
		for action in ["next", "restart", "levels", "menu"]:
			await repeated_result_actions(action)
		await detached_and_deleted_host()
	paused = false
	root.get_node("MusicManager").stop_music()
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames(3)
	print("SCENE_TRANSITION_RESULT %d checks, %d failures" % [checks,failures])
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
	host.get_node("MenuNavigation").progress.complete(1)

func confirm_role(id: String) -> void:
	var nav: Node = host.get_node("MenuNavigation")
	host._start_screen.start_button.pressed.emit()
	nav.character_select.show_selection(id)
	nav.character_select.get_node("%ConfirmButton").pressed.emit()
	nav.character_select.get_node("%ConfirmButton").pressed.emit()
	check(nav.level_select.visible and host.get_run_state()==host.RunState.MENU,"character confirmation still opens the level picker")

func repeated_cross_level() -> void:
	await fresh()
	confirm_role("lan")
	var nav: Node = host.get_node("MenuNavigation")
	var before := scene_changes
	var old: WeakRef = weakref(host)
	for i in 8: nav.level_select.get_level_button(&"level2").pressed.emit()
	check(host._transition_queued,"cross-level request locks immediately before its deferred execution")
	check(not host.request_scene_change(FIRST,{"character_id":"astra","show_levels":true}),"a conflicting request is rejected")
	nav.return_to_level_select()
	host.get_node("RunBindings").return_to_menu()
	check(CHARACTERS.selected_id=="lan" and CHARACTERS.start_pending and not NAVIGATION.pending_level_select,"rejected requests cannot overwrite the selected role or arrival screen")
	# Also defend the executor against an accidental second legacy deferred callback.
	host._change_scene.call_deferred(FIRST)
	await frames(10)
	host = current_scene
	check(scene_changes==before+1 and old.get_ref()==null,"eight level presses produce exactly one scene replacement")
	check(host.level_id==2 and host._player.character_id=="lan" and host.get_run_state()==host.RunState.PLAYING,"first cross-level destination and auto-start intent are preserved")
	check(not CHARACTERS.start_pending and not host.get_node("MenuNavigation").character_select.visible,"auto-start is consumed once without a stray character page")
	one_host()

func repeated_character_reload() -> void:
	await fresh()
	confirm_role("lan")
	var before := scene_changes
	var nav: Node = host.get_node("MenuNavigation")
	for i in 8: nav.level_select.get_level_button(&"level1").pressed.emit()
	check(host._transition_queued,"changing character in the current level uses the same lock")
	await frames(10)
	host = current_scene
	check(scene_changes==before+1 and host._player.character_id=="lan" and host.get_run_state()==host.RunState.PLAYING,"repeated first-level launch performs one character reload and one start")
	one_host()

func repeated_in_place_start() -> void:
	await fresh()
	confirm_role("knight")
	var before := scene_changes
	for i in 8: host.get_node("MenuNavigation").level_select.get_level_button(&"level1").pressed.emit()
	await frames(4)
	check(scene_changes==before and host.get_run_state()==host.RunState.PLAYING and not host._transition_queued,"same-character start keeps its existing in-place behavior")
	one_host()

func start_lan() -> void:
	await fresh()
	confirm_role("lan")
	host.get_node("MenuNavigation").level_select.get_level_button(&"level1").pressed.emit()
	await frames(10)
	host = current_scene
	host.get_node("RunBindings").tutorial.skip()

func repeated_pause_actions() -> void:
	for action in ["menu", "restart"]:
		await start_lan()
		host.set_paused(true)
		var before := scene_changes
		var old: WeakRef = weakref(host)
		var menu: Control = host._commerce.pause_menu
		for i in 8:
			if action=="menu": menu.main_menu_requested.emit()
			else: menu.restart_requested.emit()
		check(host._transition_queued,"pause %s locks the pending request" % action)
		check(not host.request_scene_change(SECOND,{"start_run":true}),"pause %s ignores a conflicting cross-level request" % action)
		await frames(10)
		host = current_scene
		check(scene_changes==before+1 and old.get_ref()==null,"pause %s replaces the scene exactly once" % action)
		check(host.level_id==1 and host._player.character_id=="lan" and host.get_run_state()==host.RunState.MENU and host._start_screen.visible,"pause %s preserves its existing menu destination and character" % action)
		check(not paused and not host._transition_queued,"new scene releases pause and accepts future navigation")
		one_host()

func win_first_level() -> void:
	await start_lan()
	host._player._invulnerability_remaining = 1000.0
	await go(Vector3(0,0.05,-23))
	host._dungeon.get_node("MeleeEnemy").take_damage(999)
	await create_timer(1.2).timeout
	await go(Vector3(22,0.05,-23))
	host._boss.take_damage(999)
	await create_timer(1.2).timeout
	await go(Vector3(30,0.05,-45))
	check(host.get_run_state()==host.RunState.VICTORY,"real level-one exit produces settlement")

func repeated_result_actions(action: String) -> void:
	await win_first_level()
	var before := scene_changes
	var old: WeakRef = weakref(host)
	var win: Control = host._hud.get_result_screen()
	var button_name: String = {"next":"NextLevelButton","restart":"RestartButton","levels":"LevelSelectButton","menu":"MainMenuButton"}[action]
	for i in 8: win.get_node("%"+button_name).pressed.emit()
	# Different buttons in the same frame must not change the first accepted destination.
	for other in ["NextLevelButton","RestartButton","LevelSelectButton","MainMenuButton"]:
		win.get_node("%"+other).pressed.emit()
	check(host._transition_queued,"settlement %s owns the transition lock" % action)
	var direct := action in ["next", "restart"]
	check(NAVIGATION.pending_level_select==(action=="levels") and CHARACTERS.start_pending==direct,"settlement %s keeps the first arrival intent" % action)
	await frames(10)
	host = current_scene
	var nav: Node = host.get_node("MenuNavigation")
	check(scene_changes==before+1 and old.get_ref()==null,"settlement %s creates one replacement despite repeated and conflicting buttons" % action)
	check(host.level_id==(2 if action=="next" else 1) and host.get_run_state()==(host.RunState.PLAYING if direct else host.RunState.MENU) and host._player.character_id=="lan","settlement %s preserves its level, character and intended run state" % action)
	check(nav.level_select.visible==(action=="levels") and host._start_screen.visible==(action=="menu"),"settlement %s preserves the correct visible screen" % action)
	one_host()

func detached_and_deleted_host() -> void:
	await fresh()
	var before := scene_changes
	var stale: Node = host
	current_scene = null
	root.remove_child(stale)
	check(not stale.request_scene_change(SECOND),"detached scene ignores new requests without accessing its old tree")
	stale._transition_queued = true
	stale._change_scene(SECOND)
	await frames(2)
	check(scene_changes==before and current_scene==null,"detached executor callback leaves the scene tree unchanged")
	stale.free()
	await fresh()
	host.queue_free()
	check(not host.request_scene_change(SECOND),"a scene already queued for deletion rejects new requests")
	await frames(3)

func failure_and_retry() -> void:
	await start_lan()
	host.set_paused(true)
	var before := scene_changes
	var original: PackedScene = load(SECOND)
	var broken := PackedScene.new()
	broken.take_over_path(SECOND)
	print("EXPECTED_LOAD_FAILURE_BEGIN")
	check(host.request_scene_change(SECOND,{"character_id":"astra","start_run":true,"show_levels":true}),"first request is accepted before the controlled loading failure")
	check(not host.request_scene_change(FIRST),"duplicate requests remain blocked while the failing request is pending")
	await frames(8)
	print("EXPECTED_LOAD_FAILURE_END")
	check(not host._transition_queued and not host._transition_executing and scene_changes==before,"failed load releases both locks without replacing the scene")
	check(paused and host.get_run_state()==host.RunState.PAUSED,"failed load restores the original pause state")
	check(CHARACTERS.selected_id=="lan" and not CHARACTERS.start_pending and not NAVIGATION.pending_level_select,"failed load rolls back its role, auto-start and level-picker handoff")
	original.take_over_path(SECOND)
	check(host.request_scene_change(FIRST),"a new request can be accepted after loading failure")
	await frames(10)
	host = current_scene
	check(scene_changes==before+1 and host._player.character_id=="lan" and host._start_screen.visible and not paused,"retry succeeds once without stale flags or pause state")
	one_host()

func one_host() -> void:
	check(root.get_children().filter(func(n: Node) -> bool: return n.has_method("get_run_state")).size()==1,"only one live game host remains")
func go(point: Vector3) -> void:
	host._player.global_position = point
	host._player.velocity = Vector3.ZERO
	await frames(6)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
	# Transitions now await real threaded resources, not a fixed frame budget.
	var deadline := Time.get_ticks_msec()+15000
	while root.get_node_or_null("LoadingScreen") != null and Time.get_ticks_msec() < deadline:
		await process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
