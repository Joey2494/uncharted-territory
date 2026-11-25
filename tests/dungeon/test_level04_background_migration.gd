extends SceneTree
const PROFILE := preload("res://scripts/integration/player_profile.gd")
const PROGRESS := preload("res://scripts/integration/campaign_progress.gd")
const PLAN := preload("res://scenes/dungeon/level04/observatory_plan.gd")
var checks := 0
var failures := 0

class AuditedFinish:
	extends "res://scenes/dungeon/level04/observatory_background.gd"
	var before: Dictionary
	var after: Dictionary
	func snapshot(level: Node3D) -> Dictionary:
		var result := {}
		for node in level.find_children("*","Node",true,false):
			var values: Array = [node.get_parent().get_instance_id(),node.name,node.get_class(),node.process_mode,node.get_groups()]
			if node is Node3D: values.append_array([node.transform,node.visible])
			if node is MeshInstance3D: values.append_array([node.mesh.get_rid(),node.material_overlay,node.layers,node.cast_shadow])
			if node is CollisionObject3D: values.append_array([node.collision_layer,node.collision_mask])
			if node is CollisionShape3D: values.append_array([node.shape.get_rid(),node.disabled,node.shape.get_debug_mesh().get_aabb()])
			if node is CollisionPolygon3D: values.append_array([node.polygon.duplicate(),node.depth,node.disabled])
			if node is Sprite3D: values.append_array([node.texture,node.frame,node.hframes,node.vframes,node.pixel_size])
			if node is Label3D: values.append_array([node.text,node.font,node.pixel_size])
			if node is Camera3D: values.append_array([node.fov,node.projection,node.minimum_distance,node.get_safe_frame()])
			result[node.get_instance_id()] = values
		return result
	func apply(level: Node3D) -> void:
		before = snapshot(level)
		super.apply(level)
		after = snapshot(level)

func _initialize() -> void:
	PROFILE.override_path = "user://latest-background-profile.cfg"
	PROGRESS.override_path = "user://latest-background-campaign.cfg"
	run.call_deferred()
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL "+label)
func capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	var output := OS.get_environment("GODOT_TEST_OUTPUT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"Screenshot "+label)
func run() -> void:
	var host: Node = load("res://scenes/dungeon/Level04Run.tscn").instantiate()
	var audit := AuditedFinish.new()
	host.get_node("DungeonTest/WorldEnvironment").finish = audit
	root.add_child(host)
	current_scene = host
	await frames(12)
	host._on_run_started()
	var world: Node3D = host._dungeon
	world.player._invulnerability_remaining = 100000
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	check(not audit.before.is_empty() and audit.before.size() == audit.after.size(),"Background adds no nodes, props, models or lights")
	check(audit.before == audit.after,"Background preserves every mesh RID, node transform, collider, group, clue, label, warning overlay and camera setting")
	check(PLAN.CENTERS.size() == 12 and PLAN.LINKS.size() == 16,"Target keeps twelve rooms and all sixteen wing passages")
	for id: String in PLAN.CENTERS:
		var deck: Node3D = world.layout.get_node(id+"/Deck")
		check(deck.get_child(0).polygon == PLAN.outline(id),"Target room footprint is preserved "+id)
		var expected: Shader = load("res://scenes/dungeon/level04/counterweight_deck.gdshader") if id == "D" else audit.FLOOR
		if id == "F": expected = load("res://scenes/dungeon/level04/prismatic_walkway.gdshader")
		if id == "L": expected = load("res://scenes/dungeon/level04/darkroom_floor.gdshader")
		check(audit._deck_surface(deck).material_override.shader == expected,"Room retains its background with restored specialised surfaces in D/F/L "+id)
	for link: String in PLAN.LINKS:
		var deck: Node3D = world.layout.get_node(link+"/Deck")
		var surface := audit._deck_surface(deck)
		var count: int = deck.get_children().filter(func(c): return c is CollisionShape3D).size()
		var expected: Shader = load("res://scenes/dungeon/level04/prismatic_walkway.gdshader") if link.contains("F") else audit.BRIDGE
		check(surface.material_override.shader == expected and surface.material_override.get_shader_parameter("segment_count") == count,"Material follows every actual straight or bent bridge segment "+link)
	for id in ["H","I"]:
		check(audit._deck_surface(world.layout.get_node(id+"/Deck")).material_overlay == world.combat._sweeps[id].effect,"Original shutter warning remains above the background "+id)
	world.combat._cleared.B = true
	world._refresh_gates()
	await frames(75)
	var tracker: Control = host._hud.get_node("LevelObjective")
	tracker.refresh()
	var map: CanvasLayer = tracker.quest_map
	check(map.open_map(),"Existing M map still opens")
	check(map.view.snapshot.paths.size() == 16 and map.view.snapshot.target.get("markers",[]).size() == 2,"M map retains sixteen corridors and both wing targets")
	await capture("M-map")
	map.close_map()
	check(world.has_node("RouteMap"),"Existing Tab route map remains installed")
	world.set_physics_process(false)
	for id: String in world.combat.ROSTERS: world.combat._cleared[id] = true
	world.puzzles.calibrated = true
	world._refresh_gates()
	await frames(75)
	var camera: Camera3D = world.get_node("Camera3D")
	var views := {"A":Vector2(0,2),"B":Vector2(0,2.2),"C":Vector2(0,1.1),"D":Vector2(3,2.4),"E":Vector2(0,2),"F":Vector2(-2.5,1.9),"G":Vector2(0,3.3),"H":Vector2(0,4.7),"I":Vector2(3.5,4.2),"J":Vector2(0,2.2),"K":Vector2(0,2.3),"L":Vector2(0,3.9)}
	for id: String in views:
		var point: Vector2 = views[id]
		world.player.global_position = world.layout.room_center(id)+Vector3(point.x,0.05,point.y)
		world.player.velocity = Vector3.ZERO
		camera.reset_follow()
		var distance: float = camera._distance
		await frames(65)
		check(absf(camera._distance-distance) < 0.01,"Background atmosphere does not alter target camera framing "+id)
		var environment: Environment = world.get_node("WorldEnvironment").environment
		check(environment.ambient_light_energy >= 0.64 and environment.ambient_light_energy <= 0.74,"Ambient light remains readable and bounded "+id)
		await capture(id)
	for link in ["CF","EF","EH","LI"]:
		var path := PLAN.bridge_path(link[0],link[1])
		var point: Vector2 = path[1] if path.size() > 2 else (path[0]+path[1])*0.5
		world.player.global_position = Vector3(point.x,0.05,point.y)
		world.player.velocity = Vector3.ZERO
		camera.reset_follow()
		await frames(12)
		await capture("bridge-"+link)
	paused = false
	root.get_node("MusicManager").stop_music()
	host.queue_free()
	await frames(4)
	print("LEVEL04_BACKGROUND_MIGRATION_RESULT %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
