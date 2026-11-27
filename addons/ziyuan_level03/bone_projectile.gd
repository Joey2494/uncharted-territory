extends CharacterBody3D
const FX=preload("effects.gd")
var _source: WeakRef
var _target: WeakRef
var _direction := Vector3.FORWARD
var damage := 2
var speed := 12.0
var sand_curse := false
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
	mass.material_override=FX.mat(Color("c6a16b") if sand_curse else Color("59472f"),sand_curse)
	add_child(mass)
	for i in 4:
		var offset:=Vector3(sin(i*2.4)*0.09,cos(i*1.8)*0.08,0)
		FX.line(self,offset,-_direction*(0.22+i*0.07)+offset*0.4,FX.mat(Color("3b352b")),0.025-i*0.004)
func _physics_process(delta: float) -> void:
	if _done: return
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
			var inventory: Node=receiver.get_node_or_null("ItemInventory")
			var guarded: bool=is_instance_valid(inventory) and inventory.get("guard_active")==true
			var accepted: bool=receiver.take_direct_damage(damage,source.global_position) if receiver.has_method("take_direct_damage") else receiver.take_damage(damage)
			if accepted and sand_curse and not guarded:
				source.status_requested.emit(target,"slow",1.4,0.6)
				if target.has_method("apply_level03_slow"): target.apply_level03_slow(1.4,0.6)
		elif receiver is Node and receiver.is_in_group("breakable_cover"):
			receiver.take_damage(damage)
		FX.burst(get_parent(),hit.get_position(),Color("78684a"),0.35)
	hide()
	queue_free()
