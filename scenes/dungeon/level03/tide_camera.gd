extends "res://scenes/dungeon/follow_camera.gd"
## 进入战斗前沿通道切到房间构图；封场内敌人移位、死亡或召援都不会触发升降。
const Layout = preload("res://scenes/dungeon/level03/tide_layout.gd")
const ARENAS := [&"C", &"E", &"F", &"I", &"G"]
const APPROACH := 8.0
const ZOOM_UNITS_PER_SECOND := 12.0

var _arena_focus := Vector3.ZERO
var _arena_distance := 18.0
var _weight := 0.0
var _cached_arena: StringName
var _cached_viewport := Vector2.ZERO

func reset_follow() -> void:
	if not is_instance_valid(_target): return
	_view_basis = Basis(Vector3.RIGHT, -deg_to_rad(pitch_degrees))
	_sample_arena()
	_focus = _target.global_position + Vector3.UP
	_focus = _focus.lerp(_arena_focus, _weight)
	_distance = lerpf(minimum_distance, _arena_distance, _weight)
	_apply_view()

func set_safe_frame(frame: Rect2) -> void:
	# HUD 重排只更新边界，由下一帧统一缓动；不以旧焦点立即拉远。
	if _safe_frame.is_equal_approx(frame): return
	_safe_frame = frame
	_cached_arena = &""

func _process(delta: float) -> void:
	if not is_instance_valid(_target): return
	_sample_arena()
	var destination := (_target.global_position + Vector3.UP).lerp(_arena_focus, _weight)
	_focus = _focus.lerp(destination, 1.0 - exp(-follow_speed * delta))
	_distance = move_toward(_distance, lerpf(minimum_distance, _arena_distance, _weight), ZOOM_UNITS_PER_SECOND * delta)
	_apply_view()
	var actors := _get_actors()
	_update_labels(actors)
	_update_occluders(actors, delta)

func _sample_arena() -> void:
	var position_2d := Vector2(_target.position.x, _target.position.z)
	var nearest: StringName = &""
	var gap := APPROACH
	for id: StringName in ARENAS:
		var bounds: Rect2 = Layout.ROOMS[id]
		var distance := position_2d.distance_to(position_2d.clamp(bounds.position, bounds.end))
		if distance < gap:
			nearest = id
			gap = distance
	_weight = 1.0 - smoothstep(0.0, APPROACH, gap)
	if nearest == &"": return
	var viewport_size := get_viewport().get_visible_rect().size
	if nearest == _cached_arena and viewport_size == _cached_viewport: return
	_cached_arena = nearest
	_cached_viewport = viewport_size
	var room: Rect2 = Layout.ROOMS[nearest]
	var centre := room.get_center()
	var map := get_parent() as Node3D
	_arena_focus = map.to_global(Vector3(centre.x, 1.4, centre.y))
	# 固定覆盖完整战斗房与最高角色，不随敌人攻击、移动或死亡改变缩放。
	var height := 5.0 if nearest == &"G" else 3.8
	var points := PackedVector3Array()
	for x: float in [room.position.x, room.end.x]:
		for z: float in [room.position.y, room.end.y]:
			points.append(map.to_global(Vector3(x, 0.0, z)))
			points.append(map.to_global(Vector3(x, height, z)))
	_arena_distance = _fit_points(points, _arena_focus) + 0.35
