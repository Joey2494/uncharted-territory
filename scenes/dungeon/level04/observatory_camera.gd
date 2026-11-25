extends "res://scenes/dungeon/follow_camera.gd"
## 新版十二房、十六通路共用玩家跟随与固定视距，不再按战斗房包围盒拉远。

func _ready() -> void:
	set_safe_frame(Rect2(0.07,0.18,0.86,0.72))
	super._ready()

func reset_follow() -> void:
	if not is_instance_valid(_target): return
	_view_basis = Basis(Vector3.RIGHT, -deg_to_rad(pitch_degrees))
	_focus = _target.global_position + Vector3.UP
	_distance = minimum_distance
	_apply_view()

func set_safe_frame(frame: Rect2) -> void:
	# HUD 只调整玩家在屏幕中的落点，不重新计算整房取景距离。
	_safe_frame = frame

func _process(delta: float) -> void:
	if not is_instance_valid(_target): return
	_focus = _focus.lerp(_target.global_position + Vector3.UP, 1.0 - exp(-follow_speed * delta))
	_distance = minimum_distance
	_apply_view()
	var actors := _get_actors()
	# Keep the authored fixed view on landscape screens. In portrait combat,
	# reserve enough horizontal space for active attackers as well as the player.
	var viewport := get_viewport().get_visible_rect().size
	if viewport.x < viewport.y:
		var attackers: Array[Node3D] = [_target]
		for actor in actors:
			if actor != _target and actor.has_method("is_encounter_active") and actor.is_encounter_active(): attackers.append(actor)
		if attackers.size() > 1:
			_distance = maxf(minimum_distance,_required_distance(attackers,_focus))
			_apply_view()
	_update_labels(actors)
	_update_occluders(actors, delta)

func _update_occluders(actors: Array[Node3D], delta: float) -> void:
	super._update_occluders(actors,delta)
	var points := _actor_visibility_points(actors)
	var eye := get_camera_transform().origin
	for mesh in get_tree().get_nodes_in_group("observatory_visual_occluders"):
		if not get_parent().is_ancestor_of(mesh) or not mesh.is_visible_in_tree(): continue
		var inverse: Transform3D = mesh.global_transform.affine_inverse()
		var bounds: AABB = mesh.get_aabb().grow(0.12)
		var blocked := false
		for point in points:
			if bounds.intersects_segment(inverse*eye,inverse*point) != null:
				blocked = true
				break
		if mesh.get_meta("observatory_mirror_surface",false):
			mesh.material_override.set_shader_parameter("occlusion_alpha",0.04 if blocked else 1.0)
			continue
		if not blocked: continue
		var id: int = mesh.get_instance_id()
		if not _faded_meshes.has(id): _remember_occluder(mesh)
		if _faded_meshes.has(id):
			var entry: Dictionary = _faded_meshes[id]
			entry.fade = 0.96
			var material: BaseMaterial3D = entry.material
			var color := material.albedo_color
			color.a = entry.alpha*0.04
			material.albedo_color = color
