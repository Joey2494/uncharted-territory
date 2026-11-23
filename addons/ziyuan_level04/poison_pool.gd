extends Area3D
## 孢冠女巫的毒池（§12.4）：持续 4 秒、每秒 1 点。首次进入立即结算一次，
## 之后同一毒池至少间隔 1 秒；反复进出不会加快跳伤（§6.2 地面危险规则）。
## 只伤害玩家，不伤害孢子守卫；撤退冻结由房间停止时统一清理。
const FX = preload("effects.gd")
var _source: WeakRef
var _target: WeakRef
var _life := 4.0
var _age := 0.0
var _last_tick := -100.0
var _clock := 0.0
var _visual: MeshInstance3D
var _dissolving := false
func launch(source: Node3D, target: Node3D) -> void:
	add_to_group("l4_hazards")
	_source = weakref(source)
	_target = weakref(target)
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.6
	shape.shape = sphere
	add_child(shape)
	_visual = MeshInstance3D.new()
	# 已生效的毒液本体：不绘制规则圆盘、边缘线或攻击半径。
	var puddle := SphereMesh.new()
	puddle.radius = 1.0
	puddle.height = 2.0
	puddle.radial_segments = 20
	puddle.rings = 8
	puddle.material = FX.mat(Color("506c68", 0.85))
	_visual.mesh = puddle
	add_child(_visual)
	_visual.scale = Vector3(1.55, 0.055, 1.55)
	_visual.position.y = 0.06
	for i in 9:
		var bubble := MeshInstance3D.new()
		var blob := SphereMesh.new()
		blob.radius = 0.08 + (i % 3) * 0.025
		blob.height = blob.radius * 2
		blob.material = FX.mat(Color("a99cce"), true)
		bubble.mesh = blob
		add_child(bubble)
		bubble.position = Vector3(sin(i * 2.4) * 1.1, 0.1, cos(i * 2.4) * 1.1)
## 横扫沿 x 锁定条带，比较相同坐标轴。
func overlaps_band(center_x: float, half_width: float) -> bool:
	return absf(global_position.x - center_x) < half_width + 1.6
## 消散：替换、清场或寿命到期时淡出，不再跳伤。
func dissolve(replaced := false) -> void:
	if _dissolving: return
	_dissolving = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	if replaced: FX.burst(get_parent(), global_position + Vector3.UP * 0.1, Color("c9e89a"), 1.2)
	var t := create_tween()
	t.tween_property(_visual, "scale", Vector3.ONE * 0.05, 0.3)
	t.tween_callback(queue_free)
func _physics_process(delta: float) -> void:
	var source = _source.get_ref() if _source else null
	var target = _target.get_ref() if _target else null
	if not is_instance_valid(source) or not source.is_encounter_active() or not is_instance_valid(target) or target.is_dead():
		dissolve()
		return
	_age += delta
	_clock += delta
	if _age >= _life:
		dissolve()
		return
	if _clock - _last_tick >= 1.0:
		for body in get_overlapping_bodies():
			if body == target:
				var accepted: bool = target.take_direct_damage(1, global_position) if target.has_method("take_direct_damage") else target.take_damage(1)
				if accepted: _last_tick = _clock
				break
