extends SceneTree
## Verify decorative geometry cannot change navigation, interactions or camera fading.
const MAP = preload("res://scenes/dungeon/level02/Level02.tscn")
const FIRST = preload("res://scenes/dungeon/DungeonTest.tscn")
var OUT := OS.get_environment("GODOT_TEST_OUTPUT_DIR") if not OS.get_environment("GODOT_TEST_OUTPUT_DIR").is_empty() else ProjectSettings.globalize_path("user://verification")
var checks := 0
var failures := 0
var triangles := 0
var draw_batches := 0
var clusters := 0
var rooms: Array = []

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var map: Node3D = MAP.instantiate()
	root.add_child(map)
	await frames(5)
	var baseline_physics := physics_signature(map)
	for region: Node3D in map.get_node("Regions").get_children(): inspect_region(region)
	check(triangles < 300000 and draw_batches < 160, "silk is batched into a bounded static geometry budget")
	var hub: Node3D = map.get_node("Regions/Hub")
	var before := geometry_signature(hub)
	hub._rebuild_geometry()
	await frames(3)
	check(before == geometry_signature(hub), "editor/runtime rebuild generates the same deterministic habitat")
	check(baseline_physics == physics_signature(map), "visual rebuild preserves every existing collider path, transform and shape")
	await verify_fade(map)
	var roots: Array[Node3D] = []
	collect_habitats(map,roots)
	for prop in roots:
		prop.get_parent().remove_child(prop)
		prop.free()
	check(baseline_physics == physics_signature(map), "removing all new dressing leaves the original physics unchanged")
	var report := {"clusters":clusters,"triangles":triangles,"mesh_batches":draw_batches,"regions":rooms}
	var file := FileAccess.open(OUT.path_join("habitat-stats.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	map.queue_free()
	await frames(4)
	var first: Node3D = FIRST.instantiate()
	root.add_child(first)
	await frames(3)
	var first_props: Array[Node3D] = []
	collect_habitats(first,first_props)
	check(first_props.is_empty(), "first-level stone environment is unchanged")
	first.queue_free()
	root.get_node("MusicManager").stop_music()
	await frames(3)
	print("SPIDER_HABITAT_RESULT %d checks, %d failures; %d triangles in %d batches" % [checks,failures,triangles,draw_batches])
	quit(1 if failures else 0)

func inspect_region(region: Node3D) -> void:
	var roots: Array[Node3D] = []
	collect_habitats(region,roots)
	check(not roots.is_empty(), String(region.name)+": spider traces cover the actual room/corridor")
	var no_physics := true
	var static_only := true
	var materials_valid := true
	var finite := true
	var lane_clear := true
	var doors_clear := true
	var ceiling := false
	var cocoons := false
	var nests := false
	var half: Vector2 = region.dimensions*0.5
	var lane_along_z: bool = region.dimensions.y >= region.dimensions.x
	if (region.open_north or region.open_south) and not (region.open_east or region.open_west): lane_along_z = true
	elif (region.open_east or region.open_west) and not (region.open_north or region.open_south): lane_along_z = false
	for root_prop in roots:
		clusters += 1
		check(root_prop.get_parent().is_in_group("camera_occluders"), String(region.name)+": new dressing inherits existing wall occlusion")
		ceiling = ceiling or root_prop.has_meta("ceiling_web")
		cocoons = cocoons or root_prop.has_meta("hanging_cocoon")
		nests = nests or root_prop.has_meta("nest")
		for node in descendants(root_prop):
			no_physics = no_physics and not (node is CollisionObject3D or node is CollisionShape3D or node is NavigationRegion3D)
			static_only = static_only and node.get_script() == null and not node.is_processing() and not node.is_physics_processing()
			if not node is MeshInstance3D: continue
			draw_batches += 1
			materials_valid = materials_valid and node.mesh.get_surface_count() == 1 and node.get_active_material(0) is BaseMaterial3D
			var arrays: Array = node.mesh.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += int(indices.size()/3.0)
			var pose: Transform3D = region.global_transform.affine_inverse()*node.global_transform
			for i in points.size():
				finite = finite and points[i].is_finite() and normals[i].is_finite()
				var p := pose*points[i]
				if p.y >= 2.1: continue
				if region.exploration_room:
					lane_clear = lane_clear and not (absf(p.x) < half.x*0.45 and absf(p.z) < half.y*0.45)
				else:
					var cross_lane := p.x if lane_along_z else p.z
					lane_clear = lane_clear and absf(cross_lane) > 1.7
				if region.open_north and absf(p.z+half.y) < 0.35: doors_clear = doors_clear and absf(p.x) > region.doorway_width*0.5+0.10
				if region.open_south and absf(p.z-half.y) < 0.35: doors_clear = doors_clear and absf(p.x) > region.doorway_width*0.5+0.10
				if region.open_east and absf(p.x-half.x) < 0.35: doors_clear = doors_clear and absf(p.z) > region.doorway_width*0.5+0.10
				if region.open_west and absf(p.x+half.x) < 0.35: doors_clear = doors_clear and absf(p.z) > region.doorway_width*0.5+0.10
	check(no_physics and static_only, String(region.name)+": decoration has no collision, navigation, AI or per-frame script")
	check(materials_valid and finite, String(region.name)+": finite single-surface meshes support the current renderer and fade")
	check(lane_clear and doors_clear, String(region.name)+": low decoration leaves combat lanes and door throats visible")
	check(ceiling, String(region.name)+": open-cutaway ceiling edges carry silk without a solid roof")
	rooms.append({"region":String(region.name),"clusters":roots.size(),"ceiling":ceiling,"cocoons":cocoons,"nests":nests})

func verify_fade(map: Node3D) -> void:
	check(map.begin_run(), "the dressed level still starts normally")
	map.set_physics_process(false)
	var player: CharacterBody3D = map.player
	player.set_physics_process(false)
	player.global_position = Vector3(-9.5,0.05,-18.1)
	await frames(4)
	var camera: Camera3D = map.get_node("Camera3D")
	camera.set_process(false)
	camera.global_position = player.global_position+Vector3(0,8,15)
	camera.look_at(player.global_position+Vector3.UP)
	var actors: Array[Node3D] = [player]
	camera._update_occluders(actors,0.1)
	var props: Array[Node3D] = []
	collect_habitats(map,props)
	var faded: Array[MeshInstance3D] = []
	var originals_preserved := true
	for prop in props:
		for mesh in prop.get_children():
			if not mesh is MeshInstance3D or mesh.material_override == null: continue
			faded.append(mesh)
			var original: BaseMaterial3D = mesh.mesh.surface_get_material(0)
			originals_preserved = originals_preserved and mesh.material_override != original and original.vertex_color_use_as_albedo
	check(not faded.is_empty() and originals_preserved, "real camera rays fade wall-mounted silk without modifying shared materials")
	actors.clear()
	camera._update_occluders(actors,0.4)
	camera._update_occluders(actors,0.4)
	var restored := true
	for mesh in faded: restored = restored and mesh.material_override == null
	check(restored, "leaving the occluded wall restores silk's original materials")

func geometry_signature(region: Node3D) -> Array:
	var roots: Array[Node3D] = []
	collect_habitats(region,roots)
	var result: Array = []
	for prop in roots:
		for mesh in prop.get_children():
			if mesh is MeshInstance3D:
				var points: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				result.append([String(prop.get_path()),String(mesh.name),hash(points)])
	return result
func physics_signature(node: Node) -> Array:
	var result: Array = []
	for child in descendants(node):
		if child is CollisionShape3D and child.get_parent() is StaticBody3D:
			result.append([String(child.get_path()),child.global_transform,child.shape.get_class(),child.shape.get_debug_mesh().get_aabb(),child.get_parent().collision_layer,child.get_parent().collision_mask])
	return result
func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child in node.get_children(true): result.append_array(descendants(child))
	return result
func collect_habitats(node: Node, result: Array[Node3D]) -> void:
	if node.has_meta("spider_habitat"): result.append(node)
	for child in node.get_children(true): collect_habitats(child,result)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
