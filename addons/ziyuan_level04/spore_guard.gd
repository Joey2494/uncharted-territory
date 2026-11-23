extends CharacterBody3D
## 孢冠女巫召唤的孢子守卫（§12.4）：近身扑咬，最多同时 2 只、整场 6 只。
## 召唤物不掉金币、不触发独立奖励；首领死亡时由宿主统一回收（minions_dissolved）。
## 契约与第三关敌人模块一致的子集：bind_target / set_encounter_active /
## take_damage / take_direct_damage / apply_control / apply_slow / hp_changed / died。
signal hp_changed(current: int, maximum: int)
signal damage_received(amount: int)
signal died
signal enemy_died(enemy: Node3D)
const Catalog = preload("catalog.gd")
const FX = preload("effects.gd")
const Visual = preload("visual.gd")
enum State { IDLE, CHASE, WINDUP, STRIKE, RECOVER, HURT, DEAD }
@export var target_path := NodePath("../Player")
@export var start_active := false
var enemy_id := "spore_guard"
var definition: Dictionary
var max_hp := 4
var hp := 4
var state: State = State.IDLE
var _target: Node3D
var _aggro := false
var _enabled := false
var _battle := false
var _remaining := 0.0
var _duration := 1.0
var _direction := Vector3.FORWARD
var _visual: Node3D
var _warning: Node3D
var _control := 0.0
var _slow := 0.0
var _hit: Dictionary = {}
var _flash: Node
func _ready() -> void:
	definition = Catalog.definition(enemy_id)
	assert(not definition.is_empty(), "Unknown level04 enemy_id")
	max_hp = definition.hp
	hp = max_hp
	collision_layer = 4
	collision_mask = 3
	add_to_group("l4_enemies")
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.6
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)
	_visual = get_node_or_null("Visuals")
	if _visual == null:
		_visual = Visual.new()
		_visual.name = "Visuals"
		add_child(_visual)
	_visual.build(enemy_id, definition.color)
	_warning = Node3D.new()
	_warning.name = "Telegraph"
	add_child(_warning)
	_flash = preload("res://scenes/ui/hit_flash_3d.gd").new()
	_flash.visual_root = NodePath("../Visuals")
	add_child(_flash)
	if _target == null: _target = get_node_or_null(target_path) as Node3D
	set_encounter_active(start_active)
func is_boss() -> bool: return false
func is_dead() -> bool: return state == State.DEAD
func is_encounter_active() -> bool: return _enabled and can_process() and not is_dead()
func bind_target(target: Node3D) -> bool:
	if not is_instance_valid(target) or not target.has_method("take_damage") or not target.has_method("is_dead"): return false
	_target = target
	return true
func set_encounter_active(active: bool) -> void:
	if is_dead(): return
	_enabled = active and not is_dead()
	_aggro = false
	if not active: _clear_warning()
	process_mode = Node.PROCESS_MODE_PAUSABLE if _enabled else Node.PROCESS_MODE_DISABLED
func _clear_warning() -> void:
	if not is_instance_valid(_warning): return
	for child in _warning.get_children(): child.queue_free()
func _live_target() -> bool:
	return is_instance_valid(_target) and not _target.is_dead()
func _can_see(point: Vector3) -> bool:
	var a := global_position + Vector3.UP
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, Vector3(point.x, a.y, point.z), 1, [get_rid()])).is_empty()
func _physics_process(delta: float) -> void:
	if not _enabled or is_dead(): return
	velocity.x = 0
	velocity.z = 0
	velocity.y = 0 if is_on_floor() else velocity.y + get_gravity().y * delta
	_slow = maxf(0, _slow - delta)
	_control = maxf(0, _control - delta)
	if not _live_target():
		_clear_warning()
		state = State.IDLE
		return
	if _control > 0:
		state = State.HURT
		_remaining = _control
	elif state == State.WINDUP:
		_remaining = maxf(0, _remaining - delta)
		if _remaining <= 0: _begin_strike()
	elif state == State.STRIKE:
		_tick_strike(delta)
	elif state in [State.RECOVER, State.HURT]:
		_remaining = maxf(0, _remaining - delta)
		if _remaining <= 0: state = State.CHASE
	else:
		_pursue(delta)
	var progress := clampf(1.0 - _remaining / maxf(_duration, 0.01), 0, 1)
	_visual.pose(state, progress, Vector2(velocity.x, velocity.z).length(), delta, 0)
	move_and_slide()
func _pursue(_delta: float) -> void:
	var offset := _target.global_position - global_position
	offset.y = 0
	var distance := offset.length()
	if not _aggro and distance < 18 and _can_see(_target.global_position):
		_aggro = true
		if not _battle:
			_battle = true
	if not _aggro:
		state = State.IDLE
		return
	_direction = offset.normalized() if distance > 0.01 else Vector3.FORWARD
	_visual.rotation.y = atan2(-_direction.x, -_direction.z)
	if distance <= definition.reach and _can_see(_target.global_position):
		_clear_warning()
		_begin_strike()
	else:
		state = State.CHASE
		var speed: float = definition.speed * (0.65 if _slow > 0 else 1.0)
		velocity.x = _direction.x * speed
		velocity.z = _direction.z * speed
func _begin_strike() -> void:
	state = State.STRIKE
	_duration = 0.4
	_remaining = _duration
	_hit.clear()
	_clear_warning()
func _tick_strike(delta: float) -> void:
	var old := 1.0 - _remaining / maxf(_duration, 0.01)
	_remaining = maxf(0, _remaining - delta)
	var t := 1.0 - _remaining / maxf(_duration, 0.01)
	if old < 0.45 and t >= 0.45:
		# 前扑：扑进 1.2，命中玩家造成 1 点；扑空进入收招。
		var motion := _direction * 1.2
		var collision := move_and_collide(motion)
		if collision != null and collision.get_collider() == _target:
			_hit_player(definition.damage)
		elif _target.global_position.distance_to(global_position) <= 1.5 and _can_see(_target.global_position):
			_hit_player(definition.damage)
		_clear_warning()
	if _remaining <= 0:
		state = State.RECOVER
		_remaining = definition.recovery
		_duration = _remaining
func _hit_player(amount: int) -> void:
	if not _live_target() or _hit.has(_target.get_instance_id()): return
	_hit[_target.get_instance_id()] = true
	if _target.has_method("take_direct_damage"): _target.take_direct_damage(amount, global_position)
	else: _target.take_damage(amount)
func apply_control(duration: float) -> void:
	if not is_encounter_active(): return
	_control = maxf(_control, minf(duration, 2.5))
	_remaining = _control
	state = State.HURT
	_clear_warning()
func apply_slow(duration: float) -> void:
	if is_encounter_active(): _slow = maxf(_slow, minf(duration, 4))
func take_direct_damage(amount: int, _source_position: Vector3) -> bool:
	return take_damage(amount)
func take_damage(amount: int) -> bool:
	if not is_node_ready() or not is_encounter_active() or amount <= 0: return false
	var applied := mini(amount, hp)
	hp -= applied
	if hp == 0:
		state = State.DEAD
		_enabled = false
	_flash.flash()
	hp_changed.emit(hp, max_hp)
	damage_received.emit(applied)
	if hp == 0:
		_clear_warning()
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
		set_physics_process(false)
		enemy_died.emit(self)
		died.emit()
		FX.burst(get_parent(), global_position + Vector3.UP * 0.3, Color("a8c47e"), 0.7)
		var t := create_tween()
		t.tween_property(_visual, "scale", Vector3.ONE * 0.05, 0.3)
		t.parallel().tween_property(_visual, "position:y", -0.3, 0.3)
		t.tween_callback(queue_free)
	elif not is_boss():
		state = State.HURT
		_remaining = 0.15
		_clear_warning()
	return true
