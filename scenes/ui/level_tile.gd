extends Button
## Square campaign entry. State affects light and access, never adds captions.

const LOCK_ICON: Texture2D = preload("res://assets/ui/level_lock.svg")
const TILE_SIZE: float = 96.0


func _init() -> void:
	custom_minimum_size = Vector2.ONE * TILE_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 30)
	add_theme_color_override("font_shadow_color", Color(0,0,0,0.5))
	add_theme_constant_override("shadow_offset_y", 1)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.set_border_width_all(1)
	focus.border_color = Color("bba26a")
	focus.set_corner_radius_all(3)
	add_theme_stylebox_override("focus", focus)


func set_level_state(number: int, unlocked: bool, played: bool) -> void:
	disabled = not unlocked
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_ARROW
	text = "%02d" % number if unlocked else ""
	icon = null if unlocked else LOCK_ICON
	tooltip_text = ""
	var normal: StyleBoxFlat
	var hover: StyleBoxFlat
	if played:
		normal = _surface(Color("5c4724"), Color("d1af64"), 2)
		normal.shadow_color = Color(0.72,0.49,0.16,0.28)
		normal.shadow_size = 8
		hover = _surface(Color("70572c"), Color("efcd7d"), 2)
		hover.shadow_color = Color(0.8,0.57,0.22,0.34)
		hover.shadow_size = 10
	else:
		normal = _surface(Color("1a1c16"), Color("514a36"), 1)
		hover = _surface(Color("27291e"), Color("8b7b4c"), 1)
	var pressed := _surface(Color("382d19") if played else Color("13150f"), Color("b79a59"), 1)
	var locked := _surface(Color("10120f"), Color("2b2d25"), 1)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("disabled", locked)
	add_theme_color_override("font_color", Color("ffe4a5") if played else Color("cbbd99"))
	add_theme_color_override("font_hover_color", Color("fff0c0") if played else Color("dfc995"))
	add_theme_color_override("font_focus_color", Color("ffe4a5") if played else Color("cbbd99"))
	add_theme_color_override("font_pressed_color", Color("ecd096"))
	add_theme_color_override("icon_disabled_color", Color("77715e"))


func _surface(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 8.0
	return style
