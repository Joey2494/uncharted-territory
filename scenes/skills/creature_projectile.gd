extends CharacterBody3D
## Web/venom and broodlings burst and disappear at the first player/world contact.
const FX = preload("res://scenes/enemies/creature_fx.gd")
var target_path := NodePath()
var _source: WeakRef
var _target: WeakRef
var hit_damage := 1
var kind := 0 # silk / broodling / venom stinger
var _direction := Vector3.FORWARD
var _speed := 9.0
var _life := 3.0
var _attached := false # Compatibility for swarm separation; never attaches after impact.
var _dead := false
var _visual: Node3D
var _silk: MeshInstance3D
var _emerge_remaining := 0.0
var _emerge_total := 0.55
var emergence_delay := 0.0
var _swarm_phase := 0.0

func is_dead() -> bool: return _dead

func setup(source: Node3D, target: Node3D, direction: Vector3, type: int, damage: int = 1, speed: float = -1.0, distance: float = -1.0) -> void:
	add_to_group("creature_hazards")
	_source = weakref(source)
	_target = weakref(target)
	_direction = direction.normalized()
	kind = type
	hit_damage = maxi(1, damage)
	collision_layer = 4 if kind == 1 else 0
	collision_mask = 3
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.18 if kind == 1 else 0.23
	shape.shape = sphere
	add_child(shape)
	add_collision_exception_with(source)
	_visual = Node3D.new()
	add_child(_visual)
	if kind == 1:
		add_to_group("broodlings")
		var model := preload("res://scenes/enemies/broodling_visual.gd").new()
		_visual.add_child(model)
		_speed = 2.6 + float(get_instance_id() % 9) * 0.16
		_life = 12.0 + emergence_delay
		_emerge_remaining = _emerge_total + emergence_delay
		_visual.position.y = -0.55
		collision_mask = 0
		collision_layer = 0
		_swarm_phase = float(get_instance_id() % 100) * 0.63
	elif kind == 0:
		# One continuous strand grows from the mouth to the moving collision tip.
		_silk = FX.strand(self, Vector3.ZERO, Vector3.UP * 0.001, Color("e3f0f4"), 0.028)
		_silk.top_level = true
		_speed = 22.0
		_life = 0.5
	else:
		var mesh := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.18
		ball.height = 0.36
		ball.material = FX.material(Color("b6fa46"))
		mesh.mesh = ball
		_visual.add_child(mesh)
		for i in range(6):
			var d := Vector3(cos(i * TAU / 6), sin(i * TAU / 6), 0)
			FX.strand(_visual, d * 0.08, d * 0.32 + Vector3.BACK * 0.5, Color("8cda32"), 0.018)
		_speed = 12.0
		_life = 2.2

	if speed > 0: _speed = speed
	if distance > 0: _life = distance / _speed

func _update_silk(source: Node3D) -> void:
	if not is_instance_valid(_silk): return
	var mouth := source.global_position + Vector3.UP * 0.85
	var facing := source.get_node_or_null("Visuals") as Node3D
	if facing != null: mouth -= facing.global_basis.z * 0.85
	var end := global_position
	var up := (end - mouth).normalized()
	if up.length() < 0.01: return
	var right := up.cross(Vector3.FORWARD).normalized()
	if right.length() < 0.1: right = Vector3.RIGHT
	(_silk.mesh as CylinderMesh).height = mouth.distance_to(end)
	_silk.global_transform = Transform3D(Basis(right, up, right.cross(up)).orthonormalized(), (mouth + end) * 0.5)

func _physics_process(delta: float) -> void:
	if _dead: return
	var source = _source.get_ref() if _source else null
	var target = _target.get_ref() if _target else null
	if not is_instance_valid(source) or source.is_dead() or not source.can_process() or not is_instance_valid(target) or target.is_dead():
		queue_free()
		return
	_life -= delta
	if _life <= 0:
		queue_free()
		return
	if kind == 0:
		_update_silk(source)
	if kind == 1 and _emerge_remaining > 0:
		_emerge_remaining = maxf(0, _emerge_remaining - delta)
		var rise := clampf(1.0 - _emerge_remaining / _emerge_total, 0, 1)
		_visual.position.y = lerpf(-0.55, 0, rise)
		_visual.visible = rise > 0
		if _emerge_remaining <= 0:
			collision_mask = 3
			collision_layer = 4
		return
	if kind == 1:
		var spread := Vector3(cos(_swarm_phase + _life * 1.3), 0, sin(_swarm_phase + _life * 1.3)) * 0.32
		_direction = target.global_position + spread - global_position
		_direction.y = 0
		_direction = (_direction.normalized() + preload("res://scenes/enemies/broodling_field.gd").separation(self) * 1.65).normalized()
		_visual.rotation.y = atan2(-_direction.x, -_direction.z)
		_visual.position.y = abs(sin(_life * 22)) * 0.035
	var collision := move_and_collide(_direction * _speed * delta)
	if collision == null:
		if kind == 0: _update_silk(source)
		return
	var body := collision.get_collider()
	if body == target:
		var guarded: bool = target.get_node("ItemInventory").guard_active
		var hit: bool = target.take_direct_damage(hit_damage, source.global_position)
		if hit and not guarded and not target.is_dead():
			if kind == 0:
				target.apply_web(2.2)
	elif body is Node and body.is_in_group("breakable_cover"):
		body.take_damage(hit_damage)
	_dead = true
	FX.burst(get_parent(), collision.get_position(), Color("e3f0f4") if kind == 0 else Color("b6fa46"), 0.35)
	hide()
	queue_free()

func take_damage(amount: int) -> bool:
	if amount <= 0 or _dead or _attached: return false
	_dead = true
	FX.burst(get_parent(), global_position, Color("b6fa46"), 0.35)
	queue_free()
	return true
