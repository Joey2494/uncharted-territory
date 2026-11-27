extends Node3D
## 第四关原型程序化视觉。适配入口与第三关一致：build(id, tint) 建网格，
## pose(state, progress, moving, delta, strike) 驱动动作；伤害逻辑与模型互不调用计时器。
## 女巫：长袍 + 机械面罩（发光眼缝）+ 孢冠 + 肩部藤蔓。守卫：孢团 + 四肢。
## 网格均由 effects.mat 携带材质；最终布料、贴图与骨骼动画可由美术模块替换。
const FX = preload("effects.gd")
var _time := 0.0
var _body: Node3D
var _head: Node3D
var _arm_r: Node3D
var _arm_l: Node3D
var _crown: Node3D
var _legs: Array[Node3D] = []
var _rest: Dictionary = {}
var _kind := ""
func build(id: String, _tint: Color) -> void:
	if _body != null: return
	_kind = id
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	if id == "witch": _build_witch()
	else: _build_guard()
	_head = _body.get_node("Head")
	_arm_r = get_node("ArmR")
	_arm_l = get_node("ArmL")
	for path in ["Body", "Body/Head", "ArmR", "ArmL"]:
		var node := get_node_or_null(path) as Node3D
		if node: _rest[path] = node.transform
	pose(0, 0, 0, 0)
func _mesh(parent: Node3D, name: String, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = name
	n.mesh = mesh
	parent.add_child(n)
	n.position = at
	return n
func _sphere(radius: float, color: Color, glow := false) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2
	m.radial_segments = 12
	m.rings = 8
	m.material = FX.mat(color, glow)
	return m
func _cylinder(top: float, bottom: float, height: float, color: Color) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = 10
	m.material = FX.mat(color)
	return m
func _box(dims: Vector3, color: Color, glow := false) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = dims
	m.material = FX.mat(color, glow)
	return m
func _build_witch() -> void:
	# 长袍：下宽上窄的锥筒 + 肩部。
	_mesh(_body, "Robe", _cylinder(0.55, 1.15, 2.2, Color("4a5a44")), Vector3(0, 1.1, 0))
	_mesh(_body, "Torso", _sphere(0.5, Color("5f6b4a")), Vector3(0, 2.35, 0))
	_mesh(_body, "ShoulderR", _sphere(0.24, Color("3f4a3a")), Vector3(0.42, 2.6, 0))
	_mesh(_body, "ShoulderL", _sphere(0.24, Color("3f4a3a")), Vector3(-0.42, 2.6, 0))
	var head := Node3D.new()
	head.name = "Head"
	_body.add_child(head)
	head.position = Vector3(0, 2.85, 0)
	_mesh(head, "Skull", _sphere(0.34, Color("cbbba4")), Vector3.ZERO)
	# 机械面罩：前额板 + 两条发光眼缝 + 下颌呼吸格。
	_mesh(head, "Mask", _box(Vector3(0.5, 0.34, 0.18), Color("58646a")), Vector3(0, 0.02, -0.3))
	_mesh(head, "EyeR", _box(Vector3(0.14, 0.045, 0.02), Color("7ee787"), true), Vector3(0.1, 0.06, -0.4))
	_mesh(head, "EyeL", _box(Vector3(0.14, 0.045, 0.02), Color("7ee787"), true), Vector3(-0.1, 0.06, -0.4))
	_mesh(head, "Vent", _box(Vector3(0.24, 0.07, 0.02), Color("3d4a4e")), Vector3(0, -0.1, -0.38))
	# 孢冠：头顶一圈孢子。
	_crown = Node3D.new()
	_crown.name = "Crown"
	head.add_child(_crown)
	_crown.position = Vector3(0, 0.24, 0)
	for i in 7:
		var a := TAU * i / 7.0
		_mesh(_crown, "Spore%d" % i, _sphere(0.09, Color("9ac77a"), true), Vector3(sin(a) * 0.34, cos(a) * 0.1, -cos(a) * 0.34))
	# 手臂：细长施法臂。
	var arm_r := Node3D.new()
	arm_r.name = "ArmR"
	add_child(arm_r)
	arm_r.position = Vector3(0.42, 2.6, 0)
	_mesh(arm_r, "UpperR", _cylinder(0.07, 0.06, 1.1, Color("4a5a44")), Vector3(0, -0.55, 0))
	_mesh(arm_r, "HandR", _sphere(0.11, Color("cbbba4")), Vector3(0, -1.15, 0))
	var arm_l := Node3D.new()
	arm_l.name = "ArmL"
	add_child(arm_l)
	arm_l.position = Vector3(-0.42, 2.6, 0)
	_mesh(arm_l, "UpperL", _cylinder(0.07, 0.06, 1.1, Color("4a5a44")), Vector3(0, -0.55, 0))
	_mesh(arm_l, "HandL", _sphere(0.11, Color("cbbba4")), Vector3(0, -1.15, 0))
	# 肩部垂落的发光藤蔓。
	for side in [-0.42, 0.42]:
		for i in 3:
			var start := Vector3(side, 2.45, (i - 1) * 0.12)
			var end := start + Vector3(side * 0.3, -1.1 - i * 0.28, (i - 1) * 0.22)
			FX.line(_body, start, end, FX.mat(Color("5c7a4e", 0.9)), 0.028)
func _build_guard() -> void:
	_mesh(_body, "Blob", _sphere(0.34, Color("7a8f5a")), Vector3(0, 0.42, 0))
	_mesh(_body, "Ridge", _sphere(0.22, Color("8aa563")), Vector3(0, 0.62, 0))
	var head := Node3D.new()
	head.name = "Head"
	_body.add_child(head)
	head.position = Vector3(0, 0.66, 0)
	_mesh(head, "EyeR", _sphere(0.05, Color("d8f0b0"), true), Vector3(0.1, 0.03, -0.26))
	_mesh(head, "EyeL", _sphere(0.05, Color("d8f0b0"), true), Vector3(-0.1, 0.03, -0.26))
	for side in [-0.14, 0.14]:
		for back in [-0.14, 0.14]:
			var leg := Node3D.new()
			leg.name = "Leg"
			_body.add_child(leg)
			leg.position = Vector3(side, 0.22, back)
			_mesh(leg, "Limb", _cylinder(0.035, 0.03, 0.4, Color("5f7347")), Vector3(0, -0.2, 0))
			_legs.append(leg)
	var arm_r := Node3D.new()
	arm_r.name = "ArmR"
	add_child(arm_r)
	arm_r.position = Vector3(0.3, 0.45, 0)
	_mesh(arm_r, "ClawR", _sphere(0.1, Color("8aa563")), Vector3.ZERO)
	var arm_l := Node3D.new()
	arm_l.name = "ArmL"
	add_child(arm_l)
	arm_l.position = Vector3(-0.3, 0.45, 0)
	_mesh(arm_l, "ClawL", _sphere(0.1, Color("8aa563")), Vector3.ZERO)
func pose(state: int, progress: float, moving: float, delta: float, strike := 0) -> void:
	if _body == null: return
	_time += delta
	for path in _rest:
		get_node(path).transform = _rest[path]
	var head := _body.get_node("Head") as Node3D
	if _kind == "witch":
		_body.position.y = sin(_time * 1.1) * 0.03
		head.rotation.y += sin(_time * 0.9) * 0.05
		if is_instance_valid(_crown): _crown.rotation.y = _time * 0.6
		if state == 2:
			# WINDUP：双臂抬向头顶。
			_arm_r.rotation.x -= progress * 2.4
			_arm_l.rotation.x -= progress * 2.4
		elif state == 3:
			# STRIKE：施法下压。
			_arm_r.rotation.x += -2.4 + sin(progress * PI) * 1.9
			_arm_l.rotation.x += -2.4 + sin(progress * PI) * 1.2
		elif state == 4:
			_arm_r.rotation.x += sin(_time * 3) * 0.08
			_arm_l.rotation.x -= sin(_time * 3) * 0.08
		elif state == 5:
			# 阶段转换：双臂平展。
			_arm_r.rotation.x -= 1.5
			_arm_l.rotation.x -= 1.5
		elif state == 6:
			_arm_r.rotation.x += 0.4
			_arm_l.rotation.x += 0.4
	else:
		_body.position.y = absf(sin(_time * 9)) * moving * 0.12
		if state == 2:
			_body.scale = Vector3(1.1, 0.75, 1.1)
		else:
			_body.scale = Vector3.ONE
		if state == 3:
			_body.rotation.x = -sin(progress * PI) * 0.5
			# The physics body already lunges; don't translate the mesh into the player.
		elif state == 4:
			_body.rotation.x = -(1.0 - progress) * 0.2
		for leg in _legs:
			leg.rotation.x += sin(_time * 7) * moving * 0.3
		if moving > 0: head.rotation.y += sin(_time * 5) * 0.12
