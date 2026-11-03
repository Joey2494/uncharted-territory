extends CharacterBody3D
## A swept sphere hits the first world/enemy body and applies damage once.

signal impacted(collider: Node)

@onready var _visuals: Node3D = $Visuals
@onready var _impact: MeshInstance3D = $ImpactBurst

var _direction: Vector3 = Vector3.FORWARD
var _damage: int = 2
var _speed: float = 18.0
var _max_distance: float = 10.0
var _travelled: float = 0.0
var _launched: bool = false
var _resolved: bool = false


func launch(direction: Vector3, damage: int, speed: float, distance: float, source: PhysicsBody3D) -> void:
	_direction = direction.normalized()
	_damage = damage
	_speed = maxf(speed, 0.01)
	_max_distance = maxf(distance, 0.01)
	add_collision_exception_with(source)
	look_at(global_position + _direction, Vector3.UP)
	_launched = true


func _physics_process(delta: float) -> void:
	if not _launched or _resolved:
		return
	var step_distance := minf(_speed * delta, _max_distance - _travelled)
	var collision := move_and_collide(_direction * step_distance, false, 0.001, true)
	if collision != null:
		_resolved = true
		set_physics_process(false)
		var collider := collision.get_collider() as Node
		impacted.emit(collider)
		if is_instance_valid(collider) and collider.has_method("take_damage"):
			collider.call("take_damage", _damage)
		_show_impact()
		return
	_travelled += step_distance
	if _travelled >= _max_distance - 0.000001:
		_resolved = true
		set_physics_process(false)
		var tween := create_tween()
		tween.tween_property(_visuals, "scale", Vector3.ONE * 0.01, 0.1)
		tween.tween_callback(queue_free)


func _show_impact() -> void:
	_visuals.hide()
	_impact.show()
	_impact.scale = Vector3.ONE * 0.2
	var tween := create_tween()
	tween.tween_property(_impact, "scale", Vector3.ONE * 2.5, 0.18)
	tween.parallel().tween_property(_impact, "transparency", 1.0, 0.18)
	tween.tween_callback(queue_free)
