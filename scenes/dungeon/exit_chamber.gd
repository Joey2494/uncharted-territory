@tool
extends "res://scenes/dungeon/dungeon_region.gd"
## ExitChamber-only dressing. The original map owns unlocking and victory.

const Visuals = preload("res://scenes/dungeon/almsyone_visuals.gd")
const MODELS := {
	"floor": preload("res://assets/dungeon/almsyone/SM_Floor_Stone.glb"),
	"wall": preload("res://assets/dungeon/almsyone/SM_Wall.glb"),
	"corner": preload("res://assets/dungeon/almsyone/SM_Wall_Corner.glb"),
	"blue": preload("res://assets/dungeon/almsyone/SM_Crystals_Blue.glb"),
	"banner": preload("res://assets/dungeon/almsyone/SM_Banner_Blue.glb"),
	"torch": preload("res://assets/dungeon/almsyone/SM_Torch_Standing.glb"),
}

@export_range(0.1, 1.0, 0.01) var stone_brightness: float = 0.40:
	set(value):
		stone_brightness = value
		_queue_rebuild()

var _visuals: RefCounted


func _rebuild_geometry() -> void:
	super._rebuild_geometry()
	_visuals = Visuals.new()
	_visuals.stone_brightness = stone_brightness
	var geometry: Node3D = get_node("Geometry")
	_build_floor(geometry.get_node("Floor"))
	var walls: Node3D = geometry.get_node("Walls")
	for wall in walls.get_children(): _build_wall(wall)
	_build_dressing(walls)


func _add_model(parent: Node3D, key: String, label: String, position: Vector3, yaw: float = 0.0, scale_value: Vector3 = Vector3.ONE) -> Node3D:
	var pose := Transform3D(Basis(Vector3.UP, yaw).scaled_local(scale_value), position)
	return _visuals.add_model(parent, MODELS[key], label, parent.global_transform.affine_inverse() * global_transform * pose)


func _build_floor(body: StaticBody3D) -> void:
	body.get_node("MeshInstance3D").hide()
	var shape := body.get_node("CollisionShape3D").shape as BoxShape3D
	var columns := maxi(1, roundi(dimensions.x / 2.0))
	var rows := maxi(1, roundi(dimensions.y / 2.0))
	var cell := Vector2(shape.size.x / columns, shape.size.z / rows)
	var parts: Array[Dictionary] = _visuals.parts(MODELS.floor)
	var top := -INF
	for part in parts:
		var bounds: AABB = part.transform * part.mesh.get_aabb()
		top = maxf(top, bounds.end.y)
	var room_to_body := body.global_transform.affine_inverse() * global_transform
	for index in range(parts.size()):
		var part: Dictionary = parts[index]
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = part.mesh
		instances.instance_count = columns * rows
		for z in range(rows):
			for x in range(columns):
				var position := Vector3((x + 0.5) * cell.x - shape.size.x * 0.5, -top - 0.002, (z + 0.5) * cell.y - shape.size.z * 0.5)
				var pose := Transform3D(Basis.from_scale(Vector3(cell.x / 2.0, 1.0, cell.y / 2.0)), position)
				instances.set_instance_transform(z * columns + x, room_to_body * pose * part.transform)
		var visual := MultiMeshInstance3D.new()
		visual.name = "StoneFloor%d" % index
		visual.multimesh = instances
		visual.set_meta("source_model", MODELS.floor.resource_path)
		body.add_child(visual)


func _build_wall(body: StaticBody3D) -> void:
	body.get_node("MeshInstance3D").hide()
	var size: Vector3 = body.get_node("CollisionShape3D").shape.size
	var horizontal := size.x > size.z
	var length := size.x if horizontal else size.z
	var count := maxi(1, roundi(length / 2.0))
	var width := length / count
	var thickness := size.z if horizontal else size.x
	for index in range(count):
		var position := body.position - Vector3.UP * size.y * 0.5
		if horizontal: position.x += -length * 0.5 + (index + 0.5) * width
		else: position.z += -length * 0.5 + (index + 0.5) * width
		_add_model(body, "wall", "StoneWall%d" % index, position, 0.0 if horizontal else PI * 0.5, Vector3(width / 2.0, size.y / 3.12, thickness / 0.48))


func _nearest_wall(walls: Node3D, position: Vector3) -> Node3D:
	var nearest: Node3D = walls
	var distance := INF
	for wall in walls.get_children():
		var half: Vector3 = wall.get_node("CollisionShape3D").shape.size * 0.5
		var offset: Vector3 = position - wall.position
		var edge := Vector2(maxf(absf(offset.x) - half.x, 0.0), maxf(absf(offset.z) - half.z, 0.0))
		if edge.length_squared() < distance:
			distance = edge.length_squared()
			nearest = wall
	return nearest


func _build_dressing(walls: Node3D) -> void:
	var half := dimensions * 0.5
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var position := Vector3(x * (half.x + 0.3), 0, z * (half.y + 0.3))
			_add_model(_nearest_wall(walls, position), "corner", "Corner_%s_%s" % [x, z], position, 0.0, Vector3(0.947, 3.04 / 3.12, 0.947))
	# Preserve the entire central 5 m-wide route and the original PortalGlow.
	var layout: Array[Dictionary] = [
		{"model": "blue", "position": Vector3(-4.7, 0, -2.3)},
		{"model": "blue", "position": Vector3(4.7, 0, -2.3)},
		{"model": "blue", "position": Vector3(-4.7, 0, 2.3)},
		{"model": "blue", "position": Vector3(4.7, 0, 2.3)},
		{"model": "banner", "position": Vector3(-4.4, 2.75, -3.98)},
		{"model": "banner", "position": Vector3(4.4, 2.75, -3.98)},
		{"model": "banner", "position": Vector3(-5.98, 2.75, 0.6), "yaw": PI * 0.5},
		{"model": "banner", "position": Vector3(5.98, 2.75, 0.6), "yaw": -PI * 0.5},
		{"model": "torch", "position": Vector3(-3.8, 0, -0.3)},
		{"model": "torch", "position": Vector3(3.8, 0, -0.3)},
	]
	for index in range(layout.size()):
		var entry: Dictionary = layout[index]
		var position: Vector3 = entry.position
		_add_model(_nearest_wall(walls, position), entry.model, "Dressing%d_%s" % [index, entry.model], position, entry.get("yaw", 0.0))
