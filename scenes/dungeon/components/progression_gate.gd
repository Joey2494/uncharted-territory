extends StaticBody3D
## 顺序门只负责实体阻挡和表现；开门资格由房间进度控制器判定。

signal opening_started(gate_id: StringName)
signal opened(gate_id: StringName)

enum State { LOCKED, OPENING, OPEN }

@export var gate_id: StringName
@export var locked_message: String = "清除守卫后开启"
## 已有门框文字的场景可关闭内置标签，避免两份提示叠在一起。
@export var show_lock_label: bool = true
@export_range(0.01, 10.0) var opening_duration: float = 0.9

var state: State = State.LOCKED
var _opening_tween: Tween
var _generation := 0
var _initial_visual_position := Vector3.ZERO

@onready var _visuals: Node3D = $Visuals
@onready var _collider: CollisionShape3D = $CollisionShape3D
@onready var _label: Label3D = $Visuals/LockedLabel

func _ready() -> void:
	_initial_visual_position = _visuals.position
	_label.text = locked_message
	_label.visible = show_lock_label
	add_to_group("camera_occluders")

## 接受一次已获授权的请求；离树、暂停或状态不适用时返回 false。
func open_gate() -> bool:
	if not is_inside_tree() or not is_node_ready() or not can_process():
		return false
	if state != State.LOCKED or not is_visible_in_tree() or not _visuals.visible:
		return false
	state = State.OPENING
	_label.text = "封印解除中"
	_generation += 1
	var generation := _generation
	# 节点绑定 Tween 会继承祖先暂停状态，不让菜单/死亡界面背后继续计时。
	_opening_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	_opening_tween.tween_property(_visuals, "position:y", _initial_visual_position.y - 3.6, opening_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_opening_tween.tween_callback(_finish_animation.bind(generation))
	opening_started.emit(gate_id)
	return true

## 只有物理服务器已更新通道后，才对外确认真正打开。
func is_open() -> bool:
	return state == State.OPEN

## 死亡终局取消：废弃异步回调并恢复锁定外观，下一局重新实例化。
func cancel_opening() -> void:
	if state != State.OPENING:
		return
	_generation += 1
	if _opening_tween != null and _opening_tween.is_valid():
		_opening_tween.kill()
	_opening_tween = null
	state = State.LOCKED
	_visuals.position = _initial_visual_position
	_visuals.show()
	_label.text = locked_message
	_collider.set_deferred("disabled", false)

## 动画完成后，完整隐藏所有装饰；不能用隐藏 StaticBody 代替关闭碰撞。
func _finish_animation(generation: int) -> void:
	if not _is_current_opening(generation):
		return
	_visuals.hide()
	_disable_collision.call_deferred(generation)

## 延迟写碰撞避免物理查询刷新期改形状；代际校验阻止取消后的旧调用。
func _disable_collision(generation: int) -> void:
	if not _is_current_opening(generation):
		return
	while not can_process():
		await get_tree().physics_frame
		if not _is_current_opening(generation):
			return
	_collider.disabled = true
	# physics_frame 在物理步开始前发出：等两次确保至少一整步已应用形状变化。
	await get_tree().physics_frame
	if not _is_current_opening(generation):
		return
	await get_tree().physics_frame
	if not _is_current_opening(generation):
		return
	while not can_process():
		await get_tree().physics_frame
		if not _is_current_opening(generation):
			return
	state = State.OPEN
	opened.emit(gate_id)

## generation 同时保护动画回调和跨物理帧等待，取消后不得重新宣布开放。
func _is_current_opening(generation: int) -> bool:
	return is_inside_tree() and generation == _generation and state == State.OPENING

func _exit_tree() -> void:
	_generation += 1
	if _opening_tween != null and _opening_tween.is_valid():
		_opening_tween.kill()
