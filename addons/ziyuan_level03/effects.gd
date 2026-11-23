extends RefCounted
static func mat(color: Color, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.72
	if color.a < 1: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = color * 0.3
	return m
static func line(parent: Node3D, a: Vector3, b: Vector3, material: Material, width := 0.035) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.height = 1
	mesh.top_radius = width
	mesh.bottom_radius = width
	mesh.radial_segments = 6
	mesh.material = material
	n.mesh = mesh
	parent.add_child(n)
	set_line(n, a, b)
	return n
static func set_line(n: Node3D, a: Vector3, b: Vector3) -> void:
	var up := (b-a).normalized()
	if up.length() < 0.01: up = Vector3.UP
	var right := up.cross(Vector3.FORWARD).normalized()
	if right.length() < 0.01: right = Vector3.RIGHT
	n.transform = Transform3D(Basis(right, up*maxf(0.001,a.distance_to(b)), right.cross(up)), (a+b)*0.5)
static func sector(radius: float, degrees: float, inner := 0.0) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat(Color(0.95,0.24,0.1,0.35),true))
	for i in 40:
		var a := deg_to_rad(-degrees/2 + degrees*i/40.0)
		var b := deg_to_rad(-degrees/2 + degrees*(i+1)/40.0)
		var x := Vector3(sin(a),0,-cos(a))
		var y := Vector3(sin(b),0,-cos(b))
		for point in [x*inner,y*radius,x*radius,x*inner,y*inner,y*radius]: mesh.surface_add_vertex(point)
	mesh.surface_end()
	return mesh
static func burst(parent: Node3D, point: Vector3, color: Color, radius := 0.8) -> void:
	var root := Node3D.new()
	root.add_to_group("l3_transient")
	parent.add_child(root)
	root.global_position = point
	for i in 8:
		var d := Vector3(cos(i*TAU/8),0.25,sin(i*TAU/8))
		line(root,d*0.1,d*radius,mat(color,true),0.022)
	var t := root.create_tween()
	t.tween_property(root,"scale",Vector3.ONE*1.6,0.12)
	t.tween_property(root,"scale",Vector3.ONE*0.01,0.18)
	t.tween_callback(root.queue_free)
