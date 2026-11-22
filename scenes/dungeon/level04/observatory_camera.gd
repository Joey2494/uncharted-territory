extends "res://scenes/dungeon/level03/tide_camera.gd"
## 沿用潮井镜头的稳定跟随、遮挡淡化和取景算法；此处以观测站自己的交战房间为边界。
const PLAN := preload("res://scenes/dungeon/level04/observatory_plan.gd")
const BATTLE_ROOMS := ["B", "D", "F", "H", "I"]
const BLEND_DISTANCE := 5.0
var _bounds: Dictionary = {}
var _framing: Dictionary = {}
var _size_used := Vector2.ZERO
var _frame_used := Rect2()

func _ready() -> void:
	# 观测站仅左上有紧凑读数板，无需为整条左栏预留空间。
	set_safe_frame(Rect2(0.07,0.18,0.86,0.72))
	super._ready()

func _sample_arena() -> void:
	var viewport := get_viewport().get_visible_rect().size
	if _framing.is_empty() or viewport != _size_used or _safe_frame != _frame_used:
		_size_used = viewport
		_frame_used = _safe_frame
		for id: String in BATTLE_ROOMS:
			var rect := PLAN.bounds(id)
			_bounds[id] = rect
			var center := rect.get_center()
			var anchor := get_parent_node_3d().to_global(Vector3(center.x,1.35,center.y))
			var points := PackedVector3Array()
			for x: float in [rect.position.x,rect.end.x]:
				for z: float in [rect.position.y,rect.end.y]:
					for y: float in [0.0,5.0 if id == "I" else 3.8]:
						points.append(get_parent_node_3d().to_global(Vector3(x,y,z)))
			_framing[id] = {"focus":anchor,"distance":_fit_points(points, anchor) + 0.35}
	var point := Vector2(_target.position.x,_target.position.z)
	var weight_sum := 0.0
	var focus_sum := Vector3.ZERO
	var distance_sum := 0.0
	for id: String in BATTLE_ROOMS:
		var rect: Rect2 = _bounds[id]
		var gap := point.distance_to(point.clamp(rect.position,rect.end))
		var weight := 1.0 - smoothstep(0.0,BLEND_DISTANCE,gap)
		if weight <= 0: continue
		weight_sum += weight
		focus_sum += Vector3(_framing[id].focus) * weight
		distance_sum += float(_framing[id].distance) * weight
	_weight = minf(weight_sum,1.0)
	if weight_sum > 0:
		_arena_focus = focus_sum / weight_sum
		_arena_distance = distance_sum / weight_sum
