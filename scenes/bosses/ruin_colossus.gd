extends CharacterBody3D
## Level-two prototype: deterministic telegraphs, committed strikes, recovery.

signal hp_changed(current: int, maximum: int)
signal damage_received(amount: int)
signal battle_started
signal state_changed(message: String)
signal attack_resolved(kind: int, strike_index: int)
signal died

enum State { DORMANT, CHASE, WINDUP, RECOVER, DEAD, STRIKE }
enum Attack { SHOCKWAVE, ENERGY, COMBO }

const VOLLEY_COUNT := 5
const Projectile = preload("res://scenes/skills/creature_projectile.gd")
const FX = preload("res://scenes/enemies/creature_fx.gd")
const Coins = preload("res://scenes/items/coin_pickup.gd")

@export var boss_name := "灾厄巨蝎"
@export var target_path := NodePath("../Player")
@export var max_hp: int = 36
@export var move_speed: float = 3.2
@export var detection_range: float = 13.0
@export var shock_radius: float = 5.5
@export var shock_damage: int = 2
@export var shock_windup: float = 0.85
@export var energy_windup: float = 0.65
@export var energy_damage: int = 2
@export var projectile_speed: float = 20.0
@export var projectile_range: float = 18.0
@export var combo_radius: float = 2.2
@export var combo_damage: int = 2
@export var combo_windup: float = 0.5
@export var combo_strikes: int = 3
@export var recovery_duration: float = 0.85
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
var _strike_elapsed := 0.0
var _strike_hit := false
var _tail: Node3D
var _stinger: Node3D
var _tail_rest := Vector3.ZERO
var _strike_receivers: Dictionary = {}
var _sweep_direction := Vector3.FORWARD


func _ready() -> void:
	hp = max_hp
	_target = get_node_or_null(target_path) as CharacterBody3D
	_build_visuals()
	_tail = $Visuals/Model/Tail
	_tail_rest = _tail.rotation
	var tips := _tail.find_children("*Sting*", "Node3D", true, false)
	_stinger = tips[0] if not tips.is_empty() else _tail


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
	if state == State.STRIKE:
		_tick_tail_strike(delta)
		move_and_slide()
		return
	if state == State.WINDUP:
		_tail.rotation.x = lerpf(_tail.rotation.x, _tail_rest.x - 0.65, minf(1, delta * 7))
		_remaining = maxf(0.0, _remaining - delta)
		if _remaining == 0.0:
			_strike_elapsed = 0
			_strike_hit = false
			_strike_receivers.clear()
			_set_state(State.STRIKE, "尾部出击")
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
			var reach := projectile_range - 1.0 if kind == Attack.ENERGY else (combo_radius + 1.8 if kind == Attack.COMBO else shock_radius + 0.3)
			if distance <= reach and _has_line_of_sight(_target.global_position):
				begin_attack(kind)
				_next_attack = (_next_attack + 1) % 3
			else:
				velocity.x = direction.x * move_speed
				velocity.z = direction.z * move_speed
				_set_state(State.CHASE, "巨蝎逼近")
	move_and_slide()


func begin_attack(kind: Attack) -> bool:
	if not is_node_ready() or not can_process() or is_dead() or state in [State.WINDUP, State.RECOVER, State.STRIKE]:
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
	var messages := ["巨尾蓄力 · 侧移避开横扫", "毒刺蓄力 · 留意尾针朝向", "尾针连刺 %d/%d" % [_combo_index + 1, combo_strikes]]
	_remaining = maxf(0.1, durations[attack_kind])
	_set_state(State.WINDUP, messages[attack_kind])
	_warning.hide() # Model windup provides the cue; no ground attack-range preview.
	_disc.visible = attack_kind != Attack.ENERGY
	var radius := shock_radius if attack_kind == Attack.SHOCKWAVE else combo_radius
	_disc.scale = Vector3.ONE
	_disc.mesh = _sector_mesh(radius, 220.0 if attack_kind == Attack.SHOCKWAVE else 360.0)
	_disc.rotation.y = atan2(-_direction.x, -_direction.z)
	_disc.global_position = _impact_point + Vector3.UP * 0.05
	for i in range(_lanes.size()):
		var lane := _lanes[i]
		lane.visible = attack_kind == Attack.ENERGY
		var direction := _direction.rotated(Vector3.UP, (i - (VOLLEY_COUNT - 1) * 0.5) * 0.18)
		var start := global_position + Vector3.UP
		var hit := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(start, start + direction * projectile_range, 1, [get_rid()]))
		var length := start.distance_to(hit.position) if not hit.is_empty() else projectile_range
		lane.scale.z = length
		lane.global_position = global_position + direction * length * 0.5 + Vector3.UP * 0.05
		lane.rotation.y = atan2(-direction.x, -direction.z)


func _tick_tail_strike(delta: float) -> void:
	_strike_elapsed += delta
	var t := clampf(_strike_elapsed / 0.42, 0, 1)
	if attack_kind == Attack.SHOCKWAVE:
		_tail.rotation = _tail_rest + Vector3(-0.4, lerpf(-1.92, 1.92, t), 0)
	else:
		_tail.rotation = _tail_rest + Vector3(lerpf(-0.65, 0.65, sin(t * PI)), 0, 0)
	if attack_kind == Attack.SHOCKWAVE and t >= 0.15 and t <= 0.9:
		_sweep_direction = _direction.rotated(Vector3.UP, lerpf(-1.92, 1.92, t))
		_apply_blast(shock_radius, shock_damage)
		FX.burst(get_parent(), global_position + _sweep_direction * shock_radius + Vector3.UP * 0.2, Color("e59c42"), 0.55)
	if not _strike_hit and t >= 0.5:
		_strike_hit = true
		_warning.hide()
		if attack_kind == Attack.ENERGY:
			for i in range(VOLLEY_COUNT):
				var bolt := Projectile.new()
				get_parent().add_child(bolt)
				# Project the stinger to player height, with a visible connecting discharge.
				var muzzle := Vector3(_stinger.global_position.x, global_position.y + 0.85, _stinger.global_position.z)
				bolt.global_position = muzzle
				bolt.setup(self, _target, _direction.rotated(Vector3.UP, (i - (VOLLEY_COUNT - 1) * 0.5) * 0.18), 2, energy_damage, projectile_speed, projectile_range)
				FX.burst(get_parent(), _stinger.global_position, Color("b6fa46"), 0.8)
		elif attack_kind == Attack.COMBO:
			var lash := Node3D.new()
			get_parent().add_child(lash)
			lash.add_to_group("creature_hazards")
			var from: Vector3 = _stinger.global_transform * (_stinger.get_aabb().get_center() if _stinger is MeshInstance3D else Vector3.ZERO)
			FX.strand(lash, from, _impact_point + Vector3.UP * 0.3, Color("d8b457"), 0.12)
			var fade := lash.create_tween()
			fade.tween_interval(0.12)
			fade.tween_callback(lash.queue_free)
			_apply_blast(shock_radius if attack_kind == Attack.SHOCKWAVE else combo_radius,
				shock_damage if attack_kind == Attack.SHOCKWAVE else combo_damage)
			FX.burst(get_parent(), _impact_point + Vector3.UP * 0.15, Color("e59c42"), shock_radius if attack_kind == Attack.SHOCKWAVE else combo_radius)
	if t >= 1:
		_tail.rotation = _tail_rest
		_resolve_attack()

func _resolve_attack() -> void:
	_warning.hide()
	_combo_index += 1
	attack_resolved.emit(attack_kind, _combo_index)
	if is_dead(): return
	if attack_kind == Attack.COMBO and _combo_index < maxi(1, combo_strikes):
		_begin_windup()
	else:
		_remaining = maxf(0.1, recovery_duration)
		_set_state(State.RECOVER, "尾甲回收 · 可以反击")


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
		var offset := body.global_position - global_position
		offset.y = 0
		if attack_kind == Attack.SHOCKWAVE and offset.length() > 0.01 and _sweep_direction.dot(offset.normalized()) < cos(deg_to_rad(25.0)):
			continue
		if _strike_receivers.has(body.get_instance_id()): continue
		if _has_line_of_sight(body.global_position):
			_strike_receivers[body.get_instance_id()] = true
			body.take_direct_damage(damage, global_position)


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
	$HitFlash.flash()
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
	for i in range(VOLLEY_COUNT):
		var lane := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.55, 0.03, 1)
		mesh.material = danger
		lane.mesh = mesh
		_warning.add_child(lane)
		_lanes.append(lane)
	_warning.hide()

func _sector_mesh(radius: float, degrees: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, FX.material(Color(1, 0.22, 0.08, 0.38)))
	for i in range(40):
		var a := deg_to_rad(-degrees * 0.5 + degrees * i / 40.0)
		var b := deg_to_rad(-degrees * 0.5 + degrees * (i + 1) / 40.0)
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(Vector3(sin(b), 0, -cos(b)) * radius)
		mesh.surface_add_vertex(Vector3(sin(a), 0, -cos(a)) * radius)
	mesh.surface_end()
	return mesh


func cancel_combat() -> void:
	_warning.hide()
