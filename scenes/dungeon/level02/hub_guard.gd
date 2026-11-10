extends "res://scenes/enemies/MeleeEnemy.gd"
## 仅中庭复用守卫的追击转向。把固定掩体的安全角点作为绕行点，
## 发现玩家、攻击、硬直、伤害和死亡仍由原守卫处理。

const CLEARANCE := 0.04
const CORNER_MARGIN := 0.10

@export var cover_shapes: Array[NodePath] = []

var _obstacles: Array[Rect2] = []
var _corners: Array[Vector2] = []

func _ready() -> void:
	super._ready()
	var capsule := $CollisionShape3D.shape as CapsuleShape3D
	for path in cover_shapes:
		var cover := get_node_or_null(path) as CollisionShape3D
		if cover == null or not cover.shape is BoxShape3D:
			continue
		# 白盒中庭使用与房间轴向对齐的静态盒子，按胶囊半径扩张碰撞轮廓。
		var half_size := Vector2(cover.shape.size.x, cover.shape.size.z) * 0.5
		var centre := _flat(cover.global_position)
		var bounds := Rect2(centre - half_size, half_size * 2.0).grow(capsule.radius + CLEARANCE)
		_obstacles.append(bounds)
		var exterior := bounds.grow(CORNER_MARGIN)
		_corners.append_array([
			exterior.position,
			Vector2(exterior.end.x, exterior.position.y),
			exterior.end,
			Vector2(exterior.position.x, exterior.end.y),
		])

func _update_pursuit(delta: float) -> void:
	var previous_yaw := _visuals.rotation.y
	super._update_pursuit(delta)
	if state != State.CHASE:
		return
	var origin := _flat(global_position)
	var goal := _flat(_target.global_position)
	if _clear_segment(origin, goal):
		return
	var waypoint := _outside_obstacle(origin)
	if waypoint == origin:
		waypoint = _first_waypoint(origin, _outside_obstacle(goal))
	var direction := (waypoint - origin).normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.y * move_speed
	_visuals.rotation.y = lerp_angle(previous_yaw, atan2(-direction.x, -direction.y), 1.0 - exp(-turn_speed * delta))

func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)

## 玩家贴着掩体时可能落在更宽的守卫轮廓内，把追击终点移到最近的可达边。
func _outside_obstacle(point: Vector2) -> Vector2:
	for bounds in _obstacles:
		if not bounds.has_point(point):
			continue
		var exterior := bounds.grow(CORNER_MARGIN)
		var exits := [
			Vector2(exterior.position.x, point.y), Vector2(exterior.end.x, point.y),
			Vector2(point.x, exterior.position.y), Vector2(point.x, exterior.end.y),
		]
		var closest: Vector2 = exits[0]
		for candidate: Vector2 in exits:
			if point.distance_squared_to(candidate) < point.distance_squared_to(closest):
				closest = candidate
		return closest
	return point

## 小图只含守卫、玩家和两座掩体的八个角点。只在直线受阻时找最短可见路径。
func _first_waypoint(origin: Vector2, goal: Vector2) -> Vector2:
	var points: Array[Vector2] = [origin, goal]
	points.append_array(_corners)
	var distances := PackedFloat32Array()
	var previous := PackedInt32Array()
	var visited := PackedByteArray()
	distances.resize(points.size())
	previous.resize(points.size())
	visited.resize(points.size())
	distances.fill(INF)
	previous.fill(-1)
	distances[0] = 0.0
	for step in points.size():
		var closest := -1
		var best := INF
		for i in points.size():
			if visited[i] == 0 and distances[i] < best:
				closest = i
				best = distances[i]
		if closest < 0 or closest == 1:
			break
		visited[closest] = 1
		for i in range(1, points.size()):
			if visited[i] != 0 or not _clear_segment(points[closest], points[i]):
				continue
			var cost := best + points[closest].distance_to(points[i])
			if cost < distances[i]:
				distances[i] = cost
				previous[i] = closest
	var next := 1
	while previous[next] > 0:
		next = previous[next]
	return points[next]

func _clear_segment(start: Vector2, finish: Vector2) -> bool:
	for bounds in _obstacles:
		if bounds.has_point(start) or bounds.has_point(finish):
			return false
		var top_right := Vector2(bounds.end.x, bounds.position.y)
		var bottom_left := Vector2(bounds.position.x, bounds.end.y)
		if (Geometry2D.segment_intersects_segment(start, finish, bounds.position, top_right) != null
			or Geometry2D.segment_intersects_segment(start, finish, top_right, bounds.end) != null
			or Geometry2D.segment_intersects_segment(start, finish, bounds.end, bottom_left) != null
			or Geometry2D.segment_intersects_segment(start, finish, bottom_left, bounds.position) != null):
			return false
	return true
