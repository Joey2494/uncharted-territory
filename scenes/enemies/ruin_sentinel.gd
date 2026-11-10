extends "res://scenes/enemies/MeleeEnemy.gd"

signal shot_fired(projectile: Node3D)

const BOLT: PackedScene = preload("res://scenes/skills/EnemyEnergyBolt.tscn")
@export var preferred_distance: float = 5.0
@export var shot_windup: float = 0.8
@export var shot_recovery: float = 1.2
@export var projectile_speed: float = 8.0
@export var projectile_range: float = 16.0
@export var shot_damage: int = 1

var _charging := false
var _shot_remaining := 0.0
var _shot_cooldown := 0.0
var _shot_direction := Vector3.FORWARD
var _warning: MeshInstance3D


func _ready() -> void:
	super._ready()
	_attack.attack_enabled = false
	_warning = MeshInstance3D.new()
	var lane := BoxMesh.new()
	lane.size = Vector3(0.55, 0.025, projectile_range)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.75, 1, 0.35)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lane.material = material
	_warning.mesh = lane
	add_child(_warning)
	_warning.hide()


func _physics_process(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = 0.0 if is_on_floor() else velocity.y + get_gravity().y * delta
	_hurt_remaining = maxf(0.0, _hurt_remaining - delta)
	_shot_cooldown = maxf(0.0, _shot_cooldown - delta)
	if not _has_live_target():
		_cancel_shot()
		state = State.IDLE
	elif _hurt_remaining > 0.0:
		_cancel_shot()
		state = State.HURT
	elif _charging:
		_shot_remaining = maxf(0.0, _shot_remaining - delta)
		if _shot_remaining == 0.0:
			_release_shot()
	else:
		_update_ranged_pursuit()
	move_and_slide()


func _update_ranged_pursuit() -> void:
	var offset: Vector3 = _target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance > lose_range:
		_aggro = false
	if not _aggro and distance <= detection_range and _can_see_target():
		_aggro = true
	if not _aggro:
		state = State.IDLE
		return
	var direction := offset.normalized()
	_visuals.rotation.y = atan2(-direction.x, -direction.z)
	if distance <= preferred_distance + 1.0 and _can_see_target():
		if _shot_cooldown <= 0.0:
			_charging = true
			state = State.ATTACK
			_shot_direction = direction
			_shot_remaining = shot_windup
			var start := global_position + Vector3.UP
			var hit := get_world_3d().direct_space_state.intersect_ray(
				PhysicsRayQueryParameters3D.create(start, start + direction * projectile_range, 1, [get_rid()]))
			var length := start.distance_to(hit.position) if not hit.is_empty() else projectile_range
			_warning.scale.z = length / projectile_range
			_warning.rotation.y = atan2(-direction.x, -direction.z)
			_warning.position = direction * length * 0.5 + Vector3.UP * 0.04
			_warning.show()
		else:
			state = State.IDLE
	else:
		state = State.CHASE
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed


func _release_shot() -> void:
	_cancel_shot()
	_shot_cooldown = shot_recovery
	var bolt := BOLT.instantiate() as CharacterBody3D
	get_parent().add_child(bolt)
	bolt.global_position = global_position + Vector3.UP
	bolt.launch(_shot_direction, shot_damage, projectile_speed, projectile_range, self)
	shot_fired.emit(bolt)


func _cancel_shot() -> void:
	_charging = false
	_warning.hide()


func _die() -> void:
	_cancel_shot()
	super._die()
