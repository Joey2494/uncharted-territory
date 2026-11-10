extends Node3D
## 导能设施共用的实体交互入口。输入只经玩家背包的最近目标选择。

const REACH := 1.8
const MAX_HEIGHT_DIFFERENCE := 2.0

@export var receiver_path: NodePath
@export var control_id: StringName
@export var caption := "机关"
@export var accent := Color(0.38, 0.83, 0.8)

@onready var _receiver := get_node_or_null(receiver_path)
@onready var _label: Label3D = $Caption
@onready var _signal_mesh: MeshInstance3D = $Signal
@onready var _body: StaticBody3D = $Base
var _material: StandardMaterial3D

func _ready() -> void:
	add_to_group("world_interactables")
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_signal_mesh.material_override = _material
	set_display(caption, false)

## 保留设施名称；运行时可在第二行更新档位或锁定原因。
func set_display(text: String, lit: bool) -> void:
	_label.text = text
	_material.albedo_color = accent if lit else accent.darkened(0.68)

## 使用平面距离、垂直高度和实体遮挡过滤，不越墙、不跨层。
func can_interact(player: CharacterBody3D) -> bool:
	if not is_instance_valid(player) or not player.can_process() or player.is_dead() or not can_process():
		return false
	if not is_visible_in_tree() or not is_instance_valid(_receiver) or not _receiver.can_process():
		return false
	var offset := player.global_position - global_position
	if absf(offset.y) > MAX_HEIGHT_DIFFERENCE or Vector2(offset.x, offset.z).length() > REACH:
		return false
	if not _receiver.is_control_available(control_id, player):
		return false
	var start := player.global_position + Vector3.UP * 0.8
	var finish := global_position + Vector3.UP * 0.8
	var query := PhysicsRayQueryParameters3D.create(start, finish, 1, [player.get_rid(), _body.get_rid()])
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func try_interact(player: CharacterBody3D) -> bool:
	return can_interact(player) and _receiver.perform_control(control_id, player)

func get_interaction_prompt() -> String:
	return "[E] " + caption
