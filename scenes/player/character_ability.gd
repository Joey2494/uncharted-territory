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
var prepared_remaining: float = 0.0
var _preparation_idle: float = 0.0
var _preparation_cooldown: float = 0.0
var _blocked_attacks: Dictionary = {}
var _shield_restored: Dictionary = {}
var _rewarded_rooms: Dictionary = {}
var _credited_kills: Dictionary = {}
var _preparation_label: Label3D

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
	actor.get_node("MeleeAttack").attack_started.connect(record_attack)
	actor.get_node("MeleeAttack").hit_confirmed.connect(_on_melee_hit)
	_preparation_label = Label3D.new()
	_preparation_label.text = "整备完成"
	_preparation_label.position.y = 2.3
	_preparation_label.font_size = 40
	_preparation_label.modulate = Color("e5c16c")
	add_child(_preparation_label)
	_preparation_label.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("character_skill") and not event.is_echo():
		try_activate()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("character_skill") and can_process() and not actor.is_dead() and is_guarding():
		_finish_guard(true)
		get_viewport().set_input_as_handled()

func try_activate() -> bool:
	if not is_node_ready() or not can_process() or actor.is_dead() or actor.is_dodging() or remaining > 0.0 or cooldown_remaining > 0.0:
		return false
	match actor.character_id:
		"knight":
			if actor.energy >= actor.max_energy: return false
			cooldown_remaining = get_cooldown_duration()
			actor.restore_energy(10.0)
		"lan":
			remaining = get_configuration().duration
		"iron":
			remaining = get_configuration().duration
			blocked_hits = 0
			precise = false
			_blocked_attacks.clear()
			_guard_direction = -actor.visuals.global_basis.z
			actor.get_node("MeleeAttack").cancel_attack()
			actor.get_node("CastAnimation").cancel()
		"astra":
			remaining = get_configuration().duration
	feedback.emit(CATALOG.definition(actor.character_id).skill)
	return true

func _physics_process(delta: float) -> void:
	if actor.is_dead(): return
	if actor.character_id == "lan":
		_preparation_idle += delta
		_preparation_cooldown = maxf(0.0, _preparation_cooldown - delta)
		prepared_remaining = maxf(0.0, prepared_remaining - delta)
		if prepared_remaining == 0.0 and _preparation_idle >= 1.5 and _preparation_cooldown == 0.0:
			prepared_remaining = 5.0
			_preparation_cooldown = 6.0
			feedback.emit("整备完成")
		_preparation_label.visible = prepared_remaining > 4.0
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
	var start := actor.global_position + Vector3.UP * 0.5
	var finish: Vector3 = start - actor.visuals.global_basis.z * 6.0
	var ray := PhysicsRayQueryParameters3D.create(start, finish, 1)
	ray.hit_from_inside = true
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
	var center: Vector3 = hit.position + hit.normal * 0.15 if not hit.is_empty() else finish
	var clearance := SphereShape3D.new()
	clearance.radius = 0.1
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = clearance
	query.transform.origin = center
	query.collision_mask = 1
	if start.distance_to(center) < 0.2 or not actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		cooldown_remaining = 1.0
		feedback.emit("无法放置法阵")
		return
	var field := Node3D.new()
	field.set_script(FIELD)
	field.source = actor
	actor.get_parent().add_child(field)
	field.global_position = center - Vector3.UP * 0.45
	cooldown_remaining = get_cooldown_duration()

func _on_dodge() -> void:
	if is_casting():
		remaining = 0.0
		cooldown_remaining = 1.0
	elif is_guarding():
		cancel()

func block_direct_hit(source_position: Vector3, attack_id: String = "") -> bool:
	if not is_guarding():
		return false
	var direction := source_position - actor.global_position
	direction.y = 0.0
	if direction.normalized().dot(_guard_direction) < cos(deg_to_rad(60.0)):
		return false
	if not attack_id.is_empty() and _blocked_attacks.has(attack_id): return true
	if not attack_id.is_empty(): _blocked_attacks[attack_id] = true
	blocked_hits += 1
	precise = precise or remaining >= 0.6
	feedback.emit("精准格挡" if remaining >= 0.6 else "格挡成功")
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
	if actor.is_dead():
		prepared_remaining = 0.0
		_aura.hide()
		_shield_visual.hide()
		_preparation_label.hide()
		for field in get_tree().get_nodes_in_group("gravity_fields"):
			if field.source == actor: field.queue_free()

func record_attack() -> void:
	_preparation_idle = 0.0

func consume_prepared_shot() -> int:
	var bonus := 1 if prepared_remaining > 0.0 else 0
	prepared_remaining = 0.0
	record_attack()
	return bonus

func _on_melee_hit(target: Node, _amount: int) -> void:
	if actor.character_id != "iron" or actor.is_dead() or not is_instance_valid(target): return
	if not target.has_method("is_dead") or not target.is_dead(): return
	if not target.has_method("apply_control") or target.is_in_group("bosses") or (target.has_method("is_boss") and target.is_boss()): return
	if _credited_kills.has(target.get_instance_id()): return
	if target.get_meta("is_summoned", false) or target.is_in_group("summoned_units"): return
	if actor.global_position.distance_to(target.global_position) > 2.5: return
	var room: String = target.get_meta("combat_room_key", "")
	if room.is_empty() or int(_shield_restored.get(room, 0)) >= 2 or actor.shield >= actor.max_shield: return
	actor.shield += 1
	_credited_kills[target.get_instance_id()] = true
	_shield_restored[room] = int(_shield_restored.get(room, 0)) + 1
	actor.shield_changed.emit(actor.shield, actor.max_shield)
	feedback.emit("稳固阵地 · 护盾+1")

func complete_combat_room(room_key: String) -> void:
	if actor.is_dead() or _rewarded_rooms.has(room_key): return
	_rewarded_rooms[room_key] = true
	if actor.character_id == "astra":
		actor.restore_energy(5.0)

func get_cooldown_remaining() -> float:
	return cooldown_remaining

func get_cooldown_duration() -> float:
	return CATALOG.definition(actor.character_id).cooldown

func get_configuration() -> Dictionary:
	return CATALOG.ability_definition(actor.character_id)
