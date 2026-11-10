@tool
extends Node3D
## Modular room or corridor. Geometry also rebuilds in the editor viewport.

@export var dimensions := Vector2(20.0, 16.0):
	set(value):
		dimensions = value.max(Vector2.ONE)
		_queue_rebuild()
@export var display_name: String = "探索区域"
@export var exploration_room: bool = true
@export var optional_branch: bool = false
@export var floor_color := Color(0.32, 0.30, 0.25):
	set(value):
		floor_color = value
		_queue_rebuild()
@export var open_north: bool = false:
	set(value):
		open_north = value
		_queue_rebuild()
@export var open_south: bool = false:
	set(value):
		open_south = value
		_queue_rebuild()
@export var open_west: bool = false:
	set(value):
		open_west = value
		_queue_rebuild()
@export var open_east: bool = false:
	set(value):
		open_east = value
		_queue_rebuild()
@export_range(2.5, 8.0, 0.5) var doorway_width: float = 5.0:
	set(value):
		doorway_width = value
		_queue_rebuild()

var _rebuild_pending: bool = false


func _ready() -> void:
	_rebuild_geometry()


func get_world_bounds() -> Rect2:
	return Rect2(Vector2(global_position.x, global_position.z) - dimensions * 0.5, dimensions)


func contains_point(point: Vector3) -> bool:
	return get_world_bounds().has_point(Vector2(point.x, point.z))


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_pending:
		return
	_rebuild_pending = true
	_rebuild_geometry.call_deferred()


func _rebuild_geometry() -> void:
	_rebuild_pending = false
	var old := get_node_or_null("Geometry")
	if old != null:
		remove_child(old)
		old.queue_free()
	var geometry := Node3D.new()
	geometry.name = "Geometry"
	add_child(geometry, false, Node.INTERNAL_MODE_BACK)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = floor_color
	floor_material.roughness = 0.95
	# 物理地板保留接缝余量，避免角色在房间边界掉落；可见网格仅覆盖本区域。
	# 两个门洞相接时，外扩的可见地板会在同一高度争夺深度，暗门开启后出现条纹闪烁。
	var floor_body := _box(geometry, "Floor", Vector3(0, -0.25, 0), Vector3(dimensions.x + 1.2, 0.5, dimensions.y + 1.2), floor_material)
	var floor_mesh := floor_body.get_node("MeshInstance3D").mesh as BoxMesh
	floor_mesh.size = Vector3(dimensions.x, 0.5, dimensions.y)
	var walls := Node3D.new()
	walls.name = "Walls"
	geometry.add_child(walls)
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.23, 0.25, 0.24)
	wall_material.roughness = 0.9
	_wall_side(walls, "North", dimensions.x, -dimensions.y * 0.5 - 0.3, true, open_north, wall_material)
	_wall_side(walls, "South", dimensions.x, dimensions.y * 0.5 + 0.3, true, open_south, wall_material)
	_wall_side(walls, "West", dimensions.y, -dimensions.x * 0.5 - 0.3, false, open_west, wall_material)
	_wall_side(walls, "East", dimensions.y, dimensions.x * 0.5 + 0.3, false, open_east, wall_material)


func _wall_side(parent: Node3D, side: String, length: float, edge: float, horizontal: bool, opened: bool, material: StandardMaterial3D) -> void:
	var spans: Array[Vector2] = [Vector2(-length * 0.5 - 0.6, length * 0.5 + 0.6)]
	if opened:
		var half_door := minf(doorway_width, length) * 0.5
		# A full-width corridor end has no cross wall or threshold collider.
		if doorway_width >= length:
			return
		spans = [Vector2(-length * 0.5 - 0.6, -half_door), Vector2(half_door, length * 0.5 + 0.6)]
	for i in range(spans.size()):
		var span := spans[i]
		var center := (span.x + span.y) * 0.5
		var location := Vector3(center, 1.5, edge) if horizontal else Vector3(edge, 1.5, center)
		var size := Vector3(span.y - span.x, 3.0, 0.6) if horizontal else Vector3(0.6, 3.0, span.y - span.x)
		var suffix := str(i + 1) if opened else ""
		var wall := _box(parent, side + "Wall" + suffix, location, size, material)
		wall.add_to_group("camera_occluders")


func _box(parent: Node3D, label: String, location: Vector3, size: Vector3, material: StandardMaterial3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = location
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body
