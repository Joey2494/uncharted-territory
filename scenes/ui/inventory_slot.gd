extends Button
signal item_selected(item_id: StringName)
var _id: StringName = &""
var _icon: TextureRect
var _count: Label
var _equipped: Label

func _init() -> void:
	custom_minimum_size = Vector2(76,76)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style := _style(Color("171a13"),Color("544d37"),1)
	add_theme_stylebox_override("normal",style)
	add_theme_stylebox_override("hover",_style(Color("29291c"),Color("b29455"),1))
	add_theme_stylebox_override("pressed",_style(Color("34301c"),Color("c9a75a"),2))
	add_theme_stylebox_override("disabled",_style(Color("11140f"),Color("30342a"),1))
	var focus := _style(Color.TRANSPARENT,Color("dfbd72"),1)
	add_theme_stylebox_override("focus",focus)
	_icon = TextureRect.new()
	_icon.set_anchors_preset(Control.PRESET_CENTER)
	_icon.position = Vector2(-21,-24)
	_icon.size = Vector2(42,42)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_count = Label.new()
	_count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_count.offset_left = -70
	_count.offset_top = -23
	_count.offset_right = -6
	_count.offset_bottom = -3
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.add_theme_font_size_override("font_size",13)
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count)
	_equipped = Label.new()
	_equipped.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_equipped.position = Vector2(6,3)
	_equipped.add_theme_font_size_override("font_size",10)
	_equipped.add_theme_color_override("font_color",Color("e0bd6d"))
	_equipped.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_equipped)
	pressed.connect(func() -> void:
		if not disabled and _id != &"":
			item_selected.emit(_id))

func update_item(data: Dictionary, selected: bool) -> void:
	_id = StringName(data.get("id",""))
	disabled = data.is_empty()
	mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
	_icon.texture = data.get("icon")
	_icon.self_modulate = data.get("tint",Color("c8b47b"))
	_count.text = "×%d" % int(data.get("count",0)) if not disabled else ""
	_equipped.text = "已装备" if data.get("equipped",false) else ""
	tooltip_text = str(data.get("name",""))
	add_theme_stylebox_override("normal",_style(Color("302b19") if selected else Color("171a13"),Color("c6a65c") if selected else Color("544d37"),2 if selected else 1))

func _style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(2)
	return style
