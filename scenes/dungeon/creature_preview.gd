extends Node3D
## Non-combat inspection scene; the model and lighting are saved in .tscn.

const SCENES := [
	"res://scenes/enemies/RuinCrawlerPreview.tscn",
	"res://scenes/enemies/RuinSentinelPreview.tscn",
	"res://scenes/bosses/RuinColossusPreview.tscn",
]
@export var creature_index := 2
@export var display_name := "灾厄巨蝎"
@export var base_distance := 13.5
@export var focus_height := 1.85
var _yaw := 0.42
var _pitch := 0.28
var _distance := 13.5
var _rotating := false
var _dragging := false
var _toolbar: HBoxContainer
@onready var _camera: Camera3D = $Camera3D
@onready var _model: Node3D = $Slot/Model


func _ready() -> void:
	_distance = base_distance
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_toolbar = HBoxContainer.new()
	_toolbar.position = Vector2(20, 20)
	_toolbar.add_theme_constant_override("separation", 8)
	canvas.add_child(_toolbar)
	var selector := OptionButton.new()
	for label in ["墓穴猎蛛", "蚀毒哨蛛", "灾厄巨蝎"]:
		selector.add_item(label)
	selector.selected = creature_index
	selector.custom_minimum_size = Vector2(150, 42)
	selector.item_selected.connect(func(index: int) -> void: get_tree().change_scene_to_file(SCENES[index]))
	_toolbar.add_child(selector)
	_button("−", "缩小", func() -> void: zoom(1.15))
	_button("+", "放大", func() -> void: zoom(1.0 / 1.15))
	_button("↺", "恢复视角", reset_view)
	var rotate := CheckButton.new()
	rotate.text = "旋转"
	rotate.tooltip_text = "自动旋转"
	rotate.toggled.connect(func(on: bool) -> void: _rotating = on)
	_toolbar.add_child(rotate)
	_update_camera()
	get_viewport().size_changed.connect(_update_camera)


func _button(label: String, tooltip: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(44, 42)
	button.pressed.connect(action)
	_toolbar.add_child(button)


func reset_view() -> void:
	_yaw = 0.42
	_pitch = 0.28
	_distance = base_distance
	_update_camera()


func zoom(factor: float) -> void:
	_distance = clampf(_distance * factor, base_distance * 0.72, base_distance * 1.6)
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(1.0 / 1.1)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1.1)
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.008
		_pitch = clampf(_pitch + event.relative.y * 0.006, -0.08, 0.85)
		_update_camera()


func _input(event: InputEvent) -> void:
	# Releasing over a UI control must also end a drag started in the viewport.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false


func _process(delta: float) -> void:
	if _rotating:
		_yaw += delta * 0.32
		_update_camera()


func _update_camera() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var aspect := viewport.x / maxf(1.0, viewport.y)
	var fit := maxf(1.0, 1.45 / aspect)
	var centre := Vector3(0, focus_height, 0)
	var offset := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), -cos(_yaw) * cos(_pitch))
	_camera.position = centre + offset * _distance * fit
	_camera.look_at(centre)
