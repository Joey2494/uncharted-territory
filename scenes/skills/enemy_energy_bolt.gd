extends "res://scenes/skills/energy_bolt.gd"

var _source: WeakRef
var _target: WeakRef


func _ready() -> void:
	remove_from_group("player_projectiles")
	add_to_group("enemy_projectiles")


func launch(direction: Vector3, damage: int, speed: float, distance: float, source: PhysicsBody3D) -> void:
	_source = weakref(source)
	var target := source.get_node_or_null(source.target_path)
	if target != null:
		_target = weakref(target)
	super.launch(direction, damage, speed, distance, source)


func _physics_process(delta: float) -> void:
	var source = _source.get_ref() if _source != null else null
	var target = _target.get_ref() if _target != null else null
	if not is_instance_valid(source) or source.is_dead() or not is_instance_valid(target) or target.is_dead():
		queue_free()
		return
	super._physics_process(delta)
