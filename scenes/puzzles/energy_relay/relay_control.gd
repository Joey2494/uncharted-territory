extends Node3D
## 导能设施共用的实体交互入口。输入只经玩家背包的最近目标选择。

const REACH := 1.8
const MAX_HEIGHT_DIFFERENCE := 2.0

@export var receiver_path: NodePath
@export var control_id: StringName
@export var caption := "机关"
@export var short_caption := ""
@export var auxiliary := false
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
	if not short_caption.is_empty():
		_configure_archive_visual()
	set_display(caption, false)

## 档案室只在世界中显示短标识；完整状态由当前交互目标的 HUD 提示承担。
func set_display(text: String, lit: bool) -> void:
	_label.text = short_caption if not short_caption.is_empty() else text
	_material.albedo_color = accent if lit else accent.darkened(0.68)
	if control_id == &"lever" and not short_caption.is_empty():
		_signal_mesh.rotation_degrees.z = 35.0 if lit else -35.0

## 只替换装饰网格与标签，基座碰撞、位置、可达半径均保持原状。
func _configure_archive_visual() -> void:
	if control_id in [&"a", &"b"]:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.22
		ring.outer_radius = 0.42
		_signal_mesh.mesh = ring
		_signal_mesh.rotation_degrees = Vector3(90, 0, 0)
		_signal_mesh.position.y = 1.12
	elif control_id == &"lever":
		var handle := CylinderMesh.new()
		handle.top_radius = 0.10
		handle.bottom_radius = 0.10
		handle.height = 0.9
		_signal_mesh.mesh = handle
		_signal_mesh.rotation_degrees = Vector3(0, 0, -35)
		_signal_mesh.position.y = 1.2
		# 短柄配握球，传动部分留在地面，避免把跨房间管线读成超长手柄。
		var grip := MeshInstance3D.new()
		grip.name = "Grip"
		var ball := SphereMesh.new()
		ball.radius = 0.17
		ball.height = 0.34
		grip.mesh = ball
		grip.material_override = _material
		grip.position.y = 0.45
		_signal_mesh.add_child(grip)
	elif control_id == &"bridge":
		var socket := BoxMesh.new()
		socket.size = Vector3(0.9, 0.18, 0.6)
		_signal_mesh.mesh = socket
		_signal_mesh.rotation_degrees = Vector3.ZERO
	elif control_id == &"rack":
		var tray := BoxMesh.new()
		tray.size = Vector3(1.05, 0.12, 0.55)
		_signal_mesh.mesh = tray
		_signal_mesh.rotation_degrees = Vector3.ZERO
	if auxiliary:
		_label.modulate = Color(0.72, 0.68, 0.56, 0.65)
		_signal_mesh.scale = Vector3(0.7, 0.5, 0.7)

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
	if is_instance_valid(_receiver) and _receiver.has_method("get_control_prompt"):
		return _receiver.get_control_prompt(control_id)
	return "[E] " + caption
