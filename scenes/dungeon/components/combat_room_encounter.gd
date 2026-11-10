extends Node
## 战斗房的安全入场、敌人休眠和战斗锁，清敌结果由房间进度控制器裁定。

signal battle_started(room_id: StringName)
signal completed(room_id: StringName)

const ENTRY_INSET := 1.25
const CombatGate = preload("res://scenes/dungeon/components/progression_gate.gd")
const RoomProgress = preload("res://scenes/dungeon/components/room_progress_controller.gd")

var _player: CharacterBody3D
var _region: Node3D
var _controller: Node
var _room_id: StringName
var _gates: Array[CombatGate] = []
var _enemy_modes: Dictionary = {}
var _configured := false
var _active := false
var _completed := false
var _stopped := false

## 地图在定义好房间后调用一次。这里统一登记出生归属和封存清敌名单。
func configure(player: CharacterBody3D, region: Node3D, controller: Node, room_id: StringName, enemies: Array, gates: Array) -> bool:
	if _controller != null:
		return false
	_player = player
	_region = region
	_controller = controller
	_room_id = room_id
	var valid_enemies := not enemies.is_empty()
	for enemy in enemies:
		if not enemy is Node or not is_instance_valid(enemy) or _enemy_modes.has(enemy):
			valid_enemies = false
			continue
		_enemy_modes[enemy] = enemy.process_mode
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		if not enemy.is_node_ready() or not enemy.has_signal("died") or not enemy.has_method("is_dead"):
			valid_enemies = false
	if not valid_enemies or gates.is_empty() or not _configuration_ready():
		return false
	var required_gates: Array[CombatGate] = []
	for gate in gates:
		if not gate is CombatGate or not is_instance_valid(gate) or not gate.is_node_ready() or required_gates.has(gate):
			return false
		required_gates.append(gate)
	for enemy in enemies:
		if not _controller.register_enemy(_room_id, enemy):
			return false
	if not _controller.seal_enemy_roster(_room_id):
		return false
	_gates = required_gates
	_controller.room_completed.connect(_on_room_completed)
	_configured = true
	return true

func _configuration_ready() -> bool:
	return (is_instance_valid(_player) and _player.is_node_ready() and _player.has_method("is_dead")
		and is_instance_valid(_region) and _region.is_node_ready() and _region.has_method("get_world_bounds")
		and is_instance_valid(_controller) and _controller is RoomProgress and _controller.is_node_ready())

## 游戏开始后由地图每个物理帧调用。只有玩家完整入场且前置达成才激活一次。
func try_activate() -> bool:
	if not _configured or _stopped or _active or _completed or not can_process():
		return false
	if not is_instance_valid(_player) or not is_instance_valid(_region) or not is_instance_valid(_controller):
		return false
	if _player.is_dead() or not _region.is_visible_in_tree():
		return false
	var bounds: Rect2 = _region.get_world_bounds()
	var position := Vector2(_player.global_position.x, _player.global_position.z)
	if bounds.size.x <= 2.0 * ENTRY_INSET or bounds.size.y <= 2.0 * ENTRY_INSET:
		return false
	var safe_bounds := bounds.grow(-ENTRY_INSET)
	if position.x < safe_bounds.position.x or position.y < safe_bounds.position.y or position.x > safe_bounds.end.x or position.y > safe_bounds.end.y:
		return false
	# 缺门、终局冻结或锁已被其他房间占用时，必须让本房保持待机。
	for gate in _gates:
		if not is_instance_valid(gate) or not gate.can_combat_lock():
			return false
	if not _controller.activate_room(_room_id):
		return false
	# 激活可能同步报告完成（例如登记时敌人已死亡），此时绝不再闭锁或唤醒。
	if _completed or _stopped:
		return true
	_active = true
	for gate in _gates:
		gate.set_combat_locked(true)
	for enemy in _enemy_modes:
		if is_instance_valid(enemy) and not enemy.is_dead():
			enemy.process_mode = _enemy_modes[enemy]
	battle_started.emit(_room_id)
	return true

## 本局结束后冻结门体并停止存活敌人，忽略后续房间完成信号。
func stop() -> void:
	if _stopped:
		return
	_stopped = true
	for gate in _gates:
		if is_instance_valid(gate):
			gate.freeze_gate()
	for enemy in _enemy_modes:
		if is_instance_valid(enemy) and not enemy.is_dead():
			enemy.process_mode = Node.PROCESS_MODE_DISABLED

func _on_room_completed(room_id: StringName) -> void:
	if room_id != _room_id or _stopped or _completed:
		return
	_completed = true
	if _active:
		for gate in _gates:
			if is_instance_valid(gate):
				gate.set_combat_locked(false)
	completed.emit(room_id)
