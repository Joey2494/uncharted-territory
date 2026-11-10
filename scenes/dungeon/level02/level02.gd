extends Node3D
## 第二关顺序、房间归属与实际出口。地图几何、门和出生位置都在场景中编辑。

signal exit_reached
signal feedback(message: String)

const Encounter = preload("res://scenes/dungeon/components/combat_room_encounter.gd")
const Gate = preload("res://scenes/dungeon/components/progression_gate.gd")
const Progress = preload("res://scenes/dungeon/components/room_progress_controller.gd")
const ARRIVAL := &"l2_arrival"
const HUB := &"l2_hub"
const RELAY := &"l2_relay"
const ANTECHAMBER := &"l2_antechamber"
const BOSS := &"l2_boss"
const EXIT := &"l2_exit"
const ARCHIVE := &"l2_archive"
const VAULT := &"l2_vault"

@onready var player: CharacterBody3D = $Player
@onready var progress: Progress = $RoomProgress
@onready var boss: CharacterBody3D = $Boss
@onready var puzzle := $EnergyRelayPuzzle
@onready var _exit: Area3D = $ExitArea
@onready var _regions := $Regions.get_children()
@onready var _room_ids := {
	$Regions/Arrival: ARRIVAL, $Regions/Hub: HUB, $Regions/Relay: RELAY,
	$Regions/Antechamber: ANTECHAMBER, $Regions/Boss: BOSS, $Regions/Exit: EXIT,
	$Regions/Archive: ARCHIVE, $Regions/Vault: VAULT,
}
@onready var _gates := $Gates.get_children()

var relay_activated := false
var shortcut_unlocked := false
var _encounters: Dictionary = {}
var _visited: Dictionary = {}
var _configured := false
var _active := false
var _stopped := false
var _exit_recorded := false

func _ready() -> void:
	progress.room_completed.connect(_on_room_completed)
	_configured = progress.define_room(ARRIVAL)
	_configured = _configure(HUB, $Regions/Hub, ARRIVAL, [$Enemies/Hub1, $Enemies/Hub2],
		[$Gates/HubSouth, $Gates/HubEast, $Gates/HubWest, $Gates/HubNorth]) and _configured
	_configured = _configure(RELAY, $Regions/Relay, HUB, [$Enemies/Relay1, $Enemies/Relay2],
		[$Gates/RelayWest, $Gates/RelayNorth]) and _configured
	_configured = _configure(ANTECHAMBER, $Regions/Antechamber, RELAY,
		[$Enemies/Antechamber1, $Enemies/Antechamber2, $Enemies/Antechamber3],
		[$Gates/AntechamberSouth, $Gates/AntechamberNorth, $Gates/AntechamberWest]) and _configured
	_configured = _configure(BOSS, $Regions/Boss, ANTECHAMBER, [boss],
		[$Gates/BossSouth, $Gates/BossNorth]) and _configured
	if not _configured:
		push_error("第二关战斗配置无效")
	player.died.connect(stop_run)
	puzzle.feedback.connect(func(message: String) -> void: feedback.emit(message))
	$Camera3D.set_safe_frame(Rect2(0.13, 0.16, 0.74, 0.67))
	$Camera3D.reset_follow()
	_refresh_controls()
	process_mode = Node.PROCESS_MODE_DISABLED

## 正常进入必须先封存敌人名单，避免空名单直接开门。
func _configure(id: StringName, region: Node3D, previous: StringName, enemies: Array, gates: Array) -> bool:
	var encounter := Encounter.new()
	encounter.name = String(id)
	add_child(encounter)
	_encounters[id] = encounter
	return progress.define_room(id, [previous], &"enemies", enemies.size()) and encounter.configure(player, region, progress, id, enemies, gates)

## 从菜单启动这一局。终局只能通过重新实例化场景开启新一局。
func begin_run() -> bool:
	if not _configured or _active or _stopped or get_tree().paused or player.is_dead():
		return false
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if not progress.activate_room(ARRIVAL):
		process_mode = Node.PROCESS_MODE_DISABLED
		return false
	_active = true
	_visited[ARRIVAL] = true
	puzzle.begin_run()
	return true

## 先废弃机关与门的异步动作，再冻结世界；死亡后清敌和开门都不再推进。
func stop_run() -> void:
	if _stopped:
		return
	_stopped = true
	_active = false
	puzzle.stop_run()
	progress.stop_run()
	for encounter in _encounters.values():
		encounter.stop()
	for gate in _gates:
		if is_instance_valid(gate):
			gate.freeze_gate()
	process_mode = Node.PROCESS_MODE_DISABLED

func is_run_active() -> bool:
	return _active

func get_region_at(point: Vector3) -> Node3D:
	for region in _regions:
		if region.contains_point(point):
			return region
	return null

func get_current_room_id() -> StringName:
	return _room_ids.get(get_region_at(player.global_position), &"")

func get_room_count() -> int:
	return _room_ids.size()

func get_visited_count() -> int:
	return _visited.size()

func is_room_complete(id: StringName) -> bool:
	return progress.is_complete(id)

func is_camera_target_relevant(actor: Node3D, target: Node3D) -> bool:
	return actor.can_process() and get_region_at(actor.global_position) == get_region_at(target.global_position)

func _physics_process(_delta: float) -> void:
	if not _active or player.is_dead():
		return
	var id := get_current_room_id()
	if id != &"":
		_visited[id] = true
	if _encounters.has(id) and (id not in [ANTECHAMBER, BOSS] or relay_activated):
		_encounters[id].try_activate()
	# 真实物理重叠与门开态同时成立才结算；抢先触发或重复进入无效。
	if not _exit_recorded and progress.is_complete(BOSS) and $Gates/BossNorth.is_open() and _exit.overlaps_body(player):
		_exit_recorded = true
		stop_run()
		exit_reached.emit()

func _on_room_completed(id: StringName) -> void:
	match id:
		ARRIVAL:
			$Gates/Arrival.open_gate()
		HUB:
			$Gates/HubEast.open_gate()
		ANTECHAMBER:
			$Gates/AntechamberNorth.open_gate()
		BOSS:
			$Gates/BossNorth.open_gate()
	_refresh_controls()

## 导能需要 C 清敌，回环需要 D 清敌；两个按钮只认玩家本人。
func is_control_available(id: StringName, actor: CharacterBody3D) -> bool:
	if not _active or not can_process() or actor != player or actor.is_dead():
		return false
	if id == &"relay":
		return not relay_activated and progress.is_complete(RELAY)
	return id == &"shortcut" and not shortcut_unlocked and progress.is_complete(ANTECHAMBER)

func perform_control(id: StringName, actor: CharacterBody3D) -> bool:
	if not is_control_available(id, actor):
		return false
	if id == &"relay":
		if not $Gates/RelayNorth.open_gate():
			return false
		relay_activated = true
		feedback.emit("导能成功 · 前厅通道开启")
	else:
		var hub_gate: Gate = $Gates/HubNorth
		var antechamber_gate: Gate = $Gates/AntechamberWest
		if not hub_gate.can_combat_lock() or not antechamber_gate.can_combat_lock():
			return false
		if not antechamber_gate.open_gate() or not hub_gate.open_gate():
			return false
		shortcut_unlocked = true
		feedback.emit("回环开启 · 中庭与前厅现在双向连通")
	_refresh_controls()
	return true

func _refresh_controls() -> void:
	var relay_status := "清敌后可用"
	if relay_activated:
		relay_status = "已启动"
	elif progress.is_complete(RELAY):
		relay_status = "E 启动"
	$Devices/Relay.set_display("导能核心 · " + relay_status, relay_activated or progress.is_complete(RELAY))
	var shortcut_status := "清敌后可用"
	if shortcut_unlocked:
		shortcut_status = "已开启"
	elif progress.is_complete(ANTECHAMBER):
		shortcut_status = "E 开启"
	$Devices/Shortcut.set_display("回环 · " + shortcut_status, shortcut_unlocked or progress.is_complete(ANTECHAMBER))

## 为预览提供玩家所在房间的具体动作，走廊沿地面引导线前进。
func get_objective() -> String:
	var id := get_current_room_id()
	if id == ARCHIVE or id == VAULT:
		return puzzle.get_objective()
	if _encounters.has(id) and progress.get_room_state(id) == Progress.RoomState.ACTIVE:
		return "消灭剩余守卫 · %d" % progress.get_remaining_enemies(id)
	match id:
		ARRIVAL:
			return "拾取药剂 · 向北抵达中庭"
		HUB:
			return "清敌后向东继续 · 西侧是可选支线"
		RELAY:
			return "向北进入共鸣前厅" if relay_activated else "清敌后按 E 启动导能核心"
		ANTECHAMBER:
			return "向北进入大厅 · 西侧可开启回环"
		BOSS:
			return "沿北侧通道前往出口" if progress.is_complete(BOSS) else "击败遗迹守门者"
		EXIT:
			return "进入出口区域完成探索"
	return "金线：主线 · 青线：支线 · 灰绿线：回环"
