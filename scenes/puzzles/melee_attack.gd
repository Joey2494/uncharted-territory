extends Node3D
## Default targets use physics layer 3; override the mask for other factions.
## A body, or an Area3D's parent, may implement
## take_damage(amount: int). hit_detected reports contact, not accepted damage.

signal attack_started
signal attack_finished
signal hit_detected(target: Node, amount: int)

@export var player_input_enabled: bool = true
@export var attack_enabled: bool = true
@export var range_color: Color = Color(1.0, 0.78, 0.25, 0.22)
@export var show_windup_preview: bool = false
@export_range(1, 100, 1) var attack_damage: int = 1
@export_range(0.5, 5.0, 0.1) var attack_range: float = 2.2
@export_range(10.0, 170.0, 1.0) var attack_arc_degrees: float = 110.0
@export_range(0.1, 4.0, 0.1) var attack_height: float = 1.6
@export_range(0.0, 1.0, 0.01) var windup_duration: float = 0.08
@export_range(0.01, 1.0, 0.01) var active_duration: float = 0.12
@export_range(0.0, 1.0, 0.01) var recovery_duration: float = 0.16
@export_range(0.1, 3.0, 0.01) var attack_cooldown: float = 0.5
@export_flags_3d_physics var target_collision_mask: int = 4
@export_flags_3d_physics var obstruction_collision_mask: int = 1

@onready var _facing: Node3D = $"../Visuals"
@onready var _swing: Node3D = $SwingPivot
@onready var _range_preview: MeshInstance3D = $RangePreview

var _shape: ConvexPolygonShape3D
var _attacking: bool = false
var _elapsed: float = 0.0
var _cooldown_remaining: float = 0.0
var _hit_targets: Dictionary = {}
var _current_damage: int = 1


func _ready() -> void:
	_build_attack_shape()
	_swing.position.y = 0.2 + attack_height * 0.5
	_swing.scale.z = attack_range / 2.2
	_swing.hide()
	_range_preview.hide()


func _unhandled_input(event: InputEvent) -> void:
	if player_input_enabled and event.is_action_pressed("attack") and not event.is_echo():
		try_attack()
		get_viewport().set_input_as_handled()


func try_attack() -> bool:
	if not is_node_ready() or not can_process() or not attack_enabled or _attacking or _cooldown_remaining > 0.0:
		return false
	var inventory := get_parent().get_node_or_null("ItemInventory")
	if player_input_enabled and inventory != null and inventory.equipped_weapon == inventory.FIREARM:
		return get_parent().get_node("Firearm").try_fire()
	# Snapshot the facing direction: moving or turning does not widen this swing.
	global_rotation = Vector3(0.0, _facing.global_rotation.y, 0.0)
	_current_damage = attack_damage
	var attacker := get_parent()
	if attacker.has_method("get_attack_damage"):
		_current_damage = attacker.get_attack_damage(attack_damage)
	_elapsed = 0.0
	_cooldown_remaining = maxf(
		attack_cooldown, windup_duration + active_duration + recovery_duration
	)
	_hit_targets.clear()
	_attacking = true
	_swing.rotation.y = -deg_to_rad(attack_arc_degrees) * 0.5
	_swing.show()
	_range_preview.visible = show_windup_preview
	attack_started.emit()
	return true


func is_attacking() -> bool:
	return _attacking


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func cancel_attack() -> void:
	var was_attacking := _attacking
	_attacking = false
	_swing.hide()
	_range_preview.hide()
	if was_attacking:
		attack_finished.emit()


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if not _attacking:
		return
	var previous_elapsed := _elapsed
	_elapsed += delta
	var active_end := windup_duration + active_duration
	var half_arc := deg_to_rad(attack_arc_degrees) * 0.5
	var swing_progress := clampf((_elapsed - windup_duration) / active_duration, 0.0, 1.0)
	_swing.rotation.y = lerpf(-half_arc, half_arc, swing_progress)
	_range_preview.visible = _elapsed < active_end and (show_windup_preview or _elapsed >= windup_duration)
	# Include a hit window crossed by a long physics frame rather than skipping it.
	if previous_elapsed < active_end and _elapsed >= windup_duration:
		_detect_hits()
	if _elapsed >= active_end + recovery_duration:
		_attacking = false
		_swing.hide()
		_range_preview.hide()
		attack_finished.emit()


func _detect_hits() -> void:
	var attacker := get_parent() as CollisionObject3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.transform = global_transform
	query.collision_mask = target_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [attacker.get_rid()]
	var space := get_world_3d().direct_space_state
	for hit in space.intersect_shape(query, 64):
		var collider := hit["collider"] as Node3D
		if not is_instance_valid(collider):
			continue
		var receiver: Node = collider
		if collider is Area3D and not collider.has_method("take_damage"):
			var parent := collider.get_parent()
			if parent != null and parent.has_method("take_damage"):
				receiver = parent
		if receiver == attacker or attacker.is_ancestor_of(receiver):
			continue
		var receiver_id := receiver.get_instance_id()
		if _hit_targets.has(receiver_id):
			continue
		# Check world geometry at swing height so floor contact cannot block a hit.
		var ray_start := global_position + Vector3.UP * (0.2 + attack_height * 0.5)
		var ray_end := Vector3(collider.global_position.x, ray_start.y, collider.global_position.z)
		var ray := PhysicsRayQueryParameters3D.create(
			ray_start, ray_end, obstruction_collision_mask, [attacker.get_rid()]
		)
		if not space.intersect_ray(ray).is_empty():
			continue
		_hit_targets[receiver_id] = true
		hit_detected.emit(receiver, _current_damage)
		if is_instance_valid(receiver) and receiver.has_method("take_damage"):
			receiver.call("take_damage", _current_damage)


func _build_attack_shape() -> void:
	var vertices := PackedVector3Array([Vector3(0, 0.2, 0), Vector3(0, 0.2 + attack_height, 0)])
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = range_color
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	var half_arc := deg_to_rad(attack_arc_degrees) * 0.5
	var previous_point := Vector3.ZERO
	for i in range(17):
		var angle := lerpf(-half_arc, half_arc, float(i) / 16.0)
		var point := Vector3(sin(angle) * attack_range, 0.0, -cos(angle) * attack_range)
		vertices.append(point + Vector3.UP * 0.2)
		vertices.append(point + Vector3.UP * (0.2 + attack_height))
		if i > 0:
			mesh.surface_add_vertex(Vector3(0, 0.04, 0))
			mesh.surface_add_vertex(previous_point + Vector3.UP * 0.04)
			mesh.surface_add_vertex(point + Vector3.UP * 0.04)
		previous_point = point
	mesh.surface_end()
	_shape = ConvexPolygonShape3D.new()
	_shape.points = vertices
	_range_preview.mesh = mesh
