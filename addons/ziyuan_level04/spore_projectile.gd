extends CharacterBody3D
## 脉冲种子的环形孢子弹丸：直线飞行、受墙体阻挡、命中玩家或世界后消失。
## 沿用第三关投射物契约：源停止/死亡或本房停止时清理自身。
const FX = preload("effects.gd")
var _source: WeakRef
var _target: WeakRef
var _direction := Vector3.FORWARD
var damage := 1
var speed := 5.5
var _life := 1.8
var _done := false
func launch(source: Node3D, target: Node3D, direction: Vector3, amount: int) -> void:
	add_to_group("l4_hazards")
	_source = weakref(source)
	_target = weakref(target)
	_direction = direction.normalized()
	damage = amount
	collision_layer = 0
	collision_mask = 3
	add_collision_exception_with(source)
	var shape := CollisionShape3D.new()
	var capsule := SphereShape3D.new()
	capsule.radius = 0.15
	shape.shape = capsule
	add_child(shape)
	var seed := MeshInstance3D.new()
	var blob := SphereMesh.new()
	blob.radius = 0.13
	blob.height = 0.22
	blob.radial_segments = 12
	blob.rings = 7
	seed.mesh = blob
	seed.material_override = FX.mat(Color("c8f08a"), true)
	add_child(seed)
func _physics_process(delta: float) -> void:
	if _done: return
	var source = _source.get_ref() if _source else null
	var target = _target.get_ref() if _target else null
	if not is_instance_valid(source) or source.is_dead() or not source.is_encounter_active() or not is_instance_valid(target) or target.is_dead():
		queue_free()
		return
	_life -= delta
	if _life <= 0:
		queue_free()
		return
	var hit := move_and_collide(_direction * speed * delta)
	if hit == null: return
	if not _done:
		_done = true
		var receiver = hit.get_collider()
		if receiver == target:
			if receiver.has_method("take_direct_damage"): receiver.take_direct_damage(damage, source.global_position)
			else: receiver.take_damage(damage)
		elif receiver is Node and receiver.is_in_group("breakable_cover"): receiver.take_damage(damage)
		FX.burst(get_parent(), hit.get_position(), Color("c8f08a"), 0.3)
	hide()
	queue_free()
