extends Control
## Independent square-grid selector; the host validates every launch again.

const LEVEL_TILE = preload("res://scenes/ui/level_tile.gd")
const GRID_GAP: float = 16.0
const MAX_COLUMNS: int = 4

signal back_requested
signal level_selected(level_id: StringName)

@onready var start_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel
@onready var _level_list: GridContainer = %LevelList

var _levels: Array[Dictionary] = []
var _progress: RefCounted
var _buttons: Dictionary = {}


func _ready() -> void:
	start_button.pressed.connect(func() -> void: back_requested.emit())
	visibility_changed.connect(_focus_action)
	%LevelScroll.resized.connect(_update_grid_layout)
	_focus_action()


func configure(levels: Array[Dictionary], progress: RefCounted) -> void:
	_levels = levels.duplicate()
	_progress = progress
	for child in _level_list.get_children():
		_level_list.remove_child(child)
		child.queue_free()
	_buttons.clear()
	for level in _levels:
		var button := LEVEL_TILE.new()
		button.name = String(level.id).to_pascal_case() + "Button"
		button.pressed.connect(_on_level_pressed.bind(level.id))
		_level_list.add_child(button)
		_buttons[level.id] = button
	_update_grid_layout()
	refresh_progress()


func refresh_progress() -> void:
	if _progress == null:
		return
	var completed := 0
	for i in range(_levels.size()):
		var level: Dictionary = _levels[i]
		var button: Button = _buttons[level.id]
		var unlocked: bool = _progress.is_unlocked(level.id)
		button.set_level_state(i + 1, unlocked, _progress.has_played(level.id) or _progress.is_completed(level.id))
		if _progress.is_completed(level.id):
			completed += 1
	status_label.text = _progress.message if not _progress.message.is_empty() else "已通关 %d/%d · 进度自动保存" % [completed, _levels.size()]
	_focus_action()


func _update_grid_layout() -> void:
	if not is_node_ready():
		return
	# Keep room for the brightest outline at all four scroll edges. Fixed-size
	# tiles never stretch when the container or window changes aspect ratio.
	var available_width: float = maxf(LEVEL_TILE.TILE_SIZE, %LevelScroll.size.x - 32.0)
	var fitting := maxi(1, floori((available_width + GRID_GAP) / (LEVEL_TILE.TILE_SIZE + GRID_GAP)))
	_level_list.columns = mini(mini(MAX_COLUMNS, fitting), maxi(_levels.size(), 1))
	var rows := ceili(float(_levels.size()) / _level_list.columns)
	var content_height := rows * LEVEL_TILE.TILE_SIZE + maxi(rows - 1, 0) * GRID_GAP + 24.0
	%LevelScroll.custom_minimum_size.y = clampf(content_height, 128.0, 232.0)


func get_level_button(level_id: StringName) -> Button:
	return _buttons.get(level_id)


func show_menu() -> void:
	refresh_progress()
	show()
	_focus_action()


func show_status(message: String) -> void:
	status_label.text = message


func _on_level_pressed(level_id: StringName) -> void:
	if _progress != null and _progress.is_unlocked(level_id):
		level_selected.emit(level_id)


func _focus_action() -> void:
	if is_node_ready() and is_visible_in_tree():
		var target: Button = start_button
		if _progress != null:
			var recommended: StringName = _progress.recommended_level()
			if _buttons.has(recommended):
				target = _buttons[recommended]
		_safe_focus.call_deferred(target)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		back_requested.emit()


func _safe_focus(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree() and button.is_visible_in_tree():
		button.grab_focus()
