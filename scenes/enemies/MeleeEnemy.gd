extends CharacterBody3D

signal hp_changed(current: int, maximum: int)
signal damage_received(amount: int)
signal died

enum State { IDLE, CHASE, ATTACK, HURT, DEAD }

@export var target_path: NodePath = NodePath("../Player")
@export_range(1, 100, 1) var max_hp: int = 3
@export_range(0.1, 10.0, 0.1) var move_speed: float = 2.4
@export_range(0.1, 30.0, 0.1) var turn_speed: float = 10.0
@export_range(1.0, 20.0, 0.5) var detection_range: float = 7.0
@export_range(1.0, 30.0, 0.5) var lose_range: float = 10.0
@export_range(0.5, 4.0, 0.05) var attack_distance: float = 1.5
@export_range(0.0, 1.0, 0.01) var hurt_duration: float = 0.18

@onready var _visuals: Node3D = $Visuals
@onready var _attack: Node3D = $MeleeAttack
@onready var _hit_flash: Node = $HitFlash
@onready var _health_label: Label3D = $HealthLabel

var hp: int
var state: State = State.IDLE
var _target: Node3D
var _aggro: bool = false
var _dead: bool = false
var _hurt_remaining: float = 0.0


func _ready() -> void:
	hp = max_hp
	_target = get_node_or_null(target_path) as Node3D
	_health_label.bind_health_source(self, hp, max_hp)


func _physics_process(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
	_hurt_remaining = maxf(0.0, _hurt_remaining - delta)
	if _hurt_remaining > 0.0:
		state = State.HURT
	elif _attack.is_attacking():
		state = State.ATTACK
	elif _has_live_target():
		_update_pursuit(delta)
	else:
		state = State.IDLE
		_aggro = false
	move_and_slide()


func _has_live_target() -> bool:
	return is_instance_valid(_target) and (not _target.has_method("is_dead") or not _target.is_dead())


func _update_pursuit(delta: float) -> void:
	var direction := _target.global_position - global_position
	direction.y = 0.0
	var distance := direction.length()
	if not _aggro and distance <= detection_range and _can_see_target():
		_aggro = true
	if distance > maxf(lose_range, detection_range):
		_aggro = false
	if not _aggro:
		state = State.IDLE
		return
	if distance <= attack_distance and _can_see_target():
		state = State.IDLE
		if _attack.get_cooldown_remaining() <= 0.0:
			_visuals.rotation.y = atan2(-direction.x, -direction.z)
			if _attack.try_attack():
				state = State.ATTACK
		return
	state = State.CHASE
	direction = direction.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	_visuals.rotation.y = lerp_angle(
		_visuals.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-turn_speed * delta)
	)


func _can_see_target() -> bool:
	var start := global_position + Vector3.UP
	var finish := Vector3(_target.global_position.x, start.y, _target.global_position.z)
	var ray := PhysicsRayQueryParameters3D.create(start, finish, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func is_dead() -> bool:
	return _dead


func get_hurt_time_remaining() -> float:
	return _hurt_remaining


func take_damage(amount: int) -> bool:
	if not is_node_ready() or not can_process() or _dead or amount <= 0:
		return false
	var applied := mini(amount, hp)
	hp -= applied
	_dead = hp == 0
	_aggro = true
	_hurt_remaining = hurt_duration
	_attack.cancel_attack()
	_hit_flash.flash()
	hp_changed.emit(hp, max_hp)
	damage_received.emit(applied)
	if _dead:
		_die()
	else:
		state = State.HURT
	return true


func _die() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	set_physics_process(false)
	_attack.process_mode = Node.PROCESS_MODE_DISABLED
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	$CollisionShape3D.set_deferred("disabled", true)
	died.emit()
