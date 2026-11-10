extends CharacterBody3D
## Level-two prototype: deterministic telegraphs, committed strikes, recovery.

signal hp_changed(current: int, maximum: int)
signal damage_received(amount: int)
signal battle_started
signal state_changed(message: String)
signal attack_resolved(kind: int, strike_index: int)
signal died

enum State { DORMANT, CHASE, WINDUP, RECOVER, DEAD }
enum Attack { SHOCKWAVE, ENERGY, COMBO }

const BOLT: PackedScene = preload("res://scenes/skills/EnemyEnergyBolt.tscn")
const Coins = preload("res://scenes/items/coin_pickup.gd")

@export var boss_name := "灾厄巨蝎"
@export var target_path := NodePath("../Player")
@export var max_hp: int = 36
@export var move_speed: float = 1.5
@export var detection_range: float = 13.0
@export var shock_radius: float = 4.5
@export var shock_damage: int = 2
@export var shock_windup: float = 1.1
@export var energy_windup: float = 0.9
@export var energy_damage: int = 1
@export var projectile_speed: float = 9.0
@export var projectile_range: float = 18.0
@export var combo_radius: float = 2.2
@export var combo_damage: int = 1
@export var combo_windup: float = 0.65
@export var combo_strikes: int = 3
@export var recovery_duration: float = 1.4
@export var gold_reward: int = 80

var hp: int
var state: State = State.DORMANT
var attack_kind: Attack = Attack.SHOCKWAVE
var _target: CharacterBody3D
var _active := false
var _remaining := 0.0
var _combo_index := 0
var _next_attack := 0
var _direction := Vector3.FORWARD
var _impact_point := Vector3.ZERO
var _visuals: Node3D
var _warning: Node3D
var _disc: MeshInstance3D
var _lanes: Array[MeshInstance3D] = []


func _ready() -> void:
	hp = max_hp
	_target = get_node_or_null(target_path) as CharacterBody3D
	_build_visuals()


func _physics_process(delta: float) -> void:
	if is_dead():
		return
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = 0.0 if is_on_floor() else velocity.y + get_gravity().y * delta
	if not is_instance_valid(_target) or _target.is_dead():
		_warning.hide()
		_set_state(State.DORMANT, "尚未交战")
		move_and_slide()
		return
	if state == State.WINDUP:
		_remaining = maxf(0.0, _remaining - delta)
		if _remaining == 0.0:
			_resolve_attack()
	elif state == State.RECOVER:
		_remaining = maxf(0.0, _remaining - delta)
		if _remaining == 0.0:
			_set_state(State.CHASE, "巨蝎逼近")
	else:
		var offset := _target.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if not _active and distance <= detection_range and _has_line_of_sight(_target.global_position):
			_activate()
		if _active:
			var direction := offset.normalized()
			_visuals.rotation.y = atan2(-direction.x, -direction.z)
			var kind: Attack = _next_attack as Attack
			var reach := projectile_range - 1.0 if kind == Attack.ENERGY else shock_radius + 0.5
			if distance <= reach and _has_line_of_sight(_target.global_position):
				begin_attack(kind)
				_next_attack = (_next_attack + 1) % 3
			else:
				velocity.x = direction.x * move_speed
				velocity.z = direction.z * move_speed
				_set_state(State.CHASE, "巨蝎逼近")
	move_and_slide()


func begin_attack(kind: Attack) -> bool:
	if not is_node_ready() or not can_process() or is_dead() or state == State.WINDUP or state == State.RECOVER:
		return false
	if not is_instance_valid(_target) or _target.is_dead() or kind < Attack.SHOCKWAVE or kind > Attack.COMBO:
		return false
	_activate()
	attack_kind = kind
	_combo_index = 0
	_begin_windup()
	return true


func _begin_windup() -> void:
	_direction = _target.global_position - global_position
	_direction.y = 0.0
	_direction = _direction.normalized() if not _direction.is_zero_approx() else Vector3.FORWARD
	_visuals.rotation.y = atan2(-_direction.x, -_direction.z)
	_impact_point = global_position
	if attack_kind == Attack.COMBO:
		_impact_point += _direction * 2.0
	var durations := [shock_windup, energy_windup, combo_windup]
	var messages := ["范围震击 · 离开圆形预警", "能量散射 · 避开三条射线", "连续重击 %d/%d" % [_combo_index + 1, combo_strikes]]
	_remaining = maxf(0.1, durations[attack_kind])
	_set_state(State.WINDUP, messages[attack_kind])
	_warning.show()
	_disc.visible = attack_kind != Attack.ENERGY
	var radius := shock_radius if attack_kind == Attack.SHOCKWAVE else combo_radius
	_disc.scale = Vector3(radius, 1, radius)
	_disc.global_position = _impact_point + Vector3.UP * 0.05
	for i in range(_lanes.size()):
		var lane := _lanes[i]
		lane.visible = attack_kind == Attack.ENERGY
		var direction := _direction.rotated(Vector3.UP, (i - 1) * 0.2)
		var start := global_position + Vector3.UP
		var hit := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(start, start + direction * projectile_range, 1, [get_rid()]))
		var length := start.distance_to(hit.position) if not hit.is_empty() else projectile_range
		lane.scale.z = length
		lane.global_position = global_position + direction * length * 0.5 + Vector3.UP * 0.05
		lane.rotation.y = atan2(-direction.x, -direction.z)


func _resolve_attack() -> void:
	_warning.hide()
	if attack_kind == Attack.ENERGY:
		for i in range(3):
			var bolt := BOLT.instantiate() as CharacterBody3D
			get_parent().add_child(bolt)
			bolt.global_position = global_position + Vector3.UP
			bolt.launch(_direction.rotated(Vector3.UP, (i - 1) * 0.2),
				energy_damage, projectile_speed, projectile_range, self)
	else:
		_apply_blast(shock_radius if attack_kind == Attack.SHOCKWAVE else combo_radius,
			shock_damage if attack_kind == Attack.SHOCKWAVE else combo_damage)
	_combo_index += 1
	attack_resolved.emit(attack_kind, _combo_index)
	if is_dead():
		return
	if attack_kind == Attack.COMBO and _combo_index < maxi(1, combo_strikes):
		_begin_windup()
	else:
		_remaining = maxf(0.1, recovery_duration)
		_set_state(State.RECOVER, "核心暴露 · 可以反击")


func _apply_blast(radius: float, damage: int) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 2.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, _impact_point + Vector3.UP * 1.25)
	query.collision_mask = 2
	query.exclude = [get_rid()]
	var receivers: Dictionary = {}
	for result in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var body: Node3D = result.collider
		if not body.has_method("take_damage") or receivers.has(body.get_instance_id()):
			continue
		receivers[body.get_instance_id()] = true
		if _has_line_of_sight(body.global_position):
			body.take_damage(damage)


func _has_line_of_sight(point: Vector3) -> bool:
	var start := global_position + Vector3.UP
	var finish := Vector3(point.x, start.y, point.z)
	return get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(start, finish, 1, [get_rid()])).is_empty()


func _activate() -> void:
	if not _active:
		_active = true
		battle_started.emit()


func _set_state(next_state: State, message: String) -> void:
	var changed := state != next_state or next_state == State.WINDUP
	state = next_state
	if changed:
		state_changed.emit(message)


func is_dead() -> bool:
	return state == State.DEAD


func take_damage(amount: int) -> bool:
	if not is_node_ready() or not can_process() or is_dead() or amount <= 0:
		return false
	_activate()
	var applied := mini(amount, hp)
	hp -= applied
	# Reserve death before notifying listeners; callbacks cannot kill/drop twice.
	if hp == 0:
		state = State.DEAD
	hp_changed.emit(hp, max_hp)
	damage_received.emit(applied)
	if hp == 0:
		_warning.hide()
		state_changed.emit("已击败")
		velocity = Vector3.ZERO
		set_physics_process(false)
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
		$CollisionShape3D.set_deferred("disabled", true)
		Coins.spawn(get_parent(), global_position, gold_reward, "boss:" + str(get_path()))
		died.emit()
		var tween := create_tween()
		tween.tween_property(_visuals, "scale", Vector3.ONE * 0.05, 0.6)
		tween.tween_callback(queue_free)
	return true


func _build_visuals() -> void:
	_visuals = $Visuals
	_warning = Node3D.new()
	add_child(_warning)
	var danger := StandardMaterial3D.new()
	danger.albedo_color = Color(1, 0.3, 0.08, 0.42)
	danger.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	danger.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 1
	disc_mesh.bottom_radius = 1
	disc_mesh.height = 0.03
	disc_mesh.material = danger
	_disc = MeshInstance3D.new()
	_disc.mesh = disc_mesh
	_warning.add_child(_disc)
	for i in range(3):
		var lane := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.55, 0.03, 1)
		mesh.material = danger
		lane.mesh = mesh
		_warning.add_child(lane)
		_lanes.append(lane)
	_warning.hide()
