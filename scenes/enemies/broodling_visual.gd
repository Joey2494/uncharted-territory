@static_unload
extends Node3D
## Three draw calls per spider, shared primitive geometry, articulated crawling legs.
static var _shell: StandardMaterial3D
static var _eye_material: StandardMaterial3D
static var _body_mesh: ArrayMesh
static var _limb_mesh: CylinderMesh
static var _eye_mesh: SphereMesh
var _legs: MultiMeshInstance3D
var _time := 0.0

static func _prepare() -> void:
	if _body_mesh != null: return
	_shell = StandardMaterial3D.new()
	_shell.albedo_color = Color("302c27")
	_shell.roughness = 0.38
	_eye_material = StandardMaterial3D.new()
	_eye_material.albedo_color = Color("f07d3c")
	_eye_material.emission_enabled = true
	_eye_material.emission = Color("d6481d")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for spec in [Vector3(0, 0.10, 0.10), Vector3(0, 0.08, -0.11)]:
		var sphere := SphereMesh.new()
		sphere.radius = 0.16 if spec.z > 0 else 0.10
		sphere.height = sphere.radius * 1.45
		sphere.radial_segments = 10
		sphere.rings = 5
		surface.append_from(sphere, 0, Transform3D(Basis.IDENTITY, spec))
	_body_mesh = surface.commit()
	_body_mesh.surface_set_material(0, _shell)
	_limb_mesh = CylinderMesh.new()
	_limb_mesh.top_radius = 0.012
	_limb_mesh.bottom_radius = 0.024
	_limb_mesh.height = 1
	_limb_mesh.radial_segments = 5
	_limb_mesh.material = _shell
	_eye_mesh = SphereMesh.new()
	_eye_mesh.radius = 0.022
	_eye_mesh.height = 0.044
	_eye_mesh.radial_segments = 6
	_eye_mesh.rings = 3
	_eye_mesh.material = _eye_material

func _ready() -> void:
	_prepare()
	_time = float(get_instance_id() % 100) * 0.1
	var body := MeshInstance3D.new()
	body.mesh = _body_mesh
	add_child(body)
	_legs = MultiMeshInstance3D.new()
	_legs.multimesh = MultiMesh.new()
	_legs.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_legs.multimesh.mesh = _limb_mesh
	_legs.multimesh.instance_count = 16
	add_child(_legs)
	var eyes := MultiMeshInstance3D.new()
	eyes.multimesh = MultiMesh.new()
	eyes.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	eyes.multimesh.mesh = _eye_mesh
	eyes.multimesh.instance_count = 2
	for i in 2: eyes.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3((i * 2 - 1) * 0.045, 0.115, -0.195)))
	add_child(eyes)
	_process(0)

func _bone(index: int, a: Vector3, b: Vector3) -> void:
	var up := (b - a).normalized()
	var right := up.cross(Vector3.FORWARD).normalized()
	var basis := Basis(right, up, right.cross(up)).scaled(Vector3(1, a.distance_to(b), 1))
	_legs.multimesh.set_instance_transform(index, Transform3D(basis, (a + b) * 0.5))

func _process(delta: float) -> void:
	_time += delta * 22
	for side in 2:
		var sign_x := float(side * 2 - 1)
		for leg in 4:
			var phase := _time + (leg % 2) * PI + side * PI
			var root := Vector3(sign_x * 0.075, 0.08, (leg - 1.5) * 0.065)
			var knee := Vector3(sign_x * 0.24, 0.14, (leg - 1.5) * 0.13 + sin(phase) * 0.035)
			var toe := Vector3(sign_x * 0.35, maxf(0, cos(phase)) * 0.06 - 0.04, (leg - 1.5) * 0.19 + sin(phase) * 0.07)
			_bone((side * 4 + leg) * 2, root, knee)
			_bone((side * 4 + leg) * 2 + 1, knee, toe)

