@tool
extends "res://scenes/dungeon/dungeon_region.gd"
## Entrance-only visual dressing. The base room still builds every collision.

const MODELS := {
	"floor": preload("res://assets/dungeon/almsyone/SM_Floor_Stone.glb"),
	"wall": preload("res://assets/dungeon/almsyone/SM_Wall.glb"),
	"corner": preload("res://assets/dungeon/almsyone/SM_Wall_Corner.glb"),
	"pillar": preload("res://assets/dungeon/almsyone/SM_Pillar.glb"),
	"wall_torch": preload("res://assets/dungeon/almsyone/SM_Torch_Wall.glb"),
	"statue": preload("res://assets/dungeon/almsyone/SM_Statue_Knight.glb"),
	"banner": preload("res://assets/dungeon/almsyone/SM_Banner_Blue.glb"),
	"rug": preload("res://assets/dungeon/almsyone/SM_Rug.glb"),
	"torch": preload("res://assets/dungeon/almsyone/SM_Torch_Standing.glb"),
	"bench": preload("res://assets/dungeon/almsyone/SM_Bench.glb"),
	"barrel": preload("res://assets/dungeon/almsyone/SM_Barrel.glb"),
	"crate": preload("res://assets/dungeon/almsyone/SM_Crate.glb"),
}

@export_range(0.1, 1.0, 0.01) var stone_brightness: float = 0.40:
	set(value):
		stone_brightness = value
		_queue_rebuild()

var _source_parts: Dictionary = {}
var _tinted_materials: Dictionary = {}


func _rebuild_geometry() -> void:
	# Reuse the original dimensions, openings, layers and exact collision shapes.
	super._rebuild_geometry()
	_source_parts.clear()
	_tinted_materials.clear()
	var geometry: Node3D = get_node("Geometry")
	_build_floor(geometry.get_node("Floor"))
	var walls: Node3D = geometry.get_node("Walls")
	for wall in walls.get_children():
		_build_wall(wall)
	_build_dressing(geometry, walls)


func _parts(scene: PackedScene) -> Array[Dictionary]:
	var key := scene.resource_path
	if not _source_parts.has(key):
		var model := scene.instantiate()
		var parts: Array[Dictionary] = []
		_collect_parts(model, Transform3D.IDENTITY, parts)
		_source_parts[key] = parts
		model.free()
	return _source_parts[key]


func _collect_parts(node: Node, parent_transform: Transform3D, parts: Array[Dictionary]) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform *= node.transform
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			# A single surface per wall/decor mesh lets the unchanged camera fade
			# every original colour independently using material_override.
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(node.mesh.surface_get_primitive_type(surface), node.mesh.surface_get_arrays(surface))
			mesh.surface_set_material(0, _material(node.get_active_material(surface)))
			parts.append({"mesh": mesh, "transform": transform})
	for child in node.get_children():
		_collect_parts(child, transform, parts)


func _material(source: Material) -> Material:
	var key := source.get_instance_id()
	if not _tinted_materials.has(key):
		var material := source.duplicate() as BaseMaterial3D
		if material.resource_name.begins_with("M_Stone"):
			var color := material.albedo_color
			material.albedo_color = Color(color.r * stone_brightness, color.g * stone_brightness, color.b * stone_brightness, color.a)
		_tinted_materials[key] = material
	return _tinted_materials[key]


func _add_model(parent: Node3D, key: String, label: String, position: Vector3, yaw: float = 0.0, scale_value: Vector3 = Vector3.ONE) -> Node3D:
	var scene: PackedScene = MODELS[key]
	var model := Node3D.new()
	model.name = label
	model.set_meta("source_model", scene.resource_path)
	parent.add_child(model)
	var pose := Transform3D(Basis(Vector3.UP, yaw).scaled_local(scale_value), position)
	model.transform = parent.global_transform.affine_inverse() * global_transform * pose
	var index := 0
	for part in _parts(scene):
		var mesh := MeshInstance3D.new()
		mesh.name = "Surface%d" % index
		mesh.mesh = part.mesh
		mesh.transform = part.transform
		model.add_child(mesh)
		index += 1
	return model


func _build_floor(body: StaticBody3D) -> void:
	body.get_node("MeshInstance3D").hide()
	var shape := body.get_node("CollisionShape3D").shape as BoxShape3D
	var columns := maxi(1, roundi(dimensions.x / 2.0))
	var rows := maxi(1, roundi(dimensions.y / 2.0))
	# Fit the existing overlap slab exactly, including the hidden edges under walls.
	var cell := Vector2(shape.size.x / columns, shape.size.z / rows)
	var parts := _parts(MODELS.floor)
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
				# Two millimetres below physics avoids coplanar overlap with unchanged
				# adjacent regions. Route markers remain at their original Y=0.016.
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
		if horizontal:
			position.x += -length * 0.5 + (index + 0.5) * width
		else:
			position.z += -length * 0.5 + (index + 0.5) * width
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


func _build_dressing(geometry: Node3D, walls: Node3D) -> void:
	var half := dimensions * 0.5
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var position := Vector3(x * (half.x + 0.3), 0, z * (half.y + 0.3))
			_add_model(_nearest_wall(walls, position), "corner", "Corner_%s_%s" % [x, z], position, 0.0, Vector3(0.947, 3.04 / 3.12, 0.947))
	var layout: Array[Dictionary] = [
		{"model": "pillar", "position": Vector3(-3.1, 0, 7.75)},
		{"model": "pillar", "position": Vector3(3.1, 0, 7.75)},
		{"model": "pillar", "position": Vector3(-3.1, 0, -7.75)},
		{"model": "pillar", "position": Vector3(3.1, 0, -7.75)},
		{"model": "banner", "position": Vector3(-6.0, 2.75, -7.98)},
		{"model": "banner", "position": Vector3(6.0, 2.75, -7.98)},
		{"model": "wall_torch", "position": Vector3(-4.5, 1.7, -7.98)},
		{"model": "wall_torch", "position": Vector3(4.5, 1.7, -7.98)},
		{"model": "wall_torch", "position": Vector3(-5.6, 1.7, 7.98), "yaw": PI},
		{"model": "wall_torch", "position": Vector3(5.6, 1.7, 7.98), "yaw": PI},
		{"model": "statue", "position": Vector3(-7.7, 0, 5.9)},
		{"model": "statue", "position": Vector3(7.7, 0, 5.9)},
		{"model": "torch", "position": Vector3(-3.65, 0, 6.0)},
		{"model": "torch", "position": Vector3(3.65, 0, 6.0)},
		{"model": "bench", "position": Vector3(-9.15, 0, 0.3), "yaw": PI * 0.5},
		{"model": "bench", "position": Vector3(9.15, 0, 0.3), "yaw": -PI * 0.5},
		{"model": "barrel", "position": Vector3(8.5, 0, -6.0)},
		{"model": "barrel", "position": Vector3(9.1, 0, -6.9)},
		{"model": "crate", "position": Vector3(-8.3, 0, -6.7)},
		{"model": "crate", "position": Vector3(-9.1, 0, -5.7)},
	]
	for index in range(layout.size()):
		var entry: Dictionary = layout[index]
		var position: Vector3 = entry.position
		_add_model(_nearest_wall(walls, position), entry.model, "Dressing%d_%s" % [index, entry.model], position, entry.get("yaw", 0.0))
	# Keep the rug below the existing route markers, with no extra collision.
	_add_model(geometry.get_node("Floor"), "rug", "EntranceRug", Vector3(0, -0.027, 5.85))
