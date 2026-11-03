extends Node
## Attach below an actor and set visual_root to that actor's visual subtree.
## Call flash() only after a real, accepted hit. No gameplay HP is changed here.

signal flash_started
signal flash_finished

const FLASH_SHADER: Shader = preload("res://assets/shaders/hit_flash_3d.gdshader")

@export var visual_root: NodePath = NodePath("..")
@export_range(0.01, 1.0, 0.01) var flash_duration: float = 0.1
@export var flash_color: Color = Color(0.78, 0.12, 0.08, 0.9)

var _active: bool = false
var _timer: Timer
var _material: ShaderMaterial
var _bindings: Array[Dictionary] = []


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = FLASH_SHADER
	_timer = Timer.new()
	_timer.name = "FlashTimer"
	_timer.one_shot = true
	_timer.timeout.connect(reset)
	add_child(_timer)


func flash() -> bool:
	if not is_node_ready() or not is_inside_tree():
		return false
	if not _active:
		var root: Node = get_node_or_null(visual_root)
		if root == null:
			return false
		var meshes: Array[MeshInstance3D] = []
		if root is MeshInstance3D:
			meshes.append(root)
		for node in root.find_children("*", "MeshInstance3D", true, false):
			meshes.append(node)
		if meshes.is_empty():
			return false
		for mesh in meshes:
			_bindings.append({"mesh": weakref(mesh), "overlay": mesh.material_overlay})
			mesh.material_overlay = _material
		_active = true
		flash_started.emit()
	_material.set_shader_parameter("flash_color", flash_color)
	# A new hit restarts the duration without overwriting the original overlays.
	_cancel_timing()
	if DisplayServer.get_name() == "headless":
		# There is no rendered frame to wait for in a headless simulation.
		_timer.start(flash_duration)
	else:
		# A startup delta can include time before this hit. Arm the countdown
		# only after a draw that was submitted with this overlay already set.
		RenderingServer.frame_pre_draw.connect(_on_frame_pre_draw, CONNECT_ONE_SHOT)
	return true


func _on_frame_pre_draw() -> void:
	RenderingServer.frame_post_draw.connect(_on_frame_post_draw, CONNECT_ONE_SHOT)


func _on_frame_post_draw() -> void:
	_timer.start(flash_duration)


func _cancel_timing() -> void:
	if is_instance_valid(_timer):
		_timer.stop()
	if RenderingServer.frame_pre_draw.is_connected(_on_frame_pre_draw):
		RenderingServer.frame_pre_draw.disconnect(_on_frame_pre_draw)
	if RenderingServer.frame_post_draw.is_connected(_on_frame_post_draw):
		RenderingServer.frame_post_draw.disconnect(_on_frame_post_draw)


func is_flashing() -> bool:
	return _active


func reset() -> void:
	_cancel_timing()
	var was_active: bool = _active
	_restore_overlays()
	if was_active:
		flash_finished.emit()


func _restore_overlays() -> void:
	for binding in _bindings:
		var mesh = binding.mesh.get_ref()
		if is_instance_valid(mesh) and mesh.material_overlay == _material:
			# Preserve a newer overlay installed by another system during the flash.
			mesh.material_overlay = binding.overlay
	_bindings.clear()
	_active = false


func _exit_tree() -> void:
	_cancel_timing()
	_restore_overlays()
