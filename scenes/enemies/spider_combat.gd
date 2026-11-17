extends "res://scenes/dungeon/level02/hub_guard.gd"
## Distinct ranged silk hunter and brood mother; inherited melee is permanently disabled.
signal attack_resolved(kind: int, strike_index: int)
const Projectile = preload("res://scenes/skills/creature_projectile.gd")
const FX = preload("res://scenes/enemies/creature_fx.gd")
@export_enum("Silk", "Brood") var attack_kind := 0
var _charging := false
var _remaining := 0.0
var _cooldown := 1.0
var _direction := Vector3.FORWARD
var _warning: Node3D
var _offspring: Array[WeakRef] = []
@export_range(16, 48) var brood_wave_size := 32
@export_range(32, 96) var brood_alive_limit := 64

func _ready() -> void:
	if attack_kind == 0:
		max_hp = maxi(max_hp, 4)
		move_speed = maxf(move_speed, 3.4)
		hurt_duration = 0.1
		_cooldown = 0.0
	super._ready()
	_attack.attack_enabled = false
	attack_distance = 0.0
	$HealthLabel.elite = attack_kind == 1
	$HealthLabel.update_hp(hp, max_hp)
	_warning = Node3D.new()
	add_child(_warning)
	if attack_kind == 1:
		for i in range(20):
			var a := i * TAU / 20
			var b := (i + 1) * TAU / 20
			FX.strand(_warning, Vector3(cos(a), 0.07, sin(a)) * 1.5, Vector3(cos(b), 0.07, sin(b)) * 1.5, Color("dfa34f"), 0.035)
	_warning.hide()

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0, _cooldown - delta)
	if _charging:
		velocity = Vector3.ZERO
		_hurt_remaining = maxf(0, _hurt_remaining - delta)
		_control_remaining = maxf(0, _control_remaining - delta)
		if not _has_live_target() or _hurt_remaining > 0 or _control_remaining > 0:
			_cancel_special()
			return
		_remaining -= delta
		if _remaining <= 0: _release()
		return
	super._physics_process(delta)

func _update_pursuit(delta: float) -> void:
	var offset := _target.global_position - global_position
	offset.y = 0
	if offset.length() <= detection_range and _can_see_target(): _aggro = true
	if _aggro and offset.length() <= (9.5 if attack_kind == 0 else 7.0) and _can_see_target():
		state = State.IDLE
		if _cooldown <= 0:
			if attack_kind == 0:
				# React and fire in this physics tick: no aiming phase or ground preview.
				_direction = offset.normalized()
				_visuals.rotation.y = atan2(-_direction.x, -_direction.z)
				_release()
				state = State.ATTACK
				return
			_offspring = _offspring.filter(func(w: WeakRef) -> bool: return is_instance_valid(w.get_ref()))
			if attack_kind == 1 and _offspring.size() >= brood_alive_limit: return
			_charging = true
			_remaining = 1.25
			_direction = offset.normalized()
			_visuals.rotation.y = atan2(-_direction.x, -_direction.z)
			_warning.rotation.y = _visuals.rotation.y
			_warning.show()
			state = State.ATTACK
		return
	super._update_pursuit(delta)

func _release() -> void:
	_charging = false
	_warning.hide()
	_cooldown = 0.95 if attack_kind == 0 else 5.0
	_offspring = _offspring.filter(func(w: WeakRef) -> bool: return is_instance_valid(w.get_ref()))
	var count := 1 if attack_kind == 0 else maxi(0, mini(brood_wave_size, brood_alive_limit - _offspring.size()))
	var holes: Array[Vector3] = []
	if attack_kind == 1:
		for i in 6:
			var a := i * TAU / 6
			var offset := Vector3(cos(a), 0, sin(a)) * 1.65
			var start := global_position + Vector3.UP * 0.35
			var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start, start + offset, 1, [get_rid()]))
			if not hit.is_empty(): offset *= 0.35
			var hole := global_position + offset + Vector3.UP * 0.025
			holes.append(hole)
			FX.burrow(get_parent(), hole, i * 0.05)
	for i in range(count):
		var shot := Projectile.new()
		get_parent().add_child(shot)
		if attack_kind == 0:
			shot.global_position = global_position + _direction * 0.85 + Vector3.UP * 0.85
		else:
			var jitter := Vector3(cos(i * 2.4), 0, sin(i * 2.4)) * (0.08 + (i % 4) * 0.065)
			shot.global_position = holes[i % holes.size()] + jitter + Vector3.UP * 0.15
			shot.emergence_delay = (i / 6) * 0.14 + (i % 6) * 0.035
		shot.setup(self, _target, _direction, attack_kind)
		if attack_kind == 1: _offspring.append(weakref(shot))
	attack_resolved.emit(attack_kind, 1)

func _cancel_special() -> void:
	_charging = false
	_warning.hide()
	_cooldown = maxf(_cooldown, 0.12 if attack_kind == 0 else 1.0)

func take_damage(amount: int) -> bool:
	var accepted := super.take_damage(amount)
	if accepted: _cancel_special()
	return accepted

func _die() -> void:
	_cancel_special()
	for w in _offspring:
		var child = w.get_ref()
		if is_instance_valid(child): child.queue_free()
	super._die()

func cancel_combat() -> void:
	_cancel_special()
