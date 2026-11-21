extends SceneTree
const Profile = preload("res://scripts/integration/player_profile.gd")
const Progress = preload("res://scripts/integration/campaign_progress.gd")
var checks := 0
var failures := 0
var records: Array = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL "+label)
func frames(n: int = 6) -> void:
	for i in n:
		await physics_frame
		await process_frame
func click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event,true)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await frames()
func signature(panel: Control) -> Array:
	var state := []
	for task in panel._snapshot.tasks: state.append([task.id,task.done,task.count,task.total])
	return state
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("GODOT_TEST_OUTPUT_DIR").path_join(name+".png"))
func run() -> void:
	Profile.override_path = "user://collapsed-quest-profile.cfg"
	Progress.override_path = "user://collapsed-quest-progress.cfg"
	for level in [1,2,3]:
		var path: String = "res://Main.tscn" if level == 1 else "res://scenes/dungeon/Level0%dRun.tscn" % level
		change_scene_to_file(path)
		await frames(10)
		var host: Node = current_scene
		host._on_run_started()
		if level == 1: host.get_node("RunBindings").tutorial.skip()
		host._player._invulnerability_remaining = 100000
		var panel: Control = host._hud.get_node("LevelObjective")
		await frames()
		check(not panel._history_expanded and not panel._history_scroll.is_visible_in_tree(),"level%d starts with history collapsed" % level)
		check(not panel.get_node("%QuestChapter").visible and not panel.get_node("Content/ProgressRow").visible and not panel.get_node("%QuestProgress").visible,"duplicate chapter/target/progress rows do not consume the default HUD")
		check(panel.get_node("%QuestDetail").is_visible_in_tree() and panel.get_node("%QuestQuantity").is_visible_in_tree(),"the actual route and necessary count remain visible")
		var before := signature(panel)
		await click(panel.get_node("%HistoryToggle"))
		check(panel._history_expanded and panel._empty_history.is_visible_in_tree(),"real click opens an empty-history explanation")
		check(signature(panel) == before and not paused,"history browsing does not progress tasks or pause combat")
		await click(panel.get_node("%HistoryToggle"))
		check(not panel._history_expanded,"the same button collapses history")
		host._player.global_position = Vector3(0,0.05,-23) if level == 1 else (host._dungeon.get_node("Regions/Hub").global_position+Vector3(0,0.05,2) if level == 2 else host._dungeon.get_node("Rooms/B").global_position+Vector3(0,0.05,2))
		await frames(8)
		check(panel._completed.size() >= 1 and not panel._history_expanded and not panel._history_scroll.visible,"actual milestone completion updates history without auto-expanding it")
		check(panel.get_node("%HistoryToggle").text.contains(str(panel._completed.size())),"history button reports the retained completion count")
		var history_count: int = panel._completed.size()
		for dimensions in [Vector2i(1280,720),Vector2i(720,720),Vector2i(480,800),Vector2i(640,360)]:
			root.size = dimensions
			await frames(8)
			var folded := panel.get_global_rect()
			check(root.get_visible_rect().grow(1).encloses(folded) and panel.size.x <= 290 and panel.size.y <= 170,"collapsed quest has a small bounded footprint at "+str(dimensions))
			check(panel.get_node("%QuestTask").get_visible_line_count() == panel.get_node("%QuestTask").get_line_count() and panel.get_node("%QuestDetail").get_visible_line_count() == panel.get_node("%QuestDetail").get_line_count(),"action and route remain fully wrapped")
			before = signature(panel)
			await capture("level%d-folded-%dx%d" % [level,dimensions.x,dimensions.y])
			await click(panel.get_node("%HistoryToggle"))
			check(panel._history_scroll.is_visible_in_tree() and panel._completed.size() == history_count,"history expands without discarding stored milestones")
			var shown := 0
			for row in panel._history_rows:
				if row.is_visible_in_tree():
					shown += 1
					check(row.get_child(0).text == "✓","expanded history retains gold completion marks")
			check(shown >= 1 and signature(panel) == before,"expanded rows correspond to completed real tasks")
			check(panel._history_scroll.custom_minimum_size.y <= 132 and root.get_visible_rect().grow(1).encloses(panel.get_global_rect()),"expanded history is height limited")
			records.append({"level":level,"window":str(dimensions),"folded":str(folded),"expanded":str(panel.get_global_rect()),"history":shown})
			await capture("level%d-expanded-%dx%d" % [level,dimensions.x,dimensions.y])
			await click(panel.get_node("%HistoryToggle"))
			records[-1].refolded = str(panel.get_global_rect())
			check(not panel._history_scroll.is_visible_in_tree() and absf(panel.get_global_rect().size.y-folded.size.y) <= 1,"level%d %s: collapse returns %.1f to %.1f" % [level,dimensions,panel.get_global_rect().size.y,folded.size.y])
			await click(panel.get_node("%MapButton"))
			check(panel.quest_map.root.visible and paused,"map entry remains clickable in the collapsed header")
			panel.quest_map.close_map()
			await frames()
		root.size = Vector2i(1280,720)
		host.set_paused(true)
		before = signature(panel)
		await click(panel.get_node("%HistoryToggle"))
		check(signature(panel) == before and paused,"pause retains task state after a click behind the pause menu")
		host.set_paused(false)
	var file := FileAccess.open(OS.get_environment("GODOT_TEST_OUTPUT_DIR").path_join("layout.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"\t"))
	file.close()
	root.get_node("MusicManager").stop_music()
	current_scene.queue_free()
	await frames()
	print("QUEST_COLLAPSE_RESULT ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
