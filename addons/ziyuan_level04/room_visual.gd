@tool
extends Node3D
const FX = preload("effects.gd")
@export_enum("dawn_shade", "dawn_echo", "sun_puppet", "iron_thistle", "raven_roost") var enemy_id := "dawn_shade"
var body: Node3D
var birds: Array[Node3D] = []
var limbs: Array[Node3D] = []
var sun: Node3D
var _clock := 0.0
func _ready() -> void: build(enemy_id)
func orb(parent: Node3D, at: Vector3, scale_by: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mesh.radial_segments = 16
	mesh.rings = 10
	mesh.material = FX.mat(color, glow)
	node.mesh = mesh
	parent.add_child(node)
	node.position = at
	node.scale = scale_by
	return node
func spike(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var node := FX.line(parent, a, b, FX.mat(color), radius)
	(node.mesh as CylinderMesh).top_radius = 0
func build(id: String) -> void:
	if is_instance_valid(body): return
	enemy_id = id
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	match id:
		"dawn_shade", "dawn_echo":
			# 多层透明光纱，没有木、骨或皮肤实体。
			for i in 5:
				var shade := Color(0.95, 0.86 + i * 0.02, 0.68 + i * 0.04, 0.10 + i * 0.025)
				var veil := orb(body, Vector3(sin(i * 2.1) * 0.1, 1.0, cos(i * 2.1) * 0.08), Vector3(0.9 - i * 0.09, 1.9 - i * 0.08, 0.6), shade, true)
				veil.material_override = _mist_material(shade)
			var face := orb(body, Vector3(0, 2.05, 0), Vector3(0.45, 0.6, 0.4), Color(1, 0.94, 0.8, 0.38), true)
			face.material_override = _mist_material(Color(1, 0.94, 0.8, 0.38))
			for side in [-1.0, 1.0]:
				var arm := orb(body, Vector3(side * 0.6, 1.35, 0), Vector3(0.22, 1.1, 0.17), Color(1, 0.91, 0.7, 0.2), true)
				arm.rotation.z = side * 0.4
				arm.material_override = _mist_material(Color(1, 0.91, 0.7, 0.2))
			for i in 16:
				orb(body, Vector3(sin(i * 2.4) * 0.7, 0.2 + i * 0.13, cos(i * 2.4) * 0.4), Vector3.ONE * 0.035, Color("f4dfb3"), true)
		"sun_puppet":
			orb(body, Vector3(0, 1.35, 0), Vector3(0.95, 1.15, 0.65), Color("543728"))
			orb(body, Vector3(0, 2.18, 0), Vector3(0.62, 0.68, 0.55), Color("392b23"))
			# 熔光沿椭圆木躯表面流动，交错断口保留烧裂木纹感。
			for i in 9:
				var x := -0.36 + i * 0.09
				for j in 12:
					var y := 0.87 + j * 0.075
					var yy := y + 0.075
					var px := x * sqrt(maxf(0.03, 1 - pow((y - 1.35) / 0.58, 2)))
					var qx := x * sqrt(maxf(0.03, 1 - pow((yy - 1.35) / 0.58, 2)))
					var z := -0.335 * sqrt(maxf(0.01, 1 - pow(px / 0.48, 2) - pow((y - 1.35) / 0.58, 2))) - 0.01
					var zz := -0.335 * sqrt(maxf(0.01, 1 - pow(qx / 0.48, 2) - pow((yy - 1.35) / 0.58, 2))) - 0.01
					FX.line(body, Vector3(px, y, z), Vector3(qx + sin(j * 1.5 + i) * 0.012, yy, zz), FX.mat(Color("ff8b32"), true), 0.012)
			for side in [-1.0, 1.0]:
				var limb := Node3D.new()
				body.add_child(limb)
				limb.position = Vector3(side * 0.6, 1.75, 0)
				FX.line(limb, Vector3.ZERO, Vector3(side * 0.16, -0.9, 0), FX.mat(Color("705039")), 0.13)
				orb(limb, Vector3(side * 0.16, -0.92, 0), Vector3.ONE * 0.28, Color("f39a42"), true)
				limbs.append(limb)
				FX.line(body, Vector3(side * 0.24, 0.95, 0), Vector3(side * 0.34, 0.15, 0), FX.mat(Color("583c2b")), 0.14)
				FX.line(body, Vector3(side * 0.24, 0.9, -0.1), Vector3(side * 0.34, 0.15, -0.1), FX.mat(Color("ed752d"), true), 0.022)
				orb(body, Vector3(side * 0.13, 2.22, -0.25), Vector3(0.10, 0.07, 0.08), Color("ffecaa"), true)
			sun = Node3D.new()
			body.add_child(sun)
			sun.position.y = 2.85
			orb(sun, Vector3.ZERO, Vector3.ONE * 0.43, Color("ffbb42"), true)
			for i in 7:
				var a := i * TAU / 7
				spike(sun, Vector3(sin(a), cos(a), 0) * 0.22, Vector3(sin(a), cos(a), 0) * 0.4, 0.07, Color("ff6c29"))
		"iron_thistle":
			FX.line(body, Vector3(0, 0.15, 0), Vector3(0, 2.0, 0), FX.mat(Color("465d54")), 0.23)
			orb(body, Vector3(0, 2.0, 0), Vector3(1.0, 0.9, 1.0), Color("686654"))
			for i in 22:
				var a := i * 2.4
				var dir := Vector3(sin(a), sin(i * 1.7) * 0.6, cos(a)).normalized()
				spike(body, Vector3(0, 2.0, 0) + dir * 0.4, Vector3(0, 2.0, 0) + dir * 0.9, 0.08, Color("e6edcf"))
			for i in 8:
				var dir := Vector3(sin(i * TAU / 8), 0, cos(i * TAU / 8))
				spike(body, Vector3(0, 0.65, 0), dir * 1.0 + Vector3.UP * 0.2, 0.18, Color("4c6254"))
				spike(body, dir * 0.35 + Vector3.UP, dir * 0.7 + Vector3.UP * 1.5, 0.1, Color("b5bc9e"))
		"raven_roost":
			for i in 7:
				var bird := make_bird(body)
				bird.position = Vector3(sin(i * TAU / 7) * 0.9, 1.0 + (i % 3) * 0.3, cos(i * TAU / 7) * 0.9)
				birds.append(bird)
func _mist_material(color: Color) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 mist_color : source_color;
void fragment() {
    float facing = pow(max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 1.25);
    float drift = 0.72 + 0.28 * sin(UV.y * 23.0 + TIME * 1.7 + sin(UV.x * 18.0));
    ALBEDO = mist_color.rgb;
    ALPHA = mist_color.a * facing * drift;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("mist_color", color)
	return material
func make_bird(parent: Node3D) -> Node3D:
	var bird := Node3D.new()
	parent.add_child(bird)
	orb(bird, Vector3.ZERO, Vector3(0.24, 0.3, 0.46), Color("151c2a"))
	orb(bird, Vector3(0, 0.15, -0.2), Vector3.ONE * 0.24, Color("222b3a"))
	spike(bird, Vector3(0, 0.15, -0.27), Vector3(0, 0.13, -0.43), 0.055, Color("79818b"))
	for side in [-1.0, 1.0]:
		orb(bird, Vector3(side * 0.09, 0.19, -0.27), Vector3.ONE * 0.035, Color("c6a6e7"), true)
		var wing := Node3D.new()
		wing.name = "WingL" if side < 0 else "WingR"
		bird.add_child(wing)
		for j in 5:
			orb(wing, Vector3(side * (0.17 + j * 0.08), 0, j * 0.025), Vector3(0.075, 0.045, 0.45), Color("303b50"))
	orb(bird, Vector3(0, -0.04, 0.3), Vector3(0.15, 0.05, 0.4), Color("151c2a"))
	return bird
func pose(state: int, progress: float, moving: float, delta: float, _strike := 0) -> void:
	_clock += delta
	if not is_instance_valid(body): return
	if enemy_id in ["dawn_shade", "dawn_echo"]:
		body.position.y = sin(_clock * 2) * 0.12
		body.rotation.y = sin(_clock) * 0.12
	elif enemy_id == "sun_puppet":
		body.rotation.z = sin(_clock * 4) * minf(moving, 1) * 0.06
		for i in limbs.size(): limbs[i].rotation.x = sin(_clock * 4 + i * PI) * 0.3
		sun.position.x = sin(_clock * 3) * 0.12
		sun.rotation.z = sin(_clock * 2) * 0.25
	elif enemy_id == "iron_thistle": body.rotation.y = sin(_clock) * 0.025
	# 原地收缩/后仰蓄力，释放后回落，收招时逐渐恢复站姿。
	body.scale = Vector3.ONE
	body.rotation.x = 0.0
	if state == 2:
		body.scale = Vector3(1.0 + progress * 0.12, 1.0 - progress * 0.18, 1.0 + progress * 0.12)
		body.rotation.x = progress * 0.18
		for limb in limbs: limb.rotation.x = -progress * 1.6
	elif state == 3:
		body.rotation.x = -sin(progress * PI) * 0.22
		for limb in limbs: limb.rotation.x = -1.6 + progress * 2.0
	elif state == 4:
		body.rotation.x = -(1.0 - progress) * 0.15
		for limb in limbs: limb.rotation.x = (1.0 - progress) * 0.4
	for i in birds.size():
		for side in [-1, 1]:
			var wing := birds[i].get_node("WingL" if side < 0 else "WingR") as Node3D
			wing.rotation.z = sin(_clock * 13 + i) * 0.5 * side
