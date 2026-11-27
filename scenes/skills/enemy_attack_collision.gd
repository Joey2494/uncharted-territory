extends RefCounted
## Sweep a volume, including initial overlaps. Used by attacks without a physics body.
static func sweep(actor: Node3D, from: Vector3, to: Vector3, shape: Shape3D, exclude: Array[RID] = []) -> Dictionary:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = to - from
	query.collision_mask = 3
	query.exclude = exclude
	var space := actor.get_world_3d().direct_space_state
	var overlaps := space.intersect_shape(query, 1)
	if not overlaps.is_empty():
		return {"collider": overlaps[0].collider, "position": from, "normal": Vector3.ZERO}
	var fractions := space.cast_motion(query)
	if fractions[0] >= 1.0: return {}
	query.transform.origin = from.lerp(to, minf(1.0, fractions[1] + 0.001))
	query.motion = Vector3.ZERO
	var contact := space.get_rest_info(query)
	var hits := space.intersect_shape(query, 1)
	var point: Vector3 = from.lerp(to, fractions[0])
	if not contact.is_empty():
		return {"collider": instance_from_id(contact.collider_id), "position": contact.point, "normal": contact.normal}
	return {"collider": hits[0].collider if not hits.is_empty() else null, "position": point, "normal": Vector3.ZERO}
