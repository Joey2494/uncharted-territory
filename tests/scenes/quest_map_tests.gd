extends SceneTree
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
const DATA = preload("res://scenes/ui/quest_map_data.gd")
const SIZES = [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(1180,720),Vector2i(1179,720),Vector2i(1024,768),Vector2i(800,600),Vector2i(720,720),Vector2i(640,360),Vector2i(480,800)]
var host: Node
var panel: Control
var map: CanvasLayer
var checks := 0
var failures := 0
var capture_enabled := false
var out := "user://quest-map"

func _initialize() -> void: run.call_deferred()
func run() -> void:
	PROFILE.override_path = "user://map-profile.cfg"
	PROGRESS.override_path = "user://map-campaign.cfg"
	capture_enabled = "--capture" in OS.get_cmdline_user_args()
	if not OS.get_environment("GODOT_TEST_OUTPUT_DIR").is_empty(): out = OS.get_environment("GODOT_TEST_OUTPUT_DIR")
	if capture_enabled: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for level in [1,2,3]:
		await boot(level)
		check(not map.open_map(),"Map cannot open in the main menu")
		host._on_run_started()
		host._player._invulnerability_remaining = 100000
		if level == 1: host.get_node("RunBindings").tutorial.skip()
		await frames(8)
		check(panel.get_node("%MapButton").text == "地图" and not panel.get_node("%MapButton").disabled,"All three trackers expose a map button and keyboard shortcut")
		check_copy()
		await click(panel.get_node("%MapButton"))
		check(map.root.visible and paused and host.get_run_state() == host.RunState.PAUSED,"Actual map button opens a modal map using the host pause permission")
		check(not host._commerce.pause_menu.visible,"Map does not stack the pause menu")
		var elapsed: float = host._elapsed_seconds
		var position: Vector3 = host._player.global_position
		var old: Dictionary = panel._snapshot.duplicate(true)
		Input.action_press("move_forward")
		await create_timer(0.15).timeout
		Input.action_release("move_forward")
		check(host._elapsed_seconds == elapsed and position == host._player.global_position and panel._snapshot == old,"Reading the map freezes movement, the game clock and task progression")
		check(not host._items.try_interact_nearest(),"The map cannot bypass actual E permissions")
		var snapshot: Dictionary = map.view.snapshot
		check(snapshot.player == Vector2(position.x,position.z),"Player marker uses the real X/Z position")
		check(not snapshot.target.is_empty() and snapshot.target.name in ["回廊中庭","分流中庭","中央潮井 · 潮位总控"],"Initial marker names the real current main location")
		if level == 1:
			check(not _has_room(snapshot,"HiddenRewardRoom") and not _has_room(snapshot,"SecretPassage"),"The map does not reveal the castle's concealed corridor or reward room")
		for size in SIZES:
			root.size = size
			await frames(10)
			verify("level%d/%s" % [level,size])
			if size in [Vector2i(1280,720),Vector2i(720,720),Vector2i(640,360),Vector2i(480,800)]: await capture("level%d-map-%dx%d" % [level,size.x,size.y])
		await key(KEY_P)
		check(map.root.visible and host._commerce.view == host._commerce.View.NONE,"Action/shop shortcuts cannot open a second modal over the map")
		await key(KEY_ESCAPE)
		check(not map.root.visible and not paused and host.get_run_state() == host.RunState.PLAYING,"Escape closes just the map and resumes the original game")
		await key(KEY_M)
		check(map.root.visible and paused,"M opens the same map")
		await click(map.close_button)
		check(not map.root.visible and not paused,"The visible return button restores gameplay")
		host.set_paused(true)
		check(not map.open_map() and host._commerce.pause_menu.visible,"Opening a map cannot take over an existing pause menu")
		host.set_paused(false)
		await location_checks(level)
		check_copy()
		await key(KEY_M)
		check(map.root.visible,"Map reopens after actual main progression")
		await frames(5)
		check(map.view.snapshot.target.name.contains(["","守门者大厅","导能回廊","折流廊"][level]),"Marker changes to the next true action location")
		await capture("level%d-next-target" % level)
		map.close_map()
		# Boss presentation fixture checks layout only; original combat regressions
		# separately verify task deaths, roster ownership and physical exits.
		host._boss_bar.begin_encounter(host._boss.boss_name,20,40)
		root.size = Vector2i(720,720)
		await frames(8)
		await click(panel.get_node("%MapButton"))
		check(map.root.visible and panel._compact,"Compact Boss layout retains a working map entry")
		verify("level%d/boss" % level)
		await capture("level%d-boss-map" % level)
		map.close_map()
		check(host._boss_bar.visible and host.get_run_state() == host.RunState.PLAYING,"Closing the map preserves the existing Boss display and encounter state")
	paused = false
	root.get_node("MusicManager").stop_music()
	current_scene.queue_free()
	await frames(3)
	print("QUEST_MAP_RESULT %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func boot(level: int) -> void:
	paused = false
	change_scene_to_file("res://Main.tscn" if level == 1 else "res://scenes/dungeon/Level%02dRun.tscn" % level)
	await frames(10)
	host = current_scene
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	panel = host._hud.get_node("LevelObjective")
	map = panel.quest_map
	await frames(5)

func location_checks(level: int) -> void:
	if level == 1:
		await go(Vector3(0,0.05,-23))
		host._dungeon.get_node("MeleeEnemy").take_damage(999)
		await frames(4)
	elif level == 2:
		await go(host._dungeon.get_node("Regions/Hub").global_position+Vector3(0,0.05,2))
		for id in ["Hub1","Hub2"]: host._dungeon.get_node("Enemies/"+id).take_damage(999)
		await frames(4)
	else:
		await go(host._dungeon.get_node("Rooms/B").global_position+Vector3(0,0.05,2))
		await go(host._dungeon.get_node("Rooms/C").global_position+Vector3(0,0.05,3))
		for enemy in host._dungeon.get_node("Enemies").get_children():
			if enemy.get_meta("room",&"") == &"C": enemy.take_damage(999)
		await go(host._dungeon.get_node("Stations/conductor").global_position+Vector3(0,0.05,1.1))
		check(host._items.try_interact_nearest(),"Actual conductor pickup advances the displayed destination")
		await frames(4)
		var data: Dictionary = DATA.read(host._dungeon,panel._snapshot,3)
		check(data.target.point == Vector2(host._dungeon.get_node("Stations/director").global_position.x,host._dungeon.get_node("Stations/director").global_position.z),"Puzzle marker points to the real device, not an invented waypoint")
		var before: Dictionary = data.paths.filter(func(path: Dictionary) -> bool: return path.id == "BC")[0]
		await go(host._dungeon.get_node("Stations/tide").global_position+Vector3(0,0.05,1.1))
		check(host._items.try_interact_nearest(),"Actual tide control changes route availability")
		await frames(4)
		var after: Dictionary = DATA.read(host._dungeon,panel._snapshot,3).paths.filter(func(path: Dictionary) -> bool: return path.id == "BC")[0]
		check(before.open and not after.open,"Map route state follows the actual tidal barrier")
		check(DATA.goal(host._dungeon,panel._snapshot,3).name.contains("中央潮井"),"Wrong water level points to the current control to inspect without specifying the answer")
		check(host._items.try_interact_nearest(),"Restore the actual low water route")
		await frames(4)

func check_copy() -> void:
	for task in panel._snapshot.tasks:
		var text: String = task.title+task.detail+task.target
		for code in [" A "," B "," C "," D "," F "," G "," I "," J ","C—I","F—B"]:
			check(not text.contains(code),"Task uses place names instead of room code: "+task.id)
		for answer in ["东向 F","西向 I","转向东侧","转向西侧","升高水位","降低水位","供能可回供"]:
			check(not text.contains(answer),"Task names observation/action without a puzzle answer: "+task.id)
		check(not text.contains("继续探索") and not text.contains("前往深处"),"Action identifies a concrete destination or object: "+task.id)

func verify(label: String) -> void:
	var bounds := root.get_visible_rect().grow(1)
	check(bounds.encloses(map.card.get_global_rect()),label+": map card fits the viewport")
	var controls: Array[Control] = [map.title,map.close_button,map.location,map.objective,map.view,map.legend,map.note]
	var separated := true
	for i in controls.size():
		check(bounds.encloses(controls[i].get_global_rect()),label+": modal content fits: "+controls[i].name)
		for j in range(i+1,controls.size()):
			if controls[i].get_global_rect().intersection(controls[j].get_global_rect()).get_area() > 1: separated = false
	check(separated,label+": title, locations, map, legend and return button are separated")
	for text: Label in [map.location,map.objective,map.legend,map.note]:
		check(text.get_visible_line_count() == text.get_line_count() and text.size.y >= text.get_minimum_size().y,label+": map text wraps completely")
	var pixels: float = map.location.get_theme_font_size("font_size")*root.size.x/root.get_visible_rect().size.x
	check(pixels >= 13,label+": map text stays readable after canvas scaling")
	check(not map.objective.text.contains("东向") and not map.objective.text.contains("西向"),label+": map objective does not reveal orientation answers")

func _has_room(data: Dictionary, id: String) -> bool:
	return not data.rooms.filter(func(room: Dictionary) -> bool: return room.id == id).is_empty()
func go(position: Vector3) -> void:
	host._player.global_position = position
	host._player.velocity = Vector3.ZERO
	await frames(8)
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event,true)
		await frames(2)
func click(control: Control) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event,true)
		await frames(2)
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
