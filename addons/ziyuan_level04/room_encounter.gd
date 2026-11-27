extends Node3D
## 普通房遭遇适配器：只有四种正式敌人计入清场，曦影假身与乌鸦子体不计。
signal enemy_spawned(enemy: Node3D)
signal enemy_died(enemy: Node3D)
signal room_cleared(room_index: int)
signal reward_requested(source_id: String, coins: int)
signal status_requested(target: Node3D, status_id: String, duration: float, strength: float)
const Factory = preload("factory.gd")
const Catalog = preload("room_catalog.gd")
var actors: Array[Node3D] = []
var room_index := 0
var _active := false
var _cleared := false
var _generation := 0
func spawn_for_room(room: Node3D, player: Node3D, index: int, source_prefix: String, center: Vector3, size := Vector2(26, 22)) -> bool:
	if not is_instance_valid(room) or not room.has_method("get_enemy_spawn_points") or source_prefix.is_empty(): return false
	var points: Array = room.get_enemy_spawn_points()
	if points.is_empty(): return false
	for point in points:
		if not point is Marker3D: return false
	var positions: Array[Vector3] = []
	for point in points: positions.append(point.global_position)
	return spawn_at_positions(player, index, source_prefix, positions, center, size)
func spawn_at_positions(player: Node3D, index: int, source_prefix: String, positions: Array[Vector3], center: Vector3, size := Vector2(26, 22)) -> bool:
	if not is_instance_valid(player) or not player.has_method("take_damage") or not player.has_method("is_dead") or index < 0 or index >= 4 or positions.is_empty() or source_prefix.is_empty(): return false
	clear_encounter()
	room_index = index
	_cleared = false
	var generation := _generation
	for i in positions.size():
		var actor := Factory.create(Catalog.ROOMS[index].id, player)
		actor.reward_source_id = source_prefix + ":" + str(i)
		actor.arena_center = center
		actor.arena_size = size
		add_child(actor)
		actor.global_position = positions[i]
		actor._attack_cd = 1.5 + i * 0.35
		actors.append(actor)
		actor.enemy_died.connect(func(enemy: Node3D) -> void:
			if generation != _generation: return
			enemy_died.emit(enemy)
			_check_cleared.call_deferred(generation))
		actor.reward_requested.connect(func(id: String, coins: int) -> void:
			if generation == _generation: reward_requested.emit(id, coins))
		actor.status_requested.connect(func(target: Node3D, id: String, duration: float, strength: float) -> void:
			if generation == _generation: status_requested.emit(target, id, duration, strength))
		actor.decoy_spawned.connect(func(echo: Node3D) -> void:
			if generation == _generation: enemy_spawned.emit(echo))
		enemy_spawned.emit(actor)
	return true
func set_encounter_active(active: bool) -> void:
	_active = active
	for actor in actors:
		if is_instance_valid(actor): actor.set_encounter_active(active)
func living_count() -> int:
	var count := 0
	for actor in actors:
		if is_instance_valid(actor) and not actor.is_dead(): count += 1
	return count
func _check_cleared(generation: int) -> void:
	if generation != _generation or _cleared or not _active or living_count() > 0: return
	_cleared = true
	_active = false
	room_cleared.emit(room_index)
func clear_encounter() -> void:
	_generation += 1
	_active = false
	for actor in actors:
		if is_instance_valid(actor):
			actor.set_encounter_active(false)
			actor.queue_free()
	actors.clear()
