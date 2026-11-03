@tool
extends "res://scenes/dungeon/dungeon_region.gd"
## Arena-only visuals. Original room bodies and Boss AI own all gameplay.

const Visuals = preload("res://scenes/dungeon/almsyone_visuals.gd")
const MODELS := {
	"floor": preload("res://assets/dungeon/almsyone/SM_Floor_Stone.glb"),
	"cracked_floor": preload("res://assets/dungeon/almsyone/SM_Floor_Stone_Cracked.glb"),
	"wall": preload("res://assets/dungeon/almsyone/SM_Wall.glb"),
	"corner": preload("res://assets/dungeon/almsyone/SM_Wall_Corner.glb"),
	"pillar": preload("res://assets/dungeon/almsyone/SM_Pillar.glb"),
	"broken_pillar": preload("res://assets/dungeon/almsyone/SM_Pillar_Broken.glb"),
	"throne": preload("res://assets/dungeon/almsyone/SM_Throne.glb"),
	"banner": preload("res://assets/dungeon/almsyone/SM_Banner_Red.glb"),
	"brazier": preload("res://assets/dungeon/almsyone/SM_Brazier.glb"),
	"statue": preload("res://assets/dungeon/almsyone/SM_Statue_Knight.glb"),
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
	var model: Node3D = _visuals.add_model(parent, MODELS[key], label, parent.global_transform.affine_inverse() * global_transform * pose)
	if key == "brazier":
		for mesh in model.get_children():
			var material: BaseMaterial3D = mesh.mesh.surface_get_material(0)
			if material.resource_name.begins_with("M_Fire"):
				# Retain orange flame colour under existing arena lighting.
				material.emission_energy_multiplier = 0.35
	return model


func _build_floor(body: StaticBody3D) -> void:
	body.get_node("MeshInstance3D").hide()
	var shape := body.get_node("CollisionShape3D").shape as BoxShape3D
	var columns := maxi(1, roundi(dimensions.x / 2.0))
	var rows := maxi(1, roundi(dimensions.y / 2.0))
	var cell := Vector2(shape.size.x / columns, shape.size.z / rows)
	var tiles := {"floor": [], "cracked_floor": []}
	for z in range(rows):
		for x in range(columns):
			# Wear stays on the perimeter; central warning/charge lanes stay plain.
			var cracked := ((x == 0 or x == columns - 1) and (z == 1 or z == rows - 2)) or ((z == 0 or z == rows - 1) and (x == 2 or x == columns - 3))
			tiles["cracked_floor" if cracked else "floor"].append(Vector2i(x, z))
	var room_to_body := body.global_transform.affine_inverse() * global_transform
	for key in tiles:
		var parts: Array[Dictionary] = _visuals.parts(MODELS[key])
		var top := -INF
		for part in parts:
			var bounds: AABB = part.transform * part.mesh.get_aabb()
			top = maxf(top, bounds.end.y)
		for surface in range(parts.size()):
			var part: Dictionary = parts[surface]
			var instances := MultiMesh.new()
			instances.transform_format = MultiMesh.TRANSFORM_3D
			instances.mesh = part.mesh
			instances.instance_count = tiles[key].size()
			for index in range(tiles[key].size()):
				var tile: Vector2i = tiles[key][index]
				var position := Vector3((tile.x + 0.5) * cell.x - shape.size.x * 0.5, -top - 0.002, (tile.y + 0.5) * cell.y - shape.size.z * 0.5)
				var pose := Transform3D(Basis.from_scale(Vector3(cell.x / 2.0, 1.0, cell.y / 2.0)), position)
				instances.set_instance_transform(index, room_to_body * pose * part.transform)
			var visual := MultiMeshInstance3D.new()
			visual.name = "%sSurface%d" % [key.to_pascal_case(), surface]
			visual.multimesh = instances
			visual.set_meta("source_model", MODELS[key].resource_path)
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
	# All solid dressing stays outside the central 17.6 x 15.6 m clear zone,
	# and outside a full 7 m charge plus Boss radius around its original spawn.
	var layout: Array[Dictionary] = [
		{"model": "pillar", "position": Vector3(-10.75, 0, -3.1)},
		{"model": "pillar", "position": Vector3(-10.75, 0, 3.1)},
		{"model": "pillar", "position": Vector3(-3.1, 0, -9.75)},
		{"model": "pillar", "position": Vector3(3.1, 0, -9.75)},
		{"model": "throne", "position": Vector3(10.3, 0, 0), "yaw": -PI * 0.5},
		{"model": "statue", "position": Vector3(-9.6, 0, -5.8), "yaw": PI * 0.5},
		{"model": "statue", "position": Vector3(-9.6, 0, 5.8), "yaw": PI * 0.5},
		{"model": "statue", "position": Vector3(9.9, 0, -6.5), "yaw": -PI * 0.5},
		{"model": "statue", "position": Vector3(9.9, 0, 6.5), "yaw": -PI * 0.5},
		{"model": "brazier", "position": Vector3(9.7, 0, -3.8)},
		{"model": "brazier", "position": Vector3(9.7, 0, 3.8)},
		{"model": "brazier", "position": Vector3(-9.55, 0, -7.8)},
		{"model": "brazier", "position": Vector3(-9.55, 0, 7.8)},
		{"model": "broken_pillar", "position": Vector3(-7.8, 0, 8.9), "yaw": PI * 0.5},
		{"model": "broken_pillar", "position": Vector3(7.8, 0, 8.9), "yaw": -PI * 0.5},
		{"model": "banner", "position": Vector3(10.98, 2.75, -2.0), "yaw": -PI * 0.5},
		{"model": "banner", "position": Vector3(10.98, 2.75, 2.0), "yaw": -PI * 0.5},
		{"model": "banner", "position": Vector3(-6.5, 2.75, -9.98)},
		{"model": "banner", "position": Vector3(6.5, 2.75, -9.98)},
		{"model": "banner", "position": Vector3(-5.5, 2.75, 9.98), "yaw": PI},
		{"model": "banner", "position": Vector3(5.5, 2.75, 9.98), "yaw": PI},
	]
	for index in range(layout.size()):
		var entry: Dictionary = layout[index]
		var position: Vector3 = entry.position
		_add_model(_nearest_wall(walls, position), entry.model, "Dressing%d_%s" % [index, entry.model], position, entry.get("yaw", 0.0))
