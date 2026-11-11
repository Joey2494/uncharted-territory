extends Control
## Grid, selection and use intents; gameplay effects belong to the data provider.
signal use_item_requested(item_id: StringName)
signal shop_requested
signal back_requested
const SLOT = preload("res://scenes/ui/inventory_slot.gd")
const UI_STYLE = preload("res://scenes/ui/commerce_ui_style.gd")
var _items: Array[Dictionary] = []
var _slots: Array[Button] = []
var _selected_id: StringName = &""
var _demo_mode: bool = true

func _ready() -> void:
	theme = UI_STYLE.create_theme()
	%BackButton.pressed.connect(func() -> void: back_requested.emit())
	%ShopTab.pressed.connect(func() -> void: shop_requested.emit())
	%UseButton.pressed.connect(_request_use)

func set_inventory_data(items: Array, capacity: int = 12) -> void:
	_items.clear()
	for item in items:
		if item is Dictionary and item.get("id") != null and int(item.get("count",0)) > 0:
			_items.append(item.duplicate(true))
	var count := maxi(clampi(capacity,1,100),_items.size())
	while _slots.size() > count:
		var old: Button = _slots.pop_back()
		%ItemGrid.remove_child(old)
		old.queue_free()
	while _slots.size() < count:
		var slot := SLOT.new()
		slot.item_selected.connect(_select_item)
		%ItemGrid.add_child(slot)
		_slots.append(slot)
	if _find(_selected_id).is_empty():
		_selected_id = StringName(_items[0].id) if not _items.is_empty() else &""
	%CapacityLabel.text = "物品 %d / %d" % [_items.size(),count]
	_refresh()
	if _items.is_empty() and is_visible_in_tree():
		_safe_focus.call_deferred(%BackButton)

func show_backpack(back_label: String = "返回主菜单") -> void:
	%BackButton.text = back_label
	show_feedback("选择物品查看详情。",true)
	show()
	var target: Button = _slots[0] if not _items.is_empty() else %BackButton
	_safe_focus.call_deferred(target)

func show_feedback(message: String, success: bool) -> void:
	%FeedbackLabel.text = message
	%FeedbackLabel.add_theme_color_override("font_color",Color("b7c294") if success else Color("d9a08a"))

func get_selected_item_id() -> StringName:
	return _selected_id

func get_slot(index: int) -> Button:
	return _slots[index] if index >= 0 and index < _slots.size() else null

func _select_item(item_id: StringName) -> void:
	if _find(item_id).is_empty():
		return
	_selected_id = item_id
	_refresh()

func _refresh() -> void:
	for i in range(_slots.size()):
		var item: Dictionary = _items[i] if i < _items.size() else {}
		_slots[i].update_item(item,not item.is_empty() and StringName(item.id) == _selected_id)
	var selected := _find(_selected_id)
	%DetailIcon.texture = selected.get("icon")
	%DetailIcon.self_modulate = selected.get("tint",Color("b7a16a"))
	%ItemName.text = str(selected.get("name","背包暂空"))
	%ItemCategory.text = str(selected.get("category",""))
	%ItemDescription.text = str(selected.get("description","前往商城选购补给。"))
	%ItemCount.text = "持有数量：%d" % int(selected.get("count",0))
	%EquipmentState.text = ("状态：已装备（演示）" if _demo_mode else "状态：已装备") if selected.get("equipped",false) else ("状态：未装备" if selected.get("category") == "装备" else "")
	%UseButton.text = str(selected.get("use_label","使用物品"))
	%UseButton.disabled = selected.is_empty() or not selected.get("can_use",false)

func _request_use() -> void:
	var selected := _find(_selected_id)
	if not selected.is_empty() and selected.get("can_use",false):
		use_item_requested.emit(_selected_id)

func _find(item_id: StringName) -> Dictionary:
	for item in _items:
		if StringName(item.id) == item_id:
			return item
	return {}


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		back_requested.emit()


func set_demo_mode(enabled: bool) -> void:
	%ModeLabel.text = "演示数据 · 每次启动重置 · Esc 返回" if enabled else "Esc 返回"
	_demo_mode = enabled
	_refresh()


func _safe_focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()
