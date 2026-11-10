extends SceneTree
## 运行时画面取证。固定点位与直接伤害仅用于重复采样，不代表手动难度测试。
## 用法：Godot --path . --windowed -s res://tests/dungeon/capture_level02.gd -- --output <绝对目录> [--full-hd]

const PREVIEW := preload("res://tests/scenes/Level02Preview.tscn")
var _viewport: SubViewport
var _preview: Node3D
var _map: Node3D
var _player: CharacterBody3D
var _camera: Camera3D
var _output: String
var _resolution_label: String
var _saved := 0
var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_output = OS.get_user_data_dir().path_join("level02-captures")
	var output_index := args.find("--output")
	if output_index >= 0:
		if output_index + 1 >= args.size() or not args[output_index + 1].is_absolute_path():
			push_error("--output 后需要绝对目录")
			quit(1)
			return
		_output = args[output_index + 1]
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		push_error("无法创建取证目录 " + _output)
		quit(1)
		return
	var sizes := [Vector2i(1920, 1080)] if args.has("--full-hd") else [Vector2i(1280, 720), Vector2i(1920, 1080)]
	for size in sizes:
		await _record(size)
	print("LEVEL02_CAPTURE: ", _saved, " PNG, ", _output)
	quit(1 if _failed or _saved != sizes.size() * 8 else 0)

func _record(size: Vector2i) -> void:
	_resolution_label = str(size.y)
	_viewport = SubViewport.new()
	_viewport.size = size
	# 与项目主窗口一致，以 720 逻辑像素高、宽屏扩展的方式排版 HUD。
	_viewport.size_2d_override = Vector2i(1280, 720)
	_viewport.size_2d_override_stretch = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_preview = PREVIEW.instantiate()
	_viewport.add_child(_preview)
	_map = _preview.get_node("Level02")
	_player = _map.get_node("Player")
	_camera = _map.get_node("Camera3D")
	await _capture("01-menu")
	_preview.get_node("%Primary").pressed.emit()
	await create_timer(1.02).timeout
	_preview.open_guide()
	await _capture("02-guide")
	_preview.close_guide()
	await _go(Vector3(0, 0.05, -25))
	await _capture("03-hub-battle")
	_defeat(["Enemies/Hub1", "Enemies/Hub2"])
	await create_timer(1.03).timeout
	await _go(Vector3(34, 0.05, -24.5))
	_defeat(["Enemies/Relay1", "Enemies/Relay2"])
	await _use("Devices/Relay")
	await _capture("04-relay")
	for id in ["RuneSun", "RuneMoon", "RuneStar", "SwitchA", "SwitchB", "SwitchB"]:
		await _use("EnergyRelayPuzzle/" + id)
	await _go(Vector3(-34, 0.05, -28.55))
	await _capture("05-archive")
	await _use("EnergyRelayPuzzle/Confirm")
	await create_timer(1.03).timeout
	await _use("EnergyRelayPuzzle/Reward")
	await _go(Vector3(34, 0.05, -54))
	_defeat(["Enemies/Antechamber1", "Enemies/Antechamber2", "Enemies/Antechamber3"])
	await _use("Devices/Shortcut")
	await create_timer(1.03).timeout
	await _go(Vector3(27, 0.05, -55.85))
	await _capture("06-shortcut")
	await _capture_overview()
	await _go(Vector3(34, 0.05, -84))
	_defeat(["Boss"])
	await create_timer(1.05).timeout
	await _go(Vector3(34, 0.05, -111))
	await create_timer(0.22).timeout
	if _preview.get_run_state() != _preview.State.VICTORY:
		push_error("未观察到实际出口结算")
		_failed = true
	else:
		await _capture("08-victory")
	_viewport.queue_free()
	await process_frame

func _go(point: Vector3) -> void:
	_player.global_position = point
	for frame in 5:
		await physics_frame
	_camera.reset_follow()

func _defeat(enemies: Array) -> void:
	for path in enemies:
		if not _map.get_node(path).take_damage(999):
			push_error("取证时未触发真实死亡 " + path)
			_failed = true

func _use(path: String) -> void:
	var control := _map.get_node(path) as Node3D
	await _go(control.global_position + Vector3(0, 0.05, 1.35))
	if not _player.get_node("ItemInventory").try_interact_nearest():
		push_error("取证时机关交互失败 " + path)
		_failed = true

func _capture_overview() -> void:
	var overview := Camera3D.new()
	overview.projection = Camera3D.PROJECTION_ORTHOGONAL
	overview.size = 124.0
	overview.position = Vector3(0, 125, -54)
	overview.rotation_degrees = Vector3(-90, 0, 0)
	_map.add_child(overview)
	overview.make_current()
	_preview.get_node("UI/HUD").hide()
	await _capture("07-overview")
	_camera.make_current()
	_preview.get_node("UI/HUD").show()
	overview.queue_free()

func _capture(suffix: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	if image == null or image.get_size() != _viewport.size:
		push_error("截图尺寸与采样分辨率不符 " + suffix)
		_failed = true
		return
	var path := _output.path_join("%sp-%s.png" % [_resolution_label, suffix])
	if image.save_png(path) != OK:
		push_error("无法保存 " + path)
		_failed = true
	else:
		_saved += 1
