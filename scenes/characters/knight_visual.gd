extends Node3D
## Shared presentation for the character preview and Player; no combat logic.
@export var sword_scene: PackedScene = preload("res://assets/characters/kaykit/weapons/sword_1handed.gltf")
@export var shield_scene: PackedScene = preload("res://assets/characters/kaykit/weapons/shield_badge_color.gltf")

func _ready() -> void:
	_attach(&"RightHandWeapon", &"handslot.r", sword_scene)
	_attach(&"LeftHandShield", &"handslot.l", shield_scene)

func _attach(socket_name: StringName, bone: StringName, scene: PackedScene) -> void:
	var skeleton: Skeleton3D = $Knight/Rig_Medium/Skeleton3D
	if scene == null or skeleton.has_node(NodePath(socket_name)):
		return
	var socket := BoneAttachment3D.new()
	socket.name = socket_name
	socket.bone_name = bone
	skeleton.add_child(socket)
	var equipment: Node3D = scene.instantiate()
	if socket_name == &"LeftHandShield":
		# The grip follows the hand; orient the shield upright along the forearm.
		equipment.basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
	socket.add_child(equipment)
