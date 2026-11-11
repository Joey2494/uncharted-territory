extends Node
## 关卡房间进度：到达记录由地图管理；本组件只负责完成条件和敌人出生归属。
## 所有完成信号先写入终态再发出，防止监听方重入导致重复开门。
signal room_completed(room_id: StringName)
signal configuration_error(message: String)
enum RoomState { UNVISITED, ACTIVE, COMPLETE }
var _rooms: Dictionary = {}
var _enemy_owners: Dictionary = {}
var _configuration_locked := false
var _stopped := false
var last_error := ""

## 按前置顺序登记房间；前置只能引用已定义房间，从结构上排除循环依赖。
func define_room(room_id: StringName, prerequisites: Array = [], objective: StringName = &"arrival", minimum_enemies: int = 1) -> bool:
	if _configuration_locked or room_id == &"" or _rooms.has(room_id):
		return _invalid("房间ID重复、为空或配置已经封存：%s" % room_id)
	if objective not in [&"arrival", &"enemies"] or minimum_enemies < 1:
		return _invalid("房间目标或敌人下限无效：%s" % room_id)
	for prerequisite in prerequisites:
		if (not prerequisite is StringName and not prerequisite is String) or not _rooms.has(prerequisite):
			return _invalid("房间%s引用未定义的前置%s" % [room_id, prerequisite])
	_rooms[room_id] = {"state": RoomState.UNVISITED, "prerequisites": prerequisites.duplicate(),
		"objective": objective, "minimum": minimum_enemies, "enemies": {}, "sealed": false}
	return true

## 绑定实际敌人的无参数 died；实例ID只用作本局去重，绝不跨关存储。
func register_enemy(room_id: StringName, enemy: Node) -> bool:
	if _stopped or not _rooms.has(room_id) or not is_instance_valid(enemy): return false
	var room: Dictionary = _rooms[room_id]
	if room.objective != &"enemies" or room.sealed or not enemy.has_signal("died") or not enemy.has_method("is_dead"):
		return _invalid("房间敌人接口或登记时机无效：%s" % room_id)
	var id := enemy.get_instance_id()
	if _enemy_owners.has(id): return false
	_enemy_owners[id] = room_id
	room.enemies[id] = {"node": weakref(enemy), "dead": enemy.is_dead()}
	enemy.died.connect(_on_enemy_died.bind(room_id, id))
	return true

## 只有登记完且数量符合配置，清敌条件才生效；缺敌人的配置不能自动开门。
func seal_enemy_roster(room_id: StringName) -> bool:
	if _stopped or not _rooms.has(room_id): return false
	var room: Dictionary = _rooms[room_id]
	if room.objective != &"enemies" or room.sealed: return false
	if room.enemies.size() < room.minimum:
		return _invalid("战斗房%s的敌人数量小于配置下限" % room_id)
	room.sealed = true
	_try_complete(room_id)
	return true

## 玩家实际到达后激活；前置房间未完成、暂停或终局时拒绝推进。
func activate_room(room_id: StringName) -> bool:
	if not _can_advance() or not _rooms.has(room_id): return false
	var room: Dictionary = _rooms[room_id]
	for prerequisite in room.prerequisites:
		if not is_complete(prerequisite): return false
	_configuration_locked = true
	if room.state == RoomState.UNVISITED: room.state = RoomState.ACTIVE
	_try_complete(room_id)
	return true

func is_complete(room_id: StringName) -> bool:
	return get_room_state(room_id) == RoomState.COMPLETE

## 未定义ID返回-1，不把它当作未访问的有效房间。
func get_room_state(room_id: StringName) -> int:
	return _rooms[room_id].state if _rooms.has(room_id) else -1

func get_remaining_enemies(room_id: StringName) -> int:
	if not _rooms.has(room_id): return 0
	var count := 0
	for entry in _rooms[room_id].enemies.values():
		if not entry.dead: count += 1
	return count

## 本局死亡或结算后单向停止；重新开始必须创建新控制器，避免复用旧信号。
func stop_run() -> void:
	_stopped = true

func _can_advance() -> bool:
	return is_inside_tree() and can_process() and not _stopped

func _on_enemy_died(room_id: StringName, id: int) -> void:
	if not _can_advance(): return
	var entry: Dictionary = _rooms[room_id].enemies[id]
	var enemy: Node = entry.node.get_ref()
	if entry.dead or not is_instance_valid(enemy) or not enemy.is_dead(): return
	entry.dead = true
	_try_complete(room_id)

func _try_complete(room_id: StringName) -> void:
	if not _can_advance(): return
	var room: Dictionary = _rooms[room_id]
	if room.state != RoomState.ACTIVE: return
	var fulfilled: bool = room.objective == &"arrival"
	if room.objective == &"enemies":
		fulfilled = room.sealed and get_remaining_enemies(room_id) == 0
	if not fulfilled: return
	room.state = RoomState.COMPLETE
	room_completed.emit(room_id)

func _invalid(message: String) -> bool:
	last_error = message
	configuration_error.emit(message)
	return false
