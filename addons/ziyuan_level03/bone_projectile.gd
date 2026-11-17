extends CharacterBody3D
const FX=preload("effects.gd")
var _source: WeakRef
var _target: WeakRef
var _direction := Vector3.FORWARD
var damage := 2
var speed := 10.0
var _life := 1.7
var _done := false
func launch(source: Node3D, target: Node3D, direction: Vector3, amount: int) -> void:
	add_to_group("l3_hazards")
	_source=weakref(source)
	_target=weakref(target)
	_direction=direction.normalized()
	damage=amount
	collision_layer=0
	collision_mask=3
	add_collision_exception_with(source)
	var shape:=CollisionShape3D.new()
	var capsule:=SphereShape3D.new()
	capsule.radius=0.15
	shape.shape=capsule
	add_child(shape)
	# Stable projectile script path retained for integrations; no bone spike geometry.
	var mass:=MeshInstance3D.new()
	var blob:=SphereMesh.new()
	blob.radius=0.14
	blob.height=0.25
	blob.radial_segments=12
	blob.rings=7
	mass.mesh=blob
	mass.material_override=FX.mat(Color("59472f"))
	add_child(mass)
	for i in 4:
		var offset:=Vector3(sin(i*2.4)*0.09,cos(i*1.8)*0.08,0)
		FX.line(self,offset,-_direction*(0.22+i*0.07)+offset*0.4,FX.mat(Color("3b352b")),0.025-i*0.004)
func _physics_process(delta: float) -> void:
	var source = _source.get_ref() if _source else null
	var target = _target.get_ref() if _target else null
	if not is_instance_valid(source) or source.is_dead() or not source.is_encounter_active() or not is_instance_valid(target) or target.is_dead(): queue_free(); return
	_life-=delta
	if _life<=0: queue_free(); return
	var hit:=move_and_collide(_direction*speed*delta)
	if hit==null: return
	if not _done:
		_done=true
		var receiver=hit.get_collider()
		if receiver==target:
			if receiver.has_method("take_direct_damage"): receiver.take_direct_damage(damage,source.global_position)
			else: receiver.take_damage(damage)
		FX.burst(get_parent(),global_position,Color("78684a"),0.35)
	queue_free()
