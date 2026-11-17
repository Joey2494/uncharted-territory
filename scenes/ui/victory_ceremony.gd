extends Node3D
## Presentation only: shares the actual arena world and never spawns combat actors.
const KNIGHT = preload("res://scenes/characters/knight_visual.tscn")
var hero_source: Node3D

func _ready() -> void:
	var hero: Node3D
	# Clone the live hierarchy: integrated characters rename imported rigs at
	# runtime, so re-instantiating the original GLB loses those renamed paths.
	hero = hero_source.duplicate(0) if is_instance_valid(hero_source) else KNIGHT.instantiate()
	var model := hero.get_node_or_null("Model") as Node3D
	if model != null:
		# Gameplay's model faces -Z; the migrated salute faces the result camera.
		model.rotation.y = 0.0
	hero.rotation.y = 0.15
	hero.scale *= 1.65
	hero.name = "VictoriousExplorer"
	hero.position = Vector3(-2.0, 0, 1.7)
	add_child(hero)
	var animator: AnimationPlayer = hero.find_child("AnimationPlayer", true, false)
	if animator != null and animator.has_animation(&"locomotion/Idle_A"):
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		animator.play(&"locomotion/Idle_A")
		animator.advance(0.0)
		animator.pause()
		var skeleton: Skeleton3D = hero.find_child("Skeleton3D", true, false)
		if skeleton != null:
			_salute(skeleton)
	_add_effects(hero)

func _salute(skeleton: Skeleton3D) -> void:
	var arm := skeleton.find_bone("upperarm.r")
	var elbow := skeleton.find_bone("lowerarm.r")
	var slot := skeleton.find_bone("handslot.r")
	if arm < 0 or elbow < 0 or slot < 0:
		return
	skeleton.set_bone_pose_rotation(elbow, Quaternion.IDENTITY)
	skeleton.force_update_all_bone_transforms()
	var pose := skeleton.get_bone_global_pose(arm)
	var direction := skeleton.get_bone_global_pose(elbow).origin - pose.origin
	pose.basis = Basis(Quaternion(direction.normalized(), Vector3(-0.25, 0.96, 0.05).normalized())) * pose.basis
	skeleton.set_bone_global_pose(arm, pose)
	skeleton.force_update_all_bone_transforms()
	var grip := skeleton.get_bone_global_pose(slot)
	grip.basis = Basis.IDENTITY
	skeleton.set_bone_global_pose(slot, grip)

func _add_effects(hero: Node3D) -> void:
	var gold := StandardMaterial3D.new()
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gold.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gold.albedo_color = Color(1, 0.72, 0.24, 0.07)
	gold.cull_mode = BaseMaterial3D.CULL_DISABLED
	var beam := MeshInstance3D.new()
	beam.name = "GoldenLightPillar"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 0.65
	cylinder.height = 7.0
	beam.mesh = cylinder
	beam.material_override = gold
	beam.position = hero.position + Vector3(0, 3.5, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	var light := OmniLight3D.new()
	light.position = hero.position + Vector3(0, 2.7, 1.8)
	light.light_color = Color("ffd48b")
	light.light_energy = 0.8
	light.omni_range = 7.0
	add_child(light)
	var dust := CPUParticles3D.new()
	dust.name = "GoldenMotes"
	dust.position = hero.position + Vector3(0, 0.2, 0)
	dust.amount = 48
	dust.lifetime = 4.0
	dust.preprocess = 2.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1.2, 0.1, 1.2)
	dust.direction = Vector3.UP
	dust.spread = 20.0
	dust.initial_velocity_min = 0.35
	dust.initial_velocity_max = 0.9
	dust.gravity = Vector3(0, 0.08, 0)
	var mote := QuadMesh.new()
	mote.size = Vector2(0.06, 0.06)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow.albedo_color = Color("ffe5a1")
	glow.emission_enabled = true
	glow.emission = Color("ffd879")
	mote.material = glow
	dust.mesh = mote
	add_child(dust)
