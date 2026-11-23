extends Node3D
## 房间适配器。只依赖房间 spawn point 和玩家公开伤害方法，不接管地图或 HUD。
signal enemy_spawned(enemy: Node3D)
signal enemy_died(enemy: Node3D)
signal reward_requested(source_id: String, coins: int)
const Factory = preload("factory.gd")
var boss: Node3D
var guards: Array[Node3D] = []
var _generation := 0
var _player: Node3D

func spawn_for_room(room: Node3D, player: Node3D, source_id: String, center: Vector3, size := Vector2(26, 22)) -> Node3D:
	## 调用后仍休眠，由宿主在封门完成后调用 set_encounter_active(true)。
	if not is_instance_valid(room) or not room.has_method("get_enemy_spawn_points"): return null
	if not is_instance_valid(player) or not player.has_method("take_damage") or not player.has_method("is_dead"): return null
	var points: Array = room.get_enemy_spawn_points()
	if points.is_empty() or not points[0] is Marker3D or source_id.is_empty(): return null
	clear_encounter()
	_player = player
	boss = Factory.create("witch", player)
	boss.reward_source_id = source_id
	boss.arena_center = center
	boss.arena_size = size
	add_child(boss)
	boss.global_position = points[0].global_position
	boss.summon_requested.connect(func(kind: String, at: Vector3) -> void:
		_spawn_guard.call_deferred(_generation, kind, at))
	boss.minions_dissolved.connect(_dissolve_guards)
	boss.enemy_died.connect(func(enemy: Node3D) -> void: enemy_died.emit(enemy))
	boss.reward_requested.connect(func(id: String, coins: int) -> void: reward_requested.emit(id, coins))
	enemy_spawned.emit(boss)
	return boss

func _spawn_guard(generation: int, kind: String, at: Vector3) -> void:
	if generation != _generation or not is_instance_valid(boss) or not boss.is_encounter_active(): return
	if not is_instance_valid(_player) or _player.is_dead(): return
	var guard := Factory.create(kind, _player)
	if guard == null: return
	add_child(guard)
	guard.global_position = at
	guard.set_encounter_active(true)
	guards.append(guard)
	boss.register_minion(guard)
	enemy_spawned.emit(guard)

func set_encounter_active(active: bool) -> void:
	if is_instance_valid(boss): boss.set_encounter_active(active)
	if not active:
		_generation += 1
		_dissolve_guards()

func _dissolve_guards() -> void:
	for guard in guards:
		if is_instance_valid(guard):
			guard.set_encounter_active(false)
			guard.queue_free()
	guards.clear()

func clear_encounter() -> void:
	_generation += 1
	_dissolve_guards()
	if is_instance_valid(boss):
		boss.set_encounter_active(false)
		boss.queue_free()
	boss = null
