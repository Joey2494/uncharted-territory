extends SceneTree
## Real room activation, damage, rune interaction and physical exit drive every journal state.
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
const PRESENTER = preload("res://scenes/ui/castle_objective_presenter.gd")
var host: Node
var panel: Control
var checks := 0
var failures := 0
var captures := false
var output := "user://castle-quest-captures"

func _initialize() -> void: run.call_deferred()
func run() -> void:
	PROFILE.override_path = "user://castle-quest-profile.cfg"
	PROGRESS.override_path = "user://castle-quest-campaign.cfg"
	captures = "--capture" in OS.get_cmdline_user_args()
	if not OS.get_environment("GODOT_TEST_OUTPUT_DIR").is_empty(): output = OS.get_environment("GODOT_TEST_OUTPUT_DIR")
	if captures: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	await boot()
	check(panel.get_node("%QuestHeader").text == "主线任务","The quest header omits the mandatory label")
	verify_current("courtyard",0)
	for task in panel._snapshot.tasks:
		var copy: String = task.title+task.detail+task.target
		check(not copy.contains("继续探索") and not copy.contains("前往深处") and not copy.contains("深入") and not copy.contains("寻找离开"),"Main objective copy names a concrete action and target: "+task.id)
	check(panel.world == host._dungeon and panel.mouse_filter == Control.MOUSE_FILTER_IGNORE,"First-level journal binds the real map and never intercepts combat input")
	check(not host._dungeon.get_node("MeleeEnemy").take_damage(999),"An inactive courtyard enemy cannot be completed from the entrance")
	host._on_exit_reached()
	check(not panel._snapshot.complete and host.get_run_state() == host.RunState.PLAYING,"An unauthorized exit callback cannot finish the journal or level")
	await capture("01-arrival")
	await go(Vector3(0,0.05,-23))
	verify_current("guard",1)
	var roster: Node = host._dungeon.get_node("RoomProgress")
	check(panel._snapshot.tasks[1].total == roster.get_total_enemies(&"l1_crossroads"),"Guard quantity comes from the registered encounter roster")
	await capture("02-guard-active")
	check(host._dungeon.get_node("MeleeEnemy").take_damage(999),"The actual courtyard guard accepts damage")
	verify_current("hall",2)
	await frames(3)
	await capture("02-courtyard-complete")
	await go(Vector3(0,0.05,2))
	verify_current("hall",2)
	host.set_paused(true)
	var snapshot: Dictionary = panel._snapshot.duplicate(true)
	await create_timer(0.1).timeout
	check(panel._snapshot == snapshot,"Pause retains completed tasks without advancing game progression")
	host.set_paused(false)
	await go(Vector3(-26,0.05,-27))
	check(not panel.has_node("%QuestOptional") and panel._snapshot.show_optional,"The main journal keeps only mandatory objectives; optional context is separate")
	verify_current("hall",2)
	await rune(0,"SunRune")
	check(panel._snapshot.optional[0].count == 0 and not panel._snapshot.optional[0].done,"Wrong rune order never earns a completion check")
	await create_timer(0.8).timeout
	await rune(1,"MoonRune")
	check(panel._snapshot.optional[0].count == 1 and not panel._snapshot.optional[0].done,"One real rune interaction displays partial 1/3 progress")
	check(not panel._snapshot.optional[0].done and not panel._snapshot.optional[1].done,"Partial rune progress does not complete either optional objective")
	await capture("03-rune-partial")
	await create_timer(0.25).timeout
	await rune(1,"MoonRune")
	check(panel._snapshot.optional[0].count == 0,"Failed sequence resets displayed partial progress")
	await create_timer(0.8).timeout
	for entry in [[1,"MoonRune"],[2,"StarRune"],[0,"SunRune"]]:
		await rune(entry[0],entry[1])
		if entry[0] != 0: await create_timer(0.25).timeout
	check(not panel._snapshot.optional[0].done,"Three inputs do not mark the door complete during its opening animation")
	await create_timer(1.0).timeout
	await frames(2)
	check(panel._snapshot.optional[0].done and not panel._snapshot.optional[1].done,"Actual door completion finishes only the rune objective")
	check(not host._dungeon.get_node("RunePuzzle").claim_reward(host._player),"Remote reward requests cannot complete the chest objective")
	await go(Vector3(-26,0.05,-39.5))
	check(host._items.try_interact_nearest(),"Real E interaction claims the optional chest")
	check(panel._snapshot.optional[1].done,"Successful inventory delivery completes the optional chest state")
	await capture("03-rune-branch-complete")
	await go(Vector3(0,0.05,-23))
	verify_current("hall",2)
	check(panel._snapshot.optional[0].done and panel._snapshot.optional[1].done,"Leaving the branch retains both completed optional states")
	await go(Vector3(28,0.05,-23))
	verify_current("boss",3)
	check(panel.get_node("%QuestTask").text.contains(host._boss.boss_name),"Boss target uses the actual enemy's authored name")
	root.size = Vector2i(720,720)
	await frames(5)
	check(panel.visible and host._boss_bar.visible and panel._compact,"Compact Boss combat keeps the current task and gold markers visible")
	await capture("04-boss-compact")
	check(host._boss.take_damage(999),"Actual Boss damage advances the encounter")
	verify_current("gate",4)
	check(host.get_run_state() == host.RunState.PLAYING,"Boss death does not replace actual exit traversal")
	await wait_exit()
	verify_current("exit",5)
	for dimensions in [Vector2i(1280,720),Vector2i(720,720),Vector2i(480,800),Vector2i(640,360)]:
		root.size = dimensions
		await frames(6)
		verify_layout()
		await capture("05-exit-ready-%dx%d" % [dimensions.x,dimensions.y])
	root.size = Vector2i(1280,720)
	await frames(5)
	await exit_level()
	check(panel._snapshot.complete and panel.get_node("%QuestTask").text == "关卡目标已完成","Physical exit traversal immediately marks all main objectives complete")
	check(panel.get_node("%ActiveMarker").text == "✓","Final completion replaces the active hollow marker with a check")
	check(host.get_run_state() == host.RunState.VICTORY and panel._completed.size() == 6,"Original victory flow and all six journal checks finish together")
	check(host._hud.get_result_screen().summary_label.text == "失落石堡 · 主线目标已全部完成","Existing settlement visibly preserves the all-complete state")
	await frames(50)
	await capture("06-level-complete")
	var previous_id := host.get_instance_id()
	check(host.restart_run(),"The existing restart action remains available")
	var deadline := Time.get_ticks_msec()+45000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != previous_id and root.get_node_or_null("LoadingScreen") == null: break
	await frames(4)
	host = current_scene
	panel = host._hud.get_node("LevelObjective")
	host._player._invulnerability_remaining = 100000.0
	host.get_node("RunBindings").tutorial.skip()
	verify_current("courtyard",0)
	check(panel._completed.is_empty() and not panel._snapshot.show_optional,"A new run clears journal history and optional completion")
	# The optional puzzle remains optional: finish a second real run without touching it.
	await go(Vector3(0,0.05,-23))
	host._dungeon.get_node("MeleeEnemy").take_damage(999)
	await frames(3)
	await go(Vector3(28,0.05,-23))
	host._boss.take_damage(999)
	await wait_exit()
	await exit_level()
	check(panel._snapshot.complete and not host._rune_puzzle.is_solved() and not host._rune_puzzle.is_reward_claimed(),"All main objectives complete without the optional rune puzzle or chest")
	paused = false
	root.get_node("MusicManager").stop_music()
	current_scene.queue_free()
	await frames(3)
	print("CASTLE_QUEST_RESULT %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func boot() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(8)
	host = current_scene
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	host._on_run_started()
	host._player._invulnerability_remaining = 100000.0
	host.get_node("RunBindings").tutorial.skip()
	panel = host._hud.get_node("LevelObjective")
	await frames(4)
func verify_current(id: String, completed: int) -> void:
	panel.refresh()
	check(panel._snapshot.tasks[panel._snapshot.current].id == id,"Actual current action is "+id)
	check(panel._snapshot.completed.size() == completed,"Persistent completed quantity is %d" % completed)
	for i in completed:
		check(panel._marks[i].get_child(1).text == "✓" and panel._history_rows[i].get_child(0).text == "✓","Completed step %d retains a check in summary and history" % (i+1))
	var pending_hollow := true
	for i in range(completed,panel._snapshot.tasks.size()):
		pending_hollow = pending_hollow and panel._marks[i].get_child(1).text == "○"
	check(pending_hollow and panel.get_node("%ActiveMarker").text == "○","All unfinished task markers, including the active task, are hollow circles")
	var task: Dictionary = panel._snapshot.tasks[panel._snapshot.current]
	check(panel.get_node("%QuestTask").text == task.title and panel.get_node("%QuestQuantity").text == "%d/%d" % [task.count,task.total],"The highlighted action and quantity match the actual current task")
	var active_frame: StyleBoxFlat = panel.get_node("Content/Active").get_theme_stylebox("panel")
	check(active_frame.border_width_left >= 3 and panel.get_node("%QuestTask").get_theme_color("font_color") == panel.GOLD,"Current objective has an independent gold frame and highlighted text")
func verify_layout() -> void:
	check(root.get_visible_rect().grow(1).encloses(panel.get_global_rect()),"Journal fits the current viewport")
	var clear: Rect2 = host._dungeon.get_node("Camera3D").get_safe_frame()
	var size: Vector2 = root.get_visible_rect().size
	check(Rect2(clear.position*size,clear.size*size).intersection(panel.get_global_rect()).get_area() < 1,"Combat camera reserves a region clear of the journal")
	for other in [host._boss_bar,host._commerce.shortcut,host._hud.get_node("Panel"),host._hud.get_node("ResourcesPanel"),host._hud.get_node("FeedbackPanel"),host._hud.get_node("Hotbar"),host._hud.get_node("CooldownBar")]:
		if other.is_visible_in_tree(): check(not panel.get_global_rect().intersects(other.get_global_rect()),"Journal avoids "+String(other.name))
func rune(kind: int, node: String) -> void:
	var puzzle: Node3D = host._dungeon.get_node("RunePuzzle")
	await go(puzzle.get_node(node).global_position+Vector3(0,0.05,1.2))
	check(puzzle.activate_rune(kind,host._player),"Accepted actual rune interaction: "+node)
	await frames(2)
func wait_exit() -> void:
	var deadline := Time.get_ticks_msec()+5000
	while not host._dungeon.is_exit_open() and Time.get_ticks_msec() < deadline: await frames(2)
	check(host._dungeon.is_exit_open(),"The original exit gate finishes opening")
func exit_level() -> void:
	var exit_position: Vector3 = host._dungeon.get_node("ExitTrigger").global_position
	await go(Vector3(exit_position.x,0.05,exit_position.z))
	await frames(4)
func go(position: Vector3) -> void:
	host._player.global_position = position
	await frames(4)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func capture(label: String) -> void:
	if not captures: return
	await process_frame
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"Capture "+label)
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
