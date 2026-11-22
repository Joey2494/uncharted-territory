extends "res://addons/ziyuan_level03/enemy.gd"
## 沿用现有敌人的招式、模型和受击契约；本关石墙会挡住追击，需要绕至通行缺口。
var encounter: Node3D
var _next_corner := Vector3.ZERO
var _repath_in := 0.0
var advancing := false
var advance_goal := Vector3.ZERO
var _advance_warning := 0.0
var _advance_left := 0.0

func _pursue(delta: float) -> void:
	# 栈道射手守在各自标记廊段，隔墙失去视线时留守，玩家可利用横口换线。
	if get_meta("room","") == "F" and enemy_id == "bone_spike":
		if _can_see(_target.global_position) and global_position.distance_to(_target.global_position) <= definition.reach:
			super._pursue(delta)
		velocity.x = 0
		velocity.z = 0
		return
	if _can_see(_target.global_position):
		_repath_in = 0
		super._pursue(delta)
		# 射线能穿过的窄缝未必能容纳身体。贴到墙角时仍从寻路网格重选落脚点。
		if state != State.CHASE or get_slide_collision_count() == 0: return
		var touching_wall := false
		for i in get_slide_collision_count():
			if absf(get_slide_collision(i).get_normal().y) < 0.6:
				touching_wall = true
		if not touching_wall: return
	state = State.CHASE
	_walk_toward(_target.global_position, delta, definition.speed * (0.65 if _slow > 0 else 1.0))

func _walk_toward(goal: Vector3, delta: float, speed: float) -> void:
	_repath_in -= delta
	if _repath_in <= 0 or global_position.distance_to(_next_corner) < 0.45:
		_next_corner = encounter.next_corner(global_position, goal)
		_repath_in = 0.24
	var heading := _next_corner - global_position
	heading.y = 0
	heading = heading.normalized()
	velocity.x = heading.x * speed
	velocity.z = heading.z * speed
	if not heading.is_zero_approx():
		_visual.rotation.y = atan2(-heading.x,-heading.z)

func announce_advance(goal: Vector3) -> void:
	advancing = true
	advance_goal = goal
	_advance_warning = 1.3
	_advance_left = 6.5
	_repath_in = 0
	_clear_warning()
	_disc(goal,1.1,360)
	var marker := _warning.get_child(-1) as Node3D
	marker.top_level = true
	marker.global_position = goal + Vector3.UP*0.06
	state = State.CHASE

func _physics_process(delta: float) -> void:
	if not advancing:
		super._physics_process(delta)
		return
	if not is_encounter_active() or not _live_target(): return
	velocity = Vector3.ZERO
	if _advance_warning > 0:
		_advance_warning -= delta
		_visual.pose(State.WINDUP,1.0-maxf(0,_advance_warning)/1.3,0,delta,0)
		return
	_advance_left -= delta
	var offset := advance_goal-global_position
	offset.y = 0
	if offset.length() < 0.8 or _advance_left <= 0:
		advancing = false
		_clear_warning()
		state = State.RECOVER
		_duration = 0.85
		_remaining = _duration
		return
	_walk_toward(advance_goal,delta,4.1)
	velocity.y = 0 if is_on_floor() else get_gravity().y * delta
	move_and_slide()
	_visual.pose(State.CHASE,0,Vector2(velocity.x,velocity.z).length(),delta,0)
