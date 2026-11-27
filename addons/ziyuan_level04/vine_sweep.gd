extends Node3D
## 藤蔓横扫（§12.4）：宽 2 的条带跨整个场地纵向展开，波前从一侧扫过。
## 波前经过玩家所在位置时，若玩家仍在条带内则造成伤害；一次横扫只登记一次，
## 翻滚无敌可穿过条带。条带位置在预警开始时锁定，不追踪玩家。
const FX = preload("effects.gd")
const Collision = preload("res://scenes/skills/enemy_attack_collision.gd")
var _source: WeakRef
var _target: WeakRef
var _travel := 1.6
var _age := 0.0
var _start_z := -11.0
var _end_z := 11.0
var _band_x := 0.0
var _wave: MeshInstance3D
var _done := false
func launch(source: Node3D, target: Node3D, band_x: float) -> void:
	add_to_group("l4_hazards")
	_source = weakref(source)
	_target = weakref(target)
	_band_x = band_x
	_start_z = source.arena_center.z - source.arena_size.y * 0.5 + 1.0
	_end_z = source.arena_center.z + source.arena_size.y * 0.5 - 1.0
	_wave = MeshInstance3D.new()
	# 只显示正在扫过的实体藤蔓，未扫过的地面没有条带或范围底色。
	var vine := CylinderMesh.new()
	vine.top_radius = 0.16
	vine.bottom_radius = 0.22
	vine.height = 2.0
	vine.radial_segments = 10
	vine.material = FX.mat(Color("526954"))
	_wave.mesh = vine
	add_child(_wave)
	_wave.rotation.z = PI * 0.5
	_wave.position = Vector3(_band_x, source.arena_center.y + 0.3, _start_z)
	for i in 7:
		var thorn := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.09
		cone.height = 0.4
		cone.material = FX.mat(Color("a48ec1"))
		thorn.mesh = cone
		_wave.add_child(thorn)
		thorn.position = Vector3(0.18, -0.85 + i * 0.28, 0)
		thorn.rotation.z = -PI * 0.5
func _physics_process(delta: float) -> void:
	if _done: return
	var source = _source.get_ref() if _source else null
	var target = _target.get_ref() if _target else null
	if not is_instance_valid(source) or not source.is_encounter_active() or not is_instance_valid(target) or target.is_dead():
		queue_free()
		return
	_age += delta
	var t := clampf(_age / _travel, 0.0, 1.0)
	var wave_z := lerpf(_start_z, _end_z, t)
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 0.4, 0.3)
	var excluded: Array[RID] = []
	if source is CollisionObject3D: excluded.append(source.get_rid())
	var contact := Collision.sweep(self, _wave.global_position, Vector3(_band_x, _wave.global_position.y, wave_z), shape, excluded)
	if not contact.is_empty():
		_done = true
		if contact.collider == target:
			if target.has_method("take_direct_damage"): target.take_direct_damage(source.definition.damage, contact.position)
			else: target.take_damage(source.definition.damage)
		elif contact.collider is Node and contact.collider.is_in_group("breakable_cover"): contact.collider.take_damage(source.definition.damage)
		FX.burst(get_parent(), contact.position, Color("d9a3ff"), 0.6)
		hide()
		queue_free()
		return
	_wave.position.z = wave_z
	if t >= 1.0:
		queue_free()
