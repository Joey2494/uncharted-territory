extends Node3D
## Frozen with the dungeon. All damage/control uses radius AND wall visibility.
var source: CharacterBody3D
var elapsed: float = 0.0
var _ticks: int = 0

func _ready() -> void:
	add_to_group("gravity_fields")
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 2.5
	mesh.bottom_radius = 2.5
	mesh.height = 0.035
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.35, 0.28, 0.6, 0.35)
	visual.material_override = material
	add_child(visual)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or source.is_dead():
		queue_free()
		return
	elapsed += delta
	var targets := targets_in_radius(source, global_position, 2.5)
	for target in targets:
		if target.has_method("apply_control"):
			target.apply_slow(0.1)
			var direction: Vector3 = global_position - target.global_position
			direction.y = 0.0
			if direction.length() > 0.4:
				target.move_and_collide(direction.normalized() * minf(delta * 0.6, direction.length()))
	while _ticks < mini(int(elapsed), 3):
		_ticks += 1
		for target in targets:
			target.take_damage(source.get_attack_damage(1))
	if elapsed >= 3.0:
		for target in targets:
			target.take_damage(source.get_attack_damage(2))
		queue_free()

static func targets_in_radius(actor: Node3D, center: Vector3, radius: float) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = center + Vector3.UP * 0.8
	query.collision_mask = 4
	var space := actor.get_world_3d().direct_space_state
	for hit in space.intersect_shape(query, 64):
		var target := hit.collider as Node3D
		if target == null or not target.has_method("take_damage"):
			continue
		var ray := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 0.8, target.global_position + Vector3.UP * 0.8, 1)
		if space.intersect_ray(ray).is_empty():
			result.append(target)
	return result
