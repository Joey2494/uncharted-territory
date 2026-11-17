extends "res://scenes/dungeon/follow_camera.gd"
## 第二关在战斗期间用房间边界取景，探索继续沿用缓动跟随。

const Progress := preload("res://scenes/dungeon/components/room_progress_controller.gd")
const COMBAT_PITCH := 44.0
const FIGHTER_HEIGHT := 2.8

@onready var _progress: Progress = $"../RoomProgress"
@onready var _boss: CharacterBody3D = $"../Boss"
@onready var _combat_rooms := {
	&"l2_hub": $"../Regions/Hub",
	&"l2_relay": $"../Regions/Relay",
	&"l2_antechamber": $"../Regions/Antechamber",
	&"l2_boss": $"../Regions/Boss",
}

var _framed_room: StringName
var _framed_size := Vector2.ZERO
var _ground_samples := PackedVector3Array()


func _ready() -> void:
	pitch_degrees = COMBAT_PITCH
	super._ready()


func reset_follow() -> void:
	_view_basis = Basis(Vector3.RIGHT, -deg_to_rad(COMBAT_PITCH))
	var room := _get_combat_room()
	if room == &"":
		_framed_room = &""
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
	var room := _get_combat_room()
	if room == &"":
		_framed_room = &""
		_ground_samples.clear()
		super._process(delta)
		return
	if room != _framed_room or _framed_size != get_viewport().get_visible_rect().size:
		_frame_battle(room)
	var actors := _get_actors()
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


func _frame_battle(room: StringName) -> void:
	var region: Node3D = _combat_rooms[room]
	var bounds: Rect2 = region.get_world_bounds()
	var height := FIGHTER_HEIGHT
	var model_margin := 0.0
	if room == &"l2_boss" and is_instance_valid(_boss):
		var dimensions := _actor_dimensions(_boss)
		var capsule := _boss.get_node("CollisionShape3D").shape as CapsuleShape3D
		height = dimensions.y
		model_margin = maxf(0.0, dimensions.x - capsule.radius)
	# 地面预警以实际可站立范围为准；巨蝎的轮廓可以越过物理边界。
	var envelope := bounds.grow(model_margin)
	var points := PackedVector3Array()
	for x: float in [envelope.position.x, envelope.end.x]:
		for z: float in [envelope.position.y, envelope.end.y]:
			points.append(Vector3(x, region.global_position.y, z))
			points.append(Vector3(x, region.global_position.y + height, z))
	var center := bounds.get_center()
	_focus = Vector3(center.x, region.global_position.y + height * 0.33, center.y)
	_distance = _fit_points(points, _focus) + 0.35
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
