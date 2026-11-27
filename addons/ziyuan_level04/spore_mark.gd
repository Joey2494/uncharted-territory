extends Node3D
## 三点孢弹实体：从法杖飞向发射时锁定的位置，落地爆炸并留下毒液。
## 保留旧文件名以兼容模块引用；没有落点标记、阴影圆或范围提示。
const FX = preload("effects.gd")
const Collision = preload("res://scenes/skills/enemy_attack_collision.gd")
var _source: WeakRef
var _target: WeakRef
var _fuse := 0.9
var _age := 0.0
var _visual: MeshInstance3D
var _origin := Vector3.ZERO
var _destination := Vector3.ZERO
var _done := false
func launch(source: Node3D, target: Node3D, at: Vector3, fuse: float) -> void:
	add_to_group("l4_hazards")
	_source = weakref(source)
	_target = weakref(target)
	_fuse = fuse
	_destination = at + Vector3.UP * 0.05
	_origin = source.global_position + Vector3(0, 2.7, 0) if source.is_inside_tree() else _destination + Vector3.UP * 3
	global_position = _origin
	_visual = MeshInstance3D.new()
	var seed := SphereMesh.new()
	seed.radius = 0.17
	seed.height = 0.34
	seed.material = FX.mat(Color("b4a0ed"), true)
	_visual.mesh = seed
	add_child(_visual)
func _physics_process(delta: float) -> void:
	if _done: return
	var source = _source.get_ref() if _source else null
	if not is_instance_valid(source) or not source.is_encounter_active():
		queue_free()
		return
	var sphere := SphereShape3D.new()
	sphere.radius = 0.17
	var excluded: Array[RID] = []
	if source is CollisionObject3D: excluded.append(source.get_rid())
	var end_age := minf(_fuse, _age + delta)
	# Subdivide the arc so a long frame cannot cut through a wall or the player.
	while _age < end_age:
		_age = minf(end_age, _age + 0.025)
		var t := clampf(_age / maxf(_fuse, 0.01), 0, 1)
		var next := _origin.lerp(_destination, t) + Vector3.UP * sin(t * PI) * 1.5
		var hit := Collision.sweep(self, global_position, next, sphere, excluded)
		if not hit.is_empty():
			global_position = hit.position
			_done = true
			var target = _target.get_ref() if _target else null
			if hit.collider == target or hit.normal.y > 0.65:
				_explode()
			else:
				FX.burst(get_parent(), global_position, Color("b4a0ed"), 0.4)
				if hit.collider is Node and hit.collider.is_in_group("breakable_cover"): hit.collider.take_damage(source.definition.damage)
			hide()
			queue_free()
			return
		global_position = next
	if _age >= _fuse:
		_done = true
		_explode()
		queue_free()
func _explode() -> void:
	var source = _source.get_ref() if _source else null
	var target = _target.get_ref() if _target else null
	if not is_instance_valid(source) or not is_instance_valid(target) or target.is_dead(): return
	var offset: Vector3 = target.global_position - global_position
	offset.y = 0
	FX.burst(get_parent(), global_position + Vector3.UP * 0.1, Color("9ac77a"), 1.6)
	if offset.length() <= 1.6 + 0.3:
		var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, target.global_position + Vector3.UP * 0.8, 1)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return
		# 尊重翻滚无敌与守护，由玩家伤害接口统一处理。
		if target.has_method("take_direct_damage"): target.take_direct_damage(source.definition.damage, global_position)
		else: target.take_damage(source.definition.damage)
	source._spawn_pool(global_position)
