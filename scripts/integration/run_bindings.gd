extends Node
## Connect authored UI/audio to the actual player, economy and run lifecycle.
const Catalog = preload("res://data/item_catalog.gd")
const Presenter = preload("res://scenes/items/commerce_presenter.gd")
const Profile = preload("res://scripts/integration/player_profile.gd")
@onready var host := get_parent()
@onready var player := host.get_node("DungeonTest/Player")
@onready var items := player.get_node("ItemInventory")
@onready var hud := host.get_node("UILayer/HUD")
var tutorial: Node
var sfx: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	host._start_screen.character_purchased.connect(func() -> void:
		items.gold = Profile.coins
		items._publish_state())
	hud.skip_tutorial_requested.connect(func() -> void:
		if tutorial != null: tutorial.skip())
	hud.main_menu_requested.connect(return_to_menu)
	host.get_node("CommerceLayer").main_menu_requested.connect(return_to_menu)
	hud.hotbar_selection_requested.connect(_use_hotbar)
	items.state_changed.connect(_refresh_inventory)
	player.energy_changed.connect(hud.update_energy_bar)
	hud.update_energy_bar(player.energy, player.max_energy)
	_refresh_inventory({})
	sfx = preload("res://scenes/audio/game_sfx.gd").new()
	sfx.name = "GameSfx"
	sfx.process_mode = Node.PROCESS_MODE_PAUSABLE
	host.add_child.call_deferred(sfx)
	if host.level_id == 1:
		tutorial = preload("res://scenes/tutorial/tutorial_controller.gd").new()
		tutorial.name = "TutorialController"
		add_child(tutorial)
	host.get_node("CommerceLayer/ShopScreen").backpack_requested.connect(func() -> void:
		host._commerce.close_all()
		host._commerce.open_backpack())
	host.get_node("CommerceLayer/BackpackScreen").shop_requested.connect(func() -> void:
		host._commerce.close_all()
		host._commerce.open_shop())

func _refresh_inventory(_snapshot: Dictionary) -> void:
	if not Profile.set_coins(items.gold): hud.show_item_message(Profile.message)
	hud.update_gold(items.gold)
	hud.update_ammo(items.ammo)
	hud.update_guard_rune(&"active" if items.guard_active else (&"ready" if items.guard_count > 0 else &"none"), 1 if items.guard_active else items.guard_count)
	var slots: Array = []
	for product in Catalog.get_products():
		slots.append({"id": StringName(product.key), "icon": Presenter.ICONS[product.id], "count": items.get_count(product.id), "tint": Presenter.TINTS[product.id]})
	slots.append({})
	hud.set_hotbar_data(slots)

func _use_hotbar(_index: int, key: StringName) -> void:
	if host._run_state != host.RunState.PLAYING or not player.can_process(): return
	var id := Presenter.item_id(key)
	if id >= 0:
		items.try_use_item(id)

func _process(_delta: float) -> void:
	hud.update_energy_bar(player.energy, player.max_energy)
	var ability := player.get_node("CharacterAbility")
	var card := hud.get_node("%CharacterCooldown")
	card.visible = player.character_id != "knight"
	card.get_node("%AbilityName").text = player.CATALOG.definition(player.character_id).skill
	var state := ""
	if player.is_dead() or not player.can_process(): state = "暂不可用"
	elif player.is_dodging(): state = "闪避中"
	elif ability.remaining > 0: state = "持续 %.1fs" % ability.remaining
	card.update_cooldown(ability.get_cooldown_remaining(), ability.get_cooldown_duration(), state)
	hud.hp_state_label.tooltip_text = "角色护盾 %d/%d" % [player.shield, player.max_shield]
	hud.hp_state_label.text = hud.hp_state_label.text.split(" · ")[0] + " · 盾%d" % player.shield

func return_to_menu() -> void:
	host._transition_queued = true
	host._change_scene.call_deferred("res://Main.tscn")
