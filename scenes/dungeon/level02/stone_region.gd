@tool
extends "res://scenes/dungeon/dungeon_region.gd"
## Level-two natural cave shell; shared base still owns every floor and wall collider.
const CAVERN = preload("res://scenes/dungeon/level02/cavern_geometry.gd")
const HABITAT = preload("res://scenes/dungeon/level02/spider_habitat.gd")
const GROUND = preload("res://scenes/dungeon/level02/cavern_floor_detail.gd")

func _rebuild_geometry() -> void:
	super._rebuild_geometry()
	var maker := CAVERN.new()
	var geometry: Node3D = get_node("Geometry")
	var floor_body: StaticBody3D = geometry.get_node("Floor")
	floor_body.get_node("MeshInstance3D").hide()
	var half_door := doorway_width*0.5+0.15
	var openings := Vector4(half_door if open_north else 0.0,half_door if open_south else 0.0,half_door if open_west else 0.0,half_door if open_east else 0.0)
	var ground := GROUND.new()
	ground.configure(String(name),dimensions,global_position,openings,exploration_room,_protected_ground())
	_mount(floor_body,maker.floor_mesh(String(name),dimensions,global_position,openings,ground))
	_mount(floor_body,ground.build())
	var walls: Node3D = geometry.get_node("Walls")
	for wall: StaticBody3D in walls.get_children():
		wall.get_node("MeshInstance3D").hide()
		var size: Vector3 = wall.get_node("CollisionShape3D").shape.size
		var normal := Vector3.FORWARD
		if String(wall.name).begins_with("South"): normal = Vector3.BACK
		elif String(wall.name).begins_with("East"): normal = Vector3.RIGHT
		elif String(wall.name).begins_with("West"): normal = Vector3.LEFT
		_mount(wall,maker.wall_mesh(String(name)+String(wall.name),wall.position,size,normal,exploration_room,global_position,dimensions))
	_build_habitat(walls,dimensions*0.5)

func _protected_ground() -> PackedVector3Array:
	var result := PackedVector3Array()
	var map := get_parent().get_parent() if get_parent() != null else null
	if map == null: return result
	for path in ["Devices","EnergyRelayPuzzle","Cover","Enemies"]:
		var container := map.get_node_or_null(path)
		if container == null: continue
		for node in container.get_children():
			if not node is Node3D or node is Label3D: continue
			var at: Vector3 = to_local(node.global_position)
			result.append(Vector3(at.x,at.z,1.8 if path == "Cover" else 1.5))
	for path in ["Player","Boss","ExitArea"]:
		var node := map.get_node_or_null(path) as Node3D
		if node == null: continue
		var at := to_local(node.global_position)
		result.append(Vector3(at.x,at.z,2.0 if path == "ExitArea" else 1.5))
	return result

func _mount(parent: Node3D, visual: Node3D) -> void:
	parent.add_child(visual)
	visual.transform = parent.global_transform.affine_inverse()*global_transform

func _nearest_wall(walls: Node3D, at: Vector3) -> Node3D:
	var nearest: Node3D = walls
	var distance := INF
	for wall in walls.get_children():
		var half: Vector3 = wall.get_node("CollisionShape3D").shape.size*0.5
		var offset: Vector3 = at-wall.position
		var edge := Vector2(maxf(absf(offset.x)-half.x,0.0),maxf(absf(offset.z)-half.z,0.0))
		if edge.length_squared() < distance:
			distance = edge.length_squared()
			nearest = wall
	return nearest

func _build_habitat(walls: Node3D, half: Vector2) -> void:
	var maker = HABITAT.new()
	if not exploration_room:
		var vertical := dimensions.y >= dimensions.x
		# Shortened passages can be wider than they are long; openings own the lane direction.
		if (open_north or open_south) and not (open_east or open_west):
			vertical = true
		elif (open_east or open_west) and not (open_north or open_south):
			vertical = false
		for side in [-1.0,1.0]:
			var opened: bool = (open_west if side < 0 else open_east) if vertical else (open_north if side < 0 else open_south)
			if opened: continue
			var opposite_open: bool = (open_east if side < 0 else open_west) if vertical else (open_south if side < 0 else open_north)
			var at := Vector3(side*(half.x-0.12),0,-0.65) if vertical else Vector3(-0.65,0,side*(half.y-0.12))
			# Tiny room connectors have no space for low hanging silk beside their door mouths.
			if (dimensions.y if vertical else dimensions.x) < 3.0:
				at.y = 0.6
			_mount_habitat(walls,maker.corridor(String(name),half,vertical,side,not opposite_open),at)
		return
	var density: float = {"Arrival":0.18,"Hub":0.58,"Relay":0.70,"Antechamber":0.84,"Boss":1.0,"Archive":0.91,"Vault":0.95,"Exit":0.30}.get(String(name),0.55)
	var corners := [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]
	for i in corners.size():
		if density < 0.35 and i > 1: continue
		var signs: Vector2 = corners[i]
		var at := Vector3(signs.x*(half.x-0.08),0,signs.y*(half.y-0.08))
		var reach := 3.9
		if (signs.y < 0 and open_north) or (signs.y > 0 and open_south): reach = minf(reach,half.x-doorway_width*0.5-0.35)
		if (signs.x < 0 and open_west) or (signs.x > 0 and open_east): reach = minf(reach,half.y-doorway_width*0.5-0.35)
		_mount_habitat(walls,maker.corner(String(name),signs,density,i,reach),at)

func _mount_habitat(walls: Node3D, habitat: Node3D, at: Vector3) -> void:
	var parent := _nearest_wall(walls,at)
	parent.add_child(habitat)
	var rock: Node3D = parent.get_node("CavernRock")
	var support := clampf((float(rock.get_meta("ceiling_height"))-0.18-2.1)/1.20,0.25,1.0)
	if support < 1.0:
		# Fit overhead anchors to the low cutaway without lowering webs into the route.
		for mesh: MeshInstance3D in habitat.get_children():
			var arrays: Array = mesh.mesh.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in points.size():
				if points[i].y <= 2.1: continue
				points[i].y = 2.1+(points[i].y-2.1)*support
				normals[i] = (normals[i]/Vector3(1,support,1)).normalized()
			arrays[Mesh.ARRAY_VERTEX] = points
			arrays[Mesh.ARRAY_NORMAL] = normals
			var fitted := ArrayMesh.new()
			fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			fitted.surface_set_material(0,mesh.mesh.surface_get_material(0))
			mesh.mesh = fitted
	habitat.transform = parent.global_transform.affine_inverse()*global_transform*Transform3D(Basis.IDENTITY,at)
