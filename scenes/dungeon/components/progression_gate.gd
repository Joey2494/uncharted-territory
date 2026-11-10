extends StaticBody3D
## 同一门体支持长期进度锁和临时战斗锁；只有两者均解除后才开放。

signal opening_started(gate_id: StringName)
signal opened(gate_id: StringName)

enum State { CLOSED, CLOSING, OPENING, OPEN }

const LIFT_HEIGHT := 3.6

@export var gate_id: StringName
@export var locked_message: String = "清除守卫后开启"
## 已有门框文字的场景可关闭内置标签，避免两份提示叠在一起。
@export var show_lock_label: bool = true
@export var initially_open: bool = false
@export_range(0.01, 10.0) var opening_duration: float = 0.9

var state: State = State.CLOSED
var _progression_locked := true
var _combat_locked := false
var _frozen := false
var _motion: Tween
var _generation := 0
var _closed_position := Vector3.ZERO

@onready var _visuals: Node3D = $Visuals
@onready var _collider: CollisionShape3D = $CollisionShape3D
@onready var _label: Label3D = $Visuals/LockedLabel

func _ready() -> void:
	_closed_position = _visuals.position
	_label.text = locked_message
	_label.visible = show_lock_label
	add_to_group("camera_occluders")
	if initially_open:
		_progression_locked = false
		state = State.OPEN
		_visuals.position.y += LIFT_HEIGHT
		_visuals.hide()
		_collider.disabled = true

## 接受一次进度授权。若战斗仍未结束，授权记录先保留，门继续关闭。
func open_gate() -> bool:
	if not is_inside_tree() or not is_node_ready() or not can_process() or _frozen or not _progression_locked:
		return false
	if not is_visible_in_tree() or not _visuals.visible:
		return false
	_progression_locked = false
	_sync_locks()
	return true

## 仅修改战斗锁；开合反向时从当前高度续接。
func set_combat_locked(locked: bool) -> bool:
	if not is_inside_tree() or not is_node_ready() or _frozen or _combat_locked == locked:
		return false
	_combat_locked = locked
	_sync_locks()
	return true

## 战斗房激活前确认这扇门仍能施加战斗锁。
func can_combat_lock() -> bool:
	return (is_inside_tree() and is_node_ready() and can_process() and is_visible_in_tree()
		and not is_queued_for_deletion() and not _frozen and not _combat_locked
		and is_instance_valid(_collider) and _collider.is_inside_tree() and _collider.shape != null)

## 只有物理服务器已更新通道后，才对外确认真正打开。
func is_open() -> bool:
	return state == State.OPEN

## 终局保留动画停下的位置，废弃未完成的开门确认并维持封锁。
func freeze_gate() -> void:
	if _frozen or not is_node_ready():
		return
	_frozen = true
	_cancel_motion()
	if state != State.OPEN:
		_collider.set_deferred("disabled", false)

## 保留顺序门显式取消接口，回到锁定姿态；终局调用 freeze_gate。
func cancel_opening() -> void:
	if state != State.OPENING or _frozen:
		return
	_cancel_motion()
	if initially_open:
		_combat_locked = true
	else:
		_progression_locked = true
	state = State.CLOSED
	_visuals.position = _closed_position
	_visuals.show()
	_label.text = locked_message
	_collider.set_deferred("disabled", false)

func _sync_locks() -> void:
	if _progression_locked or _combat_locked:
		if state == State.OPEN or state == State.OPENING:
			_move_gate(State.CLOSING, _closed_position.y)
	elif state == State.CLOSED or state == State.CLOSING:
		_move_gate(State.OPENING, _closed_position.y + LIFT_HEIGHT)

func _move_gate(direction: State, target_height: float) -> void:
	_cancel_motion()
	state = direction
	_visuals.show()
	_label.text = "封印解除中" if direction == State.OPENING else locked_message
	# 激活时玩家已在安全内侧；下降开始即提交完整碰撞，不等视觉落地。
	_collider.set_deferred("disabled", false)
	var generation := _generation
	_motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	_motion.tween_property(_visuals, "position:y", target_height, opening_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_callback(_finish_motion.bind(generation))
	if direction == State.OPENING:
		opening_started.emit(gate_id)

func _finish_motion(generation: int) -> void:
	if not _is_current(generation):
		return
	if state == State.CLOSING:
		state = State.CLOSED
		return
	_visuals.hide()
	_confirm_open.call_deferred(generation)

## 在物理查询刷新期之外关闭碰撞，再等一整物理步才发送 opened。
func _confirm_open(generation: int) -> void:
	while _is_current(generation) and not can_process():
		await get_tree().physics_frame
	if not _is_current(generation):
		return
	_collider.disabled = true
	for frame in 2:
		await get_tree().physics_frame
		if not _is_current(generation):
			return
	while _is_current(generation) and not can_process():
		await get_tree().physics_frame
	if not _is_current(generation):
		return
	state = State.OPEN
	opened.emit(gate_id)

func _is_current(generation: int) -> bool:
	return is_inside_tree() and generation == _generation

func _cancel_motion() -> void:
	_generation += 1
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null

func _exit_tree() -> void:
	_cancel_motion()
