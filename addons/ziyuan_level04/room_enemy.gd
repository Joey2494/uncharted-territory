extends CharacterBody3D
signal hp_changed(current: int, maximum: int)
signal damage_received(amount: int)
signal died
signal enemy_died(enemy: Node3D)
signal reward_requested(source_id: String, coins: int)
signal attack_started(enemy_id: String, mode: int)
signal attack_resolved(enemy_id: String, mode: int)
signal status_requested(target: Node3D, status_id: String, duration: float, strength: float)
signal decoy_spawned(decoy: Node3D)
const Catalog = preload("room_catalog.gd")
const Visual = preload("room_visual.gd")
const FX = preload("effects.gd")
const Hazard = preload("room_hazard.gd")
const Bolt = preload("spore_projectile.gd")
const BirdHitbox = preload("raven_hitbox.gd")
@export_enum("dawn_shade", "dawn_echo", "sun_puppet", "iron_thistle", "raven_roost") var enemy_id := "dawn_shade"
@export var target_path := NodePath("../Player")
@export var start_active := false
@export var reward_source_id := ""
@export var arena_center := Vector3.ZERO
@export var arena_size := Vector2(26, 22)
var definition: Dictionary
var hp := 1
var max_hp := 1
var _enabled := false
var _dead := false
var _target: Node3D
var _visual: Node3D
var _clock := 0.0
var _attack_cd := 1.5
var _split_cd := 0.0
var _control := 0.0
var _slow := 0.0
var _contact_cd := 0.0
var _shared_hit_cd := 0.0
var _cycle := 0
var _echo_life := 6.0
var _owner_ref: WeakRef
var _echoes: Array[WeakRef] = []
var _bird_boxes: Array[Node3D] = []
var _dive_hits: Dictionary = {}
var _dive_target := Vector3.ZERO
var _dive_origin := Vector3.ZERO
var _dive_age := -1.0
var _flash: Node
func _ready() -> void:
	definition = Catalog.definition(enemy_id)
	max_hp = definition.hp
	hp = max_hp
	collision_layer = 4
	# 曦影和群鸦不挡玩家身体，但仍可被现有近战与弹丸命中。
	collision_mask = 1 if enemy_id in ["dawn_shade", "dawn_echo", "raven_roost"] else 3
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.7 if enemy_id == "iron_thistle" else 0.45
	capsule.height = 2.2
	shape.position.y = 1.1
	shape.shape = capsule
	add_child(shape)
	_visual = get_node_or_null("Visuals")
	if _visual == null:
		_visual = Visual.new()
		_visual.enemy_id = enemy_id
		add_child(_visual)
	_visual.build(enemy_id)
	# 曦影不挂血条或闪白，以免标记本体；其余敌人可由 HUD 消费 hp_changed。
	if enemy_id not in ["dawn_shade", "dawn_echo"]:
		_flash = preload("res://scenes/ui/hit_flash_3d.gd").new()
		_flash.visual_root = NodePath("../Visuals")
		_visual.name = "Visuals"
		add_child(_flash)
	if _target == null: _target = get_node_or_null(target_path)
	if enemy_id in ["dawn_shade", "dawn_echo"] and _target is PhysicsBody3D:
		# 虚影穿过玩家身体；形状仍保留给玩家攻击查询使用。
		add_collision_exception_with(_target)
		_target.add_collision_exception_with(self)
	if reward_source_id.is_empty(): reward_source_id = "l4:room:" + str(get_instance_id())
	add_to_group("l4_enemies")
	add_to_group("camera_targets")
	if enemy_id == "raven_roost":
		# 根节点不占一只鸟的受击判定，七只鸟各自转发到共享生命。
		collision_layer = 0
		for i in 7:
			var proxy := BirdHitbox.new()
			add_child(proxy)
			proxy.setup(self)
			_bird_boxes.append(proxy)
	set_encounter_active(start_active)
func is_boss() -> bool: return false
func is_dead() -> bool: return _dead
func is_decoy() -> bool: return enemy_id == "dawn_echo"
func is_required_enemy() -> bool: return not is_decoy()
func is_encounter_active() -> bool: return _enabled and not _dead and can_process()
func bind_target(target: Node3D) -> bool:
	if not is_instance_valid(target) or not target.has_method("take_damage") or not target.has_method("is_dead"): return false
	_target = target
	return true
func set_encounter_active(active: bool) -> void:
	if _dead: return
	_enabled = active
	if not active:
		_clear_owned()
		_dive_age = -1
		_attack_cd = 1.5
	process_mode = Node.PROCESS_MODE_PAUSABLE if active else Node.PROCESS_MODE_DISABLED
func can_see(at: Vector3) -> bool:
	var start := global_position + Vector3.UP
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start, Vector3(at.x, start.y, at.z), 1, [get_rid()])).is_empty()
func _clamp(at: Vector3) -> Vector3:
	var half := arena_size * 0.5 - Vector2.ONE * 1.5
	return Vector3(clampf(at.x, arena_center.x - half.x, arena_center.x + half.x), arena_center.y + 0.05, clampf(at.z, arena_center.z - half.y, arena_center.z + half.y))
func _physics_process(delta: float) -> void:
	if not is_encounter_active(): return
	if not is_instance_valid(_target) or _target.is_dead():
		_clear_owned()
		return
	_clock += delta
	_split_cd = maxf(0, _split_cd - delta)
	_shared_hit_cd = maxf(0, _shared_hit_cd - delta)
	_contact_cd = maxf(0, _contact_cd - delta)
	_control = maxf(0, _control - delta)
	_slow = maxf(0, _slow - delta)
	if is_decoy():
		_echo_life -= delta
		var owner_actor = _owner_ref.get_ref() if _owner_ref else null
		if _echo_life <= 0 or not is_instance_valid(owner_actor) or owner_actor.is_dead():
			_die(false)
			return
	var offset := _target.global_position - global_position
	offset.y = 0
	var direction := offset.normalized()
	velocity = Vector3.ZERO
	if _control <= 0:
		var speed: float = definition.speed * (0.6 if _slow > 0 else 1)
		var desired := direction
		if enemy_id in ["dawn_shade", "dawn_echo"]:
			desired = direction.rotated(Vector3.UP, 1.2) if offset.length() < 6 else direction
		elif enemy_id == "raven_roost": desired = direction.rotated(Vector3.UP, 1.1) if offset.length() < 5 else direction
		velocity = desired * speed
		_attack_cd -= delta
		if _attack_cd <= 0 and not is_decoy(): perform_attack()
	if enemy_id not in ["dawn_shade", "dawn_echo", "raven_roost"]:
		velocity.y = -1
	move_and_slide()
	global_position = _clamp(global_position)
	if enemy_id != "raven_roost" and direction.length() > 0.01: _visual.rotation.y = atan2(-direction.x, -direction.z)
	_visual.pose(0, 0, velocity.length(), delta)
	if enemy_id == "raven_roost": _update_flock(delta)
	elif enemy_id in ["sun_puppet", "dawn_shade"] and offset.length() < 1.3 and _contact_cd <= 0 and can_see(_target.global_position):
		_contact_cd = 1.2
		_hurt_player(global_position)
func perform_attack() -> bool:
	if not is_encounter_active() or not is_instance_valid(_target) or _target.is_dead() or _control > 0: return false
	_attack_cd = definition.period
	_cycle += 1
	attack_started.emit(enemy_id, _cycle % 2)
	match enemy_id:
		"dawn_shade":
			if global_position.distance_to(_target.global_position) < 7 and can_see(_target.global_position):
				# 只是实际闪光，不以锁定线或地面图形预告。
				FX.burst(get_parent(), global_position + Vector3.UP * 1.8, Color("fbe8b6"), 0.6)
				status_requested.emit(_target, "dawn_blind", 0.85, 0.48)
				if _target.has_method("apply_dawn_blind"): _target.apply_dawn_blind(0.85, 0.48)
		"sun_puppet": _spawn_hazard("heat", global_position)
		"iron_thistle":
			if _cycle % 2 == 1: _fire_thorns()
			else:
				for i in 6:
					var dir := Vector3(sin(i * TAU / 6), 0, cos(i * TAU / 6))
					_spawn_hazard("thorns", _clamp(global_position + dir * 2.0))
		"raven_roost":
			_dive_origin = global_position
			_dive_target = _clamp(_target.global_position)
			_dive_age = 0
			_dive_hits.clear()
	if enemy_id != "raven_roost": attack_resolved.emit(enemy_id, _cycle % 2)
	return true
func _spawn_hazard(kind: String, at: Vector3) -> void:
	var hazard := Hazard.new()
	get_parent().add_child(hazard)
	hazard.launch(self, _target, kind, at)
func _fire_thorns() -> void:
	var dir := _target.global_position - global_position
	dir.y = 0
	if not can_see(_target.global_position): return
	for i in 7:
		var bolt := Bolt.new()
		get_parent().add_child(bolt)
		bolt.global_position = global_position + Vector3.UP
		bolt.speed = 7.0
		bolt.launch(self, _target, dir.normalized().rotated(Vector3.UP, (i - 3) * 0.19), 1)
		# 用白亮的细针实体替换种子球体。
		var seed := bolt.get_child(1) as MeshInstance3D
		var needle := CylinderMesh.new()
		needle.top_radius = 0
		needle.bottom_radius = 0.05
		needle.height = 0.6
		needle.material = FX.mat(Color("eff3d4"), true)
		seed.mesh = needle
		seed.rotation.x = PI * 0.5
func _update_flock(delta: float) -> void:
	if _dive_age >= 0: _dive_age += delta
	for i in 7:
		var a := i * TAU / 7 + _clock * 0.35
		var orbit := global_position + Vector3(sin(a) * 2.3, 0, cos(a) * 2.3)
		var at := orbit
		if _dive_age >= 0:
			if _cycle % 2 == 1:
				# 四散后逐只穿过锁定点，每只起飞错开 0.12 秒。
				var t := clampf((_dive_age - i * 0.12) / 0.7, 0, 1)
				var start := _dive_origin + Vector3(sin(a) * 3.4, 0, cos(a) * 3.4)
				var end := _dive_target + (_dive_target - start).normalized() * 2
				at = start.lerp(end, t) if t < 1 else orbit
			else:
				# 鸟群从开始即聚拢并前进，聚拢是本次攻击的实际运动。
				var t := clampf(_dive_age / 0.9, 0, 1)
				at = _dive_origin.lerp(_dive_target, t) + Vector3(sin(a) * 0.45, 0, cos(a) * 0.45)
		at = _clamp(at)
		var bird: Node3D = _visual.birds[i]
		bird.global_position = at + Vector3.UP * (1.0 + sin(_clock * 3 + i) * 0.15)
		var proxy: Node3D = _bird_boxes[i]
		var previous := proxy.global_position
		proxy.global_position = at
		var nearest := Geometry3D.get_closest_point_to_segment(_target.global_position, previous, at)
		if _dive_age >= 0 and _control <= 0 and not _dive_hits.has(i) and nearest.distance_to(_target.global_position) < 0.8 and can_see(at) and can_see(_target.global_position):
			_dive_hits[i] = true
			_hurt_player(at)
	if _dive_age > 1.7:
		_dive_age = -1
		attack_resolved.emit(enemy_id, _cycle % 2)
func _hurt_player(at: Vector3) -> void:
	if _target.has_method("take_direct_damage"): _target.take_direct_damage(definition.damage, at)
	else: _target.take_damage(definition.damage)
func take_direct_damage(amount: int, _at: Vector3) -> bool: return take_damage(amount)
func take_damage(amount: int) -> bool:
	if not is_encounter_active() or amount <= 0: return false
	# 一个近战扇面碰到多只乌鸦时只能扣一次整群生命。
	if enemy_id == "raven_roost" and _shared_hit_cd > 0: return false
	_shared_hit_cd = 0.15
	var applied := mini(hp, amount)
	hp -= applied
	hp_changed.emit(hp, max_hp)
	damage_received.emit(applied)
	if is_instance_valid(_flash): _flash.flash()
	if hp <= 0: _die(not is_decoy())
	elif enemy_id == "dawn_shade" and _split_cd <= 0: split_mirrors()
	return true
func split_mirrors() -> void:
	_echoes = _echoes.filter(func(r: WeakRef) -> bool: return is_instance_valid(r.get_ref()) and not r.get_ref().is_dead())
	if not is_encounter_active() or _echoes.size() > 0: return
	_split_cd = 2.5
	var base := global_position
	# 本体与两假身使用相同外观，并同时换位；用世界碰撞测试拒绝穿墙。
	var slots: Array[Vector3] = []
	for i in 3:
		var candidate := _clamp(base + Vector3(sin(_clock + i * TAU / 3), 0, cos(_clock + i * TAU / 3)) * 1.7)
		if can_see(candidate): slots.append(candidate)
	if slots.size() < 3: return
	global_position = slots[(_cycle + int(_clock * 10)) % 3]
	for at in slots:
		if at.distance_to(global_position) < 0.1: continue
		var echo = get_script().new()
		echo.enemy_id = "dawn_echo"
		echo.bind_target(_target)
		echo.arena_center = arena_center
		echo.arena_size = arena_size
		echo._owner_ref = weakref(self)
		get_parent().add_child(echo)
		echo.global_position = at
		echo.set_encounter_active(true)
		_echoes.append(weakref(echo))
		decoy_spawned.emit(echo)
func apply_control(duration: float) -> void:
	if is_encounter_active(): _control = maxf(_control, minf(duration, 2))
func apply_slow(duration: float) -> void:
	if is_encounter_active(): _slow = maxf(_slow, minf(duration, 4))
func _clear_owned() -> void:
	for ref in _echoes:
		var echo = ref.get_ref()
		if is_instance_valid(echo): echo._die(false)
	_echoes.clear()
	if not is_inside_tree(): return
	for hazard in get_tree().get_nodes_in_group("l4_hazards"):
		var source = hazard.get("_source")
		if source != null and source.get_ref() == self: hazard.queue_free()
func _die(reward: bool) -> void:
	if _dead: return
	_dead = true
	_enabled = false
	_clear_owned()
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	for proxy in _bird_boxes: proxy.set_deferred("collision_layer", 0)
	set_physics_process(false)
	if reward: reward_requested.emit(reward_source_id, definition.gold)
	enemy_died.emit(self)
	died.emit()
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE * 0.01, 0.2)
	tween.tween_callback(queue_free)
