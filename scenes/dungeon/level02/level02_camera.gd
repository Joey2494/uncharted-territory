extends "res://scenes/dungeon/follow_camera.gd"
## 战斗和档案室按完整房间取景，普通探索继续缓动跟随。

signal framing_mode_changed

const Progress := preload("res://scenes/dungeon/components/room_progress_controller.gd")
const COMBAT_PITCH := 44.0
const FIGHTER_HEIGHT := 2.8
const ARCHIVE := &"l2_archive"

@onready var _progress: Progress = $"../RoomProgress"
@onready var _boss: CharacterBody3D = $"../Boss"
@onready var _archive: Node3D = $"../Regions/Archive"
@onready var _combat_rooms := {
	&"l2_hub": $"../Regions/Hub",
	&"l2_relay": $"../Regions/Relay",
	&"l2_antechamber": $"../Regions/Antechamber",
	&"l2_boss": $"../Regions/Boss",
}

var _framed_room: StringName
var _framed_size := Vector2.ZERO
var _ground_samples := PackedVector3Array()
var _arena_distance := 18.0
var _room_focus := Vector3.ZERO
# 档案室两侧门槛使用滞回，防止一小步反复切换；出入过渡与战斗镜头分开。
const ARCHIVE_EXIT_MARGIN := 0.7
const TRANSITION_SECONDS := 0.45
var _transition_remaining := 0.0
var _transition_focus := Vector3.ZERO
var _transition_distance := 18.0


func _ready() -> void:
	pitch_degrees = COMBAT_PITCH
	super._ready()


func reset_follow() -> void:
	_transition_remaining = 0.0
	_view_basis = Basis(Vector3.RIGHT, -deg_to_rad(COMBAT_PITCH))
	var room := _get_fixed_room()
	if room == &"":
		_clear_fixed_frame()
		_ground_samples.clear()
		super.reset_follow()
	else:
		_frame_battle(room)


func set_safe_frame(frame: Rect2) -> void:
	if frame.is_equal_approx(_safe_frame):
		return
	if _framed_room == &"":
		super.set_safe_frame(frame)
	else:
		_safe_frame = frame
		_frame_battle(_framed_room)


func _process(delta: float) -> void:
	var room := _get_fixed_room()
	if room != _framed_room and (room == ARCHIVE or _framed_room == ARCHIVE):
		_transition_focus = _focus
		_transition_distance = _distance
		_transition_remaining = TRANSITION_SECONDS
	if room == &"":
		_clear_fixed_frame()
		_ground_samples.clear()
		super._process(delta)
		_apply_archive_transition(delta)
		return
	if room != _framed_room or _framed_size != get_viewport().get_visible_rect().size:
		_frame_battle(room)
	_focus = _room_focus
	var actors := _get_actors()
	# 房间中心保持稳定；仅当真实角色轮廓越过固定构图时扩展视距。
	# 不再为“可能站在每个角落的巨蝎”同时预留四份体积。
	var required := maxf(_arena_distance, _required_distance(actors, _focus))
	_distance = maxf(required, lerpf(_distance, required, 1.0-exp(-zoom_speed*delta)))
	_apply_archive_transition(delta)
	_apply_view()
	_update_labels(actors)
	# 同时检视战斗地面，挡住预警的墙体也可淡出，即使后方没有角色。
	var samples := _actor_visibility_points(actors)
	samples.append_array(_ground_samples)
	_fade_occluders(samples, delta)


func _get_combat_room() -> StringName:
	for id: StringName in _combat_rooms:
		if _progress.get_room_state(id) == Progress.RoomState.ACTIVE:
			return id
	return &""


## 档案室本身没有战斗；若存在有效封场，战斗构图始终优先。
func is_puzzle_framed() -> bool:
	if not is_instance_valid(_target) or not is_instance_valid(_archive) \
		or not get_parent().is_run_active() or _get_combat_room() != &"":
		return false
	var bounds: Rect2 = _archive.get_world_bounds()
	if _framed_room == ARCHIVE: bounds = bounds.grow(ARCHIVE_EXIT_MARGIN)
	return bounds.has_point(Vector2(_target.global_position.x, _target.global_position.z))


func _get_fixed_room() -> StringName:
	var combat := _get_combat_room()
	return combat if combat != &"" else (ARCHIVE if is_puzzle_framed() else &"")


func _clear_fixed_frame() -> void:
	if _framed_room != &"":
		_framed_room = &""
		framing_mode_changed.emit()


func _frame_battle(room: StringName) -> void:
	var region: Node3D = _archive if room == ARCHIVE else _combat_rooms[room]
	var bounds: Rect2 = region.get_world_bounds()
	var height := FIGHTER_HEIGHT
	if room == &"l2_boss" and is_instance_valid(_boss):
		var dimensions := _actor_dimensions(_boss)
		height = dimensions.y
	# 以真实战场取景，不把巨蝎半径扩张到整个房间四角形成虚构的大房间。
	var envelope := bounds
	var points := PackedVector3Array()
	for x: float in [envelope.position.x, envelope.end.x]:
		for z: float in [envelope.position.y, envelope.end.y]:
			points.append(Vector3(x, region.global_position.y, z))
			points.append(Vector3(x, region.global_position.y + height, z))
	var center := bounds.get_center()
	_focus = Vector3(center.x, region.global_position.y + height * 0.33, center.y)
	_room_focus = _focus
	_arena_distance = _fit_points(points, _focus) + 0.35
	_distance = maxf(_arena_distance, _required_distance(_get_actors(), _focus))
	var changed := _framed_room != room
	_framed_room = room
	_framed_size = get_viewport().get_visible_rect().size
	_ground_samples.clear()
	# 稍微避开墙面接缝。采样间距约四米，覆盖两端和房间中心。
	var inside := bounds.grow(-0.25)
	var steps := Vector2i(ceil(inside.size.x / 4.0), ceil(inside.size.y / 4.0))
	for x in range(steps.x + 1):
		for z in range(steps.y + 1):
			var point := inside.position + inside.size * (Vector2(x, z) / Vector2(steps))
			_ground_samples.append(Vector3(point.x, region.global_position.y + 0.05, point.y))
	_apply_view()
	if changed:
		framing_mode_changed.emit()


## 用固定时长缓入缓出，完成后精确落到房间构图；显式 reset_follow 仍即时复位。
func _apply_archive_transition(delta: float) -> void:
	if _transition_remaining <= 0.0: return
	_transition_remaining = maxf(0.0, _transition_remaining-delta)
	var weight := smoothstep(0.0, 1.0, 1.0-_transition_remaining/TRANSITION_SECONDS)
	_focus = _transition_focus.lerp(_focus, weight)
	_distance = lerpf(_transition_distance, _distance, weight)
	_apply_view()
