extends Camera3D

@export var target_path: NodePath = NodePath("../Player")
@export_range(0.1, 30.0, 0.1) var follow_speed: float = 8.0
@export_range(50.0, 55.0, 0.1) var pitch_degrees: float = 52.0
@export_range(8.0, 40.0, 0.5) var minimum_distance: float = 18.0
@export_range(0.1, 20.0, 0.1) var zoom_speed: float = 5.0
@export_range(0.1, 1.0, 0.05) var actor_padding: float = 0.45
@export_range(0.5, 0.98, 0.01) var occluder_transparency: float = 0.9
@export_range(10.0, 32.0) var label_height_pixels := 24.0

# Default framing also supports using the dungeon scene on its own.
const SAFE_FRAME := Rect2(0.30, 0.18, 0.64, 0.74)

var _safe_frame: Rect2 = SAFE_FRAME
var _target: Node3D
var _focus: Vector3
var _distance: float = 18.0
var _view_basis: Basis
var _faded_meshes: Dictionary = {}
var _scaled_labels: Dictionary = {}


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		push_warning("Follow camera target is missing: %s" % target_path)
		set_process(false)
		return
	projection = Camera3D.PROJECTION_PERSPECTIVE
	keep_aspect = Camera3D.KEEP_HEIGHT
	reset_follow()


func reset_follow() -> void:
	if not is_instance_valid(_target):
		return
	_view_basis = Basis(Vector3.RIGHT, -deg_to_rad(pitch_degrees))
	var actors := _get_actors()
	_focus = _desired_focus(actors)
	_distance = maxf(minimum_distance, _required_distance(actors, _focus) * 1.1)
	_apply_view()


func set_safe_frame(frame: Rect2) -> void:
	_safe_frame = frame
	if not is_instance_valid(_target):
		return
	_distance = maxf(_distance, _required_distance(_get_actors(), _focus) * 1.1)
	_apply_view()
	_update_labels(_get_actors())


func get_safe_frame() -> Rect2:
	return _safe_frame


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	var actors := _get_actors()
	_focus = _focus.lerp(_desired_focus(actors), 1.0 - exp(-follow_speed * delta))
	var fit := _required_distance(actors, _focus)
	var desired_distance := maxf(minimum_distance, fit * 1.1)
	_distance = lerpf(_distance, desired_distance, 1.0 - exp(-zoom_speed * delta))
	# Normal motion uses the framing reserve. A sudden spread/resize must still
	# keep every actor on screen instead of waiting for the zoom interpolation.
	_distance = maxf(_distance, fit)
	_apply_view()
	_update_labels(actors)
	_update_occluders(actors, delta)


func _get_actors() -> Array[Node3D]:
	var actors: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("camera_targets"):
		if not node is Node3D or not get_parent().is_ancestor_of(node) or node.is_queued_for_deletion():
			continue
		if node != _target and node.has_method("is_dead") and node.is_dead():
			continue
		if node != _target and get_parent().has_method("is_camera_target_relevant") and not get_parent().is_camera_target_relevant(node, _target):
			continue
		actors.append(node)
	if not actors.has(_target):
		actors.append(_target)
	return actors


func _desired_focus(actors: Array[Node3D]) -> Vector3:
	var low := _target.global_position
	var high := low
	for actor in actors:
		low = low.min(actor.global_position)
		high = high.max(actor.global_position)
	var centre := (low + high) * 0.5
	var spread := maxf(high.x - low.x, high.z - low.z)
	# Prefer the player in close combat; centre a widely separated group so
	# keeping distant enemies visible does not require an excessive zoom-out.
	var group_weight := lerpf(0.3, 1.0, clampf((spread - 6.0) / 8.0, 0.0, 1.0))
	var focus := _target.global_position.lerp(centre, group_weight)
	focus.y = _target.global_position.y + 1.0
	return focus


func _actor_dimensions(actor: Node3D) -> Vector2:
	var radius: float = 0.5
	var height: float = 2.0
	var collision := actor.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null and collision.shape is CapsuleShape3D:
		var capsule := collision.shape as CapsuleShape3D
		radius = capsule.radius
		height = collision.position.y + capsule.height * 0.5
	for child in actor.get_children():
		if child is Label3D and child.visible:
			height = maxf(height, child.position.y + 0.7)
	# Arthropod silhouettes extend beyond their central collision capsules.
	radius = maxf(radius, float(actor.get_meta("camera_radius", radius)))
	height = maxf(height, float(actor.get_meta("camera_height", height)))
	return Vector2(radius, height)


func _required_distance(actors: Array[Node3D], focus: Vector3) -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	var tan_y := tan(deg_to_rad(fov) * 0.5)
	var tan_x := tan_y * viewport_size.x / maxf(viewport_size.y, 1.0)
	var left := _safe_frame.position.x * 2.0 - 1.0
	var right := _safe_frame.end.x * 2.0 - 1.0
	var bottom := 1.0 - _safe_frame.end.y * 2.0
	var top := 1.0 - _safe_frame.position.y * 2.0
	var aim_x := _safe_frame.get_center().x * 2.0 - 1.0
	var aim_y := 1.0 - _safe_frame.get_center().y * 2.0
	var required := minimum_distance
	for actor in actors:
		var dimensions := _actor_dimensions(actor)
		var radius := dimensions.x + actor_padding
		for x in [-radius, radius]:
			for z in [-radius, radius]:
				for y in [0.0, dimensions.y + actor_padding]:
					var point := actor.global_transform * Vector3(x, y, z)
					var local := _view_basis.transposed() * (point - focus)
					required = maxf(required, local.z + near + 0.5)
					required = maxf(required, (local.x / tan_x + right * local.z) / (right - aim_x))
					required = maxf(required, (-local.x / tan_x - left * local.z) / (aim_x - left))
					required = maxf(required, (local.y / tan_y + top * local.z) / (top - aim_y))
					required = maxf(required, (-local.y / tan_y - bottom * local.z) / (aim_y - bottom))
	return required


func _apply_view() -> void:
	global_basis = _view_basis
	global_position = _focus + _view_basis.z * _distance
	var viewport_size := get_viewport().get_visible_rect().size
	var tan_y := tan(deg_to_rad(fov) * 0.5)
	var tan_x := tan_y * viewport_size.x / maxf(viewport_size.y, 1.0)
	h_offset = -(_safe_frame.get_center().x * 2.0 - 1.0) * _distance * tan_x
	v_offset = -(1.0 - _safe_frame.get_center().y * 2.0) * _distance * tan_y


func _update_labels(actors: Array[Node3D]) -> void:
	var active: Dictionary = {}
	var viewport_size := get_viewport().get_visible_rect().size
	# Match UI text in logical pixels; Window applies the uniform screen scale.
	var label_height := label_height_pixels
	var camera_transform := get_camera_transform()
	for actor in actors:
		for child in actor.get_children():
			if not child is Label3D or not child.visible:
				continue
			var id: int = child.get_instance_id()
			active[id] = true
			if not _scaled_labels.has(id):
				_scaled_labels[id] = {"node": weakref(child), "size": child.pixel_size, "no_depth_test": child.no_depth_test}
			child.no_depth_test = true
			var depth: float = -(camera_transform.affine_inverse() * child.global_position).z
			child.pixel_size = label_height * 2.0 * maxf(depth, near) * tan(deg_to_rad(fov) * 0.5) / (maxf(viewport_size.y, 1.0) * child.font_size)
	for id in _scaled_labels.keys():
		if not active.has(id):
			var label = _scaled_labels[id].node.get_ref()
			if is_instance_valid(label):
				label.pixel_size = _scaled_labels[id].size
				label.no_depth_test = _scaled_labels[id].no_depth_test
			_scaled_labels.erase(id)


func _update_occluders(actors: Array[Node3D], delta: float) -> void:
	var blocked: Dictionary = {}
	var start := get_camera_transform().origin
	var space := get_world_3d().direct_space_state
	for actor in actors:
		var dimensions := _actor_dimensions(actor)
		var chest := actor.global_position + Vector3.UP * dimensions.y * 0.5
		var points := [actor.global_position + Vector3.UP * 0.1, chest, actor.global_position + Vector3.UP * dimensions.y, chest + _view_basis.x * dimensions.x * 0.8, chest - _view_basis.x * dimensions.x * 0.8]
		for point in points:
			var excluded: Array[RID] = []
			for i in range(4):
				var query := PhysicsRayQueryParameters3D.create(start, point, 1, excluded)
				var hit := space.intersect_ray(query)
				if hit.is_empty():
					break
				var body := hit.collider as CollisionObject3D
				if body == null or not body.is_in_group("camera_occluders"):
					break
				excluded.append(body.get_rid())
				for mesh in body.find_children("*", "MeshInstance3D", true, false):
					var id: int = mesh.get_instance_id()
					blocked[id] = true
					if not _faded_meshes.has(id):
						_remember_occluder(mesh)
	for id in _faded_meshes.keys():
		var mesh = _faded_meshes[id].node.get_ref()
		if not is_instance_valid(mesh):
			_faded_meshes.erase(id)
			continue
		var entry: Dictionary = _faded_meshes[id]
		if blocked.has(id):
			entry.fade = occluder_transparency
		else:
			entry.fade = lerpf(entry.fade, 0.0, 1.0 - exp(-12.0 * delta))
			if entry.fade < 0.001:
				mesh.material_override = entry.original_material
				_faded_meshes.erase(id)
				continue
		var material: BaseMaterial3D = entry.material
		var color := material.albedo_color
		color.a = entry.alpha * (1.0 - entry.fade)
		material.albedo_color = color


func _remember_occluder(mesh: MeshInstance3D) -> void:
	var source := mesh.get_active_material(0) as BaseMaterial3D
	if source == null:
		return
	# GeometryInstance3D.transparency is ignored by Compatibility. Give each
	# obstructing wall its own alpha material, preserving all shared resources.
	var material := source.duplicate() as BaseMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_faded_meshes[mesh.get_instance_id()] = {"node": weakref(mesh), "original_material": mesh.material_override, "material": material, "alpha": source.albedo_color.a, "fade": 0.0}
	mesh.material_override = material


func _exit_tree() -> void:
	for entry in _faded_meshes.values():
		var mesh = entry.node.get_ref()
		if is_instance_valid(mesh):
			mesh.material_override = entry.original_material
	for entry in _scaled_labels.values():
		var label = entry.node.get_ref()
		if is_instance_valid(label):
			label.pixel_size = entry.size
			label.no_depth_test = entry.no_depth_test
