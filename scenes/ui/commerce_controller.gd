extends CanvasLayer
## Separate shop/backpack views share inventory and pause ownership, not navigation.

signal restart_requested
signal main_menu_requested

const Presenter = preload("res://scenes/items/commerce_presenter.gd")
const Catalog = preload("res://data/item_catalog.gd")
enum View { NONE, PAUSE, SHOP, BACKPACK }
enum ReturnTo { MENU, GAME, PAUSE }
@export var external_pause := false
var external_pause_state: Callable

@onready var shop: Control = $ShopScreen
@onready var backpack: Control = $BackpackScreen
@onready var pause_menu: Control = $PauseMenu
@onready var shortcut: Control = $Shortcut
@onready var shop_button: Button = $Shortcut/ShopButton
@onready var wallet: Label = $Shortcut/Wallet

var view: View = View.NONE
var _return_to: ReturnTo = ReturnTo.GAME
var _inventory: Node3D
var _available: Callable
var _elapsed: Callable
var _playing := false
var _enabled := true
var _pause_captured := false
var _previous_pause := false
var _previous_mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _previous_focus: WeakRef
var _refresh_queued := false


func _ready() -> void:
	add_to_group("commerce_controllers")
	shop_button.pressed.connect(open_shop)
	shop.back_requested.connect(close_panel)
	shop.purchase_requested.connect(_purchase)
	backpack.back_requested.connect(close_panel)
	backpack.use_item_requested.connect(_use_item)
	pause_menu.shop_requested.connect(open_shop)
	pause_menu.backpack_requested.connect(open_backpack)
	pause_menu.resume_requested.connect(close_panel)
	pause_menu.restart_requested.connect(func() -> void:
		close_all()
		restart_requested.emit())
	pause_menu.main_menu_requested.connect(func() -> void:
		close_all()
		main_menu_requested.emit())
	# The settings subsystem is owned by the UI branch; don't expose a dead action
	# in this scoped commerce integration or replace its settings implementation.
	pause_menu.get_node("%SettingsButton").hide()
	shop.set_demo_mode(false)
	backpack.set_demo_mode(false)
	_hide_views()
	shortcut.hide()
	get_viewport().size_changed.connect(_update_shortcut)


func bind_inventory(inventory: Node3D, available: Callable, elapsed: Callable = Callable()) -> void:
	if is_instance_valid(_inventory):
		if _inventory.state_changed.is_connected(_queue_refresh):
			_inventory.state_changed.disconnect(_queue_refresh)
	_inventory = inventory
	_available = available
	_elapsed = elapsed
	_inventory.state_changed.connect(_queue_refresh)
	_refresh()


func set_run_active(active: bool) -> void:
	_playing = active
	_update_shortcut()


func finish_run() -> void:
	_enabled = false
	close_all()


func _can_open() -> bool:
	return is_inside_tree() and _enabled and is_instance_valid(_inventory) \
		and _inventory.is_inside_tree() and not _inventory.get_parent().is_dead() \
		and (not _playing or (_available.is_valid() and _available.call()))


func allows_inventory_action(inventory: Node3D, purchasing: bool) -> bool:
	if inventory != _inventory or not _can_open() or not _pause_captured:
		return false
	return view == View.SHOP if purchasing else view == View.BACKPACK and _playing


func open_menu_shop() -> void:
	if not _playing:
		open_shop()


func open_menu_backpack() -> void:
	if not _playing:
		open_backpack()


func _begin_commerce() -> bool:
	if not _can_open():
		return false
	if view == View.NONE:
		# Don't take ownership of another subsystem's pause.
		if get_tree().paused and (not external_pause or not external_pause_state.is_valid()
			or not external_pause_state.call()):
			return false
		_return_to = ReturnTo.PAUSE if get_tree().paused else (ReturnTo.GAME if _playing else ReturnTo.MENU)
		_capture_pause()
	elif view == View.PAUSE:
		_return_to = ReturnTo.PAUSE
	return true


func open_shop() -> void:
	if view == View.BACKPACK or not _begin_commerce():
		return
	_hide_views()
	view = View.SHOP
	_refresh()
	shop.show_shop(_back_label())
	shop.get_node("%ModeLabel").text = "本局背包" if not _playing else "战斗已暂停"
	shop.get_node("Backdrop").color.a = 0.92 if _playing else 1.0
	_update_shortcut()


func open_backpack() -> void:
	if view == View.SHOP or not _begin_commerce():
		return
	_hide_views()
	view = View.BACKPACK
	_refresh()
	backpack.show_backpack(_back_label())
	backpack.get_node("%ModeLabel").text = "本局背包" if not _playing else "战斗已暂停"
	_update_shortcut()


func open_pause() -> void:
	if not _playing or not _can_open() or view != View.NONE or get_tree().paused:
		return
	_capture_pause()
	_show_pause()


func _show_pause() -> void:
	_hide_views()
	view = View.PAUSE
	pause_menu.show_pause(float(_elapsed.call()) if _elapsed.is_valid() else 0.0)
	_update_shortcut()


func close_panel() -> void:
	if view in [View.SHOP, View.BACKPACK] and _return_to == ReturnTo.PAUSE:
		if external_pause:
			close_all()
		else:
			_show_pause()
	else:
		close_all()


func close_all() -> void:
	_hide_views()
	view = View.NONE
	_restore_pause()
	_update_shortcut()
	if external_pause and get_parent().has_method("_refresh_overlay"):
		get_parent()._refresh_overlay()


func _hide_views() -> void:
	shop.hide()
	backpack.hide()
	pause_menu.hide()


func _capture_pause() -> void:
	if _pause_captured:
		return
	_previous_pause = get_tree().paused
	_previous_mouse_mode = Input.mouse_mode
	var focus := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	_pause_captured = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _restore_pause() -> void:
	if not _pause_captured:
		return
	_pause_captured = false
	get_tree().paused = _previous_pause
	Input.mouse_mode = _previous_mouse_mode
	var focus: Control = _previous_focus.get_ref() if _previous_focus != null else null
	if is_instance_valid(focus) and focus.is_visible_in_tree() and not focus.is_queued_for_deletion():
		_safe_focus.call_deferred(focus)
	_previous_focus = null


func _back_label() -> String:
	match _return_to:
		ReturnTo.MENU: return "返回主菜单"
		ReturnTo.PAUSE: return "返回暂停菜单"
	return "返回游戏"


func _input(event: InputEvent) -> void:
	var shop_key := event.is_action_pressed("open_shop")
	var cancel := event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")
	if not shop_key and not cancel:
		return
	if view == View.NONE and (not _playing or not _can_open()
		or (get_tree().paused and not external_pause) or (cancel and external_pause)):
		return
	get_viewport().set_input_as_handled()
	if event.is_echo():
		return
	if cancel:
		if view == View.NONE:
			open_pause()
		else:
			close_panel()
	elif view == View.SHOP:
		close_panel()
	else:
		open_shop()


func _purchase(key: StringName) -> void:
	if not allows_inventory_action(_inventory, true):
		return
	var id := Presenter.item_id(key)
	var error: String = _inventory.get_purchase_error(id, 1, self)
	if not error.is_empty():
		shop.show_feedback(error, false)
		_refresh()
		return
	var success: bool = _inventory.try_purchase(id, 1, self)
	_refresh()
	if success:
		var product := Catalog.get_item(id)
		shop.show_feedback("已购入 %s ×%d · 花费 %d 金币" % [product.name, product.quantity, product.price], true)
	else:
		shop.show_feedback("当前无法购买", false)


func _use_item(key: StringName) -> void:
	if not allows_inventory_action(_inventory, false):
		return
	var id := Presenter.item_id(key)
	var success: bool
	if id == Catalog.FIREARM and _inventory.equipped_weapon == Catalog.FIREARM:
		success = _inventory.try_equip(Catalog.MELEE, self)
	else:
		success = _inventory.try_use_item(id, self)
	_refresh()
	backpack.show_feedback("已使用或装备物品" if success else "当前无法使用，物品未消耗", success)


func _queue_refresh(_snapshot: Dictionary) -> void:
	# State signals fire under the inventory's transaction lock. Refresh after
	# the commit so eligible buttons don't remain disabled by that lock.
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if not is_instance_valid(_inventory):
		return
	wallet.text = "金币 %d" % _inventory.gold
	shop.set_shop_data(_inventory.gold, Presenter.products(_inventory, self))
	backpack.set_inventory_data(Presenter.backpack(_inventory, self))
	_update_shortcut()


func _update_shortcut() -> void:
	if external_pause:
		# Shared campaign HUD owns the top-right resources at every window width.
		var top := 154.0
		shortcut.offset_top = top
		shortcut.offset_bottom = top + 76.0
		wallet.hide() # The shared resource panel already displays the same wallet.
	shortcut.visible = _playing and _enabled and view == View.NONE
	shop_button.disabled = not _can_open()


func _exit_tree() -> void:
	_restore_pause()


func _safe_focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()
