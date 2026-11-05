extends PanelContainer
## Six presentation slots. The provider owns inventory, selection and item effects.
signal selection_requested(index: int, item_id: StringName)

const SLOT_COUNT: int = 6
const SLOT_SIZE: float = 56.0
var _items: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _icons: Array[TextureRect] = []
var _counts: Array[Label] = []
var _selected_index: int = 0
var selection_enabled: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.035, 0.04, 0.03, 0.94)
	frame.border_color = Color("514b39")
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(2)
	frame.content_margin_left = 6
	frame.content_margin_right = 6
	frame.content_margin_top = 6
	frame.content_margin_bottom = 6
	add_theme_stylebox_override("panel", frame)
	var row := HBoxContainer.new()
	row.name = "Slots"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	for index in range(SLOT_COUNT):
		var button := Button.new()
		button.name = "Slot%d" % (index + 1)
		button.custom_minimum_size = Vector2.ONE * SLOT_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.add_child(button)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 8
		icon.offset_top = 8
		icon.offset_right = -8
		icon.offset_bottom = -8
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var count := Label.new()
		count.name = "Count"
		count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		count.offset_left = 3
		count.offset_top = 3
		count.offset_right = -4
		count.offset_bottom = -2
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.add_theme_font_size_override("font_size", 15)
		count.add_theme_color_override("font_color", Color("eee8d6"))
		count.add_theme_color_override("font_outline_color", Color("12130f"))
		count.add_theme_constant_override("outline_size", 4)
		button.add_child(count)
		button.pressed.connect(_on_slot_pressed.bind(index))
		_buttons.append(button)
		_icons.append(icon)
		_counts.append(count)
	# Keep data supplied before ready; otherwise the bar starts with empty slots.
	set_items(_items)

func set_items(items: Array, selected_index: int = -1) -> void:
	var rendered: Array[Dictionary] = []
	for index in range(SLOT_COUNT):
		rendered.append(_display_item(items[index]) if index < items.size() else {})
	_items = rendered
	if selected_index >= 0 and selected_index < SLOT_COUNT:
		_selected_index = selected_index
	if _buttons.size() == SLOT_COUNT:
		_refresh()

func set_selected(index: int) -> bool:
	if index < 0 or index >= SLOT_COUNT:
		return false
	_selected_index = index
	if _buttons.size() == SLOT_COUNT:
		_refresh()
	return true

func get_selected_index() -> int:
	return _selected_index

func get_slot_data(index: int) -> Dictionary:
	return _items[index].duplicate(true) if index >= 0 and index < _items.size() else {}

func _display_item(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var item_id: Variant = value.get("id", "")
	var icon: Variant = value.get("icon")
	var count: Variant = value.get("count", 0)
	if not (item_id is String or item_id is StringName) or String(item_id).is_empty() or not icon is Texture2D or not count is int or count <= 0:
		return {}
	var tint: Variant = value.get("tint", Color.WHITE)
	return {"id": StringName(item_id), "icon": icon, "count": count, "tint": tint if tint is Color else Color.WHITE}

func _refresh() -> void:
	for index in range(SLOT_COUNT):
		var item: Dictionary = _items[index]
		_icons[index].texture = item.get("icon")
		_icons[index].self_modulate = item.get("tint", Color.WHITE)
		_icons[index].visible = not item.is_empty()
		_counts[index].text = _format_count(item.get("count", 0)) if not item.is_empty() else ""
		_counts[index].visible = not item.is_empty()
		var selected := index == _selected_index
		_buttons[index].add_theme_stylebox_override("normal", _slot_style(selected))
		_buttons[index].add_theme_stylebox_override("hover", _slot_style(selected, true))
		_buttons[index].add_theme_stylebox_override("pressed", _slot_style(selected, true))
		_buttons[index].add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _slot_style(selected: bool, hover: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("302c20") if hover else (Color("242219") if selected else Color("1a1c17"))
	style.border_color = Color("a88b4d") if selected else Color("4e5045")
	style.set_border_width_all(3 if selected else 1)
	style.set_corner_radius_all(1)
	return style

func _format_count(count: int) -> String:
	if count >= 100000000:
		return "99亿+" if count >= 10000000000 else "%d亿" % (count / 100000000)
	if count >= 10000:
		return "%d万" % (count / 10000)
	return str(count)

func _on_slot_pressed(index: int) -> void:
	if not _can_select():
		return
	_request_selection(index)

func _can_select() -> bool:
	return selection_enabled and can_process() and is_visible_in_tree()

func _request_selection(index: int) -> void:
	set_selected(index) # Local highlight only; never consumes or equips an item.
	selection_requested.emit(index, StringName(_items[index].get("id", "")))

func _unhandled_input(event: InputEvent) -> void:
	if not _can_select() or event.is_echo():
		return
	if event is InputEventKey and event.pressed:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code >= KEY_1 and code <= KEY_6:
			_request_selection(code - KEY_1)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var direction: int = -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else 0)
		if direction != 0:
			_request_selection((_selected_index + direction + SLOT_COUNT) % SLOT_COUNT)
			get_viewport().set_input_as_handled()
