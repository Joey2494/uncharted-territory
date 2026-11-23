extends "res://scenes/dungeon/level03/tide_camera.gd"
## Art-only visibility for tall walls above the original low whitebox colliders.
func _update_occluders(actors: Array[Node3D], delta: float) -> void:
	super._update_occluders(actors,delta)
	var points := _actor_visibility_points(actors)
	for visual in get_tree().get_nodes_in_group("tomb_visual_occluders"):
		if not get_parent().is_ancestor_of(visual) or not visual.is_visible_in_tree(): continue
		var inverse: Transform3D = visual.global_transform.affine_inverse()
		var bounds: AABB = visual.get_meta("tomb_bounds")
		var blocked := false
		for point in points:
			if bounds.intersects_segment(inverse*global_position,inverse*point) != null:
				blocked = true
				break
		if not blocked: continue
		for mesh in visual.find_children("*","MeshInstance3D",true,false):
			if not mesh.is_visible_in_tree(): continue
			var id: int = mesh.get_instance_id()
			if not _faded_meshes.has(id): _remember_occluder(mesh)
			if not _faded_meshes.has(id): continue
			var entry: Dictionary = _faded_meshes[id]
			entry.fade = occluder_transparency
			var material: BaseMaterial3D = entry.material
			var color := material.albedo_color
			color.a = entry.alpha*(1.0-occluder_transparency)
			material.albedo_color = color
