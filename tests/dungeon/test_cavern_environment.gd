extends SceneTree
const MAP = preload("res://scenes/dungeon/level02/Level02.tscn")
const FIRST = preload("res://scenes/dungeon/DungeonTest.tscn")
const BASE = preload("res://scenes/dungeon/dungeon_region.gd")
var checks := 0
var failures := 0
var triangles := 0
var batches := 0

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var map: Node3D = MAP.instantiate()
	root.add_child(map)
	await frames(4)
	for region: Node3D in map.get_node("Regions").get_children():
		await inspect_region(region)
	check(triangles < 200000 and batches < 240,"natural geology stays within a bounded static geometry budget")
	for body in map.get_node("Cover").get_children():
		if not body is StaticBody3D: continue
		var visual: Node3D = body.get_node("StoneCover")
		check(visual.get_meta("cavern_geometry") == "cover" and not body.get_node("Mesh").visible,"existing combat cover is visibly a natural boulder")
		var box: BoxShape3D = body.get_node("CollisionShape3D").shape
		var mesh: MeshInstance3D = visual.get_node("FracturedBoulder")
		check(mesh.mesh.get_aabb().size.is_equal_approx(box.size),"boulder bounds still advertise the original collider dimensions")
	var hub: Node3D = map.get_node("Regions/Hub")
	var signature := geometry_signature(hub)
	var colliders := physics_signature(hub)
	hub._rebuild_geometry()
	await frames(3)
	check(signature == geometry_signature(hub),"rebuilding the cave preserves its deterministic rock silhouettes")
	check(colliders == physics_signature(hub),"visual rebuild leaves collision shapes and transforms unchanged")
	await verify_camera_fade(map)
	map.queue_free()
	await frames(3)
	var first: Node3D = FIRST.instantiate()
	root.add_child(first)
	await frames(3)
	check(geology(first).is_empty(),"first-level masonry receives no cave geometry or materials")
	first.queue_free()
	root.get_node("MusicManager").stop_music()
	await frames(3)
	print("CAVERN_ENVIRONMENT_RESULT %d checks, %d failures; %d triangles, %d batches" % [checks,failures,triangles,batches])
	quit(1 if failures else 0)

func inspect_region(region: Node3D) -> void:
	var original: Node3D = BASE.new()
	for key in ["dimensions","open_north","open_south","open_east","open_west","doorway_width"]:
		original.set(key,region.get(key))
	root.add_child(original)
	await frames(1)
	check(physics_signature(original) == physics_signature(region),String(region.name)+": complete collider set matches the untouched region builder")
	original.free()
	var roots := geology(region)
	check(not roots.is_empty() and not region.get_node("Geometry/Floor/MeshInstance3D").visible,String(region.name)+": masonry replaced by natural sediment and rock")
	var valid := true
	var static_only := true
	var clear := true
	var floor_clear := true
	var occlusion := true
	var height_variation := false
	var foreground_clear := true
	var half: Vector2 = region.dimensions*0.5
	for visual: Node3D in roots:
		var kind: String = visual.get_meta("cavern_geometry")
		if kind == "wall":
			occlusion = occlusion and visual.get_parent().is_in_group("camera_occluders")
			height_variation = height_variation or visual.get_meta("peripheral_depth") < -3.0
		for node in descendants(visual):
			static_only = static_only and not (node is CollisionObject3D or node is CollisionShape3D or node is NavigationRegion3D) and node.get_script() == null
			if not node is MeshInstance3D: continue
			batches += 1
			var material: BaseMaterial3D = node.get_active_material(0)
			valid = valid and node.mesh.get_surface_count() == 1 and material != null
			var arrays: Array = node.mesh.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			triangles += int(points.size()/3.0)
			var pose: Transform3D = region.global_transform.affine_inverse()*node.global_transform
			for i in points.size():
				var p := pose*points[i]
				valid = valid and p.is_finite() and normals[i].is_finite() and normals[i].length_squared() > 0.9
				if kind == "floor":
					floor_clear = floor_clear and p.y < 0.0 and absf(p.x) <= half.x+0.001 and absf(p.z) <= half.y+0.001
					continue
				if String(visual.get_parent().name).begins_with("South"): foreground_clear = foreground_clear and p.y <= 2.86
				if p.y < -0.1 or p.y > 2.1: continue
				if region.exploration_room:
					clear = clear and not (absf(p.x) < half.x*0.60 and absf(p.z) < half.y*0.60)
				else:
					var cross_lane := p.x if region.dimensions.y >= region.dimensions.x else p.z
					if maxf(region.dimensions.x,region.dimensions.y) <= 5.1:
						clear = clear and (absf(p.x) > 1.7 or absf(p.z) > 1.7)
					else: clear = clear and absf(cross_lane) > 1.7
	check(valid and static_only,String(region.name)+": finite static single-surface geology adds no collision or runtime behavior")
	check(clear and floor_clear,String(region.name)+": central combat area, route marks and corridor lane remain exposed")
	check(occlusion and foreground_clear,String(region.name)+": low foreground and existing wall fade protect the camera view")
	check(height_variation,String(region.name)+": peripheral cliffs provide real vertical rock relief")
	check(region.find_children("Decor_*","Node3D",true,false).is_empty(),String(region.name)+": no old banners, masonry pillars or bookshelves remain")

func verify_camera_fade(map: Node3D) -> void:
	map.begin_run()
	map.set_physics_process(false)
	map.player.set_physics_process(false)
	map.player.global_position = Vector3(-9.5,0.05,-18.1)
	await frames(3)
	var camera: Camera3D = map.get_node("Camera3D")
	camera.set_process(false)
	camera.global_position = map.player.global_position+Vector3(0,8,15)
	camera.look_at(map.player.global_position+Vector3.UP)
	var actors: Array[Node3D] = [map.player]
	camera._update_occluders(actors,0.1)
	var faded: Array[MeshInstance3D] = []
	var preserved := true
	for visual in geology(map):
		if visual.get_meta("cavern_geometry") != "wall": continue
		for mesh: MeshInstance3D in visual.get_children():
			if mesh.material_override == null: continue
			faded.append(mesh)
			preserved = preserved and mesh.material_override != mesh.mesh.surface_get_material(0)
	check(not faded.is_empty() and preserved,"actual camera rays fade new rock without mutating its shared material")
	actors.clear()
	for i in 3: camera._update_occluders(actors,0.4)
	var restored := true
	for mesh in faded: restored = restored and mesh.material_override == null
	check(restored,"cave wall materials restore after the camera clears them")

func physics_signature(region: Node3D) -> Array:
	var result: Array = []
	for node in descendants(region):
		if node is CollisionShape3D and node.get_parent() is StaticBody3D:
			var body: StaticBody3D = node.get_parent()
			result.append([String(region.get_path_to(node)),body.transform,node.transform,node.shape.size,body.collision_layer,body.collision_mask])
	return result
func geometry_signature(region: Node3D) -> Array:
	var result: Array = []
	for visual in geology(region):
		for mesh: MeshInstance3D in visual.get_children():
			result.append([String(region.get_path_to(mesh)),hash(mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])])
	return result
func geology(node: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in descendants(node):
		if child.has_meta("cavern_geometry"): result.append(child)
	return result
func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child in node.get_children(true): result.append_array(descendants(child))
	return result
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
