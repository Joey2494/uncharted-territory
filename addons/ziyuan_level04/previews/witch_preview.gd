extends Node3D
const FX = preload("../effects.gd")
@onready var model: Node3D = $Model
@onready var camera: Camera3D = $Camera3D
var auto_rotate := false
var motion := 0
var elapsed := 0.0
var distance := 8.4
var yaw := 0.0
var pitch := 0.2

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("111725")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("bec9e2")
	settings.ambient_light_energy = 0.5
	environment.environment = settings
	add_child(environment)
	for data in [[Vector3(-42, -30, 0), Color("e6dbd0"), 1.8], [Vector3(-25, 150, 0), Color("878cdb"), 2.0]]:
		var light := DirectionalLight3D.new()
		add_child(light)
		light.rotation_degrees = data[0]
		light.light_color = data[1]
		light.light_energy = data[2]
	var plinth := MeshInstance3D.new()
	var stone := CylinderMesh.new()
	stone.top_radius = 1.48
	stone.bottom_radius = 1.65
	stone.height = 0.3
	stone.radial_segments = 12
	stone.material = FX.mat(Color("3a414f"))
	plinth.mesh = stone
	add_child(plinth)
	plinth.position.y = -0.16
	for i in 12:
		var a := TAU * i / 12.0
		var block := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = Vector3(0.27, 0.24, 0.24)
		shape.material = FX.mat(Color("59606b"))
		block.mesh = shape
		add_child(block)
		block.position = Vector3(sin(a) * 1.49, -0.04, cos(a) * 1.49)
		block.rotation.y = a
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	layer.add_child(panel)
	panel.position = Vector2(24, 22)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("151c2be8")
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	panel.add_child(column)
	for text in ["第四关 · 袍冠女巫", "黑袍 / 银发 / 金饰 / 月晶法杖 / 乌鸦", "鼠标左键拖动旋转 · 滚轮缩放 · A 自动旋转", "1 待机   2 施法   3 阶段转换   F 正面复位"]:
		var label := Label.new()
		label.text = text
		label.add_theme_font_override("font", preload("res://scenes/ui/dungeon_font.tres"))
		label.add_theme_font_size_override("font_size", 22 if column.get_child_count() == 0 else 15)
		label.add_theme_color_override("font_color", Color("d6c39d"))
		column.add_child(label)
	_update_camera()

func _update_camera() -> void:
	camera.position = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance + Vector3(0, 1.65, 0)
	camera.look_at(Vector3(0, 1.65, 0))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		auto_rotate = false
		model.rotation.y += event.relative.x * 0.008
		pitch = clampf(pitch + event.relative.y * 0.005, -0.1, 1.0)
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(4.5, distance - 0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(14, distance + 0.5)
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A: auto_rotate = not auto_rotate
		elif event.keycode >= KEY_1 and event.keycode <= KEY_3: motion = event.keycode - KEY_1
		elif event.keycode == KEY_F:
			model.rotation.y = PI
			pitch = 0.2
			distance = 8.4
			_update_camera()

func _process(delta: float) -> void:
	elapsed += delta
	if auto_rotate: model.rotation.y += delta * 0.3
	model.pose([0, 3, 5][motion], fmod(elapsed, 1.5) / 1.5, 0, delta)
