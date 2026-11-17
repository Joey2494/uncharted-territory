extends RefCounted
## Geometry-based silk, venom and impact effects share the actual attack positions.
static func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = color * 0.35
	return m

static func strand(parent: Node3D, a: Vector3, b: Vector3, color: Color, width := 0.025) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = width
	mesh.bottom_radius = width
	mesh.height = maxf(0.001, a.distance_to(b))
	mesh.material = material(color)
	n.mesh = mesh
	parent.add_child(n)
	n.position = (a + b) * 0.5
	var up := (b - a).normalized()
	var right := up.cross(Vector3.FORWARD).normalized()
	if right.length() < 0.1: right = Vector3.RIGHT
	n.basis = Basis(right, up, right.cross(up)).orthonormalized()
	return n

static func burst(parent: Node3D, point: Vector3, color: Color, radius := 0.8) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.add_to_group("creature_hazards")
	root.global_position = point
	for i in range(10):
		var d := Vector3(cos(i * TAU / 10), 0.25, sin(i * TAU / 10))
		strand(root, d * 0.12, d * radius, color, 0.018)
	var tween := root.create_tween()
	tween.tween_property(root, "scale", Vector3.ONE * 1.5, 0.16)
	tween.tween_property(root, "scale", Vector3.ONE * 0.01, 0.18)
	tween.tween_callback(root.queue_free)

static func burrow(parent: Node3D, point: Vector3, delay := 0.0) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.add_to_group("creature_hazards")
	root.global_position = point
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.48
	mesh.bottom_radius = 0.48
	mesh.height = 0.025
	mesh.radial_segments = 14
	mesh.material = material(Color("15110e"))
	disc.mesh = mesh
	root.add_child(disc)
	for i in 8:
		var a := i * TAU / 8
		strand(root, Vector3(cos(a), 0.02, sin(a)) * 0.36, Vector3(cos(a + 0.22), 0.07, sin(a + 0.22)) * 0.60, Color("796044"), 0.026)
	root.scale = Vector3.ONE * 0.02
	var tween := root.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(root, "scale", Vector3.ONE, 0.22)
	tween.tween_interval(2.0)
	tween.tween_property(root, "scale", Vector3.ONE * 0.01, 0.6)
	tween.tween_callback(root.queue_free)
