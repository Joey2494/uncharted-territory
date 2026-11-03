@tool
extends RefCounted
## Per-owner visual resources; never edits imported meshes or materials.

var stone_brightness: float = 0.40
var _parts: Dictionary = {}
var _materials: Dictionary = {}


func parts(scene: PackedScene) -> Array[Dictionary]:
	var key := scene.resource_path
	if not _parts.has(key):
		var source := scene.instantiate()
		var result: Array[Dictionary] = []
		_collect(source, Transform3D.IDENTITY, result)
		_parts[key] = result
		source.free()
	return _parts[key]


func _collect(node: Node, parent_transform: Transform3D, result: Array[Dictionary]) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform *= node.transform
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			# One colour per mesh is required by the existing camera's fade.
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(node.mesh.surface_get_primitive_type(surface), node.mesh.surface_get_arrays(surface))
			mesh.surface_set_material(0, _material(node.get_active_material(surface)))
			result.append({"mesh": mesh, "transform": transform})
	for child in node.get_children():
		_collect(child, transform, result)


func _material(source: Material) -> Material:
	var key := source.get_instance_id()
	if not _materials.has(key):
		var material := source.duplicate() as BaseMaterial3D
		if material.resource_name.begins_with("M_Stone"):
			var color := material.albedo_color
			material.albedo_color = Color(color.r * stone_brightness, color.g * stone_brightness, color.b * stone_brightness, color.a)
		if material.resource_name.begins_with("M_Crystal"):
			# The pack's strength 3 clips blue/purple to white in the existing
			# chamber lighting. Rune followers override this with original feedback.
			material.emission_energy_multiplier = 0.12
		_materials[key] = material
	return _materials[key]


func add_model(parent: Node3D, scene: PackedScene, label: String, transform: Transform3D) -> Node3D:
	var model := Node3D.new()
	model.name = label
	model.transform = transform
	model.set_meta("source_model", scene.resource_path)
	parent.add_child(model)
	var index := 0
	for part in parts(scene):
		var mesh := MeshInstance3D.new()
		mesh.name = "Surface%d" % index
		mesh.mesh = part.mesh
		mesh.transform = part.transform
		model.add_child(mesh)
		index += 1
	return model
