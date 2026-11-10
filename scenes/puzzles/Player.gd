extends CharacterBody3D

signal hp_changed(current: int, maximum: int)
signal damage_received(amount: int)
signal died
signal death_animation_finished
signal dodge_started
signal dodge_finished

@export_range(0.1, 30.0, 0.1) var move_speed: float = 8.0
@export_range(0.1, 30.0, 0.1) var walk_speed: float = 5.0
@export_range(0.1, 30.0, 0.1) var turn_speed: float = 12.0
@export_range(1, 100, 1) var max_hp: int = 5
@export_range(0.0, 2.0, 0.05) var hit_invulnerability: float = 0.6
@export_range(0.5, 6.0, 0.1) var dodge_distance: float = 3.0
@export_range(0.05, 0.5, 0.01) var dodge_duration: float = 0.2
@export_range(0.0, 1.0, 0.01) var dodge_invulnerability: float = 0.2
@export_range(0.1, 3.0, 0.05) var dodge_cooldown: float = 0.8

@onready var visuals: Node3D = $Visuals
@onready var _attack: Node3D = $MeleeAttack
@onready var _hit_flash: Node = $HitFlash
@onready var _items: Node3D = $ItemInventory

var hp: int
var _dead: bool = false
var _invulnerability_remaining: float = 0.0
var _dodge_remaining: float = 0.0
var _dodge_invulnerability_remaining: float = 0.0
var _dodge_cooldown_remaining: float = 0.0
var _dodge_direction: Vector3 = Vector3.ZERO
var _dodge_speed: float = 0.0
var _dodge_total_duration: float = 0.0
var _attack_was_enabled: bool = true


func _ready() -> void:
	hp = max_hp


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dodge") and not event.is_echo():
		try_dodge()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_invulnerability_remaining = maxf(0.0, _invulnerability_remaining - delta)
	_dodge_invulnerability_remaining = maxf(0.0, _dodge_invulnerability_remaining - delta)
	_dodge_cooldown_remaining = maxf(0.0, _dodge_cooldown_remaining - delta)
	if _dodge_cooldown_remaining < 0.000001:
		_dodge_cooldown_remaining = 0.0
	var move_direction := _get_move_direction()
	var dodging := is_dodging()
	if dodging:
		# move_and_slide uses the entire physics delta. Scale the last step so
		# short durations cannot move farther than the configured distance.
		var step_fraction := minf(delta, _dodge_remaining) / delta
		velocity.x = _dodge_direction.x * _dodge_speed * step_fraction
		velocity.z = _dodge_direction.z * _dodge_speed * step_fraction
	else:
		var speed := move_speed if Input.is_action_pressed("sprint") else minf(walk_speed, move_speed)
		velocity.x = move_direction.x * speed
		velocity.z = move_direction.z * speed
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	if dodging:
		_dodge_remaining = maxf(0.0, _dodge_remaining - delta)
		if _dodge_remaining < 0.000001:
			_finish_dodge()
	elif not move_direction.is_zero_approx():
		var target_yaw := atan2(-move_direction.x, -move_direction.z)
		visuals.rotation.y = lerp_angle(
			visuals.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta)
		)


func _get_move_direction() -> Vector3:
	var direction := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	return Vector3(direction.x, 0.0, direction.y)


func try_dodge() -> bool:
	if not is_node_ready() or not can_process() or _dead or is_dodging() or _dodge_cooldown_remaining > 0.0 or not is_on_floor():
		return false
	_dodge_direction = _get_move_direction()
	if _dodge_direction.is_zero_approx():
		_dodge_direction = -visuals.global_basis.z
		_dodge_direction.y = 0.0
	_dodge_direction = _dodge_direction.normalized()
	var duration := maxf(dodge_duration, 0.01)
	_dodge_speed = dodge_distance / duration
	_dodge_total_duration = duration
	_dodge_remaining = duration
	_dodge_invulnerability_remaining = clampf(dodge_invulnerability, 0.0, duration)
	_dodge_cooldown_remaining = maxf(dodge_cooldown, duration)
	_attack_was_enabled = _attack.attack_enabled
	_attack.attack_enabled = false
	_attack.cancel_attack()
	# Keep the starting facing so forward/back/side dodges match their displacement.
	dodge_started.emit()
	return true


func _finish_dodge() -> void:
	_dodge_remaining = 0.0
	_dodge_invulnerability_remaining = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	_attack.attack_enabled = _attack_was_enabled and not _dead
	dodge_finished.emit()


func is_dodging() -> bool:
	return _dodge_remaining > 0.0


func get_dodge_direction() -> Vector3:
	return _dodge_direction


func get_dodge_progress() -> float:
	return clampf(1.0 - _dodge_remaining / maxf(_dodge_total_duration, 0.01), 0.0, 1.0)


func get_dodge_cooldown_remaining() -> float:
	return _dodge_cooldown_remaining


func is_invulnerable() -> bool:
	return _invulnerability_remaining > 0.0 or _dodge_invulnerability_remaining > 0.0


func is_dead() -> bool:
	return _dead


func heal(amount: int, menu: Node = null) -> int:
	var menu_healing: bool = is_instance_valid(menu) and menu.is_in_group("commerce_controllers") \
		and menu.has_method("allows_inventory_action") and menu.allows_inventory_action(_items, false)
	if not is_node_ready() or (not can_process() and not menu_healing) or _dead or amount <= 0:
		return 0
	var restored := mini(amount, max_hp - hp)
	if restored > 0:
		hp += restored
		hp_changed.emit(hp, max_hp)
	return restored


func get_attack_damage(base_damage: int) -> int:
	return _items.get_attack_damage(base_damage)


func take_damage(amount: int) -> bool:
	if not is_node_ready() or not can_process() or _dead or amount <= 0 or is_invulnerable():
		return false
	if _items.guard_active:
		# Reserve the contact window before guard/UI signals can cause reentry.
		_invulnerability_remaining = maxf(hit_invulnerability, 0.05)
		if _items.consume_guard():
			return true
	var applied := mini(amount, hp)
	hp -= applied
	_dead = hp == 0
	_invulnerability_remaining = hit_invulnerability
	_hit_flash.flash()
	hp_changed.emit(hp, max_hp)
	damage_received.emit(applied)
	if _dead:
		if is_dodging():
			_finish_dodge()
		velocity = Vector3.ZERO
		set_physics_process(false)
		set_process_unhandled_input(false)
		$EnergyShock.set_process_unhandled_input(false)
		_items.set_process_unhandled_input(false)
		_attack.attack_enabled = false
		_attack.cancel_attack()
		_attack.process_mode = Node.PROCESS_MODE_DISABLED
		died.emit()
	return true
