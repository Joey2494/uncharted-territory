extends Node3D
## H、I 百叶顶光。CPU 命中与材质共用椭圆半径、左右侧和角度区间，无视物体高度。
const LIGHT := preload("res://scenes/dungeon/level04/shutter_light.gdshader")
const CHOOSE := 3.0
const LOCK_END := 4.5
const ROUND_END := 6.0
const BAND_WIDTH := 0.14
var radii := Vector2.ONE
var side := -1
var elapsed := 0.0
var active := false
var harmless := false
var hit_ids := {}
var effect := ShaderMaterial.new()

func build(layout: Node3D, center: Vector3, bounds: Vector2) -> void:
	global_position = center
	radii = bounds
	effect.shader = LIGHT
	effect.set_shader_parameter("center",Vector2(center.x,center.z))
	effect.set_shader_parameter("radii",radii)
	# 渲染每片受光表面的实际世界坐标，石挡顶部和地面按相同投影着色。
	for mesh: MeshInstance3D in layout.find_children("*","MeshInstance3D",true,false):
		var offset := mesh.global_position - center
		if absf(offset.x) <= radii.x+1.0 and absf(offset.z) <= radii.y+1.0:
			mesh.material_overlay = effect

func begin(which: int, demo: bool) -> void:
	side = which
	harmless = demo
	elapsed = 0
	active = true
	hit_ids.clear()
	_refresh()

func stop() -> void:
	active = false
	effect.set_shader_parameter("enabled",false)

func choose(which: int) -> bool:
	if not active or elapsed >= CHOOSE: return false
	side = which
	_refresh()
	return true

func _front(time: float) -> float:
	return clampf((time-LOCK_END)/(ROUND_END-LOCK_END),0,1)*PI

func _inside(point: Vector3, from_angle: float, to_angle: float) -> bool:
	var relative := point-global_position
	var p := Vector2(relative.x/radii.x,relative.z/radii.y)
	if p.length_squared() > 1.0 or p.x*side < 0: return false
	var angle := atan2(p.x*side,-p.y)
	return angle >= from_angle and angle <= to_angle

## 更新一次扫光并返回该轮是否结束。长帧检查前后位置间的扫掠角。
func advance(delta: float, targets: Array) -> bool:
	if not active: return false
	var previous := elapsed
	elapsed = minf(ROUND_END, elapsed+delta)
	if not harmless and elapsed > LOCK_END:
		var low := maxf(0,_front(previous)-BAND_WIDTH)
		var high := minf(PI,_front(elapsed)+BAND_WIDTH)
		for target in targets:
			if not is_instance_valid(target) or target.is_dead(): continue
			var key: int = target.get_instance_id()
			if not hit_ids.has(key) and _inside(target.global_position,low,high):
				hit_ids[key] = true
				target.take_damage(2 if target is CharacterBody3D and target.has_method("is_encounter_active") else 1)
	_refresh()
	if elapsed < ROUND_END: return false
	stop()
	return true

func _refresh() -> void:
	var angles := Vector2(0,PI)
	var tint := Color(0.83,0.64,0.28,0.24)
	if elapsed >= LOCK_END:
		angles = Vector2(maxf(0,_front(elapsed)-BAND_WIDTH),minf(PI,_front(elapsed)+BAND_WIDTH))
		tint = Color(1.0,0.91,0.48,0.85)
	elif elapsed >= CHOOSE:
		tint = Color(1,0.42,0.12,0.48+0.10*sin(elapsed*13))
	if harmless: tint = Color(0.44,0.91,0.92,tint.a)
	effect.set_shader_parameter("side",float(side))
	effect.set_shader_parameter("angles",angles)
	effect.set_shader_parameter("tint",tint)
	effect.set_shader_parameter("enabled",active)
