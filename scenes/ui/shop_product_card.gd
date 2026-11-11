extends PanelContainer
signal purchase_requested(item_id: StringName)
const STONE: Material = preload("res://scenes/ui/stone_material.tres")
var _id: StringName
var _icon: TextureRect
var _name_label: Label
var _category: Label
var _summary: Label
var _price: Label
var _owned: Label
var _buy: Button

func _init() -> void:
	custom_minimum_size = Vector2(0,152)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("15180f")
	style.border_color = Color("655b3e")
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)
	var stone := ColorRect.new()
	stone.material = STONE
	stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stone)
	var padding := MarginContainer.new()
	for key in ["margin_left","margin_right"]:
		padding.add_theme_constant_override(key,12)
	for key in ["margin_top","margin_bottom"]:
		padding.add_theme_constant_override(key,10)
	add_child(padding)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",6)
	padding.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",10)
	content.add_child(header)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(36,36)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_icon)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation",0)
	header.add_child(titles)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size",18)
	titles.add_child(_name_label)
	_category = Label.new()
	_category.add_theme_font_size_override("font_size",11)
	_category.add_theme_color_override("font_color",Color("a59c82"))
	titles.add_child(_category)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size",13)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.max_lines_visible = 2
	_summary.custom_minimum_size.y = 32
	content.add_child(_summary)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",6)
	content.add_child(footer)
	var numbers := VBoxContainer.new()
	numbers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	numbers.add_theme_constant_override("separation",0)
	footer.add_child(numbers)
	_price = Label.new()
	_price.add_theme_font_size_override("font_size",16)
	_price.add_theme_color_override("font_color",Color("d9b76b"))
	numbers.add_child(_price)
	_owned = Label.new()
	_owned.add_theme_font_size_override("font_size",11)
	_owned.add_theme_color_override("font_color",Color("9b927a"))
	numbers.add_child(_owned)
	_buy = Button.new()
	_buy.name = "BuyButton"
	_buy.custom_minimum_size = Vector2(90,36)
	_buy.add_theme_font_size_override("font_size",14)
	_buy.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_buy.pressed.connect(func() -> void:
		if not _buy.disabled:
			purchase_requested.emit(_id))
	footer.add_child(_buy)

func update_product(data: Dictionary) -> void:
	_id = StringName(data.id)
	_icon.texture = data.get("icon")
	_icon.self_modulate = data.get("tint",Color("c8b47b"))
	_name_label.text = str(data.get("name","物品"))
	_category.text = str(data.get("category",""))
	_summary.text = str(data.get("summary",""))
	_price.text = "%d 金币" % maxi(int(data.get("price",0)),0)
	_owned.text = "已持有 %d" % maxi(int(data.get("owned",0)),0)
	_buy.text = str(data.get("purchase_label","购买"))
	_buy.disabled = not data.get("can_buy",false)

func get_buy_button() -> Button:
	return _buy
