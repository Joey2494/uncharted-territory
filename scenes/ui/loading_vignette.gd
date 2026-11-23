extends "res://scenes/ui/menu_dungeon_preview.gd"
## Static compositions, existing game models and authored/procedural poses only.
const POSE = preload("res://scenes/ui/character_preview.gd")
const GATEKEEPER = preload("res://assets/characters/kaykit/BronzeGatekeeper.tscn")
const KING = preload("res://addons/ziyuan_level03/models/SandKingModel.tscn")
const BOSS_MELEE = preload("res://assets/characters/kaykit/barbarian/animations/melee.tres")
const AXE = preload("res://assets/characters/kaykit/barbarian/weapons/axe_2handed.gltf")
var variant := 0
var portrait := false
var subjects: Array[Node3D] = []
var composition_bounds := AABB()
var _composed := false

func _ready() -> void:
	super._ready()
	for entry in _actors.values():
		remove_child(entry.node)
		entry.node.free()
	_actors.clear()
	for dust in get_children():
		if dust is CPUParticles3D:
			dust.emitting = false
			dust.hide()
	if variant in [0,2]:
		var stagger := 0.6 if variant == 2 else 0.0
		if portrait:
			var step := MeshInstance3D.new()
			var stone := BoxMesh.new()
			stone.size = Vector3(6,1.25,2.4)
			step.mesh = stone
			step.position = Vector3(0,0.625,-2.1)
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("4c4d42")
			material.roughness = 0.9
			step.material_override = material
			add_child(step)
			_hero("knight",Vector3(1.45,0,1.4),0.05,1.15)
			_hero("lan",Vector3(-1.45,0,1.4),-0.18,0.65)
			_hero("iron",Vector3(-1.45,1.25,-2.1),0.25,0.8)
			_hero("astra",Vector3(1.45,1.25,-2.1),0.05,1.6)
		else:
			_hero("knight",Vector3(-1.25,0,1.6),0.1,1.15)
			_hero("lan",Vector3(-3.7,0,-0.1-stagger),-0.24,0.65)
			_hero("iron",Vector3(2.1,0,1.2),0.40,0.8)
			_hero("astra",Vector3(3.8,0,-1.0),0.05,1.6) if variant == 2 else _hero("astra",Vector3(0.3,0.32,-2.1),0.05,1.6)
		if variant == 2:
			for node in find_children("*RuinedStone*","Node3D",true,false): node.hide()
	else:
		_hero("knight",Vector3(-0.7,0,1.0),1.05,1.3)
		_hero("astra",Vector3(-1.65 if portrait else -3.0,0,-1.2),0.9,2.2)
		var boss: Node3D = (GATEKEEPER if variant == 1 else KING).instantiate()
		add_child(boss)
		boss.position = Vector3(1.7,0,-0.4)
		boss.rotation.y = -0.6
		if variant == 1:
			boss.scale *= 1.65
			var skeleton: Skeleton3D = boss.find_child("Skeleton3D",true,false)
			if skeleton != null:
				var socket := BoneAttachment3D.new()
				socket.bone_name = "handslot.r"
				skeleton.add_child(socket)
				socket.add_child(AXE.instantiate())
				var animator := AnimationPlayer.new()
				boss.add_child(animator)
				animator.root_node = NodePath("..")
				animator.add_animation_library("strike",BOSS_MELEE)
				animator.play("strike/Melee_2H_Attack_Slice")
				animator.seek(0.42,true)
				animator.pause()
		else:
			boss.scale *= 1.4
			boss.rotation.y += PI # This model's face is authored toward -Z.
			if boss.has_method("pose"): boss.pose(3,0.68,0.0,0.0,0)
		subjects.append(boss)
		_freeze(boss)
	_camera.position = Vector3(0.7,7.5,14) if portrait else (Vector3(3.2,4.7,15) if variant != 2 else Vector3(0.5,4.2,15))
	_camera.look_at(Vector3(0,1.3,0))
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_composed = true
	_fit_camera()
	set_process(false)

func _hero(id: String, at: Vector3, yaw: float, time: float) -> void:
	var preview := POSE.new()
	add_child(preview)
	preview.show_character(id)
	preview._elapsed = time
	preview._update_pose()
	if variant in [1,3] and id == "knight":
		preview._attack_pose(0.23,1.0)
		preview._body(Vector3(0,-0.08,0.12),-0.16,0.2)
		preview._plant_feet(0.10,0.18)
		preview._skeleton.force_update_all_bone_transforms()
		preview._weapon.global_transform = preview._skeleton.global_transform*preview._skeleton.get_bone_global_pose(preview._skeleton.find_bone("handslot.r"))
	var avatar: Node3D = preview._avatar
	avatar.reparent(self)
	avatar.position = at
	avatar.rotation.y = yaw
	# Consistent party scale, retaining the existing character proportions.
	avatar.scale *= 0.84
	subjects.append(avatar)
	_actors[id] = {"node":avatar}
	_freeze(avatar)
	remove_child(preview)
	preview.free()

func _freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is AnimationPlayer: node.pause()
	for child in node.get_children(): _freeze(child)

func _process(_delta: float) -> void:
	pass

func _fit_camera() -> void:
	if not _composed: return
	var first := true
	for subject in subjects:
		var bounds := _bounds(subject)
		if first:
			composition_bounds = bounds
			first = false
		else: composition_bounds = composition_bounds.merge(bounds)
	var center := composition_bounds.get_center()
	_camera.look_at(center)
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for i in 8:
		var point := composition_bounds.get_endpoint(i)-center
		var projected := Vector2(_camera.global_basis.x.dot(point),_camera.global_basis.y.dot(point))
		low = low.min(projected)
		high = high.max(projected)
	var viewport := get_viewport().get_visible_rect().size
	var aspect := viewport.x/maxf(1,viewport.y)
	_camera.size = maxf(6.0 if portrait else 7.8,maxf((high.y-low.y)/(0.70 if portrait else 0.56),(high.x-low.x)/(aspect*0.88)))
	_camera.v_offset = -_camera.size*(0.025 if portrait else 0.12)
	if get_viewport() is SubViewport: get_viewport().render_target_update_mode = SubViewport.UPDATE_ONCE

func _bounds(node: Node3D) -> AABB:
	var result := AABB(node.global_position,Vector3.ONE*0.01)
	for child in node.find_children("*","MeshInstance3D",true,false):
		if child.is_visible_in_tree() and child.mesh != null:
			result = result.merge(child.global_transform*child.mesh.get_aabb())
	return result
