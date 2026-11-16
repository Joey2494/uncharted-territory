extends Node3D
## Menu-only diorama built from the game's existing art, without gameplay actors.
const KNIGHT = preload("res://scenes/characters/knight_visual.tscn")
const CHARACTERS = preload("res://scenes/player/character_catalog.gd")
const LOCOMOTION = preload("res://assets/characters/kaykit/animations/locomotion.tres")
const MAGIC = preload("res://assets/characters/kaykit/animations/magic.tres")
# A triangular party composition: foreground, two flanks, raised rear position.
const STAGING := {
	"knight": {"at": Vector3(-0.4, 0, 1.50), "yaw": 0.22, "scale": 1.40, "phase": 0.0, "speed": 0.64, "action": "从容持剑"},
	"lan": {"at": Vector3(-2.80, 0, -1.65), "yaw": -0.40, "scale": 1.25, "phase": 0.35, "speed": 0.52, "action": "侧身观察"},
	"iron": {"at": Vector3(2.10, 0, -0.65), "yaw": 0.62, "scale": 1.36, "phase": 0.68, "speed": 0.43, "action": "持盾待命"},
	"astra": {"at": Vector3(0.15, 0.32, -2.7), "yaw": -0.20, "scale": 1.28, "phase": 0.18, "speed": 0.37, "action": "凝神施法"},
}
const VISUALS = preload("res://scenes/dungeon/almsyone_visuals.gd")
const FLOOR = preload("res://assets/dungeon/almsyone/SM_Floor_Stone.glb")
const WALL = preload("res://assets/dungeon/almsyone/SM_Wall.glb")
const PILLAR = preload("res://assets/dungeon/almsyone/SM_Pillar.glb")
const TORCH = preload("res://assets/dungeon/almsyone/SM_Torch_Standing.glb")
const BANNER = preload("res://assets/dungeon/almsyone/SM_Banner_Blue.glb")
const RUBBLE = preload("res://assets/dungeon/almsyone/SM_Rubble.glb")
var _art := VISUALS.new()
var _torches: Array[OmniLight3D] = []
var _elapsed := 0.0
var _animator: AnimationPlayer
var _knight: Node3D
var _moon: DirectionalLight3D
var _actors: Dictionary = {}
var _camera: Camera3D
var _selection_light: OmniLight3D
var _selected_id := "knight"

func _ready() -> void:
	_art.stone_brightness = 0.55
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("080d12")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7894ae")
	environment.ambient_light_energy = 0.20
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("16202a")
	environment.fog_density = 0.025
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var camera := Camera3D.new()
	_camera = camera
	camera.name = "PreviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.6
	camera.position = Vector3(3.8, 3.3, 10.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.15, -0.6))
	camera.current = true
	var moon := DirectionalLight3D.new()
	_moon = moon
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-42, -25, 0)
	moon.light_color = Color("9bbada")
	moon.light_energy = 0.5
	moon.shadow_enabled = true
	add_child(moon)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.5, 3.2, 3.0)
	fill.light_color = Color("cedce4")
	fill.light_energy = 1.0
	fill.omni_range = 7.0
	add_child(fill)
	var flank_fill := OmniLight3D.new()
	flank_fill.name = "PartyFill"
	flank_fill.position = Vector3(-2, 2.5, 2.5)
	flank_fill.light_color = Color("cedce4")
	flank_fill.light_energy = 0.45
	flank_fill.omni_range = 6.0
	add_child(flank_fill)
	var top := -INF
	for part in _art.parts(FLOOR):
		var bounds: AABB = part.transform * part.mesh.get_aabb()
		top = maxf(top, bounds.end.y)
	for x in range(-4, 6):
		for z in range(-6, 7):
			_model(FLOOR, "Floor", Vector3(x * 2, -top, z * 2))
	for x in [-5.0, -3.0, 3.0, 5.0]:
		_model(WALL, "AncientWall", Vector3(x, 0, -4))
	for side in [-1.0, 1.0]:
		_model(PILLAR, "GatePillar", Vector3(side * 1.6, 0, -3.85), Vector3.ONE * 1.15)
		_model(BANNER, "BlueBanner", Vector3(side * 3.2, 2.6, -3.65))
		_model(TORCH, "GateTorch", Vector3(side * 2.0, 0, -2.2))
		for z in [-6.0, -8.0, -10.0]:
			_model(WALL, "CorridorWall", Vector3(side * 1.8, 0, z), Vector3.ONE, PI * 0.5)
		var light := OmniLight3D.new()
		light.name = "TorchLight"
		light.position = Vector3(side * 2.0, 1.8, -1.8)
		light.light_color = Color("ffa958")
		light.light_energy = 2.0
		light.omni_range = 5.0
		light.shadow_enabled = true
		add_child(light)
		_torches.append(light)
	_model(WALL, "GateLintel", Vector3(0, 3.0, -4), Vector3(1.8, 0.35, 1))
	_model(RUBBLE, "RuinedStone", Vector3(3.6, 0, 0.4))
	# Existing stone floor pieces form the rear character's shallow dais.
	_model(FLOOR, "RearDais", Vector3(0, 0.32 - top, -2.7), Vector3(0.85, 1, 0.85))
	for id in CHARACTERS.IDS:
		_add_character(id)
	_selection_light = OmniLight3D.new()
	_selection_light.name = "SelectedCharacterLight"
	_selection_light.light_color = Color("ffe0a3")
	_selection_light.light_energy = 0.38
	_selection_light.omni_range = 3.0
	add_child(_selection_light)
	set_character("knight")
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()
	_add_dust()

func set_character(id: String) -> void:
	if not _actors.has(id):
		return
	_selected_id = id
	# Selection emphasizes the chosen member without removing the party.
	for member in _actors:
		_actors[member].node.set_meta("selected", member == id)

func _add_character(id: String) -> void:
	var actor: Node3D
	if id == "knight":
		actor = KNIGHT.instantiate()
	else:
		actor = Node3D.new()
		var model: Node3D = CHARACTERS.create_model(id)
		model.name = "Avatar"
		model.scale *= 0.71
		actor.add_child(model)
		var animator := AnimationPlayer.new()
		animator.name = "AnimationPlayer"
		animator.root_node = NodePath("../Avatar")
		animator.add_animation_library("locomotion", LOCOMOTION)
		animator.add_animation_library("magic", MAGIC)
		actor.add_child(animator)
	var staging: Dictionary = STAGING[id]
	actor.name = "Menu" + id.capitalize()
	actor.set_meta("character_id", id)
	actor.set_meta("presentation_action", staging.action)
	actor.position = staging.at
	actor.rotation.y = staging.yaw
	actor.scale *= staging.scale
	add_child(actor)
	var animator: AnimationPlayer = actor.get_node("AnimationPlayer")
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var clip: StringName = &"magic/Ranged_Magic_Shoot" if id == "astra" else (&"locomotion/Walking_A" if id == "lan" else &"locomotion/Idle_A")
	animator.play(clip)
	animator.advance(0.0)
	animator.pause()
	var skeleton: Skeleton3D = actor.find_child("Skeleton3D", true, false)
	_actors[id] = {"node": actor, "animator": animator, "skeleton": skeleton, "clip": clip}
	if id == "knight":
		_knight = actor
		_animator = animator

func _fit_camera() -> void:
	var dimensions := get_viewport().get_visible_rect().size
	# Keep the party framed above the bottom-right selection panel, including
	# the narrow SubViewport used by square and portrait windows.
	var aspect := dimensions.x / maxf(1.0, dimensions.y)
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = maxf(7.6, 6.5 / maxf(0.3, aspect))
	_camera.v_offset = -0.35 if aspect < 0.8 else 0.0

func _model(scene: PackedScene, label: String, at: Vector3, dimensions: Vector3 = Vector3.ONE, yaw: float = 0.0) -> void:
	_art.add_model(self, scene, label, Transform3D(Basis(Vector3.UP, yaw).scaled_local(dimensions), at))

func _process(delta: float) -> void:
	_elapsed += delta
	for id in _actors:
		_update_character(id)
	var chosen: Node3D = _actors[_selected_id].node
	_selection_light.position = _selection_light.position.lerp(chosen.position + Vector3(0, 2.1, 1.2), minf(1, delta * 4))
	_moon.rotation_degrees.y = -25.0 + sin(_elapsed * 0.13) * 2.0
	_moon.light_energy = 0.47 + sin(_elapsed * 0.17) * 0.035
	for i in range(_torches.size()):
		_torches[i].light_energy = 1.85 + sin(_elapsed * 6.0 + i * 2.0) * 0.15 + sin(_elapsed * 11.0 + i) * 0.06
		_torches[i].position.x = (-2.0 if i == 0 else 2.0) + sin(_elapsed * 2.0 + i) * 0.035

func _update_character(id: String) -> void:
	var entry: Dictionary = _actors[id]
	var staging: Dictionary = STAGING[id]
	var animator: AnimationPlayer = entry.animator
	var time := _elapsed * float(staging.speed) + float(staging.phase)
	match id:
		"lan":
			# Gently sample a planted walking pose as a weight shift, no root travel.
			time = 0.10 + sin(time * 1.1) * 0.035
		"astra":
			# The existing magic preparation poses become a quiet hand display.
			time = 0.22 + sin(time * 0.9) * 0.06
		_:
			time = fmod(time, animator.get_animation(entry.clip).length)
	var skeleton: Skeleton3D = entry.skeleton
	if skeleton != null:
		skeleton.reset_bone_poses()
	animator.seek(time, true)
	if skeleton != null:
		_offset_bone(skeleton, "head", Vector3.UP, sin(_elapsed * 0.35 + float(staging.phase) * 4) * (0.12 if id == "lan" else 0.035))
		if id == "iron":
			_offset_bone(skeleton, "upperarm.l", Vector3.FORWARD, -0.24)
			_offset_bone(skeleton, "lowerarm.l", Vector3.RIGHT, -0.36)
		elif id == "lan":
			_offset_bone(skeleton, "chest", Vector3.UP, -0.12)
		elif id == "astra":
			_offset_bone(skeleton, "chest", Vector3.FORWARD, sin(_elapsed * 0.55) * 0.025)
	entry.node.rotation.y = float(staging.yaw) + sin(_elapsed * 0.27 + float(staging.phase) * 3) * 0.015

func _offset_bone(skeleton: Skeleton3D, bone_name: String, axis: Vector3, angle: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone >= 0:
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * Quaternion(axis, angle))

func _add_dust() -> void:
	var dust := CPUParticles3D.new()
	dust.name = "TorchMotes"
	dust.position = Vector3(0, 1.1, -1.4)
	dust.amount = 24
	dust.lifetime = 7.0
	dust.preprocess = 3.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(3.0, 1.0, 1.5)
	dust.direction = Vector3.UP
	dust.spread = 35.0
	dust.initial_velocity_min = 0.06
	dust.initial_velocity_max = 0.16
	dust.gravity = Vector3.ZERO
	var mote := QuadMesh.new()
	mote.size = Vector2(0.018, 0.018)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color("c5a572")
	mote.material = material
	dust.mesh = mote
	add_child(dust)
