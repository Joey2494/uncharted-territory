extends SceneTree
## Offline asset builder. Saved meshes, not _ready(), own editor visibility.

var _root: Node3D
var _materials: Dictionary = {}
var _serial := 0


func _initialize() -> void:
	_build.call_deferred()


func _material(key: String, color: Color, metallic: float, roughness: float, glow := 0.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.resource_name = key
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if key in ["Shell", "Armor", "Joint"]:
		var noise := FastNoiseLite.new()
		noise.seed = 719
		noise.frequency = 0.085
		var normal := NoiseTexture2D.new()
		normal.width = 256
		normal.height = 256
		normal.seamless = true
		normal.noise = noise
		normal.as_normal_map = true
		normal.bump_strength = 1.8
		mat.normal_enabled = true
		mat.normal_texture = normal
		mat.normal_scale = 0.5
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	_materials[key] = mat


func _node(label: String, parent: Node3D, point := Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = point
	parent.add_child(node)
	node.owner = _root
	return node


func _mesh(label: String, mesh: Mesh, parent: Node3D, material: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	_serial += 1
	node.name = "%s_%03d" % [label, _serial]
	node.mesh = mesh
	node.material_override = _materials[material]
	parent.add_child(node)
	node.owner = _root
	return node


func _ellipsoid(label: String, parent: Node3D, point: Vector3, dimensions: Vector3, material: String) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 1.0
	shape.height = 2.0
	shape.radial_segments = 24
	shape.rings = 12
	var node := _mesh(label, shape, parent, material)
	node.position = point
	node.scale = dimensions
	return node


func _tube(label: String, parent: Node3D, points: Array[Vector3], radii: Array[float], material: String, sides := 10) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for i in range(points.size()):
		var tangent: Vector3 = points[mini(i + 1, points.size() - 1)] - points[maxi(0, i - 1)]
		tangent = tangent.normalized()
		var axis := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var right := tangent.cross(axis).normalized()
		var up := tangent.cross(right).normalized()
		var ring := PackedVector3Array()
		for j in range(sides):
			var angle := TAU * j / sides
			ring.append(points[i] + (right * cos(angle) + up * sin(angle)) * maxf(0.003, radii[i]))
		rings.append(ring)
	for i in range(rings.size() - 1):
		for j in range(sides):
			var k := (j + 1) % sides
			for vertex in [rings[i][j], rings[i + 1][j], rings[i + 1][k], rings[i][j], rings[i + 1][k], rings[i][k]]:
				st.add_vertex(vertex)
	for j in range(sides):
		var k := (j + 1) % sides
		for vertex in [points[0], rings[0][j], rings[0][k], points[-1], rings[-1][k], rings[-1][j]]:
			st.add_vertex(vertex)
	st.generate_normals()
	var result := _mesh(label, st.commit(), parent, material)
	var mat := result.material_override as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result


func _spike(parent: Node3D, from: Vector3, to: Vector3, radius: float, material := "Edge") -> void:
	var bend := from.lerp(to, 0.6) + Vector3(0, radius * 0.8, 0.06)
	_tube("Spine", parent, [from, bend, to], [radius, radius * 0.5, 0.004], material, 8)


func _legs(parent: Node3D, large: bool) -> void:
	var factor := 1.0 if large else 0.52
	for side in [-1.0, 1.0]:
		for i in range(4):
			var origin := Vector3(side * 0.83, 1.03, -0.9 + i * 0.62) * factor
			var leg := _node("Leg%s%d" % ["L" if side < 0 else "R", i], parent, origin)
			var knee := Vector3(side * (1.65 + sin(i * 0.85) * 0.25), 0.72, -1.2 + i * 0.62) * factor
			var ankle := Vector3(side * (2.4 + sin(i * 0.85) * 0.3), -0.88, -1.5 + i * 0.82) * factor
			var tip := ankle + Vector3(side * 0.14, -0.15, -0.19) * factor
			_tube("Femur", leg, [Vector3.ZERO, knee * 0.4, knee], [0.23 * factor, 0.29 * factor, 0.16 * factor], "Shell")
			_ellipsoid("Joint", leg, knee, Vector3.ONE * 0.22 * factor, "Joint")
			_tube("Tibia", leg, [knee, knee.lerp(ankle, 0.48), ankle, tip],
				[0.2 * factor, 0.15 * factor, 0.08 * factor, 0.004], "Shell")
			_tube("ShinEdge", leg, [knee + Vector3(0, 0.06, -0.12) * factor, knee.lerp(ankle, 0.7) + Vector3(0, 0, -0.07) * factor],
				[0.035 * factor, 0.012 * factor], "Edge", 6)
			for n in range(3):
				var spot := knee.lerp(ankle, 0.18 + n * 0.22)
				_spike(leg, spot, spot + Vector3(side * 0.3, 0.12, 0.13) * factor, 0.07 * factor)


func _spider(ranged: bool) -> void:
	_root = Node3D.new()
	_root.name = "VenomSpiderModel" if ranged else "CryptSpiderModel"
	_root.set_script(load("res://scenes/enemies/creature_visual.gd"))
	_root.set("creature_kind", 1 if ranged else 0)
	var body := _node("Body", _root)
	_ellipsoid("Abdomen", body, Vector3(0, 0.83, 0.44), Vector3(0.68, 0.58, 0.88), "Shell")
	_ellipsoid("Thorax", body, Vector3(0, 0.67, -0.38), Vector3(0.52, 0.37, 0.58), "Armor")
	_ellipsoid("Face", body, Vector3(0, 0.62, -0.8), Vector3(0.39, 0.27, 0.2), "Shell")
	var glow := "Venom" if ranged else "Eye"
	for side in [-1.0, 1.0]:
		_ellipsoid("EyeSocket", body, Vector3(side * 0.19, 0.76, -0.97), Vector3(0.13, 0.115, 0.07), "Joint")
		_ellipsoid("Eye", body, Vector3(side * 0.19, 0.77, -1.025), Vector3(0.082, 0.065, 0.06), "Eye")
		var brow := _ellipsoid("Brow", body, Vector3(side * 0.19, 0.85, -0.99), Vector3(0.17, 0.055, 0.09), "Armor")
		brow.rotation.z = side * -0.2
		_ellipsoid("SmallEye", body, Vector3(side * 0.34, 0.82, -0.83), Vector3(0.042, 0.045, 0.04), "Eye")
		_ellipsoid("UpperEye", body, Vector3(side * 0.09, 0.91, -0.76), Vector3(0.034, 0.03, 0.04), "Eye")
		_tube("Mandible", body, [Vector3(side * 0.25, 0.49, -0.9), Vector3(side * 0.4, 0.32, -1.09), Vector3(side * 0.26, 0.2, -1.32), Vector3(side * 0.12, 0.28, -1.37)],
			[0.105, 0.09, 0.05, 0.003], "Ivory")
		_ellipsoid("FangBase", body, Vector3(side * 0.27, 0.48, -0.96), Vector3(0.12, 0.13, 0.13), "Shell")
		for i in range(4):
			var spot := Vector3(side * (0.54 - i * 0.06), 1.1, 0.1 + i * 0.28)
			_spike(body, spot, spot + Vector3(side * 0.25, 0.36, 0.15), 0.1)
		for i in range(3):
			var z := 0.0 + i * 0.31
			_tube("Rune", body, [Vector3(side * 0.08, 1.38, z), Vector3(side * 0.38, 1.3, z + 0.09), Vector3(side * 0.48, 1.16, z + 0.01)], [0.02, 0.023, 0.01], glow, 6)
	if ranged:
		_ellipsoid("VenomSac", body, Vector3(0, 1.15, 0.52), Vector3(0.34, 0.41, 0.42), "Joint")
		for side in [-1.0, 1.0]:
			_tube("VenomVein", body, [Vector3(side * 0.1, 1.55, 0.39), Vector3(side * 0.24, 1.43, 0.54), Vector3(side * 0.2, 1.32, 0.82)],
				[0.028, 0.023, 0.009], "Venom")
	_legs(_root, false)
	_save("res://scenes/enemies/%s.tscn" % _root.name)


func _scorpion() -> void:
	_root = Node3D.new()
	_root.name = "DreadScorpionModel"
	_root.set_script(load("res://scenes/enemies/creature_visual.gd"))
	_root.set("creature_kind", 2)
	var body := _node("Body", _root)
	_ellipsoid("Abdomen", body, Vector3(0, 1.2, 0.45), Vector3(1.18, 0.75, 1.73), "Joint")
	for i in range(5):
		var z := -0.3 + i * 0.47
		var width := 1.24 - maxf(0.0, i - 1) * 0.14
		_ellipsoid("DorsalPlate", body, Vector3(0, 1.53, z), Vector3(width, 0.5, 0.48), "Armor" if i % 2 == 0 else "Shell")
		_spike(body, Vector3(0, 1.94, z), Vector3(0, 2.38, z + 0.3), 0.17)
		for side in [-1.0, 1.0]:
			_spike(body, Vector3(side * width * 0.82, 1.78, z), Vector3(side * (width + 0.36), 2.15, z + 0.23), 0.17)
			_tube("Crack", body, [Vector3(side * 0.06, 2.01, z - 0.15), Vector3(side * 0.37, 1.99, z - 0.08), Vector3(side * 0.58, 1.91, z - 0.18)],
				[0.018, 0.027, 0.012], "Fissure", 6)
	_ellipsoid("Head", body, Vector3(0, 1.1, -1.03), Vector3(0.86, 0.6, 0.68), "Shell")
	for side in [-1.0, 1.0]:
		_ellipsoid("Brow", body, Vector3(side * 0.38, 1.5, -1.5), Vector3(0.35, 0.14, 0.2), "Armor")
		_ellipsoid("Eye", body, Vector3(side * 0.38, 1.37, -1.61), Vector3(0.19, 0.12, 0.08), "Eye")
		_ellipsoid("SmallEye", body, Vector3(side * 0.65, 1.48, -1.39), Vector3(0.07, 0.07, 0.055), "Eye")
		_tube("Fang", body, [Vector3(side * 0.38, 0.95, -1.57), Vector3(side * 0.46, 0.64, -1.83), Vector3(side * 0.2, 0.48, -2.15)],
			[0.2, 0.13, 0.003], "Ivory")
		_spike(body, Vector3(side * 0.68, 1.58, -1.04), Vector3(side * 0.99, 2.25, -0.96), 0.18)
	_legs(_root, true)
	for side in [-1.0, 1.0]:
		var arm := _node("ClawL" if side < 0 else "ClawR", _root, Vector3(side * 0.65, 1.1, -1.0))
		_tube("Arm", arm, [Vector3.ZERO, Vector3(side * 1.0, 0.15, -0.3), Vector3(side * 1.65, -0.05, -1.1)],
			[0.27, 0.36, 0.27], "Shell")
		var palm := Vector3(side * 1.9, -0.05, -1.65)
		_ellipsoid("Palm", arm, palm, Vector3(0.62, 0.46, 0.84), "Armor")
		for i in range(3):
			var point := palm + Vector3(side * 0.35, 0.3, 0.35 - i * 0.32)
			_spike(arm, point, point + Vector3(side * 0.3, 0.4, 0.07), 0.16)
		var outer: Array[Vector3] = [palm + Vector3(side * 0.37, 0, -0.42), palm + Vector3(side * 0.72, -0.01, -0.95), palm + Vector3(side * 0.5, -0.02, -1.63), palm + Vector3(side * 0.08, -0.05, -1.91)]
		_tube("FixedPincer", arm, outer, [0.28, 0.26, 0.15, 0.004], "Shell")
		_tube("PincerIvoryTip", arm, [outer[2], outer[2].lerp(outer[3], 0.6), outer[3]], [0.15, 0.08, 0.003], "Ivory")
		var jaw := _node("Jaw", arm, palm)
		_tube("MovingPincer", jaw, [Vector3(-side * 0.32, -0.02, -0.3), Vector3(-side * 0.55, -0.04, -0.9), Vector3(-side * 0.24, -0.05, -1.48), Vector3(side * 0.08, -0.05, -1.75)],
			[0.24, 0.22, 0.12, 0.003], "Shell")
		for i in range(3):
			_spike(jaw, Vector3(-side * 0.29, -0.01, -0.65 - i * 0.26), Vector3(side * 0.02, -0.02, -0.83 - i * 0.25), 0.08, "Ivory")
	var tail := _node("Tail", _root, Vector3(0, 1.2, 1.65))
	var curve: Array[Vector3] = [Vector3.ZERO, Vector3(0, 0.15, 0.7), Vector3(0, 0.75, 1.22), Vector3(0, 1.6, 1.5), Vector3(0, 2.5, 1.18), Vector3(0, 3.05, 0.46), Vector3(0, 3.12, -0.48), Vector3(0, 2.84, -1.3)]
	for i in range(curve.size() - 1):
		var a: Vector3 = curve[i]
		var b: Vector3 = curve[i + 1]
		var r := 0.4 - i * 0.024
		_tube("TailSegment", tail, [a, a.lerp(b, 0.5), b], [r * 0.84, r * 1.15, r * 0.8], "Armor")
		_ellipsoid("TailJoint", tail, b, Vector3.ONE * r * 0.83, "Joint")
		for side in [-1.0, 1.0]:
			_spike(tail, a.lerp(b, 0.5) + Vector3(side * r * 0.75, 0.15, 0),
				a.lerp(b, 0.5) + Vector3(side * (r + 0.22), 0.43, 0.08), 0.11)
	_ellipsoid("VenomBulb", tail, curve[-1], Vector3(0.36, 0.34, 0.47), "Shell")
	_tube("Stinger", tail, [curve[-1], Vector3(0, 2.58, -1.75), Vector3(0, 2.08, -2.02), Vector3(0, 1.77, -1.91)],
		[0.28, 0.2, 0.1, 0.004], "Ivory")
	_tube("StingerGlow", tail, [Vector3(0.03, 2.84, -1.65), Vector3(0.03, 2.53, -1.86), Vector3(0.03, 2.16, -2.05)],
		[0.03, 0.025, 0.008], "Fissure")
	_save("res://scenes/bosses/DreadScorpionModel.tscn")


func _save(path: String) -> void:
	var packed := PackedScene.new()
	var error := packed.pack(_root)
	if error == OK:
		error = ResourceSaver.save(packed, path)
	print("CREATURE_ASSET ", path, " meshes=", _root.find_children("*", "MeshInstance3D", true, false).size(), " status=", error)
	_root.free()
	if error != OK:
		quit(1)


func _build() -> void:
	_material("Shell", Color("#24272b"), 0.28, 0.55)
	_material("Armor", Color("#3c4147"), 0.4, 0.47)
	_material("Joint", Color("#240e19"), 0.1, 0.65)
	_material("Edge", Color("#737c83"), 0.45, 0.48)
	_material("Ivory", Color("#c5b7a2"), 0.25, 0.32)
	_material("Eye", Color("#ec1519"), 0.1, 0.32, 0.8)
	_material("Fissure", Color("#9f1232"), 0.25, 0.4, 0.35)
	_material("Venom", Color("#9c40c9"), 0.15, 0.4, 0.6)
	_spider(false)
	_spider(true)
	_scorpion()
	quit()
