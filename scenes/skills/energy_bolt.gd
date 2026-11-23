extends CharacterBody3D
## A swept sphere hits the first world/enemy body and applies damage once.

signal impacted(collider: Node)

@onready var _visuals: Node3D = $Visuals
@onready var _impact: MeshInstance3D = $ImpactBurst

var _direction: Vector3 = Vector3.FORWARD
var _damage: int = 2
var _speed: float = 18.0
var _max_distance: float = 10.0
var _travelled: float = 0.0
var _launched: bool = false
var _resolved: bool = false
var weapon_id: String = ""
var _weapon_source: WeakRef
var _weapon_room: Node3D

func set_tint(color: Color) -> void:
	for node in [$Visuals/Core, $Visuals/Tail, $Visuals/Ring, $ImpactBurst]:
		var mat := node.mesh.material.duplicate() as StandardMaterial3D
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		node.material_override = mat
	match weapon_id:
		"pistol", "coil":
			$Visuals/Ring.visible = weapon_id == "coil"
			var tracer := CapsuleMesh.new()
			tracer.radius = 0.045 if weapon_id == "pistol" else 0.075
			tracer.height = 0.55 if weapon_id == "pistol" else 0.95
			$Visuals/Core.mesh = tracer
			$Visuals/Core.rotation.x = PI/2
			$Visuals/Tail.scale = Vector3(0.45,1.6,0.45)
		"frost":
			var crystal := CylinderMesh.new()
			crystal.top_radius = 0
			crystal.bottom_radius = 0.16
			crystal.height = 0.7
			crystal.radial_segments = 6
			$Visuals/Core.mesh = crystal
			$Visuals/Core.rotation.x = PI/2
			$Visuals/Ring.hide()
		"fire":
			$Visuals/Ring.hide()
			$Visuals/Core.scale = Vector3(1,1,1.35)
			$Visuals/Tail.scale = Vector3(1.4,1.8,1.4)
		"practice":
			$Visuals/Ring.hide()
			$Visuals/Core.scale = Vector3.ONE*0.7


func launch(direction: Vector3, damage: int, speed: float, distance: float, source: PhysicsBody3D) -> void:
	_weapon_source = weakref(source)
	if not weapon_id.is_empty() and source.get_parent().has_method("get_region_at"):
		_weapon_room = source.get_parent().get_region_at(source.global_position)
	_direction = direction.normalized()
	_damage = damage
	_speed = maxf(speed, 0.01)
	_max_distance = maxf(distance, 0.01)
	add_collision_exception_with(source)
	look_at(global_position + _direction, Vector3.UP)
	_launched = true


func _physics_process(delta: float) -> void:
	if not _launched or _resolved:
		return
	if not weapon_id.is_empty() and is_instance_valid(_weapon_room):
		var source = _weapon_source.get_ref()
		if not is_instance_valid(source) or source.get_parent().get_region_at(source.global_position) != _weapon_room or source.get_parent().get_region_at(global_position) != _weapon_room:
			queue_free()
			return
	var step_distance := minf(_speed * delta, _max_distance - _travelled)
	var collision := move_and_collide(_direction * step_distance, false, 0.001, true)
	if collision != null:
		_resolved = true
		set_physics_process(false)
		var collider := collision.get_collider() as Node
		impacted.emit(collider)
		if is_instance_valid(collider) and collider.has_method("take_direct_damage"):
			collider.call("take_direct_damage", _damage, global_position - _direction)
		elif is_instance_valid(collider) and collider.has_method("take_damage"):
			collider.call("take_damage", _damage)
		if is_instance_valid(collider) and collider.has_method("take_damage"):
			if weapon_id == "frost" and not collider.is_in_group("bosses") and not (collider.has_method("is_boss") and collider.is_boss()) and collider.has_method("apply_slow"):
				collider.apply_slow(2.0)
			elif weapon_id == "fire" and not collider.has_node("WeaponEmber"):
				var ember := Node.new()
				ember.name = "WeaponEmber"
				ember.set_script(preload("res://scenes/weapons/weapon_ember.gd"))
				collider.add_child(ember)
		_show_impact()
		return
	_travelled += step_distance
	if _travelled >= _max_distance - 0.000001:
		_resolved = true
		set_physics_process(false)
		var tween := create_tween()
		tween.tween_property(_visuals, "scale", Vector3.ONE * 0.01, 0.1)
		tween.tween_callback(queue_free)


func _show_impact() -> void:
	_visuals.hide()
	_impact.show()
	_impact.scale = Vector3.ONE * 0.2
	var tween := create_tween()
	tween.tween_property(_impact, "scale", Vector3.ONE * 2.5, 0.18)
	tween.parallel().tween_property(_impact, "transparency", 1.0, 0.18)
	tween.tween_callback(queue_free)
