extends RefCounted
## 固定建筑与掩体；所有会改变战斗或谜题状态的物件由相应房间模块摆放。
const STONE := Color("#586873")
const BRONZE := Color("#ad8558")
const COPPER := Color("#c5945b")
const NIGHT := Color("#24353e")
const CYAN := Color("#83cec8")

static func dress(layout) -> void:
	var a: Node3D = layout.get_node("A")
	layout.solid(a, Vector3(-3.9,0.57,1.6), Vector3(1.35,1.14,1.35), STONE)
	layout.block(a, Vector3(-3.9,1.16,1.6), Vector3(1.49,0.13,1.49), BRONZE)
	var b: Node3D = layout.get_node("B")
	var tower = layout.solid(b, Vector3(4,0.88,1), Vector3(1.85,1.76,2.25), STONE)
	layout.block(tower, Vector3(0,1.36,0), Vector3(0.48,1.32,0.48), BRONZE)
	layout.block(tower, Vector3(-0.7,2.1,0), Vector3(2.2,0.24,0.44), COPPER)
	layout.block(tower, Vector3(-1.55,1.58,0), Vector3(0.1,0.92,0.1), NIGHT)

	var c: Node3D = layout.get_node("C")
	for radius: float in [1.8, 2.1, 3.35]:
		_ring(layout,c,Vector3(0,0.017,0),radius,0.036,COPPER)
	layout.ground_label(c, "↑ 曝光盘 · 接通栈道", Vector2(0,-4.8),layout.MAIN)
	layout.ground_label(c, "← 检修吊机 · 可调掩体", Vector2(-4.45,-1.2),layout.SIDE).pixel_size = 0.013

	var d: Node3D = layout.get_node("D")
	# 深井的暗色井口低于护栏，弯曲的实体护栏把近路与外侧绕行路分开。
	var well := Vector3(-1,0,0)
	_disc(layout,d,well + Vector3.UP*0.026,2.15,0.05,NIGHT,false)
	_ring(layout,d,well + Vector3.UP*0.10,2.17,0.10,BRONZE)
	for i in 14:
		var theta := i * TAU / 14
		var p := well + Vector3(cos(theta),0.52,sin(theta))*2.17
		p.y = 0.47
		var guard = layout.solid(d,p,Vector3(0.22,0.94,1.03),STONE)
		guard.rotation.y = -theta
	for p: Vector2 in [Vector2(-5.4,1.6),Vector2(-3.6,-4.9)]:
		layout.solid(d,Vector3(p.x,0.74,p.y),Vector3(1.25,1.48,1.02),STONE)
	_threshold(layout,d,Vector2(3.5,0),Vector2(0,1),"跨线迎战",true)

	var f: Node3D = layout.get_node("F")
	# 横向开口在中段，两侧腐尸分别有视线；外侧永久石挡与可移动吊笼分开。
	for z: float in [-4.45,4.45]:
		var wall = layout.solid(f,Vector3(0.8,0.86,z),Vector3(0.51,1.72,3.75),STONE)
		layout.block(wall,Vector3(0,0.89,0),Vector3(0.57,0.09,3.8),BRONZE)
	layout.solid(f,Vector3(-6.5,0.82,0.25),Vector3(1.35,1.64,1.3),STONE)
	layout.solid(f,Vector3(6.6,0.82,0.10),Vector3(1.35,1.64,1.3),STONE)
	for x: float in [-4,4]:
		_ring(layout,f,Vector3(x,0.019,2),1.32,0.045,CYAN)
	var h: Node3D = layout.get_node("H")
	_threshold(layout,h,Vector2(0,3),Vector2(1,0),"试车线",false)
	for p: Vector2 in [Vector2(-6.6,1.6),Vector2(6.6,-0.8)]:
		_disc(layout,h,Vector3(p.x,0.64,p.y),0.77,1.28,STONE,true)

	var dome: Node3D = layout.get_node("I")
	_threshold(layout,dome,Vector2(0,5.5),Vector2(1,0),"前方封场 · 可先返回",false)
	# 穹顶仪器座的碰撞挡住投射物；日轮与黄道圈只作仪器的上部轮廓。
	_disc(layout,dome,Vector3(0,0.87,0),2.30,1.74,STONE,true)
	_disc(layout,dome,Vector3(0,1.78,0),2.34,0.12,BRONZE,false)
	_ring(layout,dome,Vector3(0,2.32,0),1.43,0.095,COPPER).rotation.x = 1.02
	_ring(layout,dome,Vector3(0,2.32,0),1.42,0.075,CYAN).rotation.z = 1.20
	_disc(layout,dome,Vector3(0,2.05,0),0.39,0.56,COPPER,false)
	for p: Vector2 in [Vector2(-7.4,1.55),Vector2(7.4,-2)]:
		layout.solid(dome,Vector3(p.x,0.82,p.y),Vector3(1.4,1.64,1.35),STONE)
	var j: Node3D = layout.get_node("J")
	_disc(layout,j,Vector3(0,0.035,-1),2.65,0.06,BRONZE,false)
	_disc(layout,j,Vector3(0,0.07,-1),2.4,0.025,STONE,false)
	_ring(layout,j,Vector3(0,0.10,-1),1.85,0.055,COPPER)

static func _threshold(layout,parent: Node3D,at: Vector2,axis: Vector2,title: String,side: bool) -> void:
	var ink: Color = layout.SIDE if side else layout.MAIN
	for index in range(-5,6):
		var p := at + axis*index*0.55
		layout.block(parent,Vector3(p.x,0.025,p.y),Vector3(0.34,0.03,0.14),ink).rotation.y = -axis.angle()
	var text_at := at + (Vector2(1.2,1.75) if side else Vector2(0,0.68))
	layout.ground_label(parent,title,text_at,ink).pixel_size = 0.013

static func _disc(layout, parent: Node3D, pos: Vector3, radius: float, height: float, ink: Color, collidable: bool) -> Node3D:
	var base: Node3D = StaticBody3D.new() if collidable else Node3D.new()
	parent.add_child(base)
	base.position = pos
	if base is StaticBody3D:
		base.collision_mask = 0
		base.add_to_group("camera_occluders")
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		var collision := CollisionShape3D.new()
		collision.shape = shape
		base.add_child(collision)
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = height
	disc.radial_segments = 24
	disc.rings = 0
	var view := MeshInstance3D.new()
	view.mesh = disc
	view.material_override = layout.material(ink)
	base.add_child(view)
	return base

static func _ring(layout,parent: Node3D,pos: Vector3,radius: float,thickness: float,ink: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 36
	mesh.ring_segments = 8
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = layout.material(ink)
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)
	view.position = pos
	return view
