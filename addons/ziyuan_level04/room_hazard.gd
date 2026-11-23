extends Node3D
## 只绘制正在生效的热浪 / 刺丛；没有预告网格。
const FX = preload("effects.gd")
var _source: WeakRef
var _target: WeakRef
var kind := "heat"
var age := 0.0
var radius := 0.2
var hit := false
var visual: Node3D
func launch(source: Node3D, target: Node3D, mode: String, at: Vector3) -> void:
	_source = weakref(source)
	_target = weakref(target)
	kind = mode
	add_to_group("l4_hazards")
	global_position = at
	visual = Node3D.new()
	add_child(visual)
	if kind == "heat":
		# 飞散的火舌组成活动波前，无地面圆盘或范围填色。
		for i in 36:
			var flame := MeshInstance3D.new()
			var shape := SphereMesh.new()
			shape.radius = 0.12
			shape.height = 0.45
			shape.material = FX.mat(Color("ffac55"), true)
			flame.mesh = shape
			visual.add_child(flame)
	else:
		for i in 9:
			var dir := Vector3(sin(i * 2.4), 0, cos(i * 2.4))
			var thorn := FX.line(visual, dir * 0.3, dir * 0.8 + Vector3.UP * (0.8 + i % 3 * 0.2), FX.mat(Color("dbe1ba")), 0.12)
			(thorn.mesh as CylinderMesh).top_radius = 0
func _physics_process(delta: float) -> void:
	var source = _source.get_ref() if _source else null
	var target = _target.get_ref() if _target else null
	if not is_instance_valid(source) or not source.is_encounter_active() or not is_instance_valid(target) or target.is_dead():
		queue_free()
		return
	age += delta
	var offset: Vector3 = target.global_position - global_position
	offset.y = 0
	if kind == "heat":
		var previous := radius
		radius += delta * 4.5
		for i in visual.get_child_count():
			var a := i * TAU / visual.get_child_count()
			visual.get_child(i).position = Vector3(sin(a) * radius, 0.35 + sin(age * 10 + i) * 0.12, cos(a) * radius)
		if not hit and offset.length() >= previous - 0.4 and offset.length() <= radius + 0.4:
			if source.can_see(target.global_position): _damage(source, target)
		if radius >= 9: queue_free()
	else:
		visual.scale.y = minf(1, age / 0.16)
		if not hit and offset.length() <= 1.05 and source.can_see(target.global_position): _damage(source, target)
		if age >= 2.2: queue_free()
func _damage(source: Node3D, target: Node3D) -> void:
	hit = true
	if target.has_method("take_direct_damage"): target.take_direct_damage(source.definition.damage, global_position)
	else: target.take_damage(source.definition.damage)
