extends Node3D
const CATALOG = preload("res://scenes/player/character_catalog.gd")
const KNIGHT = preload("res://scenes/characters/knight_visual.tscn")
const MELEE = preload("res://assets/characters/kaykit/animations/melee.tres")
var _avatar: Node3D
var _elapsed: float = 0.0
var _id := ""
var _camera: Camera3D
var _animator: AnimationPlayer
var _skeleton: Skeleton3D
const CYCLE_SECONDS := {"knight":4.4, "lan":2.6, "iron":4.2, "astra":4.6}
const STANDARD_PREVIEW_YAW := 0.12
var _orb: MeshInstance3D
var _orb_light: OmniLight3D
var _orb_material: ShaderMaterial
var _weapon: Node3D
var _offhand_weapon: Node3D
var _shield_parts: Dictionary = {}
var _feet: Dictionary = {}
var _orb_ring: MeshInstance3D
var _orb_halo: MeshInstance3D
var _ring_material: StandardMaterial3D
var _halo_material: ShaderMaterial
var _spark_material: ShaderMaterial
var _orb_particles: Array[MeshInstance3D] = []

func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("06080a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b6bbad")
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = 0.045
	environment.fog_light_color = Color("0b1118")
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var camera := Camera3D.new()
	_camera = camera
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.8
	camera.position = Vector3(3.4,2.7,7)
	add_child(camera)
	camera.look_at(Vector3(0,1.5,0))
	camera.current = true
	get_viewport().size_changed.connect(_fit_camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38,-30,0)
	key.light_color = Color("ffe3b0")
	key.light_energy = 1.3
	key.shadow_enabled = true
	add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2,2,-2)
	fill.light_color = Color("97b9d3")
	fill.light_energy = 0.8
	add_child(fill)
	var rim_light := OmniLight3D.new()
	rim_light.name = "RimLight"
	rim_light.position = Vector3(0,3,-2)
	rim_light.light_color = Color("87b6da")
	rim_light.light_energy = 1.8
	rim_light.omni_range = 7
	add_child(rim_light)
	var pedestal := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.3
	cylinder.bottom_radius = 1.4
	cylinder.height = 0.16
	pedestal.mesh = cylinder
	pedestal.position.y = -0.08
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("10151b")
	stone.roughness = 0.9
	pedestal.material_override = stone
	add_child(pedestal)
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.20
	ring.outer_radius = 1.24
	rim.mesh = ring
	rim.position.y = 0.01
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("ac8c4d")
	gold.metallic = 0.4
	rim.material_override = gold
	add_child(rim)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40,40)
	floor_mesh.mesh = plane
	floor_mesh.position.y = -0.18
	floor_mesh.material_override = stone
	add_child(floor_mesh)

func show_character(id: String) -> void:
	if _id == id and is_instance_valid(_avatar): return
	_id = id
	_orb = null
	_orb_light = null
	_weapon = null
	_offhand_weapon = null
	_shield_parts.clear()
	_feet.clear()
	_orb_particles.clear()
	if is_instance_valid(_avatar):
		remove_child(_avatar)
		_avatar.free()
	if id == "knight":
		_avatar = KNIGHT.instantiate()
		_avatar.rotation.y = 0.0
	else:
		_avatar = Node3D.new()
		var model: Node3D = CATALOG.create_model(id)
		model.name = "Avatar"
		model.scale *= 0.71
		_avatar.add_child(model)
		var animator := AnimationPlayer.new()
		animator.name = "AnimationPlayer"
		animator.root_node = NodePath("../Avatar")
		animator.add_animation_library("locomotion", preload("res://assets/characters/kaykit/animations/locomotion.tres"))
		animator.add_animation_library("magic", preload("res://assets/characters/kaykit/animations/magic.tres"))
		_avatar.add_child(animator)
	_avatar.name = "CharacterAvatar"
	_avatar.scale *= 1.65
	add_child(_avatar)
	_animator = _avatar.get_node("AnimationPlayer")
	_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_animator.play(&"locomotion/Idle_A")
	_animator.advance(0.0)
	_animator.pause()
	_skeleton = _avatar.find_child("Skeleton3D", true, false)
	if id == "knight":
		_weapon = _skeleton.get_node("RightHandWeapon").get_child(0)
		_weapon.reparent(_avatar)
	if id == "lan":
		# Preview-only short blades; the shared model and combat equipment stay untouched.
		for side in ["r", "l"]:
			var grip := Node3D.new()
			grip.name = "PreviewBladeRight" if side == "r" else "PreviewBladeLeft"
			var blade := preload("res://assets/characters/kaykit/weapons/sword_1handed.gltf").instantiate()
			blade.scale = Vector3.ONE * 0.62
			grip.add_child(blade)
			_avatar.add_child(grip)
			if side == "r": _weapon = grip
			else: _offhand_weapon = grip
	if id == "iron":
		for part in _skeleton.get_node("IronRoundShield").get_children():
			_shield_parts[part] = part.position
	if id == "astra":
		var orb := MeshInstance3D.new()
		_orb = orb
		orb.name = "DisplaySpell"
		var sphere := SphereMesh.new()
		sphere.radius = 0.065
		sphere.height = 0.13
		orb.mesh = sphere
		var glow := ShaderMaterial.new()
		_orb_material = glow
		glow.shader = preload("res://assets/shaders/preview_magic_orb.gdshader")
		orb.material_override = glow
		_avatar.add_child(orb)
		_orb_light = OmniLight3D.new()
		_orb_light.light_color = Color("3b8dff")
		_orb_light.omni_range = 1.2
		orb.add_child(_orb_light)
		_orb_ring = MeshInstance3D.new()
		var orbit := TorusMesh.new()
		orbit.inner_radius = 0.086
		orbit.outer_radius = 0.088
		_orb_ring.mesh = orbit
		_ring_material = StandardMaterial3D.new()
		_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ring_material.albedo_color = Color(0.07,0.38,1.0,0.0)
		_orb_ring.material_override = _ring_material
		orb.add_child(_orb_ring)
		_halo_material = ShaderMaterial.new()
		_halo_material.shader = preload("res://assets/shaders/preview_magic_glow.gdshader")
		_orb_halo = _glow_quad("SoftHalo",Vector2(0.36,0.36),_halo_material)
		_spark_material = ShaderMaterial.new()
		_spark_material.shader = _halo_material.shader
		_spark_material.set_shader_parameter("spark",1.0)
		for i in 18:
			var particle := _glow_quad("OrbitSpark%02d" % i,Vector2.ONE*(0.015+0.004*(i%3)),_spark_material)
			_orb_particles.append(particle)
	_elapsed = 0.0
	_fit_camera()
	_update_pose()

func _fit_camera() -> void:
	var dimensions := get_viewport().get_visible_rect().size
	var aspect := dimensions.x / maxf(1.0, dimensions.y)
	_camera.size = maxf(5.1 if _id == "astra" else 4.8, 3.3 / maxf(0.4,aspect))

func _process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(_avatar):
		_update_pose()

func _update_pose() -> void:
	_skeleton.reset_bone_poses()
	var yaw: float = {"knight":STANDARD_PREVIEW_YAW,"lan":STANDARD_PREVIEW_YAW,"iron":0.32,"astra":0.18}[_id]
	_avatar.rotation.y = yaw
	var duration: float = CYCLE_SECONDS[_id]
	var t := fposmod(_elapsed,duration)
	var phase := t / duration
	# One closed breathing cycle keeps the first/last pose continuous.
	_animator.seek(phase * _animator.get_animation(&"locomotion/Idle_A").length,true)
	_skeleton.force_update_all_bone_transforms()
	if _feet.is_empty():
		for side in ["r","l"]:
			var pose := _skeleton.get_bone_global_pose(_skeleton.find_bone("foot."+side))
			_feet[side] = _skeleton.global_transform * pose
	var head := _bone_world("head")
	var height := maxf(0.5,head.y - _avatar.global_position.y)
	match _id:
		"knight":
			var wind := _gesture(t,0.35,1.25,1.50,1.80)
			var drive := _gesture(t,1.50,1.80,2.15,3.50)
			# Retime the authored strike: deliberate loading, a short release, a heavy recovery.
			_attack_pose(_attack_time(t,0.35,1.25,1.50,1.80,2.15,3.50),0.90)
			_body(Vector3(-0.055*wind+0.07*drive,-0.085-0.035*wind,0.075*drive-0.035*wind)*height,-0.06-0.08*drive,0.12*wind-0.10*drive)
			_plant_feet(0.07,0.095)
			_offset("head",Vector3.RIGHT,0.06+0.08*wind)
		"lan":
			_lan_cross_assault(t,height,yaw)
		"iron":
			var guard := _gesture(t,0.25,0.80,2.05,2.85)
			var drive := _gesture(t,1.15,1.35,1.60,2.10)
			var recoil := _gesture(t,1.35,1.45,1.52,1.85)
			var stance := _gesture(t,2.85,3.15,3.35,3.80)
			_body(Vector3(0.025*guard,-0.055-0.045*guard,0.115*drive-0.035*recoil-0.025*guard)*height,-0.05-0.12*drive,-0.10*guard+0.07*stance)
			_plant_feet(0.115,0.105)
			var shield_radius := 0.40 * _skeleton.global_basis.x.length()
			var resting := Vector3(0.28*height,shield_radius+0.015,0.18*height)
			var defensive := Vector3(0.12,0.70,0.32+0.19*drive-0.035*recoil)*height
			_arm("l",_point(resting.lerp(defensive,guard)),1.0,Vector3.RIGHT)
			_grip("l",Basis(Vector3.RIGHT,PI*0.5),1.0)
			_arm("r",_point(Vector3(-0.29,0.53,0.23)*height),0.7,Vector3.LEFT)
			_skeleton.force_update_all_bone_transforms()
			var drop := maxf(0,_bone_world("handslot.l").y-shield_radius-0.015)*(1.0-guard)
			var grip_world := _skeleton.global_basis*_skeleton.get_bone_global_pose(_skeleton.find_bone("handslot.l")).basis
			for part in _shield_parts:
				part.position = _shield_parts[part] + grip_world.inverse()*Vector3(0,-drop,0)
			_offset("head",Vector3.RIGHT,0.08*guard)
		"astra":
			var hand := _gesture(t,0.35,1.25,3.10,4.10)
			var glow := _gesture(t,0.65,1.60,2.45,3.10)
			var drive := _gesture(t,1.90,2.18,2.50,3.25)
			_body(Vector3(-0.04*hand+0.07*drive,-0.045-0.035*hand,0.085*drive-0.025*hand)*height,-0.04-0.08*drive,-0.18*hand+0.23*drive)
			_plant_feet(0.07,0.09)
			_arm("r",_point(Vector3(-0.23-0.04*drive,0.65,0.30+0.17*drive)*height),hand,Vector3.LEFT)
			_grip("r",Basis.IDENTITY,hand)
			_arm("l",_point(Vector3(0.16,0.54,0.30)*height),0.85*hand,Vector3.RIGHT)
			_offset("head",Vector3.RIGHT,0.08+0.07*hand)
			_skeleton.force_update_all_bone_transforms()
			_orb.visible = glow > 0.001
			_orb.scale = Vector3.ONE * (0.35+1.6*glow+0.60*drive*glow)
			var orb_radius := 0.065*_orb.global_basis.x.length()
			_orb.global_position = _bone_world("handslot.r")+Vector3.UP*(orb_radius+0.06)+Basis(Vector3.UP,yaw)*Vector3(-0.04,0,0.055)
			_orb_ring.rotation = Vector3(0.45,phase*TAU*2.0,0.55)
			_orb_material.set_shader_parameter("reveal",glow)
			_orb_material.set_shader_parameter("phase",phase*TAU)
			_orb_material.set_shader_parameter("power",drive)
			_ring_material.albedo_color.a = 0.32*glow
			_halo_material.set_shader_parameter("strength",glow*(0.65+0.35*drive))
			_spark_material.set_shader_parameter("strength",glow)
			_orb_halo.look_at(_camera.global_position)
			for i in _orb_particles.size():
				var angle := phase*TAU*(2+i%3)+i*TAU/18.0
				var radius := 0.105+0.018*sin(phase*TAU*2+i)
				var orbit := Vector3(cos(angle),sin(angle)*0.35,sin(angle))*radius
				_orb_particles[i].position = Basis(Vector3.FORWARD,(i%3)*0.8)*orbit
				_orb_particles[i].scale = Vector3.ONE*(0.75+0.25*sin(angle*2+i))
				_orb_particles[i].look_at(_camera.global_position)
			_orb_light.light_energy = (0.45+0.6*drive)*glow
	_skeleton.force_update_all_bone_transforms()
	if is_instance_valid(_weapon):
		_weapon.global_transform = _skeleton.global_transform*_skeleton.get_bone_global_pose(_skeleton.find_bone("handslot.r"))
	if is_instance_valid(_offhand_weapon):
		_offhand_weapon.global_transform = _skeleton.global_transform*_skeleton.get_bone_global_pose(_skeleton.find_bone("handslot.l"))

func _lan_cross_assault(t: float, height: float, yaw: float) -> void:
	# Offset the peaks with no held keys: compact coil -> 0.15 s burst ->
	# immediate opening -> light recovery. The torso follows the hands through impact.
	var load := _gesture(t,0.10,0.45,0.45,0.64)
	var thrust := _gesture(t,0.45,0.60,0.60,0.93)
	var spread := _gesture(t,0.60,0.90,0.90,1.70)
	var advance := _gesture(t,0.45,0.64,0.64,1.92)
	_body(Vector3(-0.02*load+0.025*thrust+0.015*spread,-0.04-0.055*load+0.01*thrust,0.115*advance-0.02*load)*height,
		-0.06-0.07*load-0.09*thrust+0.025*spread,-0.15*load+0.19*thrust+0.05*spread)
	var right_step := _footstep(t,0.45,0.61,1.20,1.44,Vector3(-0.01,0,0.19),0.035)
	var left_step := _footstep(t,0.53,0.72,1.45,1.69,Vector3(0.01,0,0.09),0.035)
	_plant_feet(0.045,0.075,right_step,left_step)
	_offset("head",Vector3.RIGHT,0.04+0.045*load-0.02*thrust)
	_offset("head",Vector3.UP,-0.025*load+0.04*thrust)
	for side in ["r", "l"]:
		var right: bool = side == "r"
		var sign_x := -1.0 if right else 1.0
		var hand := Vector3(sign_x*0.25,0.52 if right else 0.56,0.22)
		hand = hand.lerp(Vector3(sign_x*0.29,0.49 if right else 0.54,0.04),load)
		# Stagger the wrists vertically and in depth so the crossing blades clear each other.
		hand = hand.lerp(Vector3(sign_x*0.12,0.63 if right else 0.65,0.52 if right else 0.34),thrust)
		hand = hand.lerp(Vector3(sign_x*0.36,0.62 if right else 0.60,0.25),spread)
		_arm(side,_point(hand*height),1.0,Vector3.LEFT if right else Vector3.RIGHT)
		var direction := Vector3(sign_x*0.60,-0.10,0.79)
		direction = direction.lerp(Vector3(-sign_x*0.16,0.10,0.98),load)
		direction = direction.lerp(Vector3(0.82 if right else -0.55,0.44,0.37 if right else 0.71),thrust)
		direction = direction.lerp(Vector3(sign_x*0.82,0.14,0.55),spread)
		var world_direction := Basis(Vector3.UP,yaw)*direction.normalized()
		_grip(side,Basis(Quaternion(Vector3.UP,world_direction)),1.0)

func _glow_quad(node_name: String, size: Vector2, material: ShaderMaterial) -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	quad.name = node_name
	var mesh := QuadMesh.new()
	mesh.size = size
	quad.mesh = mesh
	quad.material_override = material
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orb.add_child(quad)
	return quad

func _footstep(t: float, start: float, planted: float, back: float, end: float, travel: Vector3, lift: float = 0.065) -> Vector3:
	var offset := travel*_gesture(t,start,planted,back,end)
	if t > start and t < planted:
		offset.y = sin(PI*smoothstep(start,planted,t))*lift
	elif t > back and t < end:
		offset.y = sin(PI*smoothstep(back,end,t))*lift
	return offset

func _attack_time(t: float, start: float, loaded: float, release: float, impact: float, follow: float, end: float) -> float:
	if t < start: return 0.0
	if t < loaded: return 0.33*smoothstep(start,loaded,t)
	if t < release: return 0.33
	if t < impact: return lerpf(0.33,0.48,smoothstep(release,impact,t))
	if t < follow: return lerpf(0.48,0.56,smoothstep(impact,follow,t))
	return lerpf(0.56,1.0,smoothstep(follow,end,t))

func _attack_pose(time: float, weight: float) -> void:
	# Read shared clips without editing them or changing gameplay animation playback.
	var animation: Animation = MELEE.get_animation(&"Melee_1H_Attack_Slice_Diagonal")
	for track in animation.get_track_count():
		var bone := _skeleton.find_bone(animation.track_get_path(track).get_subname(0))
		if bone < 0: continue
		if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			_skeleton.set_bone_pose_rotation(bone,_skeleton.get_bone_pose_rotation(bone).slerp(animation.rotation_track_interpolate(track,time),weight))
		elif animation.track_get_type(track) == Animation.TYPE_POSITION_3D:
			var position := animation.position_track_interpolate(track,time)
			if _skeleton.get_bone_name(bone) == "hips":
				var origin := animation.position_track_interpolate(track,0.0)
				position = origin+(position-origin)*0.24
			_skeleton.set_bone_pose_position(bone,_skeleton.get_bone_pose_position(bone).lerp(position,weight))
	_skeleton.force_update_all_bone_transforms()

func _body(shift: Vector3, lean: float, twist: float) -> void:
	var hips := _skeleton.find_bone("hips")
	var pose := _skeleton.get_bone_global_pose(hips)
	pose.origin += _skeleton.global_basis.inverse()*(_point(shift)-_avatar.global_position)
	_skeleton.set_bone_global_pose(hips,pose)
	_offset("spine",Vector3.RIGHT,lean)
	_offset("chest",Vector3.UP,twist)
	_skeleton.force_update_all_bone_transforms()

func _plant_feet(width: float, stagger: float, right_step := Vector3.ZERO, left_step := Vector3.ZERO) -> void:
	# Fixed ankle anchors let the pelvis travel and knees bend without skating.
	for side in ["r","l"]:
		var sign_x := -1.0 if side == "r" else 1.0
		var anchor: Transform3D = _feet[side]
		var offset := Vector3(sign_x*width,0,-sign_x*stagger)+(right_step if side == "r" else left_step)
		var target := anchor.origin + _point(offset)-_avatar.global_position
		_limb("upperleg."+side,"lowerleg."+side,"foot."+side,target,1.0,Vector3.BACK)
		var bone := _skeleton.find_bone("foot."+side)
		var pose := _skeleton.get_bone_global_pose(bone)
		pose.basis = _skeleton.global_basis.inverse()*anchor.basis
		_skeleton.set_bone_global_pose(bone,pose)
		_skeleton.force_update_all_bone_transforms()

func _gesture(t: float, start: float, raised: float, hold: float, end: float) -> float:
	if t < start or t >= end: return 0.0
	if t < raised: return smoothstep(start,raised,t)
	if t <= hold: return 1.0
	return 1.0-smoothstep(hold,end,t)

func _point(local: Vector3) -> Vector3:
	# Targets are in world metres; avatar/model scales remain the authored ones.
	return _avatar.global_position + Basis(Vector3.UP,_avatar.rotation.y)*local

func _bone_world(name: String) -> Vector3:
	return _skeleton.to_global(_skeleton.get_bone_global_pose(_skeleton.find_bone(name)).origin)

func _arm(side: String, target_world: Vector3, weight: float, pole_world: Vector3) -> void:
	_limb("upperarm."+side,"lowerarm."+side,"handslot."+side,target_world,weight,pole_world)

func _limb(upper_name: String, lower_name: String, end_name: String, target_world: Vector3, weight: float, pole_world: Vector3) -> void:
	var upper := _skeleton.find_bone(upper_name)
	var lower := _skeleton.find_bone(lower_name)
	var hand := _skeleton.find_bone(end_name)
	if mini(upper,mini(lower,hand)) < 0 or weight <= 0: return
	_skeleton.force_update_all_bone_transforms()
	var shoulder := _skeleton.get_bone_global_pose(upper).origin
	var elbow := _skeleton.get_bone_global_pose(lower).origin
	var wrist := _skeleton.get_bone_global_pose(hand).origin
	var target := wrist.lerp(_skeleton.to_local(target_world),weight)
	var a := shoulder.distance_to(elbow)
	var b := elbow.distance_to(wrist)
	var direction := (target-shoulder).normalized()
	var distance := clampf(shoulder.distance_to(target),absf(a-b)+0.001,a+b-0.001)
	var projection := (a*a-b*b+distance*distance)/(2*distance)
	var pole := _skeleton.global_basis.inverse()*pole_world
	var bend := (pole-direction*pole.dot(direction)).normalized()
	var desired_elbow := shoulder+direction*projection+bend*sqrt(maxf(0,a*a-projection*projection))
	_aim(upper,lower,desired_elbow)
	_aim(lower,hand,shoulder+direction*distance)

func _aim(parent: int, child: int, target: Vector3) -> void:
	var pose := _skeleton.get_bone_global_pose(parent)
	var current := _skeleton.get_bone_global_pose(child).origin-pose.origin
	var desired := target-pose.origin
	if current.length_squared() < 0.000001 or desired.length_squared() < 0.000001: return
	pose.basis = Basis(Quaternion(current.normalized(),desired.normalized()))*pose.basis
	_skeleton.set_bone_global_pose(parent,pose)
	_skeleton.force_update_all_bone_transforms()

func _grip(side: String, basis: Basis, weight: float) -> void:
	var bone := _skeleton.find_bone("handslot."+side)
	var pose := _skeleton.get_bone_global_pose(bone)
	var desired := _skeleton.global_basis.orthonormalized().inverse()*basis
	pose.basis = Basis(pose.basis.get_rotation_quaternion().slerp(desired.get_rotation_quaternion(),weight))
	_skeleton.set_bone_global_pose(bone,pose)

func _offset(name: String, axis: Vector3, angle: float) -> void:
	var bone := _skeleton.find_bone(name)
	if bone >= 0: _skeleton.set_bone_pose_rotation(bone,_skeleton.get_bone_pose_rotation(bone)*Quaternion(axis,angle))
