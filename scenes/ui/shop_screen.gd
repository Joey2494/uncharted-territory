extends Control
## Presentation and intents only. Supply data from a mock or a real provider.
signal purchase_requested(item_id: StringName)
signal backpack_requested
signal back_requested
const PRODUCT_CARD = preload("res://scenes/ui/shop_product_card.gd")
const UI_STYLE = preload("res://scenes/ui/commerce_ui_style.gd")
var _cards: Dictionary = {}
var _ids: Array[StringName] = []

func _ready() -> void:
	theme = UI_STYLE.create_theme()
	%BackButton.pressed.connect(func() -> void: back_requested.emit())
	%BackpackTab.pressed.connect(func() -> void: backpack_requested.emit())

func set_shop_data(gold: int, products: Array) -> void:
	%WalletLabel.text = "金币 %d" % maxi(gold,0)
	var ids: Array[StringName] = []
	for product in products:
		if product is Dictionary and product.get("id") != null:
			var id := StringName(product.id)
			if not ids.has(id):
				ids.append(id)
	if ids != _ids:
		for card in %ProductGrid.get_children():
			%ProductGrid.remove_child(card)
			card.queue_free()
		_cards.clear()
		_ids = ids
		for id in ids:
			var card := PRODUCT_CARD.new()
			card.name = String(id).to_pascal_case() + "Product"
			card.purchase_requested.connect(func(item_id: StringName) -> void: purchase_requested.emit(item_id))
			%ProductGrid.add_child(card)
			_cards[id] = card
	for product in products:
		if product is Dictionary and _cards.has(StringName(product.get("id",""))):
			_cards[StringName(product.id)].update_product(product)

func show_shop(back_label: String = "返回主菜单") -> void:
	%BackButton.text = back_label
	show_feedback("选择商品购买，物品将放入背包。",true)
	show()
	var target: Button = %BackButton
	for id in _ids:
		var buy: Button = _cards[id].get_buy_button()
		if not buy.disabled:
			target = buy
			break
	_safe_focus.call_deferred(target)

func show_feedback(message: String, success: bool) -> void:
	%FeedbackLabel.text = message
	%FeedbackLabel.add_theme_color_override("font_color",Color("b7c294") if success else Color("d9a08a"))

func get_product_card(item_id: StringName) -> PanelContainer:
	return _cards.get(item_id)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		back_requested.emit()


func set_demo_mode(enabled: bool) -> void:
	%ModeLabel.text = "演示数据 · 每次启动重置 · Esc 返回" if enabled else "Esc 返回"


func _safe_focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()
