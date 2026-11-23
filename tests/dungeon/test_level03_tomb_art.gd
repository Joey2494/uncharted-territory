extends SceneTree
## Art integration checks: unchanged physics, actual thick geometry, fading and actor lifecycle.
const SCENE = preload("res://scenes/dungeon/level03/Level03Preview.tscn")
const BASE = preload("res://scenes/dungeon/level03/tide_layout.gd")
var checks := 0
var failures := 0
var stats := {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var tag := str(OS.get_process_id())
	preload("res://scripts/integration/player_profile.gd").override_path = "user://tomb-art-profile-"+tag+".cfg"
	preload("res://scripts/integration/campaign_progress.gd").override_path = "user://tomb-art-progress-"+tag+".cfg"
	var original := SCENE.instantiate()
	original.get_node("Layout").set_script(BASE)
	original.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(original)
	await physics_frame
	await process_frame
	var original_physics := _physics(original)
	original.queue_free()
	await process_frame
	var level := SCENE.instantiate()
	level.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(level)
	await physics_frame
	await process_frame
	var art_physics := _physics(level)
	_check(original_physics == art_physics,"Every collision shape, transform, layer, mask and enabled state matches the original map")
	stats["unchanged_collision_shapes"] = art_physics.size()
	var counts := {}
	var art_colliders := 0
	var geometry_ok := true
	var triangles := 0
	var batches := 0
	var static_triangles := 0
	var static_batches := 0
	for node in level.find_children("*","Node3D",true,false):
		if node.has_meta("tomb_art"):
			var kind: String = node.get_meta("tomb_art")
			counts[kind] = counts.get(kind,0)+1
			art_colliders += node.find_children("*","CollisionShape3D",true,false).size()
			if kind == "wall":
				geometry_ok = geometry_ok and float(node.get_meta("wall_thickness")) >= 1.3
		if node is MeshInstance3D and node.mesh is ArrayMesh and node.is_visible_in_tree():
			for index in node.mesh.get_surface_count():
				var arrays: Array = node.mesh.surface_get_arrays(index)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				triangles += vertices.size()/3
				batches += 1
				if _under_art(node):
					static_triangles += vertices.size()/3
					static_batches += 1
				for vertex in vertices:
					if not vertex.is_finite(): geometry_ok = false
	stats["art_nodes"] = counts
	stats["visible_array_mesh_triangles"] = triangles
	stats["visible_array_mesh_surfaces"] = batches
	stats["static_architecture_triangles"] = static_triangles
	stats["static_architecture_surfaces"] = static_batches
	_check(art_colliders == 0,"Art meshes and drifting sand add no collision shapes")
	_check(geometry_ok,"Sandstone walls have 1.3m or greater thickness and all mesh positions are finite")
	_check(counts.get("wall",0) >= 40 and counts.get("floor",0) >= 20,"Thick architecture and paving cover the connected map")
	_check(counts.get("arch",0) == 8 and counts.get("sarcophagus",0) == 4,"Eight solid portals and four distinct burial recesses are present")
	_check(counts.get("sand_basin",0) == 2 and counts.get("altar",0) == 10,"Settling sand stays local and all ten interaction altars are skinned")
	_check(level.get_node("Layout")._burials.size() == 4,"Burial cavities occupy four different rooms")
	var torch_lights := 0
	var shadow_lights := 0
	for light in level.find_children("*","OmniLight3D",true,false):
		if light.name != "WarmTorchLight": continue
		torch_lights += 1
		if light.shadow_enabled: shadow_lights += 1
	_check(torch_lights >= 15 and shadow_lights*2 >= torch_lights-1,"Warm light and shadow are distributed across the burial rooms")
	stats["torch_lights"] = torch_lights
	stats["shadowed_torches"] = shadow_lights
	_check(static_triangles < 350000 and static_batches < 650,"The static map stays within its geometry and material batch budgets")
	# Exercise the tall art above the original 1.15m collision walls.
	var camera: Camera3D = level.get_node("Camera3D")
	var visual: Node3D
	for node in get_nodes_in_group("tomb_visual_occluders"):
		if node.get_meta("tomb_art","") == "wall" and float(node.get_meta("top_height",0)) > 4.5:
			visual = node
			break
	var bounds: AABB = visual.get_meta("tomb_bounds")
	var actor := Node3D.new()
	level.add_child(actor)
	actor.global_position = visual.global_transform*(bounds.get_center()+Vector3(0,0,-4))
	camera.global_position = visual.global_transform*(bounds.get_center()+Vector3(0,0,4))
	var actors: Array[Node3D] = [actor]
	camera._update_occluders(actors,0.2)
	_check(not camera._faded_meshes.is_empty(),"Tall art fades when its volume blocks an actor above the low physics wall")
	var shared_material: StandardMaterial3D = preload("res://scenes/dungeon/level03/tomb_geometry.gd").stone
	_check(shared_material.albedo_color.a == 1.0 and shared_material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,"Fading never modifies the shared sandstone material")
	actors.clear()
	camera._update_occluders(actors,2.0)
	_check(camera._faded_meshes.is_empty(),"Occluder overrides restore when the actor leaves")
	actor.queue_free()
	var enemy: CharacterBody3D = level.get_node("Enemies").get_child(0)
	var native_enemy_script = load("res://addons/ziyuan_level03/enemy.gd")
	for guardian in level.get_node("Enemies").get_children():
		_check(guardian.has_node("TombMummyPresentation") and guardian.get_node("Visuals/Model").visible and guardian.get_script() == native_enemy_script,"Linen decorates the native enemy without replacing its model, weapon or AI: "+guardian.enemy_id)
	var wrapped := enemy.get_node("Visuals/Model/Body/FrayedLinenBands")
	var original_model: Node3D = enemy.get_node("Visuals/Model")
	original_model.pose(2,0.75,0.0,0.1)
	_check(not original_model.get_node("ArmR").transform.is_equal_approx(original_model._rest["ArmR"]),"Native attack articulation still drives the bandaged limbs")
	var summoned: CharacterBody3D = level._spawn_enemy("bone_axe",&"G",Vector3(0,0.05,-24),"TombSummonFixture")
	_check(summoned.has_node("TombMummyPresentation") and summoned.get_node("TombMummyPresentation")._native_pose,"Dynamically spawned reinforcements receive the same native mummy presentation")
	var projectile := CharacterBody3D.new()
	level.get_node("Enemies").add_child(projectile)
	_check(not projectile.has_node("TombMummyPresentation"),"Projectile bodies under Enemies never receive a mummy skin")
	var water: MeshInstance3D = level.get_node("Layout")._water[&"BC"].find_children("*","MeshInstance3D",true,false)[0]
	_check(water.material_override.albedo_color == Color(0.10,0.53,0.76,1.0),"The sedimentation reservoir keeps the restored water-blue material")
	var old_hp: int = enemy.hp
	enemy.set_encounter_active(true)
	enemy.process_mode = Node.PROCESS_MODE_ALWAYS
	enemy.take_damage(1)
	_check(enemy.hp == old_hp-1 and wrapped.material_overlay != null,"Accepted damage keeps HP and hit feedback on the wrapped model")
	enemy._flash.reset()
	_check(wrapped.material_overlay == null,"Hit feedback restores the linen material")
	var enemy_ref: WeakRef = weakref(enemy)
	enemy.take_damage(100)
	# Keep the native enemy's death tween as the only cleanup owner.
	await create_timer(0.85).timeout
	await process_frame
	await process_frame
	_check(not is_instance_valid(enemy_ref.get_ref()),"Native death/reward lifecycle frees the bandaged actor")
	level.queue_free()
	await process_frame
	stats["checks"] = checks
	stats["failures"] = failures
	var report := FileAccess.open("user://tomb-art-validation.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(stats,"  "))
	print("TOMB_ART_REPORT "+JSON.stringify(stats))
	print("LEVEL03_TOMB_ART: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _physics(level: Node3D) -> Array[String]:
	var result: Array[String] = []
	for node: CollisionShape3D in level.find_children("*","CollisionShape3D",true,false):
		var shape: Shape3D = node.shape
		var size := ""
		if shape is BoxShape3D: size = str(shape.size)
		elif shape is CapsuleShape3D or shape is CylinderShape3D: size = str(shape.radius)+":"+str(shape.height)
		elif shape is SphereShape3D: size = str(shape.radius)
		elif shape is ConvexPolygonShape3D: size = str(shape.points)
		else: size = shape.get_class()
		var body: CollisionObject3D = node.get_parent()
		result.append("%s|%s|%s|%d|%d|%s" % [shape.get_class(),size,str(node.global_transform),body.collision_layer,body.collision_mask,str(node.disabled)])
	result.sort()
	return result

func _under_art(node: Node) -> bool:
	while node != null:
		if node.has_meta("tomb_art"): return true
		node = node.get_parent()
	return false

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
