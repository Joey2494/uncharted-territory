extends Node3D
## 断流档案室。两枚能源在托架、手持和三个插槽间转移，检修手柄改变两条通路。

signal feedback(message: String)
signal reward_claimed

enum State { SUPPLY_OFF, READY, OPENING, OPEN, CLAIMED }

const Gate = preload("res://scenes/dungeon/components/progression_gate.gd")
const Inventory = preload("res://scenes/items/item_inventory.gd")
const RelayControl = preload("res://scenes/puzzles/energy_relay/relay_control.gd")
const SLOT_IDS := [&"bridge", &"a", &"b"]
const ARCHIVE_BOUNDS := Rect2(-8.0, -7.0, 16.0, 14.0)
const BRIDGE_SAFE_FRONT_X := -2.15
const RESET_RANGE := 1.8
const OFFLINE := "主供能中断 · 来自东侧回廊（C）"
const HINTS := [
	"看看对岸检修台旁折起的机械步道，留意它通向哪里。",
	"临时桥上的能源可以撤回。机械步道卡合后不需要供能。",
	"用一枚能源过桥，拉下检修手柄。走侧步道回来撤回能源，再填满两个接收器。",
]

@export var gate_path: NodePath
@export var reward_point_path: NodePath
@export var player_path: NodePath = NodePath("../Player")

@onready var _gate := get_node_or_null(gate_path) as Gate
@onready var _reward_point := get_node_or_null(reward_point_path) as Marker3D
@onready var _player := get_node_or_null(player_path) as CharacterBody3D
@onready var _slot_controls: Dictionary = {&"bridge": $BridgeSocket, &"a": $ReceiverA, &"b": $ReceiverB}

var _state := State.SUPPLY_OFF
var _active := false
var _stopped := false
var _cores: Dictionary = {&"rack": 2, &"carried": 0, &"bridge": 0, &"a": 0, &"b": 0}
var _maintenance_latched := false
var _reset_pending := false
var _hint_index := 0
var _reward_taken := false
var _claiming := false
var _vault_reset_lock := false
var _flow_material := _make_flow_material(Color(0.35, 0.89, 0.84))
var _dark_material := _make_flow_material(Color(0.21, 0.34, 0.36))

func _ready() -> void:
	if _gate != null:
		_gate.opened.connect(_on_gate_opened)
	if _reward_point != null:
		$Reward.global_position = _reward_point.global_position
	_refresh_devices()

func begin_run() -> void:
	_active = not _stopped and _gate != null and _reward_point != null and _player != null

func stop_run() -> void:
	_active = false
	_stopped = true
	_reset_pending = false

## C 的主供能成功后才允许分配能源，进入新地图实例时恢复断电。
func enable_supply() -> void:
	if not _active or _state != State.SUPPLY_OFF:
		return
	_state = State.READY
	_refresh_devices()

func get_state() -> State:
	return _state

func get_core_count(location: StringName) -> int:
	return _cores.get(location, 0)

func is_maintenance_connected() -> bool:
	return _maintenance_latched

func get_objective() -> String:
	match _state:
		State.SUPPLY_OFF:
			return OFFLINE
		State.OPENING:
			return "档案门 · 正在升起"
		State.OPEN:
			return "密室已开放 · 领取攻击强化符文"
		State.CLAIMED:
			return "支线完成 · 已领取攻击强化符文"
	var line_status := "接通" if _maintenance_latched else "断开"
	return "档案门 %d/2 · 检修线%s · 手持 %d" % [_cores[&"a"] + _cores[&"b"], line_status, _cores[&"carried"]]

func _physics_process(_delta: float) -> void:
	if not _active:
		return
	if _reset_pending and not _is_near_reset(_player):
		_reset_pending = false
		_refresh_devices()
	var local := to_local(_player.global_position)
	if _cores[&"carried"] > 0 and not ARCHIVE_BOUNDS.has_point(Vector2(local.x, local.z)):
		_transfer_cores(&"carried", &"rack", _cores[&"carried"])
		_refresh_devices()
		feedback.emit("手持能源已归还档案室托架")

## 所有设施仍由玩家背包按距离与视线选择。断电时可检查插槽。
func is_control_available(id: StringName, player: CharacterBody3D) -> bool:
	if not _active or not can_process() or player != _player or player.is_dead():
		return false
	match id:
		&"inspect", &"hints":
			return true
		&"reset":
			return _state != State.SUPPLY_OFF and not _claiming and _is_near_reset(player)
		&"reward":
			return _state == State.OPEN and not _claiming and _gate.is_open()
		&"rack", &"bridge", &"a", &"b", &"lever":
			return _state == State.SUPPLY_OFF or _state == State.READY
	return false

func perform_control(id: StringName, player: CharacterBody3D) -> bool:
	if not is_control_available(id, player):
		return false
	match id:
		&"inspect":
			feedback.emit("桥台一槽，档案门有两个接收器。能源留在槽内才供能，每枚都可取回。")
		&"hints":
			feedback.emit(HINTS[_hint_index])
			_hint_index = mini(_hint_index + 1, HINTS.size() - 1)
		&"reset":
			_confirm_reset()
		&"reward":
			return _claim_reward(player)
		_:
			if _state == State.SUPPLY_OFF:
				feedback.emit(OFFLINE)
			else:
				_use_device(id, player)
	_refresh_devices()
	return true

func _use_device(id: StringName, player: CharacterBody3D) -> void:
	if id == &"rack":
		if _cores[&"rack"] > 0:
			_transfer_cores(&"rack", &"carried", _cores[&"rack"])
			feedback.emit("取用能源 · 手持 %d 枚" % _cores[&"carried"])
		else:
			_transfer_cores(&"carried", &"rack", _cores[&"carried"])
			feedback.emit("托架存放 %d/2 · 可取回插槽里的能源" % _cores[&"rack"])
		return
	if id == &"lever":
		if not _maintenance_latched:
			_maintenance_latched = true
			feedback.emit("机械步道已卡合 · 检修线已接通")
		else:
			feedback.emit("机械卡榫已锁定 · 检修线保持接通")
		_try_open_vault()
		return
	_use_socket(id, player)
	_try_open_vault()

func _use_socket(id: StringName, player: CharacterBody3D) -> void:
	var control := _slot_controls[id] as RelayControl
	if _cores[id] == 1:
		if id == &"bridge" and not _bridge_can_retract(player):
			feedback.emit("请先离开桥面 · 在前台撤回临时供能")
			return
		_transfer_cores(id, &"carried", 1)
		feedback.emit("%s · 已撤回能源" % control.caption)
	elif _cores[&"carried"] > 0:
		_transfer_cores(&"carried", id, 1)
		if id == &"bridge":
			feedback.emit("临时桥已展开 · 占用一枚能源")
		else:
			feedback.emit(get_objective())
	else:
		feedback.emit("%s需要一枚能源 · 手持为空" % control.caption)

func _transfer_cores(from: StringName, to: StringName, count: int) -> void:
	_cores[from] -= count
	_cores[to] += count

func _bridge_can_retract(player: CharacterBody3D) -> bool:
	# 能源固定在设施或手持状态。玩家是桥上唯一可移动的实体。
	var local := to_local(player.global_position)
	return local.x >= BRIDGE_SAFE_FRONT_X

func _try_open_vault() -> void:
	if not _maintenance_latched or _cores[&"a"] == 0 or _cores[&"b"] == 0:
		return
	_state = State.OPENING
	var accepted := _gate.set_combat_locked(false) if _vault_reset_lock else _gate.open_gate()
	if not accepted:
		_state = State.READY
		return
	_vault_reset_lock = false
	feedback.emit("双接收器已供能 · 档案门开始升起")

func _on_gate_opened(_id: StringName) -> void:
	if not _active or not can_process() or _state != State.OPENING or not _gate.is_open():
		return
	_state = State.CLAIMED if _reward_taken else State.OPEN
	_refresh_devices()
	feedback.emit("档案门已开启 · 北侧通往密室")

func _is_near_reset(player: CharacterBody3D) -> bool:
	return player.global_position.distance_squared_to($ResetConsole.global_position) <= RESET_RANGE * RESET_RANGE

func _confirm_reset() -> void:
	if not _reset_pending:
		_reset_pending = true
		feedback.emit("再次按 E 确认复位 · 能源回托架，通路收起")
		return
	if _state in [State.OPENING, State.OPEN, State.CLAIMED]:
		# 独立重置锁复用门体碰撞和升降动画，主线进度与奖励记录继续保留。
		_vault_reset_lock = _gate.set_combat_locked(true)
	_cores = {&"rack": 2, &"carried": 0, &"bridge": 0, &"a": 0, &"b": 0}
	_maintenance_latched = false
	_reset_pending = false
	_hint_index = 0
	_state = State.READY
	feedback.emit("档案室已复位 · 两枚能源回到托架")

## 背包会同步发信号，先占用本次领取权；拒绝入包时仍可重试。
func _claim_reward(player: CharacterBody3D) -> bool:
	_claiming = true
	var inventory := player.get_node_or_null("ItemInventory") as Inventory
	var delivered := inventory != null and inventory.add_item(Inventory.ATTACK_RUNE)
	if delivered:
		_reward_taken = true
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
	$CoreRack.set_display("能源托架 · %d/2" % _cores[&"rack"], _cores[&"rack"] > 0)
	$CoreRack/Core1.visible = _cores[&"rack"] > 0
	$CoreRack/Core2.visible = _cores[&"rack"] == 2
	$Lever.set_display("检修手柄 · " + ("已卡合" if _maintenance_latched else "待操作"), _maintenance_latched)
	$ResetConsole.set_display("再次按 E 确认" if _reset_pending else "前台复位", _reset_pending)
	for id in SLOT_IDS:
		var control := _slot_controls[id] as RelayControl
		var filled: bool = _cores[id] == 1
		control.set_display("%s · %d/1" % [control.caption, _cores[id]], filled)
		control.get_node("Core").visible = filled
	var bridged: bool = _cores[&"bridge"] == 1
	_refresh_passage($PoweredPassage, bridged)
	_refresh_passage($MechanicalPassage, _maintenance_latched)
	$Circuit/Direct.material_override = _flow_material if _cores[&"a"] == 1 else _dark_material
	var repaired_flow := _flow_material if _maintenance_latched and _cores[&"b"] == 1 else _dark_material
	for wire in [$Circuit/ReceiverLead, $Circuit/MovableLink, $Circuit/GateLead]:
		wire.material_override = repaired_flow
	$Circuit/MovableLink.rotation_degrees.y = 0.0 if _maintenance_latched else 53.0
	$Circuit/Linkage.position.x = 0.0 if _maintenance_latched else -0.24
	$Circuit/WalkwayDrive.position.z = 0.0 if _maintenance_latched else -0.24
	$PassageLabels/BridgeState.text = "临时桥 · 展开" if bridged else "临时桥 · 收起"
	$PassageLabels/WalkwayState.text = "机械步道 · 卡合" if _maintenance_latched else "机械步道 · 折起"
	$Circuit/LineState.text = "检修线 · 接通" if _maintenance_latched else "检修线 · 断开"
	$Reward.visible = _state == State.OPEN
	$Reward.get_node("Base/CollisionShape3D").set_deferred("disabled", _state != State.OPEN)
	$Reward.set_display("攻击强化符文", _state == State.OPEN)

func _refresh_passage(passage: Node3D, deployed: bool) -> void:
	passage.get_node("Deck").visible = deployed
	for rim in [passage.get_node("FrontRim"), passage.get_node("ServiceRim")]:
		rim.visible = not deployed
		rim.get_node("CollisionShape3D").set_deferred("disabled", deployed)
