@tool
extends Node3D
## 参考图的代码原生 3D 原型。正面 -Z，脚底 y=0，独立于战斗判定。
const FX = preload("effects.gd")
const INK := Color("151b29")
const FOLD := Color("293244")
const GOLD := Color("ba9a60")
const SILVER := Color("9aa8ba")
const SKIN := Color("ded0d1")
var body: Node3D
var head: Node3D
var left_arm: Node3D
var right_arm: Node3D
var raven: Node3D
var clock := 0.0

func _ready() -> void:
	build("witch", INK)

func mesh_at(parent: Node3D, label: String, mesh: Mesh, at: Vector3, stretch := Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	parent.add_child(node)
	node.position = at
	node.scale = stretch
	return node

func orb(radius: float, color: Color, glow := false) -> SphereMesh:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	shape.radial_segments = 24
	shape.rings = 16
	shape.material = FX.mat(color, glow)
	return shape

func cone(top: float, bottom: float, height: float, color: Color) -> CylinderMesh:
	var shape := CylinderMesh.new()
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = height
	shape.radial_segments = 32
	shape.material = FX.mat(color)
	return shape

func stroke(parent: Node3D, points: Array, color := GOLD, width := 0.012) -> void:
	for i in points.size() - 1:
		FX.line(parent, points[i], points[i + 1], FX.mat(color), width)

func build(_id: String, _tint: Color) -> void:
	if is_instance_valid(body): return
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	# 分层长裙：截面有褶皱，裙裾与前襟刺绣都是实体网格。
	var skirt := SurfaceTool.new()
	skirt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var heights := [0.06, 0.35, 1.2, 1.85, 2.06]
	var radii := [0.93, 0.88, 0.57, 0.31, 0.32]
	for row in 4:
		for i in 64:
			var quad: Array[Vector3] = []
			for pair in [Vector2i(row, i), Vector2i(row + 1, i), Vector2i(row + 1, i + 1), Vector2i(row, i + 1)]:
				var a: float = TAU * pair.y / 64.0
				var r: float = radii[pair.x] * (1 + 0.045 * cos(a * 16))
				quad.append(Vector3(sin(a) * r, heights[pair.x], cos(a) * r * 0.77))
			for index in [0, 1, 2, 0, 2, 3]: skirt.add_vertex(quad[index])
	skirt.generate_normals()
	skirt.set_material(FX.mat(INK))
	mesh_at(body, "PleatedRobe", skirt.commit(), Vector3.ZERO)
	mesh_at(body, "Bodice", orb(0.5, FOLD), Vector3(0, 2.22, 0), Vector3(0.82, 0.95, 0.63))
	mesh_at(body, "WaistBelt", cone(0.33, 0.36, 0.14, INK), Vector3(0, 1.89, 0))
	mesh_at(body, "Buckle", orb(0.095, GOLD), Vector3(0, 1.91, -0.36), Vector3(1, 1.15, 0.3))
	mesh_at(body, "BuckleGem", orb(0.045, Color("7870a3")), Vector3(0, 1.91, -0.39))
	for side in [-1.0, 1.0]:
		stroke(body, [Vector3(side * 0.28, 1.78, -0.29), Vector3(side * 0.48, 1.0, -0.44), Vector3(side * 0.7, 0.18, -0.5)])
		for j in 7:
			var y := 0.3 + j * 0.2
			var x: float = side * (0.62 - j * 0.045)
			var z := -0.65 + j * 0.042
			stroke(body, [Vector3(x, y, z), Vector3(x + side * 0.1, y + 0.07, z), Vector3(x + side * 0.13, y + 0.15, z), Vector3(x + side * 0.04, y + 0.17, z)])
		stroke(body, [Vector3(0, 0.23, -0.73), Vector3(side * 0.15, 0.52, -0.68), Vector3(0, 0.81, -0.58), Vector3(side * 0.14, 1.05, -0.49), Vector3(0, 1.3, -0.44)])
	for i in 48:
		var a := TAU * i / 48.0
		var b := TAU * (i + 1) / 48.0
		stroke(body, [Vector3(sin(a) * 0.935, 0.13, cos(a) * 0.72), Vector3(sin(b) * 0.935, 0.13, cos(b) * 0.72)])
	mesh_at(body, "Collar", cone(0.22, 0.25, 0.24, INK), Vector3(0, 2.64, 0))
	for side in [-1.0, 1.0]:
		var shoulder := mesh_at(body, "Mantle", cone(0, 0.35, 0.72, INK), Vector3(side * 0.44, 2.5, 0.07), Vector3(1, 0.55, 0.7))
		shoulder.rotation.z = side * -0.9
	head = Node3D.new()
	head.name = "Head"
	body.add_child(head)
	head.position.y = 2.95
	# 兜帽侧后方与压低的前额布面相连，帽沿落在眉眼上方。
	var hood := SurfaceTool.new()
	hood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var layers := [Vector3(0.39, -0.25, 0.1), Vector3(0.43, 0.1, 0.1), Vector3(0.31, 0.36, 0.06), Vector3(0.025, 0.56, 0.0)]
	for row in 3:
		for i in 28:
			var quad: Array[Vector3] = []
			for pair in [Vector2i(row, i), Vector2i(row + 1, i), Vector2i(row + 1, i + 1), Vector2i(row, i + 1)]:
				var a := lerpf(-2.3, 2.3, pair.y / 28.0)
				var l: Vector3 = layers[pair.x]
				quad.append(Vector3(sin(a) * l.x, l.y, cos(a) * l.x + l.z - 0.12))
			for index in [0, 1, 2, 0, 2, 3]: hood.add_vertex(quad[index])
	hood.generate_normals()
	hood.set_material(FX.mat(INK))
	mesh_at(head, "PointedHood", hood.commit(), Vector3.ZERO)
	# 真正覆盖额头的布面，而非仅把侧边帽饰下移。下缘中间略低，
	# 与两侧形成压低的尖拱开口，眼睛仍位于帽沿以下。
	var brow_hood := SurfaceTool.new()
	brow_hood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var brow_layers := [Vector3(0.32, 0.13, -0.365), Vector3(0.34, 0.30, -0.34), Vector3(0.25, 0.44, -0.24), Vector3(0.025, 0.56, -0.12)]
	for row in 3:
		for i in 24:
			var quad: Array[Vector3] = []
			for pair in [Vector2i(row, i), Vector2i(row + 1, i), Vector2i(row + 1, i + 1), Vector2i(row, i + 1)]:
				var u: float = pair.y / 12.0 - 1.0
				var layer: Vector3 = brow_layers[pair.x]
				var edge_lift: float = absf(u) * (0.10 if pair.x == 0 else 0.025 if pair.x == 1 else 0.0)
				quad.append(Vector3(u * layer.x, layer.y + edge_lift, layer.z + u * u * 0.035))
			for index in [0, 1, 2, 0, 2, 3]: brow_hood.add_vertex(quad[index])
	brow_hood.generate_normals()
	brow_hood.set_material(FX.mat(INK))
	mesh_at(head, "LoweredHoodBrow", brow_hood.commit(), Vector3.ZERO)
	var brim: Array = []
	for i in 25:
		var u := i / 12.0 - 1.0
		brim.append(Vector3(u * 0.32, 0.13 + absf(u) * 0.1, -0.369 + u * u * 0.035))
	stroke(head, brim, GOLD.darkened(0.25), 0.011)
	for side in [-1.0, 1.0]:
		stroke(head, [Vector3(side * 0.29, -0.25, -0.28), Vector3(side * 0.32, 0.1, -0.31), Vector3(side * 0.32, 0.23, -0.334)], GOLD, 0.018)
	mesh_at(head, "Face", orb(0.27, SKIN), Vector3(0, 0, -0.1), Vector3(0.85, 1.2, 0.8))
	mesh_at(head, "Nose", orb(0.047, SKIN), Vector3(0, -0.015, -0.323), Vector3(0.75, 1.5, 1))
	mesh_at(head, "Lips", orb(0.047, Color("79364f")), Vector3(0, -0.135, -0.3), Vector3(1, 0.3, 0.45))
	for side in [-1.0, 1.0]:
		mesh_at(head, "EyeShadow", orb(0.069, Color("63364e")), Vector3(side * 0.105, 0.068, -0.29), Vector3(1, 0.55, 0.3))
		mesh_at(head, "CrimsonEye", orb(0.036, Color("e35a83"), true), Vector3(side * 0.105, 0.065, -0.309), Vector3(1, 0.6, 0.5))
		mesh_at(head, "Pupil", orb(0.016, INK), Vector3(side * 0.105, 0.065, -0.327))
		mesh_at(head, "Earring", orb(0.057, GOLD), Vector3(side * 0.25, -0.19, -0.11), Vector3(0.65, 1.7, 0.5))
		for strand in 4:
			var points: Array = []
			for j in 17:
				var t := j / 16.0
				points.append(Vector3(side * (0.23 + sin(t * TAU + strand * 0.5) * 0.075 + t * 0.15), 0.19 - t * (0.94 + strand * 0.05), -0.16 + strand * 0.035 - sin(t * PI) * 0.03))
			stroke(head, points, SILVER.darkened(strand * 0.12), 0.035)
	left_arm = arm(-1.0)
	right_arm = arm(1.0)
	# 法杖挂在右手动作节点；默认保持直立。
	var staff := Node3D.new()
	staff.name = "Staff"
	right_arm.add_child(staff)
	staff.position = Vector3(0.08, -0.72, -0.12)
	FX.line(staff, Vector3(0, -1.55, 0), Vector3(0, 1.25, 0), FX.mat(Color("655846")), 0.045)
	for i in 6:
		mesh_at(staff, "GoldBinding", cone(0.075, 0.075, 0.035, GOLD), Vector3(0, 0.8 + i * 0.07, 0))
	for side in [-1.0, 1.0]:
		stroke(staff, [Vector3(0, 1.1, 0), Vector3(side * 0.21, 1.35, 0), Vector3(side * 0.27, 1.57, 0), Vector3(side * 0.14, 1.8, 0)], GOLD, 0.045)
	mesh_at(staff, "MoonCrystal", orb(0.18, Color("b2afff"), true), Vector3(0, 1.55, 0))
	var light := OmniLight3D.new()
	light.light_color = Color("b4a3ff")
	light.light_energy = 0.8
	light.omni_range = 2.2
	staff.add_child(light)
	light.position.y = 1.55
	raven = bird(left_arm, Vector3(-0.15, -0.62, -0.32), 0.65)
	pose(0, 0, 0, 0)

func arm(side: float) -> Node3D:
	var node := Node3D.new()
	node.name = "ArmL" if side < 0 else "ArmR"
	add_child(node)
	node.position = Vector3(side * 0.43, 2.5, 0)
	var sleeve := mesh_at(node, "BellSleeve", cone(0.12, 0.26, 0.68, INK), Vector3(side * 0.13, -0.31, 0))
	sleeve.rotation.z = side * 0.35
	mesh_at(node, "Cuff", cone(0.26, 0.27, 0.035, GOLD), Vector3(side * 0.25, -0.64, -0.05))
	mesh_at(node, "Hand", orb(0.1, SKIN), Vector3(side * 0.25, -0.73, -0.07), Vector3(0.7, 1, 0.75))
	return node

func bird(parent: Node3D, at: Vector3, size: float) -> Node3D:
	var node := Node3D.new()
	node.name = "Raven"
	parent.add_child(node)
	node.position = at
	node.scale = Vector3.ONE * size
	mesh_at(node, "Body", orb(0.19, Color("111924")), Vector3.ZERO, Vector3(0.8, 1.1, 1.4))
	mesh_at(node, "Head", orb(0.13, INK), Vector3(0, 0.2, -0.2))
	var beak := mesh_at(node, "Beak", cone(0, 0.06, 0.22, Color("526072")), Vector3(0, 0.2, -0.36))
	beak.rotation.x = -PI * 0.5
	for side in [-1.0, 1.0]:
		mesh_at(node, "Eye", orb(0.022, Color("c2a9e8"), true), Vector3(side * 0.105, 0.22, -0.25))
		for i in 6:
			var feather := mesh_at(node, "WingFeather", orb(0.12, INK), Vector3(side * (0.2 + i * 0.085), 0.08 + i * 0.04, i * 0.035), Vector3(0.42, 0.4, 3))
			feather.rotation.z = side * -0.3
	for i in 3:
		mesh_at(node, "Tail", orb(0.1, INK), Vector3((i - 1) * 0.06, -0.08, 0.3), Vector3(0.45, 0.4, 3))
	return node

func pose(state: int, progress: float, moving: float, delta: float, strike := 0) -> void:
	if not is_instance_valid(body): return
	clock += delta
	body.position.y = sin(clock * 1.6) * 0.025
	head.rotation.y = sin(clock * 0.7) * 0.04
	left_arm.rotation = Vector3(-0.7, 0, -0.65)
	right_arm.rotation = Vector3(0, 0, 0.2)
	if state == 3:
		left_arm.rotation.x -= sin(progress * PI) * 0.5
		right_arm.rotation.x -= sin(progress * PI) * 0.22
	elif state == 5:
		left_arm.rotation.z = -1.1
	if is_instance_valid(raven):
		raven.basis = left_arm.basis.inverse().scaled(Vector3.ONE * 0.65)
		raven.rotate_y(sin(clock * 0.9) * 0.14)
