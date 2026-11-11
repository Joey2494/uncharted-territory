extends Control
signal closed
const REFERENCE = preload("res://scenes/tutorial/control_reference.gd")
var _card: PanelContainer
var _scroll: ScrollContainer
var _close: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.03, 0.025, 0.98)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_card = PanelContainer.new()
	_card.name = "GuidePanel"
	add_child(_card)
	var padding := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + edge, 24)
	_card.add_child(padding)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	padding.add_child(content)
	var title := Label.new()
	title.text = "操作指南"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("ddc58e"))
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "随时查阅全部操作，按自己的节奏探索遗迹。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	content.add_child(subtitle)
	content.add_child(HSeparator.new())
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_scroll)
	var rows := VBoxContainer.new()
	rows.name = "Bindings"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	_scroll.add_child(rows)
	for entry in REFERENCE.GUIDE:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		rows.add_child(row)
		var key := REFERENCE.keycap(entry[0], 18)
		key.custom_minimum_size = Vector2(245, 40)
		row.add_child(key)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		words.add_theme_constant_override("separation", 1)
		row.add_child(words)
		var label := Label.new()
		label.text = entry[1]
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color("d4bc84"))
		words.add_child(label)
		var detail := Label.new()
		detail.text = entry[2]
		detail.add_theme_font_size_override("font_size", 13)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(detail)
	_close = Button.new()
	_close.name = "CloseGuideButton"
	_close.text = "返回设置"
	_close.custom_minimum_size.y = 44
	_close.pressed.connect(close_guide)
	content.add_child(_close)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var viewport := get_viewport_rect().size
	var dimensions := Vector2(minf(820.0, viewport.x - 48.0), minf(680.0, viewport.y - 48.0))
	_scroll.custom_minimum_size.y = maxf(100.0, dimensions.y - 220.0)
	_card.size = dimensions
	_card.position = (viewport - dimensions) * 0.5

func open_guide() -> void:
	show()
	_scroll.scroll_vertical = 0
	_safe_focus.call_deferred(_close)

func close_guide() -> void:
	hide()
	closed.emit()


func _safe_focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()
