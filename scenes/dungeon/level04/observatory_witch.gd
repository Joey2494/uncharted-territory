extends "res://addons/ziyuan_level04/witch.gd"
## 字远女巫保留所有招式；适配张宏伟的实体石岛绕行与半血让出扳杆路线。
var encounter: Node3D
var advancing := false
var advance_goal := Vector3.ZERO
var _advance_left := 0.0
var _repath_in := 0.0
var _next_corner := Vector3.ZERO

func start_dome_encounter() -> void:
	if not _battle:
		_battle = true
		battle_started.emit()

func announce_advance(goal: Vector3) -> void:
	advancing = true
	advance_goal = goal
	_advance_left = 6.5
	_repath_in = 0.0

func _pursue(delta: float) -> void:
	super._pursue(delta)
	if state == State.CHASE and _aggro and not _can_see(_target.global_position):
		_walk_toward(_target.global_position,delta,definition.speed * (0.65 if _slow > 0 else 1.0))

func _walk_toward(goal: Vector3, delta: float, speed: float) -> void:
	_repath_in -= delta
	if _repath_in <= 0.0 or global_position.distance_to(_next_corner) < 0.45:
		_next_corner = encounter.next_corner(global_position,goal)
		_repath_in = 0.24
	var heading := _next_corner-global_position
	heading.y = 0.0
	heading = heading.normalized()
	velocity.x = heading.x*speed
	velocity.z = heading.z*speed
	if not heading.is_zero_approx(): _visual.rotation.y = atan2(-heading.x,-heading.z)

func _physics_process(delta: float) -> void:
	if not advancing:
		super._physics_process(delta)
		return
	if not is_encounter_active() or not _live_target(): return
	_advance_left -= delta
	var offset := advance_goal-global_position
	offset.y = 0.0
	if offset.length() < 0.8 or _advance_left <= 0.0:
		advancing = false
		return
	_walk_toward(advance_goal,delta,4.8)
	velocity.y = 0.0 if is_on_floor() else get_gravity().y*delta
	var heading := Vector3(velocity.x,0,velocity.z).normalized()
	move_and_slide()
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == _target:
			var lateral := Vector3(-heading.z,0,heading.x)
			if (_target.global_position-global_position).dot(lateral) < 0: lateral = -lateral
			var step := (lateral+heading*0.4).normalized()*minf(0.20,delta*11)
			if _target.test_move(_target.global_transform,step): step = (-lateral+heading*0.6).normalized()*step.length()
			_target.move_and_collide(step)
			break
	_visual.pose(State.CHASE,0,Vector2(velocity.x,velocity.z).length(),delta,0)
