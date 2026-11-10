extends VBoxContainer
## Optional adapter; existing HUD signals and scenes remain compatible.

const Catalog = preload("res://data/item_catalog.gd")
var _inventory: Node3D
var _status: Label
var _guard: Button
var _weapon: Button


func bind_inventory(inventory: Node3D) -> void:
	_inventory = inventory
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 14)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	var row := HBoxContainer.new()
	add_child(row)
	_guard = Button.new()
	_guard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guard.focus_mode = Control.FOCUS_NONE
	_guard.pressed.connect(_inventory.try_use_guard)
	row.add_child(_guard)
	_weapon = Button.new()
	_weapon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon.focus_mode = Control.FOCUS_NONE
	_weapon.pressed.connect(func() -> void:
		_inventory.try_equip(Catalog.MELEE if _inventory.equipped_weapon == Catalog.FIREARM else Catalog.FIREARM))
	row.add_child(_weapon)
	_inventory.state_changed.connect(_refresh)
	_refresh(_inventory.get_snapshot())


func _refresh(snapshot: Dictionary) -> void:
	_status.text = "金币 %d · 弹药 %d · 守护%s" % [
		snapshot.gold, snapshot.ammo, "生效" if snapshot.guard_active else "未激活"]
	_guard.text = "G 守护 ×%d" % snapshot.items[Catalog.GUARD_RUNE]
	_guard.disabled = snapshot.items[Catalog.GUARD_RUNE] <= 0 or snapshot.guard_active
	_weapon.text = "V 切回近战" if snapshot.equipped_weapon == Catalog.FIREARM else "V 装备手炮"
	_weapon.disabled = snapshot.items[Catalog.FIREARM] == 0
