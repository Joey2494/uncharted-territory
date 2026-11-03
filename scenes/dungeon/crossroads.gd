@tool
extends "res://scenes/dungeon/dungeon_region.gd"
## Courtyard-only visuals. The original region owns all physics and openings.

const MODELS := {
	"floor": preload("res://assets/dungeon/almsyone/SM_Floor_Stone.glb"),
	"cracked_floor": preload("res://assets/dungeon/almsyone/SM_Floor_Stone_Cracked.glb"),
	"mossy_floor": preload("res://assets/dungeon/almsyone/SM_Floor_Stone_Mossy.glb"),
	"wall": preload("res://assets/dungeon/almsyone/SM_Wall.glb"),
	"mossy_wall": preload("res://assets/dungeon/almsyone/SM_Wall_Mossy.glb"),
	"corner": preload("res://assets/dungeon/almsyone/SM_Wall_Corner.glb"),
	"pillar": preload("res://assets/dungeon/almsyone/SM_Pillar.glb"),
	"broken_pillar": preload("res://assets/dungeon/almsyone/SM_Pillar_Broken.glb"),
	"rubble": preload("res://assets/dungeon/almsyone/SM_Rubble.glb"),
	"wall_torch": preload("res://assets/dungeon/almsyone/SM_Torch_Wall.glb"),
	"banner": preload("res://assets/dungeon/almsyone/SM_Banner_Red.glb"),
	"cracked_wall": preload("res://assets/dungeon/almsyone/SM_Wall_Cracked.glb"),
	"weapon_rack": preload("res://assets/dungeon/almsyone/SM_WeaponRack.glb"),
	"broken_barrel": preload("res://assets/dungeon/almsyone/SM_Barrel_Broken.glb"),
	"small_crate": preload("res://assets/dungeon/almsyone/SM_Crate_Small.glb"),
	"bones": preload("res://assets/dungeon/almsyone/SM_Bones_Pile.glb"),
	"cell_bars": preload("res://assets/dungeon/almsyone/SM_Wall_CellBars.glb"),
	"cage": preload("res://assets/dungeon/almsyone/SM_Cage.glb"),
}

@export_range(0.1, 1.0, 0.01) var stone_brightness: float = 0.40:
	set(value):
		stone_brightness = value
		_queue_rebuild()

var _source_parts: Dictionary = {}
var _tinted_materials: Dictionary = {}


func _rebuild_geometry() -> void:
	super._rebuild_geometry()
	_source_parts.clear()
	_tinted_materials.clear()
	var geometry: Node3D = get_node("Geometry")
	_build_floor(geometry.get_node("Floor"))
	var walls: Node3D = geometry.get_node("Walls")
	for wall in walls.get_children():
		_build_wall(wall)
	_build_dressing(walls)
	_build_combat_dressing(walls)


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
			# Keep each colour independent for the existing camera material fade.
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
		if material.resource_name.begins_with("M_Stone") or material.resource_name == "M_Moss":
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


func _floor_variant(x: int, z: int) -> String:
	# Fixed placement keeps editor rebuilds and restarts visually identical.
	# Extra wear is confined to the original enemy's eastern combat area.
	if x >= 5 and x <= 7 and z >= 2 and z <= 4:
		return "cracked_floor"
	if (x == 0 and z < 6) or (z == 0 and x % 2 == 0) or (x == 1 and z == 1):
		return "mossy_floor"
	if (x * 3 + z * 5) % 9 < 2:
		return "cracked_floor"
	return "floor"


func _build_floor(body: StaticBody3D) -> void:
	body.get_node("MeshInstance3D").hide()
	var shape := body.get_node("CollisionShape3D").shape as BoxShape3D
	var columns := maxi(1, roundi(dimensions.x / 2.0))
	var rows := maxi(1, roundi(dimensions.y / 2.0))
	var cell := Vector2(shape.size.x / columns, shape.size.z / rows)
	var tiles := {"floor": [], "cracked_floor": [], "mossy_floor": []}
	for z in range(rows):
		for x in range(columns):
			tiles[_floor_variant(x, z)].append(Vector2i(x, z))
	var room_to_body := body.global_transform.affine_inverse() * global_transform
	for key in tiles:
		var parts := _parts(MODELS[key])
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
				# Fit the original overlap slab; even raised cracked edges stay below
				# physics and the unchanged route markers. No new ground collision.
				var position := Vector3((tile.x + 0.5) * cell.x - shape.size.x * 0.5, -top - 0.002, (tile.y + 0.5) * cell.y - shape.size.z * 0.5)
				var basis := Basis.from_scale(Vector3(cell.x / 2.0, 1.0, cell.y / 2.0)) * Basis(Vector3.UP, ((tile.x + tile.y * 3) % 4) * PI * 0.5)
				instances.set_instance_transform(index, room_to_body * Transform3D(basis, position) * part.transform)
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
		if horizontal:
			position.x += -length * 0.5 + (index + 0.5) * width
		else:
			position.z += -length * 0.5 + (index + 0.5) * width
		var key := "mossy_wall" if str(body.name).begins_with("North") or str(body.name).begins_with("West") or index % 3 == 0 else "wall"
		if (str(body.name) == "NorthWall" and position.x > 2.0 and position.x < 5.0) or (str(body.name) == "EastWall2" and position.z < 6.0):
			key = "cracked_wall"
		_add_model(body, key, "StoneWall%d" % index, position, 0.0 if horizontal else PI * 0.5, Vector3(width / 2.0, size.y / 3.12, thickness / 0.48))


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
	# Tall props remain under existing occluder bodies for camera fading. All
	# dressing is outside the central 5 m-wide routes and has no physics nodes.
	var layout: Array[Dictionary] = [
		{"model": "pillar", "position": Vector3(-3.1, 0, 6.75)},
		{"model": "pillar", "position": Vector3(3.1, 0, 6.75)},
		{"model": "pillar", "position": Vector3(-8.75, 0, -3.1)},
		{"model": "pillar", "position": Vector3(-8.75, 0, 3.1)},
		{"model": "pillar", "position": Vector3(8.75, 0, -3.1)},
		{"model": "pillar", "position": Vector3(8.75, 0, 3.1)},
		{"model": "broken_pillar", "position": Vector3(-7.7, 0, -5.6), "yaw": PI * 0.5},
		{"model": "broken_pillar", "position": Vector3(7.6, 0, -5.5), "yaw": PI},
		{"model": "broken_pillar", "position": Vector3(-7.7, 0, 5.4), "yaw": -PI * 0.5},
		{"model": "broken_pillar", "position": Vector3(7.6, 0, 5.3)},
		{"model": "rubble", "position": Vector3(-6.6, 0, -5.6), "yaw": 0.4},
		{"model": "rubble", "position": Vector3(6.5, 0, -5.6), "yaw": 1.8},
		{"model": "rubble", "position": Vector3(-6.6, 0, 5.4), "yaw": 2.6},
		{"model": "rubble", "position": Vector3(6.5, 0, 5.3), "yaw": -0.6},
		{"model": "wall_torch", "position": Vector3(-5.9, 1.7, -6.98)},
		{"model": "wall_torch", "position": Vector3(5.9, 1.7, -6.98)},
		{"model": "wall_torch", "position": Vector3(-8.98, 1.7, -4.4), "yaw": PI * 0.5},
		{"model": "wall_torch", "position": Vector3(8.98, 1.7, -4.4), "yaw": -PI * 0.5},
		{"model": "wall_torch", "position": Vector3(-5.8, 1.7, 6.98), "yaw": PI},
		{"model": "wall_torch", "position": Vector3(5.8, 1.7, 6.98), "yaw": PI},
		{"model": "banner", "position": Vector3(8.98, 2.75, -5.7), "yaw": -PI * 0.5},
		{"model": "banner", "position": Vector3(8.98, 2.75, 4.8), "yaw": -PI * 0.5},
	]
	for index in range(layout.size()):
		var entry: Dictionary = layout[index]
		var position: Vector3 = entry.position
		_add_model(_nearest_wall(walls, position), entry.model, "Dressing%d_%s" % [index, entry.model], position, entry.get("yaw", 0.0))


func _build_combat_dressing(walls: Node3D) -> void:
	# Background bars sit in front of solid existing walls. They neither imply
	# new passages nor change collision, AI sight checks or projectile blocking.
	# Keep every prop outside both the 5 m routes and the central combat floor.
	var layout: Array[Dictionary] = [
		{"model": "cell_bars", "position": Vector3(4.25, 0, -6.88)},
		{"model": "cell_bars", "position": Vector3(8.86, 0, 4.9), "yaw": -PI * 0.5},
		{"model": "weapon_rack", "position": Vector3(3.9, 0, -5.65)},
		{"model": "cage", "position": Vector3(8.25, 0, 4.0), "yaw": -PI * 0.5},
		{"model": "bones", "position": Vector3(3.05, 0, -6.4), "yaw": 0.25},
		{"model": "bones", "position": Vector3(7.5, 0, 3.5), "yaw": -0.4},
		{"model": "broken_barrel", "position": Vector3(4.6, 0, 5.6)},
		{"model": "small_crate", "position": Vector3(3.5, 0, 5.2), "yaw": 0.2},
	]
	for index in range(layout.size()):
		var entry: Dictionary = layout[index]
		var position: Vector3 = entry.position
		_add_model(_nearest_wall(walls, position), entry.model, "CombatDressing%d_%s" % [index, entry.model], position, entry.get("yaw", 0.0))
