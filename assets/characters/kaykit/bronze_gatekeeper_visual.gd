extends Node3D
## Bronze gatekeeper body. Visual geometry and combat warning presentation only.
var _skeleton: Skeleton3D
var _shield_root: Node3D
var _visor_material: StandardMaterial3D

func _ready() -> void:
	_skeleton = get_node("Rig_Medium/Skeleton3D")
	var bronze := _material(Color("b39157"), 0.55)
	var steel := _material(Color("284a51"), 0.45)
	var dark := _material(Color("15232a"), 0.15)
	var ivory := _material(Color("dad2ad"), 0.1)
	var visor := _material(Color("75ceca"), 0.15)
	_visor_material = visor
	visor.emission_enabled = true
	visor.emission = Color("3a898a")
	visor.emission_energy_multiplier = 0.3
	_piece("head", "IronHelm", _cylinder(0.41, 0.39, 0.80, 10), Vector3(0, 1.72, 0), bronze)
	_piece("head", "HelmCrown", _cylinder(0.31, 0.41, 0.13, 10), Vector3(0, 2.185, 0), bronze)
	_piece("head", "IvoryCrest", _box(Vector3(0.10, 0.24, 0.56)), Vector3(0, 2.30, -0.02), ivory)
	_piece("head", "VisorRecess", _box(Vector3(0.63, 0.15, 0.08)), Vector3(0, 1.78, 0.365), dark)
	_piece("head", "CyanVisor", _box(Vector3(0.48, 0.034, 0.09)), Vector3(0, 1.79, 0.39), visor)
	for x in [-0.14, 0.0, 0.14]:
		_piece("head", "HelmVent", _box(Vector3(0.034, 0.12, 0.045)), Vector3(x, 1.52, 0.39), dark)
	var chest := _piece("chest", "Breastplate", _cylinder(0.34, 0.28, 0.52, 8), Vector3(0, 0.95, 0), steel)
	chest.scale.z = 0.75
	_piece("chest", "ChestSeal", _box(Vector3(0.14, 0.14, 0.05)), Vector3(0, 0.96, 0.26), ivory, Basis(Vector3.FORWARD, PI / 4))
	_piece("chest", "Collar", _cylinder(0.31, 0.32, 0.08, 10), Vector3(0, 1.23, 0), bronze)
	_piece("hips", "Waist", _box(Vector3(0.48, 0.20, 0.36)), Vector3(0, 0.53, 0), dark)
	_piece("hips", "Belt", _box(Vector3(0.54, 0.10, 0.40)), Vector3(0, 0.60, 0), bronze)
	for side in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		_piece("hips", "IvoryTasset_" + side, _box(Vector3(0.23, 0.27, 0.08)), Vector3(sign_x * 0.13, 0.43, 0.20), ivory)
		_segment("upperarm." + side, "lowerarm." + side, "UpperArm_" + side, 0.12, dark)
		_segment("lowerarm." + side, "wrist." + side, "ArmoredBracer_" + side, 0.14, bronze)
		var shoulder := _bone_position("upperarm." + side) + Vector3(sign_x * 0.08, 0.025, 0)
		_piece("upperarm." + side, "RoundedPauldron_" + side, _sphere(0.20, 0.32), shoulder, steel)
		_piece("hand." + side, "Gauntlet_" + side, _sphere(0.115, 0.23), _bone_position("hand." + side), bronze)
		_segment("upperleg." + side, "lowerleg." + side, "LegArmor_" + side, 0.135, steel)
		_segment("lowerleg." + side, "foot." + side, "Greave_" + side, 0.14, bronze)
		_piece("foot." + side, "Boot_" + side, _box(Vector3(0.27, 0.19, 0.38)), Vector3(sign_x * 0.17, 0.11, 0.07), dark)
	var hand := BoneAttachment3D.new()
	hand.name = "GatekeeperShield"
	_shield_root = hand
	hand.bone_name = "handslot.l"
	_skeleton.add_child(hand)
	_shield(hand, "ShieldRim", 1.0, 0.19, bronze)
	_shield(hand, "ShieldFace", 0.86, 0.22, steel)
	var seal := MeshInstance3D.new()
	seal.name = "ShieldSeal"
	seal.mesh = _box(Vector3(0.25, 0.035, 0.16))
	seal.position = Vector3(0.07, 0.25, 0)
	seal.material_override = ivory
	hand.add_child(seal)

func _bone_position(bone: String) -> Vector3:
	return _skeleton.get_bone_global_rest(_skeleton.find_bone(bone)).origin

func _piece(bone: String, label: String, mesh: Mesh, center: Vector3, material: Material, orientation: Basis = Basis.IDENTITY) -> MeshInstance3D:
	var socket := BoneAttachment3D.new()
	socket.name = label + "Socket"
	socket.bone_name = bone
	_skeleton.add_child(socket)
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.material_override = material
	var rest := _skeleton.get_bone_global_rest(_skeleton.find_bone(bone))
	visual.transform = rest.affine_inverse() * Transform3D(orientation, center)
	socket.add_child(visual)
	return visual

func _segment(bone: String, end: String, label: String, radius: float, material: Material) -> void:
	var start := _bone_position(bone)
	var finish := _bone_position(end)
	var direction := finish - start
	_piece(bone, label, _cylinder(radius, radius * 0.88, direction.length() * 0.90, 8), (start + finish) * 0.5, material, Basis(Quaternion(Vector3.UP, direction.normalized())))

func _box(dimensions: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return mesh

func _cylinder(top: float, bottom: float, height: float, segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	return mesh

func _sphere(radius: float, height: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh

func _material(color: Color, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.75
	return material

func _shield(parent: Node3D, label: String, size: float, depth: float, material: Material) -> void:
	# Hand local X is height, Y outward depth, Z width during idle.
	var outline: Array[Vector2] = [Vector2(0.43, -0.22), Vector2(0.43, 0.22), Vector2(0.25, 0.35), Vector2(-0.27, 0.30), Vector2(-0.55, 0), Vector2(-0.27, -0.30), Vector2(0.25, -0.35)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a := outline[i] * size
		var b := outline[(i + 1) % outline.size()] * size
		surface.add_vertex(Vector3(0, depth, 0))
		surface.add_vertex(Vector3(a.x, depth, a.y))
		surface.add_vertex(Vector3(b.x, depth, b.y))
	surface.generate_normals()
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = surface.commit()
	var face := material.duplicate() as StandardMaterial3D
	face.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = face
	parent.add_child(visual)

func _physics_process(_delta: float) -> void:
	var actor := get_parent()
	while actor != null and not actor is CharacterBody3D:
		actor = actor.get_parent()
	if actor == null or not actor.has_method("is_dead"): return
	var melee := actor.get_node_or_null("MeleeAttack")
	if melee != null: _shield_root.visible = not melee.is_attacking()
	var charging: bool = actor.state in [actor.State.CHARGE_WINDUP, actor.State.CHARGE]
	_visor_material.albedo_color = Color("df7445") if charging else Color("75ceca")
	_visor_material.emission = Color("a23c20") if charging else Color("3a898a")
