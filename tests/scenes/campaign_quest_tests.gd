extends SceneTree
## Actual encounter deaths, device interactions and physical exits; no task writes.
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
const SIZES = [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(1180,720),Vector2i(1179,720),Vector2i(1024,768),Vector2i(800,600),Vector2i(720,720),Vector2i(640,360),Vector2i(480,800)]
var host: Node
var panel: Control
var checks := 0
var failures := 0
var capture_enabled := false
var out := "user://campaign-quest"

func _initialize() -> void: run.call_deferred()
func run() -> void:
	PROFILE.override_path = "user://quest-profile.cfg"
	PROGRESS.override_path = "user://quest-progress.cfg"
	capture_enabled = "--capture" in OS.get_cmdline_user_args()
	if not OS.get_environment("GODOT_TEST_OUTPUT_DIR").is_empty(): out = OS.get_environment("GODOT_TEST_OUTPUT_DIR")
	if capture_enabled: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await second()
	await third()
	await boot(3)
	check(panel._completed.is_empty() and not panel._snapshot.complete,"New run resets UI history without changing persistent campaign progression")
	paused = false
	root.get_node("MusicManager").stop_music()
	current_scene.queue_free()
	await frames(3)
	print("CAMPAIGN_QUEST_RESULT %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func boot(level: int) -> void:
	paused = false
	change_scene_to_file("res://scenes/dungeon/Level%02dRun.tscn" % level)
	await frames(10)
	host = current_scene
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	host._on_run_started()
	host._player._invulnerability_remaining = 100000
	panel = host._hud.get_node("LevelObjective")
	await frames(8)

func second() -> void:
	await boot(2)
	var map: Node = host._dungeon
	expect("hub_arrival",0,1)
	check(panel.get_node("%QuestHeader").text == "主线任务" and panel.get_node("%ActiveMarker").text == "○","Level two shares the castle header and hollow active marker")
	await matrix("second-arrival")
	await room2("Hub")
	expect("hub",0,2)
	map.get_node("Enemies/Hub1").take_damage(999)
	await frames(2)
	expect("hub",1,2)
	check(panel.get_node("%QuestProgress").value == 50,"Live enemy count drives the visible progress bar")
	map.get_node("Enemies/Hub2").take_damage(999)
	await frames(2)
	expect("relay_arrival",0,1)
	check(panel._history_rows[1].visible and panel._history_rows[1].get_child(0).text == "✓","Encounter completion immediately retains a gold history checkmark")
	await go(Vector3(-34,0.05,-26))
	check(panel.get_node("%OptionalContext").visible and panel._snapshot.tasks[panel._snapshot.current].id == "relay_arrival","Optional archive instructions do not replace or add mandatory main tasks")
	check(not panel._snapshot.complete,"Optional room access never completes the main quest")
	await room2("Relay")
	expect("relay_guards",0,2)
	for id in ["Relay1","Relay2"]: map.get_node("Enemies/"+id).take_damage(999)
	await frames(2)
	expect("relay",0,1)
	await go(map.get_node("Devices/Relay").global_position+Vector3(0,0.05,1.35))
	check(host._items.try_interact_nearest(),"Existing E interaction powers the actual relay")
	await frames(3)
	expect("ante_arrival",0,1)
	await room2("Antechamber")
	expect("ante",0,3)
	for id in ["Antechamber1","Antechamber2","Antechamber3"]: map.get_node("Enemies/"+id).take_damage(999)
	await frames(2)
	expect("boss_arrival",0,1)
	await room2("Boss")
	expect("boss",0,1)
	check(panel.get_node("%QuestTask").text.contains(host._boss.boss_name),"Second-level objective names the actual Boss")
	await matrix("second-real-boss")
	map.get_node("Boss").take_damage(999)
	await frames(2)
	expect("gate",0,1)
	await create_timer(1.1).timeout
	expect("exit",0,1)
	await matrix("second-history")
	check(panel._completed.size() == 10 and map.puzzle.get_state() != map.puzzle.State.CLAIMED,"All main pre-exit milestones retain history without requiring optional vault reward")
	await go(map.get_node("ExitArea").global_position*Vector3(1,0,1)+Vector3.UP*0.05)
	await frames(3)
	check(panel._snapshot.complete and panel.get_node("%QuestTask").text == "关卡目标已完成" and panel.get_node("%ActiveMarker").text == "✓","Second-level physical exit completes the journal and gold marker")
	check(host.get_run_state() == host.RunState.VICTORY,"Original second-level exit still owns victory")

func third() -> void:
	await boot(3)
	var map: Node = host._dungeon
	expect("control",0,1)
	await matrix("third-arrival")
	await go(map.get_node("Rooms/B").global_position+Vector3(0,0.05,2))
	expect("c_guards",0,2)
	await use_station("tide")
	check(panel.get_node("%QuestTask").text == "检查中央潮井的潮位总控" and panel.get_node("%QuestQuantity").text == "0/1","Wrong water level displays the actual prerequisite action with its own quantity")
	await use_station("tide")
	await clear3("C")
	expect("conductor",0,1)
	await use_station("conductor")
	expect("east",0,1)
	await use_station("director")
	expect("high",0,1)
	await use_station("tide")
	expect("e_guards",0,2)
	await clear3("E")
	expect("f_guards",0,2)
	await clear3("F")
	expect("charge",0,1)
	await use_station("charge")
	expect("highwalk",0,1)
	await use_station("highwalk")
	expect("low",0,1)
	await use_station("tide")
	expect("west",0,1)
	await use_station("director")
	expect("i_guards",0,1)
	check_maintenance_map("i_guards","干涸维修井")
	await go(map.get_node("Rooms/I").global_position+Vector3(0,0.05,3))
	expect("i_guards",0,1)
	check(panel.get_node("%QuestQuantity").text == "0/1" and panel.get_node("%QuestProgress").value == 0,"Maintenance-well journal shows actual remaining combat progress")
	check_maintenance_map("i_guards","干涸维修井")
	check(panel.get_node("%QuestTask").text.contains("双链执刑官"),"Visible journal requires the actual maintenance-well enemy before release")
	await use_station("release")
	check(map.get_storage_state() == map.Storage.STORED,"Release remains blocked while the maintenance-well enemy is alive")
	await clear3("I")
	expect("release",0,1)
	check_maintenance_map("release","泄压装置")
	var before: Dictionary = panel._snapshot.duplicate(true)
	host.set_paused(true)
	await create_timer(0.15).timeout
	check(panel._snapshot == before and not host._items.try_interact_nearest(),"Pause freezes displayed state and retains original interaction permissions")
	host.set_paused(false)
	await matrix("third-before-release")
	# Real double-confirm reset preserves combat clears, not puzzle completion.
	await use_station("reset")
	await use_station("reset")
	expect("conductor",0,1)
	check(panel._completed.has("charge") and not panel._snapshot.tasks[7].done,"Reset keeps historical evidence while clearing the live charge checkmark")
	check(panel._history_rows[7].get_child(1).text.contains("当前需重做"),"Historic puzzle step explicitly identifies the need to redo it")
	check(panel._snapshot.tasks[1].done and panel._snapshot.tasks[5].done and panel._snapshot.tasks[6].done,"Reset retains actual C/E/F combat completion")
	await use_station("conductor")
	await use_station("director")
	await use_station("tide")
	await use_station("charge")
	await use_station("highwalk")
	await use_station("tide")
	await use_station("director")
	check(panel._snapshot.tasks.filter(func(task): return task.id == "i_guards")[0].done,"Puzzle reset preserves the completed maintenance-well battle")
	await use_station("release")
	expect("g_guards",0,1)
	check_maintenance_map("g_guards","中心闸庭")
	await go(map.get_node("Rooms/G").global_position+Vector3(0,0.05,3))
	check(host._boss_bar.visible and panel.get_node("%QuestTask").text.contains(host._boss.boss_name),"Third-level real Boss and named quest remain visible together")
	await matrix("third-real-boss")
	host._boss.take_damage(host._boss.max_hp/2)
	await frames(3)
	expect("g_guards",0,1)
	check(host._boss._phase_two and map._summons.is_empty(),"Half-health Boss changes cadence without adding a second species")
	check(not panel.get_node("%QuestTask").text.contains("执刑官"),"Center-court journal names only its actual Boss")
	host._boss.take_damage(999)
	await frames(2)
	check(not panel._snapshot.complete and map._progress.is_complete(&"G"),"Single Boss death clears its room but does not replace gate and physical exit steps")
	expect("gate",0,1)
	await create_timer(0.6).timeout
	expect("exit",0,1)
	await matrix("third-history")
	check(panel._completed.size() == 15 and not map._inventory.has_claimed(map.REWARD_ID),"Garden reward is optional; all fifteen pre-exit milestones have actual history")
	await go(map.get_node("Rooms/J").global_position+Vector3.UP*0.05)
	await frames(3)
	check(panel._snapshot.complete and panel.get_node("%QuestQuantity").text == "16/16","Real J exit finishes every main step including maintenance-well combat")
	check(host.get_run_state() == host.RunState.VICTORY,"Original tide, final-guard and exit conditions still control victory")

func expect(id: String, count: int, total: int) -> void:
	var task: Dictionary = panel._snapshot.tasks[panel._snapshot.current]
	check(task.id == id,"Current real milestone: "+id+" (actual "+task.id+")")
	check(panel.get_node("%QuestQuantity").text == "%d/%d" % [count,total],"Visible necessary quantity: %d/%d" % [count,total])
	for i in panel._snapshot.tasks.size():
		check(panel._marks[i].get_child(1).text == ("✓" if panel._snapshot.tasks[i].done else "○"),"Marker matches real state: "+panel._snapshot.tasks[i].id)
	check(panel.get_node("%QuestTask").get_theme_color("font_color") == panel.GOLD,"Active action uses the same castle gold highlight")

func check_maintenance_map(id: String, location: String) -> void:
	var quest_map: CanvasLayer = panel.quest_map
	check(quest_map.open_map(),"Actual journal map opens for "+id)
	check(quest_map.view.snapshot.target.id == id and quest_map.view.snapshot.target.name.contains(location),"Actual map marker names the current action: "+id)
	check(quest_map.objective.text.contains(panel.get_node("%QuestTask").text),"Visible map objective agrees with visible journal action: "+id)
	quest_map.close_map()

func matrix(label: String) -> void:
	for size in SIZES:
		root.size = size
		host._hud.show_item_message("")
		await frames(10)
		var rect := panel.get_global_rect()
		check(panel.is_visible_in_tree() and root.get_visible_rect().grow(1).encloses(rect),label+str(size)+": quest remains visible inside the viewport")
		var separated := true
		for other in [host._hud.get_node("Panel"),host._hud.get_node("ResourcesPanel"),host._hud.get_node("CooldownBar"),host._hud.hotbar,host._boss_bar,host._commerce.shortcut]:
			if other.is_visible_in_tree() and rect.intersection(other.get_global_rect()).get_area() > 1: separated = false
		check(separated,label+str(size)+": quest avoids permanent HUD and Boss bar")
		for key in ["QuestTask","QuestQuantity","QuestDetail"]:
			var text: Label = panel.get_node("%"+key)
			check(text.is_visible_in_tree() and text.get_visible_line_count() == text.get_line_count() and text.size.y >= text.get_minimum_size().y,label+str(size)+": action/target/quantity wraps without clipping: "+key)
		check(not panel._flow.visible and not panel._history_scroll.visible and not panel._history_expanded,label+str(size)+": completed history stays collapsed at every width")
		if size in [Vector2i(1280,720),Vector2i(720,720),Vector2i(480,800),Vector2i(640,360)]: await capture(label+"-%dx%d" % [size.x,size.y])
		if panel._completed.size() >= 3:
			var prior: Dictionary = panel._snapshot.duplicate(true)
			panel.get_node("%HistoryToggle").button_pressed = true
			await frames(6)
			check(panel._history_scroll.is_visible_in_tree() and panel._snapshot == prior,label+str(size)+": expanding history preserves actual quest state")
			check(panel._history_scroll.custom_minimum_size.y <= 132 and root.get_visible_rect().grow(1).encloses(panel.get_global_rect()),label+str(size)+": expanded history remains bounded")
			var history_clear := true
			for other in [host._hud.get_node("Panel"),host._hud.get_node("ResourcesPanel"),host._hud.get_node("CooldownBar"),host._hud.hotbar,host._boss_bar,host._commerce.shortcut]:
				if other.is_visible_in_tree() and panel.get_global_rect().intersection(other.get_global_rect()).get_area() > 1: history_clear = false
			check(history_clear,label+str(size)+": expanded history avoids permanent HUD and real Boss health")
			if panel._completed.size() >= 10:
				var bar: VScrollBar = panel._history_scroll.get_v_scroll_bar()
				check(bar.max_value > bar.page,label+str(size)+": long completed history is genuinely scrollable")
				bar.value = bar.max_value
				await frames(2)
			if size == Vector2i(1280,720): await capture(label+"-expanded")
			panel.get_node("%HistoryToggle").button_pressed = false
			await frames(4)
	root.size = Vector2i(1280,720)
	await frames(8)

func room2(id: String) -> void:
	await go(host._dungeon.get_node("Regions/"+id).global_position+Vector3(0,0.05,2))
func clear3(id: String) -> void:
	await go(host._dungeon.get_node("Rooms/"+id).global_position+Vector3(0,0.05,3))
	var killed := 0
	for enemy in host._dungeon.get_node("Enemies").get_children():
		if is_instance_valid(enemy) and enemy.get_meta("room",&"") == StringName(id) and not enemy.is_dead():
			enemy.take_damage(999)
			killed += 1
			await frames(2)
			if killed == 1 and host._dungeon._progress.get_total_enemies(StringName(id)) == 2: check(panel.get_node("%QuestQuantity").text == "1/2","Actual first kill immediately updates "+id+" quantity")
	await frames(3)
func use_station(id: String) -> void:
	await go(host._dungeon.get_node("Stations/"+id).global_position+Vector3(0,0.05,1.1))
	# 掉落金币/地图补给可能比机关更近；按真实E优先级先拾取，再操作指定机关。
	var station: Node3D = host._dungeon.get_node("Stations/"+id)
	for i in 6:
		var target: Node3D = host._items._get_nearest_interaction_target()
		if target == station or target == null: break
		check(target is Area3D and host._items.try_interact_nearest(),"Collect nearer pickup before device interaction: "+id)
		await frames(2)
	check(host._items._get_nearest_interaction_target() == station,"Nearest E target is the actual device: "+id)
	check(host._items.try_interact_nearest(),"Existing nearest-target E interaction: "+id)
	await frames(3)
func go(point: Vector3) -> void:
	host._player.global_position = point
	host._player.velocity = Vector3.ZERO
	await frames(6)
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func capture(name: String) -> void:
	if not capture_enabled: return
	await process_frame
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(out.path_join(name+".png")) == OK,"Capture "+name)
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
