extends RefCounted
## Temporary level-one art; every original tide collider stays authoritative.
const Maker = preload("res://scenes/dungeon/almsyone_visuals.gd")
const FLOOR = preload("res://assets/dungeon/almsyone/SM_Floor_Stone.glb")
const WALL = preload("res://assets/dungeon/almsyone/SM_Wall_Mossy.glb")
const ALTAR = preload("res://assets/dungeon/almsyone/SM_Altar.glb")
var maker := Maker.new()

func dress(body: Node3D, size: Vector3, floor_tile: bool) -> void:
	_dress(body, size, FLOOR if floor_tile else WALL, true)

func dress_prop(body: Node3D, size: Vector3) -> void:
	_dress(body, size, ALTAR, false)

func _dress(body: Node3D, size: Vector3, source: PackedScene, tiled: bool) -> void:
	var parts: Array[Dictionary] = maker.parts(source)
	var bounds: AABB = parts[0].transform * parts[0].mesh.get_aabb()
	for part in parts:
		bounds = bounds.merge(part.transform * part.mesh.get_aabb())
	var columns := maxi(1, ceili(size.x / 2.0)) if tiled else 1
	var rows := maxi(1, ceili(size.z / 2.0)) if tiled else 1
	var cell := Vector3(size.x / columns, size.y, size.z / rows)
	var scale_factor := Vector3(cell.x / bounds.size.x, cell.y / bounds.size.y, cell.z / bounds.size.z)
	for part in parts:
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = part.mesh
		batch.instance_count = columns * rows
		for z in rows:
			for x in columns:
				var center := Vector3(-size.x / 2 + (x + 0.5) * cell.x, 0, -size.z / 2 + (z + 0.5) * cell.z)
				var origin := center - (bounds.position + bounds.size / 2) * scale_factor
				batch.set_instance_transform(z * columns + x, Transform3D(Basis.from_scale(scale_factor), origin) * part.transform)
		var visual := MultiMeshInstance3D.new()
		visual.name = "FirstLevelStone"
		visual.multimesh = batch
		visual.set_meta("source_model", source.resource_path)
		body.add_child(visual)
