extends CharacterBody3D
## 鸟群分散时，任一鸟可受击。没有额外生命、掉落或门锁计数。
var source: WeakRef
func setup(owner_actor: Node3D) -> void:
	source = weakref(owner_actor)
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	shape.shape = capsule
	shape.position.y = 0.8
	add_child(shape)
func take_damage(amount: int) -> bool:
	var actor = source.get_ref() if source else null
	return actor.take_damage(amount) if is_instance_valid(actor) else false
func take_direct_damage(amount: int, at: Vector3) -> bool:
	var actor = source.get_ref() if source else null
	return actor.take_direct_damage(amount, at) if is_instance_valid(actor) else false
func is_dead() -> bool:
	var actor = source.get_ref() if source else null
	return not is_instance_valid(actor) or actor.is_dead()
