extends SceneTree
## Inspect actual generated geometry against play-space and interaction clearances.
const MAP = preload("res://scenes/dungeon/level02/Level02.tscn")
var checks := 0
var failures := 0
var fragments := 0
var large_fragments := 0
var puddles := 0
var fracture_cells := 0
var silk_regions := 0
var records: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var map: Node3D = MAP.instantiate()
	root.add_child(map)
	await process_frame
	var protected := PackedVector3Array()
	for container_path in ["Devices", "EnergyRelayPuzzle"]:
		for target in map.get_node(container_path).get_children():
			if target is Node3D and not target is Label3D:
				protected.append(Vector3(target.global_position.x,target.global_position.z,1.25))
	for path in ["Player", "Boss"]:
		var target: Node3D = map.get_node(path)
		protected.append(Vector3(target.global_position.x,target.global_position.z,1.25))
	for target: Node3D in map.get_node("Cover").get_children():
		if target is StaticBody3D: protected.append(Vector3(target.global_position.x,target.global_position.z,1.6))
	for region: Node3D in map.get_node("Regions").get_children():
		inspect(region,protected)
	check(fragments >= 120 and fragments <= 450,"stone population remains sparse but visible across the complete level")
	check(large_fragments >= 10 and large_fragments <= 32,"larger fragments are limited to the room margins")
	check(puddles >= 8 and puddles <= 22,"only a small number of shallow puddles exists")
	check(fracture_cells >= 15,"actual floor cells carry incised fractures")
	check(silk_regions >= 4,"ground silk remains local to several established habitat rooms")
	var report := {"fragments":fragments,"large_fragments":large_fragments,"puddles":puddles,"fracture_cells":fracture_cells,"silk_regions":silk_regions,"regions":records}
	var output := OS.get_environment("GODOT_TEST_OUTPUT_DIR")
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("ground-stats.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
	map.queue_free()
	root.get_node("MusicManager").stop_music()
	for i in 3: await process_frame
	print("CAVERN_GROUND_RESULT %d checks, %d failures; %d fragments, %d larger, %d puddles, %d fracture cells, %d silk regions" % [checks,failures,fragments,large_fragments,puddles,fracture_cells,silk_regions])
	quit(1 if failures else 0)

func inspect(region: Node3D, protected: PackedVector3Array) -> void:
	var ground: Node3D = region.get_node("Geometry/Floor/CavernGroundDetail")
	var half: Vector2 = region.dimensions*0.5
	var static_only := true
	var routes_clear := true
	var interactions_clear := true
	var bounds_safe := true
	var rock_area := 0.0
	var water_area := 0.0
	for mesh in ground.get_children():
		if mesh is ReflectionProbe:
			static_only = static_only and mesh.update_mode == ReflectionProbe.UPDATE_ONCE and mesh.ambient_mode == ReflectionProbe.AMBIENT_DISABLED and mesh.reflection_mask == 1<<19
			continue
		static_only = static_only and mesh is MeshInstance3D and mesh.get_script() == null and not mesh.is_processing() and not mesh.is_physics_processing()
		if not mesh is MeshInstance3D: continue
		var points: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var pose: Transform3D = region.global_transform.affine_inverse()*mesh.global_transform
		for at in points:
			var p := pose*at
			bounds_safe = bounds_safe and p.is_finite() and p.y <= 0.52 and p.y >= -0.18 and absf(p.x) < half.x and absf(p.z) < half.y
			if region.exploration_room:
				routes_clear = routes_clear and not (absf(p.x) < half.x*0.60 and absf(p.z) < half.y*0.60)
			elif maxf(region.dimensions.x,region.dimensions.y) <= 5.1:
				routes_clear = routes_clear and (absf(p.x) > 1.7 or absf(p.z) > 1.7)
			else:
				routes_clear = routes_clear and absf(p.x if region.dimensions.y >= region.dimensions.x else p.z) > 1.7
			if region.open_north and p.z < -half.y+1.0: routes_clear = routes_clear and absf(p.x) > region.doorway_width*0.5
			if region.open_south and p.z > half.y-1.0: routes_clear = routes_clear and absf(p.x) > region.doorway_width*0.5
			if region.open_west and p.x < -half.x+1.0: routes_clear = routes_clear and absf(p.z) > region.doorway_width*0.5
			if region.open_east and p.x > half.x-1.0: routes_clear = routes_clear and absf(p.z) > region.doorway_width*0.5
			var world: Vector3 = mesh.global_transform*at
			for zone in protected: interactions_clear = interactions_clear and Vector2(world.x,world.z).distance_to(Vector2(zone.x,zone.y)) >= zone.z
		var area := 0.0
		for i in range(0,points.size(),3):
			var a := Vector2(points[i].x,points[i].z)
			var b := Vector2(points[i+1].x,points[i+1].z)
			var c := Vector2(points[i+2].x,points[i+2].z)
			area += absf((b-a).cross(c-a))*0.5
		if mesh.name == "SettledStoneFragments": rock_area = area*0.5
		if mesh.name == "ShallowWater": water_area = area
		if mesh.name == "GroundSilk": silk_regions += 1
	var area: float = region.dimensions.x*region.dimensions.y
	check(static_only,String(region.name)+": ground detail adds no physics, scripts or per-frame processing")
	check(bounds_safe and routes_clear,String(region.name)+": details stay low, within the region and outside routes, doorways and central combat space")
	check(interactions_clear,String(region.name)+": actual device, puzzle, cover and actor positions remain unobstructed")
	check(rock_area/area < 0.045 and water_area/area < 0.025,String(region.name)+": stone and water footprints remain below the density limits")
	var count: int = ground.get_meta("fragment_count")
	var large: int = ground.get_meta("large_fragment_count")
	var pools: int = ground.get_meta("puddle_count")
	var cracks: int = ground.get_meta("crack_cells")
	fragments += count
	large_fragments += large
	puddles += pools
	fracture_cells += cracks
	records.append({"region":String(region.name),"fragments":count,"large":large,"puddles":pools,"crack_cells":cracks,"stone_area":rock_area,"water_area":water_area,"room_area":area})

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL "+message)
