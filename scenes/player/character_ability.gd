extends Node3D
## Owns only character abilities. Movement, damage, animations and K remain shared.

signal feedback(message: String)
const CATALOG = preload("res://scenes/player/character_catalog.gd")
const FIELD = preload("res://scenes/skills/gravity_field.gd")
@onready var actor: CharacterBody3D = get_parent()
var remaining: float = 0.0
var cooldown_remaining: float = 0.0
var blocked_hits: int = 0
var precise: bool = false
var _guard_direction := Vector3.FORWARD
var _aura: MeshInstance3D
var _shield_visual: MeshInstance3D

func _ready() -> void:
	_aura = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.65
	mesh.outer_radius = 0.8
	_aura.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("b99a5c")
	_aura.material_override = material
	_aura.position.y = 0.1
	add_child(_aura)
	_aura.hide()
	_shield_visual = MeshInstance3D.new()
	var shield_mesh := BoxMesh.new()
	shield_mesh.size = Vector3(0.8, 1.0, 0.12)
	_shield_visual.mesh = shield_mesh
	_shield_visual.material_override = material
	_shield_visual.position = Vector3(0.0, 1.0, -0.65)
	actor.get_node("Visuals").add_child(_shield_visual)
	_shield_visual.hide()
	actor.dodge_started.connect(_on_dodge)
	actor.died.connect(cancel)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("character_skill") and not event.is_echo():
		try_activate()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("character_skill") and is_guarding():
		_finish_guard(true)
		get_viewport().set_input_as_handled()

func try_activate() -> bool:
	if actor.character_id == "knight": return false
	if not is_node_ready() or not can_process() or actor.is_dead() or actor.is_dodging() or remaining > 0.0 or cooldown_remaining > 0.0:
		return false
	match actor.character_id:
		"lan":
			remaining = 4.0
		"iron":
			remaining = 1.2
			blocked_hits = 0
			precise = false
			_guard_direction = -actor.visuals.global_basis.z
			actor.get_node("MeleeAttack").cancel_attack()
			actor.get_node("CastAnimation").cancel()
		"astra":
			remaining = 0.25
	feedback.emit(CATALOG.definition(actor.character_id).skill)
	return true

func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if remaining > 0.0:
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.000001:
			if actor.character_id == "iron":
				_finish_guard(true)
			elif actor.character_id == "astra":
				remaining = 0.0
				_release_field()
			else:
				remaining = 0.0
				cooldown_remaining = get_cooldown_duration()
	_aura.visible = remaining > 0.0
	_shield_visual.visible = is_guarding()

func is_guarding() -> bool:
	return actor.character_id == "iron" and remaining > 0.0

func is_focused() -> bool:
	return actor.character_id == "lan" and remaining > 0.0

func is_casting() -> bool:
	return actor.character_id == "astra" and remaining > 0.0

func _release_field() -> void:
	var field := Node3D.new()
	field.set_script(FIELD)
	field.source = actor
	actor.get_parent().add_child(field)
	var start := actor.global_position + Vector3.UP * 0.5
	var finish: Vector3 = start - actor.visuals.global_basis.z * 6.0
	var ray := PhysicsRayQueryParameters3D.create(start, finish, 1)
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
	field.global_position = (hit.position + hit.normal * 0.15 if not hit.is_empty() else finish) - Vector3.UP * 0.45
	cooldown_remaining = get_cooldown_duration()

func _on_dodge() -> void:
	if is_casting():
		remaining = 0.0
		cooldown_remaining = 1.0
	elif is_guarding():
		cancel()

func block_direct_hit(source_position: Vector3) -> bool:
	if not is_guarding():
		return false
	var direction := source_position - actor.global_position
	direction.y = 0.0
	if direction.normalized().dot(_guard_direction) < cos(deg_to_rad(60.0)):
		return false
	blocked_hits += 1
	precise = precise or remaining >= 1.0
	feedback.emit("精准格挡" if remaining >= 1.0 else "格挡成功")
	return true

func _finish_guard(counter: bool) -> void:
	remaining = 0.0
	cooldown_remaining = get_cooldown_duration()
	if not counter or actor.is_dead():
		return
	# Prototype counter: 2 base + one per blocked hit, capped at 5.
	for target in FIELD.targets_in_radius(actor, actor.global_position, 2.5):
		var direction: Vector3 = target.global_position - actor.global_position
		direction.y = 0.0
		if direction.normalized().dot(_guard_direction) >= 0.5:
			target.take_damage(actor.get_attack_damage(2 + mini(blocked_hits, 3)))
			if precise and target.has_method("apply_control"):
				target.apply_control(0.5)
	feedback.emit("反击 · %d次格挡" % blocked_hits)

func cancel() -> void:
	if remaining > 0.0:
		remaining = 0.0
		cooldown_remaining = get_cooldown_duration()

func get_cooldown_remaining() -> float:
	return cooldown_remaining

func get_cooldown_duration() -> float:
	return CATALOG.definition(actor.character_id).cooldown
