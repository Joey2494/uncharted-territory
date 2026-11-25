extends SceneTree
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
const DATA = preload("res://scenes/ui/quest_map_data.gd")
const PLAN = preload("res://scenes/dungeon/level04/observatory_plan.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	PROFILE.override_path = "user://map-migration-profile.cfg"
	PROGRESS.override_path = "user://map-migration-campaign.cfg"
	run.call_deferred()
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL "+message)
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)
func capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	var output := OS.get_environment("GODOT_TEST_OUTPUT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"Screenshot "+label)
func area(points: PackedVector2Array) -> float:
	var result := 0.0
	for i in points.size(): result += points[i].cross(points[(i+1)%points.size()])
	return absf(result)*0.5
func run() -> void:
	change_scene_to_file("res://scenes/dungeon/Level04Run.tscn")
	await frames(12)
	var host: Node = current_scene
	host._on_run_started()
	var world: Node = host._dungeon
	world.player._invulnerability_remaining = 100000
	var tracker: Control = host._hud.get_node("LevelObjective")
	var map: CanvasLayer = tracker.quest_map
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	await frames(75)
	await key(KEY_M)
	check(map.root.visible and paused,"Actual M key opens the detailed map and pauses play")
	var data: Dictionary = map.view.snapshot
	check(data.rooms.size() == 12 and data.paths.size() == 16,"All target rooms and sixteen wing passages remain")
	for entry in data.rooms+data.paths:
		var deck: Node3D = world.layout.get_node(entry.id+"/Deck")
		var expected := 0.0
		for child in deck.get_children():
			if not child is MeshInstance3D: continue
			var faces: PackedVector3Array = child.mesh.get_faces()
			for i in range(0,faces.size(),3):
				var a := Vector2(faces[i].x,faces[i].z)
				var b := Vector2(faces[i+1].x,faces[i+1].z)
				var c := Vector2(faces[i+2].x,faces[i+2].z)
				expected += absf((b-a).cross(c-a))*0.5
		check(absf(area(entry.polygon)-expected)<0.01,"Map outline exactly covers actual floor "+entry.id)
	var elapsed: float = world.elapsed
	var position: Vector3 = world.player.global_position
	Input.action_press("move_forward")
	await frames(12)
	Input.action_release("move_forward")
	check(elapsed == world.elapsed and position == world.player.global_position,"Map freezes real gameplay")
	for dimensions in [Vector2i(1280,720),Vector2i(800,600),Vector2i(640,360),Vector2i(480,800)]:
		root.size = dimensions
		await frames(12)
		if not "--capture" in OS.get_cmdline_user_args(): continue
		check(map.view.label_names.size() == 12,"All Chinese names are rendered "+str(dimensions))
		for i in data.rooms.size():
			check(map.view.label_names[i].begins_with(PLAN.NAMES[data.rooms[i].id]),"Complete Chinese name "+data.rooms[i].id)
			check(Rect2(Vector2.ZERO,map.view.size).encloses(map.view.label_rects[i]),"Name remains inside map panel")
			for j in range(i): check(not map.view.label_rects[i].intersects(map.view.label_rects[j]),"Chinese labels do not overlap")
		await capture("map-%dx%d" % [dimensions.x,dimensions.y])
	root.size = Vector2i(1280,720)
	await frames(8)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	event.position = map.view.size*0.5
	map.view._gui_input(event)
	check(map.view.zoom > 1.0,"Wheel zoom is restored")
	map.view.pan = Vector2(20,15)
	event.button_index = MOUSE_BUTTON_RIGHT
	map.view._gui_input(event)
	check(map.view.zoom == 1 and map.view.pan == Vector2.ZERO,"Right click resets zoom and pan")
	for lock in data.locks:
		check(lock.name.contains(" ↔ ") and not lock.reason.contains(" E ") and not lock.reason.contains(" F "),"Locks use full Chinese names and retain target reasons")
	map.close_map()
	world.player.global_position = world.layout.room_center("B")+Vector3(1,0.05,3)
	await frames(6)
	var active := DATA.read(world,tracker._snapshot,4)
	check(active.enemies.size() == world.combat.enemy_count() and active.enemies.size() == 2,"Live enemy markers match the actual encounter")
	for enemy in world.combat._enemies.duplicate(): enemy.take_damage(999)
	await frames(80)
	tracker.refresh()
	await key(KEY_M)
	check(map.view.snapshot.target.get("markers",[]).size() == 2,"Both new wing targets survive migration")
	check(map.view.snapshot.target.name == "曝光记录室 / 折光栈道","Wing objective names both real rooms in Chinese")
	await capture("two-wings")
	map.close_map()
	check(world.has_node("RouteMap"),"Target Tab route map remains installed")
	paused = false
	root.get_node("MusicManager").stop_music()
	host.queue_free()
	await frames(3)
	print("LEVEL04_MAP_MIGRATION_RESULT %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
