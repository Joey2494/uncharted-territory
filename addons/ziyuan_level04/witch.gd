extends CharacterBody3D
## 第四关首领 袍冠女巫 原型。设计来源：玩法详细设计提案 §12.2（Boss 共同规则）
## 与 §12.4（孢冠女巫条目）。四式招式：三点孢弹、脉冲种子、孢子守卫、藤蔓横扫；
## 二阶段首次固定藤蔓横扫；毒池上限 3；硬控转架势，100 架势触发 2 秒破绽。
## 接口契约与第三关敌人模块一致（bind_target / set_encounter_active / 伤害 /
## hp_changed / died / reward_requested / summon_requested），新增 register_minion
## 与 minions_dissolved 处理孢子守卫生命周期。完整签名见 INTEGRATION.md。
signal hp_changed(current: int, maximum: int)
signal damage_received(amount: int)
signal died
signal enemy_died(enemy: Node3D)
signal battle_started
signal state_changed(message: String)
signal attack_telegraphed(enemy_id: String, mode: int, duration: float)
signal attack_started(enemy_id: String, mode: int)
signal attack_resolved(enemy_id: String, mode: int)
signal reward_requested(source_id: String, coins: int)
signal summon_requested(enemy_id: String, position: Vector3)
signal minions_dissolved
const Catalog = preload("catalog.gd")
const FX = preload("effects.gd")
const Visual = preload("witch_model.gd")
const Mark = preload("spore_mark.gd")
const Bolt = preload("spore_projectile.gd")
const Vine = preload("vine_sweep.gd")
const Pool = preload("poison_pool.gd")
enum State { IDLE, CHASE, WINDUP, STRIKE, RECOVER, TRANSITION, DEAD }
enum Move { TRIPLE, PULSE, GUARD, VINE }
const PHASE1_ROTATION := [Move.TRIPLE, Move.PULSE, Move.GUARD, Move.VINE]
const PHASE2_ROTATION := [Move.VINE, Move.TRIPLE, Move.PULSE, Move.VINE, Move.PULSE]
@export var target_path := NodePath("../Player")
@export var start_active := false
@export var reward_source_id := ""
## 世界坐标；宿主可把整个战斗房放在任意位置。
@export var arena_center := Vector3.ZERO
@export var arena_size := Vector2(26, 22)
var enemy_id := "witch"
var definition: Dictionary
var max_hp := 52
var hp := 52
var boss_name := "袍冠女巫"
var phase := 1
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
var _mode: int = Move.TRIPLE
var _rotation_index := 0
var _strike_index := 0
var _slow := 0.0
var _stance := 0
var _stance_cd := 0.0
var _stance_break_used := false
var _broken := false
var _pending_transition := false
var _summon_batches := 0
var _mark_positions: Array[Vector3] = []
var _vine_position := 0.0
var _recovery_time := 1.0
var _pools: Array[WeakRef] = []
var _minions: Array[WeakRef] = []
var _flash: Node
var _health: Node3D
func _ready() -> void:
	definition = Catalog.definition(enemy_id)
	assert(not definition.is_empty(), "Unknown level04 enemy_id")
	max_hp = definition.hp
	hp = max_hp
	boss_name = definition.name
	collision_layer = 4
	collision_mask = 7 # World + player + guards: never walk through a summoned body.
	add_to_group("camera_targets")
	add_to_group("l4_enemies")
	set_meta("camera_radius", 2.2)
	set_meta("camera_height", 4.6)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.98 # Include the wide cloak hem, not only the narrow torso.
	capsule.height = 3.6
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
	_health = preload("res://scenes/ui/enemy_health_label_3d.tscn").instantiate()
	_health.name = "HealthLabel"
	_health.position.y = 4.35
	_health.elite = true
	add_child(_health)
	_health.bind_health_source(self, hp, max_hp)
	if _target == null: _target = get_node_or_null(target_path) as Node3D
	if reward_source_id.is_empty(): reward_source_id = "l4:" + str(get_instance_id())
	set_encounter_active(start_active)
func is_boss() -> bool: return true
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
	if not active:
		_clear_warning()
		_clear_hazards()
		state = State.IDLE
		_remaining = 0.0
	process_mode = Node.PROCESS_MODE_PAUSABLE if _enabled else Node.PROCESS_MODE_DISABLED
func register_minion(minion: Node) -> bool:
	## 宿主在响应 summon_requested 创建守卫后调用；首领据此判断是否跳过召唤位。
	if not is_instance_valid(minion): return false
	_minions.append(weakref(minion))
	return true

func find_minion_spawn(preferred: Vector3, reserved: Array[Vector3] = []) -> Dictionary:
	## Recheck at actual creation time: the player can move during windup/deferred spawn.
	## Empty result means there is no clear, supported slot; never force an overlapping spawn.
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.62
	capsule.height = 1.3
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 7
	var space := get_world_3d().direct_space_state
	for ring in 4:
		var count := 1 if ring == 0 else 12
		for i in count:
			var angle := TAU * float(i) / count
			var candidate := _clamp_to_arena(preferred + Vector3(sin(angle), 0, cos(angle)) * ring * 0.9)
			candidate.y = arena_center.y + 0.05
			if not _can_see(candidate): continue
			# Find the floor; reject unsupported ledges and the tops of map equipment.
			var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 1.4, candidate - Vector3.UP * 1.0, 1))
			if floor_hit.is_empty() or floor_hit.normal.y < 0.65 or absf(floor_hit.position.y - arena_center.y) > 0.35: continue
			candidate.y = floor_hit.position.y + 0.05
			var occupied := false
			for point in reserved:
				if Vector2(candidate.x - point.x, candidate.z - point.z).length() < 1.35:
					occupied = true
					break
			if occupied: continue
			# New bodies may not have reached the physics server yet in the same frame.
			for ref in _minions:
				var actor = ref.get_ref()
				if is_instance_valid(actor) and not actor.is_dead() and Vector2(candidate.x - actor.global_position.x, candidate.z - actor.global_position.z).length() < 1.35:
					occupied = true
					break
			if occupied: continue
			if is_instance_valid(_target) and Vector2(candidate.x - _target.global_position.x, candidate.z - _target.global_position.z).length() < 1.25: continue
			if Vector2(candidate.x - global_position.x, candidate.z - global_position.z).length() < 1.7: continue
			query.transform.origin = candidate + Vector3.UP * 0.7
			if not space.intersect_shape(query, 1).is_empty(): continue
			return {"position": candidate}
	return {}
func _clear_warning() -> void:
	if not is_instance_valid(_warning): return
	for child in _warning.get_children(): child.queue_free()
func _clear_hazards() -> void:
	if not is_inside_tree(): return
	for hazard in get_tree().get_nodes_in_group("l4_hazards"):
		if hazard.get("_source") != null and hazard._source.get_ref() == self:
			if hazard.has_method("dissolve"): hazard.dissolve()
			else: hazard.queue_free()
	_pools.clear()
func _live_target() -> bool:
	return is_instance_valid(_target) and not _target.is_dead()
func _can_see(point: Vector3) -> bool:
	var a := global_position + Vector3.UP
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, Vector3(point.x, a.y, point.z), 1, [get_rid()])).is_empty()
func _clamp_to_arena(at: Vector3) -> Vector3:
	var half := arena_size * 0.5 - Vector2.ONE * Catalog.ARENA.inset
	return Vector3(clampf(at.x, arena_center.x - half.x, arena_center.x + half.x), at.y, clampf(at.z, arena_center.z - half.y, arena_center.z + half.y))
func _physics_process(delta: float) -> void:
	if not _enabled or is_dead(): return
	velocity.x = 0
	velocity.z = 0
	velocity.y = 0 if is_on_floor() else velocity.y + get_gravity().y * delta
	_slow = maxf(0, _slow - delta)
	_stance_cd = maxf(0, _stance_cd - delta)
	if not _live_target():
		_clear_warning()
		_clear_hazards()
		state = State.IDLE
		return
	if state == State.WINDUP:
		_remaining = maxf(0, _remaining - delta)
		if _remaining <= 0: _begin_strike()
	elif state == State.STRIKE:
		_tick_strike(delta)
	elif state == State.TRANSITION:
		_remaining = maxf(0, _remaining - delta)
		if _remaining <= 0:
			state = State.CHASE
			state_changed.emit("二阶段")
	elif state == State.RECOVER:
		_remaining = maxf(0, _remaining - delta)
		if _remaining <= 0:
			state = State.CHASE
			_broken = false
	else:
		_pursue(delta)
	var progress := clampf(1.0 - _remaining / maxf(_duration, 0.01), 0, 1)
	_visual.pose(state, progress, Vector2(velocity.x, velocity.z).length(), delta, _strike_index)
	move_and_slide()
func _pursue(_delta: float) -> void:
	if _pending_transition:
		_begin_transition()
		return
	var offset := _target.global_position - global_position
	offset.y = 0
	var distance := offset.length()
	if not _aggro and distance < 18 and _can_see(_target.global_position):
		_aggro = true
		if not _battle:
			_battle = true
			battle_started.emit()
	if not _aggro:
		state = State.IDLE
		return
	_direction = offset.normalized() if distance > 0.01 else Vector3.FORWARD
	_visual.rotation.y = atan2(-_direction.x, -_direction.z)
	if distance <= definition.reach and _can_see(_target.global_position):
		begin_attack()
	else:
		state = State.CHASE
		var speed: float = definition.speed * (0.65 if _slow > 0 else 1.0)
		velocity.x = _direction.x * speed
		velocity.z = _direction.z * speed
func begin_attack(mode: int = -1) -> bool:
	## 按阶段轮转选择招式；守卫在场或已召唤满 3 批时，守卫位替换为脉冲种子。
	if not is_encounter_active() or not _live_target() or state in [State.WINDUP, State.STRIKE, State.RECOVER, State.TRANSITION]: return false
	if _pending_transition:
		_begin_transition()
		return true
	var rotation: Array = PHASE2_ROTATION if phase == 2 else PHASE1_ROTATION
	var pick: int = rotation[_rotation_index % rotation.size()] if mode < 0 else clampi(mode, 0, 3)
	_mode = pick
	_rotation_index += 1
	if _mode == Move.GUARD and (_living_minions() > 0 or _summon_batches >= Catalog.GUARD_BATCH_CAP):
		_mode = Move.PULSE
		state_changed.emit("守卫仍在或已达三批上限 · 改放脉冲种子")
	_strike_index = 0
	_start_cast()
	return true
func _living_minions() -> int:
	_minions = _minions.filter(func(r: WeakRef) -> bool:
		var m := r.get_ref()
		return is_instance_valid(m) and not m.is_dead())
	return _minions.size()
func _start_cast() -> void:
	# 抬杖蓄力后施法；不创建地面标记或范围轮廓。
	_clear_warning()
	var offset := _target.global_position - global_position
	offset.y = 0
	_direction = offset.normalized() if offset.length() > 0.01 else Vector3.FORWARD
	_visual.rotation.y = atan2(-_direction.x, -_direction.z)
	match _mode:
		Move.TRIPLE:
			_recovery_time = definition.recovery
		Move.PULSE:
			_recovery_time = definition.recovery
		Move.GUARD:
			_recovery_time = definition.recovery
			var side := _direction.rotated(Vector3.UP, PI * 0.5)
			_mark_positions.clear()
			for s in [-1.0, 1.0]:
				var at := _clamp_to_arena(global_position + side * s * 2.2 + _direction * 1.0)
				_mark_positions.append(at)
		Move.VINE:
			_recovery_time = definition.recovery + 0.2
			_vine_position = _clamp_to_arena(_target.global_position).x
	state = State.WINDUP
	_duration = maxf(0.65, definition.windup * (0.9 if phase == 2 else 1.0))
	if _mode == Move.VINE: _duration += 0.2
	_remaining = _duration
	attack_telegraphed.emit(enemy_id, _mode, _duration)
	state_changed.emit("抬杖蓄力")
func _begin_strike() -> void:
	state = State.STRIKE
	_clear_warning()
	match _mode:
		Move.TRIPLE:
			_duration = 1.6
		Move.PULSE:
			_duration = 0.25
		Move.GUARD:
			_duration = 0.3
		Move.VINE:
			_duration = 1.8
			_spawn_vine()
	_remaining = _duration
	attack_started.emit(enemy_id, _mode)
	state_changed.emit(["三点孢弹", "脉冲种子", "孢子守卫", "藤蔓横扫"][_mode])
	_tick_strike(0.0)
func _tick_strike(delta: float) -> void:
	_remaining = maxf(0, _remaining - delta)
	var elapsed := _duration - _remaining
	if _mode == Move.TRIPLE:
		# 真实秒数间隔；用索引保证零步长、低帧率或重复 tick 都不重复发射。
		while _strike_index < 3 and elapsed + 0.0001 >= _strike_index * 0.35:
			_strike_index += 1
			var at := _clamp_to_arena(_target.global_position)
			var mark := Mark.new()
			get_parent().add_child(mark)
			mark.launch(self, _target, at, 0.9)
	elif _mode == Move.PULSE and _strike_index == 0:
		_strike_index = 1
		for i in 8:
			var dir := Vector3.RIGHT.rotated(Vector3.UP, TAU * i / 8.0)
			var b := Bolt.new()
			get_parent().add_child(b)
			b.global_position = global_position + Vector3.UP * 1.4
			b.launch(self, _target, dir, 1)
		FX.burst(get_parent(), global_position + Vector3.UP * 1.4, Color("c8f08a"), 1.0)
	elif _mode == Move.GUARD and _strike_index == 0:
		_strike_index = 1
		var occupied: Array[Vector3] = []
		for at in _mark_positions:
			var slot := find_minion_spawn(at, occupied)
			if slot.is_empty(): continue
			occupied.append(slot.position)
			summon_requested.emit("spore_guard", slot.position)
		if not occupied.is_empty(): _summon_batches += 1
		else: state_changed.emit("附近空间不足 · 本次不召唤")
	if _remaining <= 0:
		_finish_move()
func _finish_move() -> void:
	attack_resolved.emit(enemy_id, _mode)
	if _pending_transition:
		_begin_transition()
		return
	state = State.RECOVER
	_remaining = _recovery_time
	_duration = _remaining
	state_changed.emit("收招破绽 可反击")
func _begin_transition() -> void:
	_pending_transition = false
	phase = 2
	_rotation_index = 0
	_stance = 0
	_stance_cd = 0.0
	_stance_break_used = false
	_broken = false
	state = State.TRANSITION
	_remaining = 0.8
	_duration = 0.8
	_clear_warning()
	_clear_hazards()
	state_changed.emit("阶段转换 · 袍冠女巫展露第二阶段")
func _spawn_pool(at: Vector3) -> void:
	# Airborne spores can hit the player's upper body. The residue belongs on
	# the floor, never at the collision height where it would cover characters.
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.1, at - Vector3.UP * 6.0, 1))
	if floor_hit.is_empty() or floor_hit.normal.y < 0.65 or absf(floor_hit.position.y - arena_center.y) > 0.35: return
	_prune_pools()
	var pool := Pool.new()
	get_parent().add_child(pool)
	pool.global_position = floor_hit.position + Vector3.UP * 0.03
	pool.launch(self, _target)
	_pools.append(weakref(pool))
	if _pools.size() > Catalog.POOL_CAP:
		var oldest = _pools.pop_front().get_ref()
		if is_instance_valid(oldest):
			oldest.dissolve(true)
			state_changed.emit("毒池已满 · 最旧一处消散")
func _prune_pools() -> void:
	_pools = _pools.filter(func(r: WeakRef) -> bool: return is_instance_valid(r.get_ref()))
func _spawn_vine() -> void:
	# 通道保护（§12.4 意图）：与条带重叠的毒池会封死横向穿行路线，先移除最新一处。
	for pool_ref in _pools.duplicate():
		var pool = pool_ref.get_ref()
		if is_instance_valid(pool) and pool.overlaps_band(_vine_position, 1.0):
			pool.dissolve(true)
			_pools.erase(pool_ref)
			state_changed.emit("藤蔓路径上的毒池已消散 · 保持移动")
			break
	var vine := Vine.new()
	get_parent().add_child(vine)
	vine.launch(self, _target, _vine_position)
func apply_control(duration: float) -> void:
	## Boss 免疫硬控：转换为架势伤害（§12.2）。每次请求 25，来源间隔至少 1 秒；
	## 满 100 触发 2 秒破绽，破绽只打断主招式，不取消已成立的伤害。
	if not is_encounter_active() or duration <= 0 or _stance_cd > 0: return
	_stance += 25
	_stance_cd = 1.0
	state_changed.emit("硬控化为架势 · %d/100" % _stance)
	if _stance >= 100 and not _stance_break_used:
		_stance_break_used = true
		_stance = 0
		_broken = true
		_clear_warning()
		state = State.RECOVER
		_remaining = 2.0
		_duration = 2.0
		attack_resolved.emit(enemy_id, _mode)
		state_changed.emit("架势崩溃 · 2 秒破绽 输出翻倍")
func apply_slow(duration: float) -> void:
	if is_encounter_active(): _slow = maxf(_slow, minf(duration, 4))
func take_direct_damage(amount: int, _source_position: Vector3) -> bool:
	return take_damage(amount)
func take_damage(amount: int) -> bool:
	if not is_node_ready() or not is_encounter_active() or amount <= 0 or state == State.TRANSITION: return false
	if not _battle:
		# 受击即视为开战，避免半血演示或远程先手时血条缺席。
		_battle = true
		battle_started.emit()
	var value := amount * 2 if state == State.RECOVER and _broken else amount
	var applied := mini(value, hp)
	hp -= applied
	if hp == 0:
		state = State.DEAD
		_enabled = false
	_flash.flash()
	hp_changed.emit(hp, max_hp)
	damage_received.emit(applied)
	if hp == 0:
		_clear_warning()
		_clear_hazards()
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
		set_physics_process(false)
		minions_dissolved.emit()
		reward_requested.emit(reward_source_id, definition.gold)
		enemy_died.emit(self)
		died.emit()
		var t := create_tween()
		t.tween_property(_visual, "rotation:z", PI * 0.5, 0.35)
		t.parallel().tween_property(_visual, "position:y", -0.5, 0.35)
		t.tween_interval(0.3)
		t.tween_callback(queue_free)
	elif hp <= max_hp / 2 and phase == 1 and not _pending_transition:
		_pending_transition = true
		state_changed.emit("生命低于半数")
	return true
