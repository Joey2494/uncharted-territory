extends Node3D
## 档案室的双阶段机关。档位独立于玩家能量，奖励成功入包才结算。

signal feedback(message: String)
signal reward_claimed

enum State { CALIBRATION, ROUTING, OPENING, OPEN, CLAIMED }

const Gate = preload("res://scenes/dungeon/components/progression_gate.gd")
const Inventory = preload("res://scenes/items/item_inventory.gd")
const RUNES := [&"sun", &"moon", &"star"]
const TARGET_A := 1
const TARGET_B := 2
const FLOW := Color(0.35, 0.89, 0.84)
const NO_FLOW := Color(0.13, 0.25, 0.27)

@export var gate_path: NodePath
@export var reward_point_path: NodePath
@export var player_path: NodePath = NodePath("../Player")

@onready var _gate := get_node_or_null(gate_path) as Gate
@onready var _reward_point := get_node_or_null(reward_point_path) as Marker3D
@onready var _player := get_node_or_null(player_path) as CharacterBody3D
@onready var _reset: Timer = $Reset
@onready var _rune_controls := [$RuneSun, $RuneMoon, $RuneStar]
@onready var _flow_rows := [$FlowA, $FlowB]

var _state := State.CALIBRATION
var _rune_progress := 0
var _setting_a := 0
var _setting_b := 0
var _reset_pending := false
var _active := false
var _stopped := false
var _claiming := false
var _flow_material: StandardMaterial3D
var _dark_material: StandardMaterial3D

func _ready() -> void:
	_flow_material = _make_flow_material(FLOW)
	_dark_material = _make_flow_material(NO_FLOW)
	_reset.timeout.connect(_reset_calibration)
	if _gate != null:
		_gate.opened.connect(_on_gate_opened)
	if _reward_point != null:
		$Reward.global_position = _reward_point.global_position
	_refresh_devices()

## 地图开始与结束时调用；终局废弃错误序列的定时重置。
func begin_run() -> void:
	_active = not _stopped and _gate != null and _reward_point != null and _player != null

func stop_run() -> void:
	_active = false
	_stopped = true
	_reset.stop()
	_reset_pending = false

func get_state() -> State:
	return _state

func get_rune_progress() -> int:
	return _rune_progress

func get_settings() -> Vector2i:
	return Vector2i(_setting_a, _setting_b)

func get_objective() -> String:
	match _state:
		State.CALIBRATION:
			if _reset_pending:
				return "顺序错误 · 正在重置符文"
			return "按碑文校准符文 · %d/3" % _rune_progress
		State.ROUTING:
			return "分流 A%d / B%d · 调至 A1 / B2 后确认" % [_setting_a, _setting_b]
		State.OPENING:
			return "奖励密室 · 门体正在升起"
		State.OPEN:
			return "密室已开放 · 领取攻击强化符文"
	return "支线完成 · 已领取攻击强化符文"

## 各设施仅在所属阶段启用，中央确认始终读取当前两个档位。
func is_control_available(id: StringName, player: CharacterBody3D) -> bool:
	if not _active or not can_process() or player != _player or player.is_dead():
		return false
	if id in RUNES:
		return _state == State.CALIBRATION and not _reset_pending
	if id in [&"a", &"b", &"confirm"]:
		return _state == State.ROUTING
	return id == &"reward" and _state == State.OPEN and not _claiming and is_instance_valid(_gate) and _gate.is_open()

func perform_control(id: StringName, player: CharacterBody3D) -> bool:
	if not is_control_available(id, player):
		return false
	if id in RUNES:
		_press_rune(id)
	elif id == &"a":
		_setting_a = (_setting_a + 1) % 3
	elif id == &"b":
		_setting_b = (_setting_b + 1) % 3
	elif id == &"confirm":
		_confirm_routing()
	else:
		return _claim_reward(player)
	_refresh_devices()
	return true

func _press_rune(id: StringName) -> void:
	if id != RUNES[_rune_progress]:
		_reset_pending = true
		_reset.start()
		feedback.emit("符文顺序错误 · 即将重置")
		return
	_rune_progress += 1
	if _rune_progress == RUNES.size():
		_state = State.ROUTING
		feedback.emit("校准完成 · 调整两路分流")

func _reset_calibration() -> void:
	if not _active or _state != State.CALIBRATION or not _reset_pending:
		return
	_rune_progress = 0
	_reset_pending = false
	_refresh_devices()

func _confirm_routing() -> void:
	if _setting_a != TARGET_A or _setting_b != TARGET_B:
		feedback.emit("流向未对齐 · 校准与档位已保留")
		return
	if not is_instance_valid(_gate):
		return
	_state = State.OPENING
	if not _gate.open_gate():
		_state = State.ROUTING

func _on_gate_opened(_id: StringName) -> void:
	if not _active or not can_process() or _state != State.OPENING or not _gate.is_open():
		return
	_state = State.OPEN
	_refresh_devices()
	feedback.emit("密室开启 · 北侧可通行")

## 背包会同步发信号。先占用本次领取权，再提交唯一一件奖励。
func _claim_reward(player: CharacterBody3D) -> bool:
	_claiming = true
	var inventory := player.get_node_or_null("ItemInventory") as Inventory
	var delivered := inventory != null and inventory.add_item(Inventory.ATTACK_RUNE)
	if delivered:
		_state = State.CLAIMED
		_refresh_devices()
		reward_claimed.emit()
	_claiming = false
	return delivered

func _make_flow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

func _refresh_devices() -> void:
	for i in _rune_controls.size():
		var control = _rune_controls[i]
		control.set_display(control.caption, i < _rune_progress and not _reset_pending)
	var routed := _state >= State.ROUTING
	$SwitchA.set_display("分流 A · %d / 目标 1" % _setting_a, routed and _setting_a == TARGET_A)
	$SwitchB.set_display("分流 B · %d / 目标 2" % _setting_b, routed and _setting_b == TARGET_B)
	$Confirm.set_display("确认流向", routed and _setting_a == TARGET_A and _setting_b == TARGET_B)
	for i in 3:
		_flow_rows[0].get_child(i).material_override = _flow_material if routed and i == _setting_a else _dark_material
		_flow_rows[1].get_child(i).material_override = _flow_material if routed and i == _setting_b else _dark_material
	$Status.text = get_objective()
	$Reward.visible = _state == State.OPEN
	$Reward.get_node("Base/CollisionShape3D").set_deferred("disabled", _state != State.OPEN)
	$Reward.set_display("奖励 · 攻击强化符文", _state == State.OPEN)
