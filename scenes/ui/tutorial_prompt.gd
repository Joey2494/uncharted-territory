extends PanelContainer
signal skip_requested
const REFERENCE = preload("res://scenes/tutorial/control_reference.gd")
var _lesson: String = ""
var _fade: Tween
var _keys: HBoxContainer
var _caption: Label
var _title: Label
var _detail: Label
var skip_button: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.06, 0.05, 0.92)
	style.border_color = Color("8e7543")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 16
	add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 10)
	add_child(content)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(header)
	_caption = _label("", 13, Color("c2a66a"))
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_caption)
	skip_button = Button.new()
	skip_button.name = "SkipTutorialButton"
	skip_button.text = "Enter · 跳过教程"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	skip_button.add_theme_font_size_override("font_size", 13)
	for state in ["normal", "hover", "pressed"]:
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color("393321") if state == "hover" else Color("24231b")
		button_style.border_color = Color("73623c")
		button_style.set_border_width_all(1)
		button_style.set_corner_radius_all(3)
		button_style.content_margin_left = 10
		button_style.content_margin_right = 10
		button_style.content_margin_top = 5
		button_style.content_margin_bottom = 5
		skip_button.add_theme_stylebox_override(state, button_style)
	header.add_child(skip_button)
	skip_button.pressed.connect(func() -> void: skip_requested.emit())
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	content.add_child(row)
	_keys = HBoxContainer.new()
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_keys.add_theme_constant_override("separation", 5)
	row.add_child(_keys)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 4)
	row.add_child(words)
	_title = _label("", 25, Color("f0dcae"))
	_title.name = "TutorialStep"
	words.add_child(_title)
	_detail = _label("", 15, Color("c6bdab"))
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_detail)
	hide()

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func set_lesson(step: String, move_directions: Array[String] = []) -> void:
	if step == _lesson:
		if step == "move":
			_update_movement_progress(move_directions)
		return
	_lesson = step
	if is_instance_valid(_fade):
		_fade.kill()
	if not REFERENCE.LESSONS.has(step):
		hide()
		modulate.a = 1.0
		return
	var lesson: Dictionary = REFERENCE.LESSONS[step]
	_caption.text = "新手教程  ·  %d / 7" % lesson.number
	_title.text = lesson.title
	_detail.text = lesson.detail
	for child in _keys.get_children():
		_keys.remove_child(child)
		child.queue_free()
	for key in lesson.keys:
		_keys.add_child(REFERENCE.keycap(key))
	if step == "move":
		_update_movement_progress(move_directions)
	modulate.a = 0.0
	show()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _update_movement_progress(completed: Array[String]) -> void:
	_caption.text = "新手教程  ·  1 / 7  ·  移动 %d / 4" % completed.size()
	for i in range(_keys.get_child_count()):
		var cap: PanelContainer = _keys.get_child(i)
		var key: String = REFERENCE.LESSONS.move.keys[i]
		var done := completed.has(key)
		var style: StyleBoxFlat = cap.get_theme_stylebox("panel").duplicate()
		style.bg_color = Color("244332cc") if done else Color("28251dcc")
		style.border_color = Color("8fb47a") if done else Color("a58a50")
		cap.add_theme_stylebox_override("panel", style)
		cap.get_child(0).add_theme_color_override("font_color", Color("d8f2c3") if done else Color("f1dba2"))
		cap.tooltip_text = "%s · 已完成" % key if done else "%s · 待练习" % key
