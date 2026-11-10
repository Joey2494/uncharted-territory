extends Node3D
## Presentation-only articulation; all geometry is serialized in the scene.

@export_enum("Crawler", "Sentinel", "Scorpion") var creature_kind := 0
@export var preview_motion := false
var _time := 0.0
var _death := false
var _actor: CharacterBody3D
var _legs: Array[Node3D] = []
var _body: Node3D
var _body_origin := Vector3.ZERO
var _strike := 0.0


func _ready() -> void:
	var ancestor := get_parent()
	while ancestor != null and not ancestor is CharacterBody3D:
		ancestor = ancestor.get_parent()
	_actor = ancestor as CharacterBody3D
	_body = get_node("Body")
	_body_origin = _body.position
	for child in get_children():
		if child is Node3D and child.name.begins_with("Leg"):
			_legs.append(child)
	if is_instance_valid(_actor) and _actor.has_signal("died"):
		_actor.died.connect(_on_death)
	if is_instance_valid(_actor) and _actor.has_signal("attack_resolved"):
		_actor.attack_resolved.connect(func(_kind: int, _index: int) -> void: _strike = 1.0)


func _process(delta: float) -> void:
	if _death:
		return
	_time += delta
	var speed := 0.0
	var windup := false
	if is_instance_valid(_actor):
		speed = Vector2(_actor.velocity.x, _actor.velocity.z).length()
		windup = _actor.state == 2
	elif preview_motion:
		speed = 0.5
	var stride := minf(speed * 0.1, 0.22)
	_body.position.y = _body_origin.y + sin(_time * 2.1) * 0.025
	for i in range(_legs.size()):
		var phase := _time * (5.0 + speed) + (i % 2) * PI + (PI if i >= 4 else 0.0)
		_legs[i].rotation.y = sin(phase) * stride
		_legs[i].rotation.z = cos(phase) * stride * 0.4
	if creature_kind == 2:
		_strike = maxf(0.0, _strike - delta * 3.8)
		var tail := get_node("Tail") as Node3D
		tail.rotation.x = lerpf(tail.rotation.x, (-0.16 if windup else 0.0) + _strike * 0.28, minf(1.0, delta * 8))
		tail.rotation.z = sin(_time * 0.8) * 0.035
		for side in [-1.0, 1.0]:
			var claw := get_node("ClawL" if side < 0 else "ClawR") as Node3D
			claw.rotation.x = lerpf(claw.rotation.x, (-0.32 if windup else 0.0) + _strike * 0.3, minf(1.0, delta * 10))
			claw.get_node("Jaw").rotation.y = side * (0.15 + sin(_time * 1.7) * 0.06 + (0.14 if windup else 0.0))
	else:
		_body.rotation.x = lerpf(_body.rotation.x, -0.1 if windup else 0.0, minf(1.0, delta * 8))


func _on_death() -> void:
	_death = true
	if creature_kind == 2:
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_body, "position:y", _body_origin.y - 0.35, 0.45)
	for i in range(_legs.size()):
		tween.tween_property(_legs[i], "rotation:z", -0.9 if i < 4 else 0.9, 0.45)
	tween.chain().tween_interval(0.2)
	if is_instance_valid(_actor):
		tween.chain().tween_callback(_actor.queue_free)
