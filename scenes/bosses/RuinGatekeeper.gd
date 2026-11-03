extends CharacterBody3D

signal hp_changed(current: int, maximum: int)
signal damage_received(amount: int)
signal battle_started
signal state_changed(message: String)
signal charge_contact(target: Node, amount: int)
signal died

enum State { DORMANT, CHASE, SWING, CHARGE_WINDUP, CHARGE, RECOVER, DEAD }

@export var boss_name: String = "遗迹守门者"
@export var target_path: NodePath = NodePath("../Player")
@export_range(1, 200, 1) var max_hp: int = 24
@export_range(0.5, 10.0, 0.1) var move_speed: float = 1.8
@export_range(1.0, 20.0, 0.1) var detection_range: float = 4.2
@export_range(1.0, 5.0, 0.1) var melee_distance: float = 2.5
@export_range(1.0, 8.0, 0.1) var charge_minimum_distance: float = 3.0
@export_range(0.2, 3.0, 0.05) var charge_windup: float = 1.0
@export_range(1.0, 30.0, 0.5) var charge_speed: float = 12.0
@export_range(1.0, 12.0, 0.5) var charge_distance: float = 7.0
@export_range(1, 10, 1) var charge_damage: int = 2
@export_range(0.2, 3.0, 0.05) var recovery_duration: float = 1.0

@onready var _visuals: Node3D = $Visuals
@onready var _melee: Node3D = $MeleeAttack
@onready var _flash: Node = $HitFlash
@onready var _warning: Node3D = $ChargeWarning
@onready var _lane: MeshInstance3D = $ChargeWarning/Lane
@onready var _arrow: MeshInstance3D = $ChargeWarning/Arrow
@onready var _trail: MeshInstance3D = $Visuals/ChargeTrail

var hp: int
var state: State = State.DORMANT
var _target: Node3D
var _battle_active: bool = false
var _dead: bool = false
var _prefer_charge: bool = true
var _state_remaining: float = 0.0
var _charge_direction: Vector3 = Vector3.FORWARD
var _charge_remaining: float = 0.0
var _warning_length: float = 0.0


func _ready() -> void:
	hp = max_hp
	_target = get_node_or_null(target_path) as Node3D
	_melee.attack_finished.connect(_on_melee_finished)
	_warning.hide()
	_trail.hide()
	_build_arrow()


func _physics_process(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
	if not _has_live_target():
		_melee.cancel_attack()
		_warning.hide()
		_trail.hide()
		_set_state(State.DORMANT)
		move_and_slide()
		return
	if state == State.CHARGE:
		_move_charge(delta)
		return
	if state == State.CHARGE_WINDUP:
		_state_remaining = maxf(0.0, _state_remaining - delta)
		_lane.transparency = 0.15 + sin(_state_remaining * 12.0) * 0.1
		move_and_slide()
		if _state_remaining <= 0.0:
			_warning.hide()
			_trail.show()
			_charge_remaining = _warning_length
			_set_state(State.CHARGE)
		return
	if state == State.SWING:
		move_and_slide()
		return
	if state == State.RECOVER:
		_state_remaining = maxf(0.0, _state_remaining - delta)
		move_and_slide()
		if _state_remaining <= 0.0:
			_set_state(State.CHASE)
		return
	var direction := _target.global_position - global_position
	direction.y = 0.0
	var distance := direction.length()
	if not _battle_active and distance <= detection_range and _can_see_target():
		_activate_battle()
	if not _battle_active:
		move_and_slide()
		return
	if _prefer_charge and distance >= charge_minimum_distance and _can_see_target():
		_begin_charge(direction.normalized())
	elif distance <= melee_distance and _can_see_target():
		if _melee.get_cooldown_remaining() <= 0.0:
			_visuals.global_rotation = Vector3(0.0, atan2(-direction.x, -direction.z), 0.0)
			if _melee.try_attack():
				_set_state(State.SWING)
	else:
		_set_state(State.CHASE)
		direction = direction.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		_visuals.rotation.y = lerp_angle(_visuals.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-8.0 * delta))
	move_and_slide()


func _activate_battle() -> void:
	if not _battle_active:
		_battle_active = true
		battle_started.emit()
		_set_state(State.CHASE)


func _has_live_target() -> bool:
	return is_instance_valid(_target) and (not _target.has_method("is_dead") or not _target.is_dead())


func _can_see_target() -> bool:
	var start := global_position + Vector3.UP * 1.2
	var finish := Vector3(_target.global_position.x, start.y, _target.global_position.z)
	var ray := PhysicsRayQueryParameters3D.create(start, finish, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _begin_charge(direction: Vector3) -> void:
	_charge_direction = direction
	_visuals.global_rotation = Vector3(0.0, atan2(-direction.x, -direction.z), 0.0)
	_warning.global_rotation = _visuals.global_rotation
	_warning_length = charge_distance
	var start := global_position + Vector3.UP * 1.2
	var ray := PhysicsRayQueryParameters3D.create(start, start + direction * charge_distance, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var radius: float = ($CollisionShape3D.shape as CapsuleShape3D).radius
		_warning_length = maxf(0.0, start.distance_to(hit.position) - radius - 0.01)
	_lane.scale.z = maxf(_warning_length, 0.01)
	_lane.position.z = -_warning_length * 0.5
	_arrow.position.z = -_warning_length
	_warning.show()
	_state_remaining = charge_windup
	_set_state(State.CHARGE_WINDUP)


func _move_charge(delta: float) -> void:
	var step := minf(charge_speed * delta, _charge_remaining)
	velocity.x = _charge_direction.x * step / delta
	velocity.z = _charge_direction.z * step / delta
	var before := global_position
	move_and_slide()
	_charge_remaining = maxf(0.0, _charge_remaining - maxf(0.0, (global_position - before).dot(_charge_direction)))
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if absf(collision.get_normal().y) > 0.7:
			continue
		var collider := collision.get_collider() as CollisionObject3D
		if is_instance_valid(collider) and (collider.collision_layer & 2) != 0 and collider.has_method("take_damage"):
			charge_contact.emit(collider, charge_damage)
			if is_instance_valid(collider):
				collider.call("take_damage", charge_damage)
		_begin_recovery()
		return
	if _charge_remaining <= 0.001 or global_position.distance_to(before) < 0.00001:
		_begin_recovery()


func _on_melee_finished() -> void:
	if not _dead and state == State.SWING:
		_prefer_charge = true
		_begin_recovery()


func _begin_recovery() -> void:
	if state == State.CHARGE:
		_prefer_charge = false
	velocity.x = 0.0
	velocity.z = 0.0
	_warning.hide()
	_trail.hide()
	_state_remaining = recovery_duration
	_set_state(State.RECOVER)


func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	var messages := {
		State.DORMANT: "尚未交战",
		State.CHASE: "守门者逼近",
		State.SWING: "近战挥击 · 注意扇形预警",
		State.CHARGE_WINDUP: "冲锋蓄力 · 离开红色直线",
		State.CHARGE: "冲锋",
		State.RECOVER: "破绽 · 可以反击",
		State.DEAD: "已击败"
	}
	state_changed.emit(messages[state])


func is_dead() -> bool:
	return _dead


func take_damage(amount: int) -> bool:
	if not is_node_ready() or not can_process() or _dead or amount <= 0:
		return false
	_activate_battle()
	var applied := mini(amount, hp)
	hp -= applied
	_dead = hp == 0
	_flash.flash()
	hp_changed.emit(hp, max_hp)
	damage_received.emit(applied)
	# A living Boss keeps its telegraphed action; ordinary hits do not stun-lock it.
	if _dead:
		_set_state(State.DEAD)
		_melee.cancel_attack()
		_melee.process_mode = Node.PROCESS_MODE_DISABLED
		_warning.hide()
		_trail.hide()
		velocity = Vector3.ZERO
		set_physics_process(false)
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
		$CollisionShape3D.set_deferred("disabled", true)
		died.emit()
	return true


func _build_arrow() -> void:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1.0, 0.45, 0.1, 1.0)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	mesh.surface_add_vertex(Vector3(0, 0.06, 0))
	mesh.surface_add_vertex(Vector3(-0.6, 0.06, 0.9))
	mesh.surface_add_vertex(Vector3(0.6, 0.06, 0.9))
	mesh.surface_end()
	_arrow.mesh = mesh
