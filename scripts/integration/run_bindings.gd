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
		items._publish_state())
	hud.skip_tutorial_requested.connect(func() -> void:
		if tutorial != null: tutorial.skip())
	hud.main_menu_requested.connect(return_to_menu)
	if host.practice_run:
		host._commerce.pause_menu.get_node("%MainMenuButton").text = "返回关卡选择"
		host._commerce.main_menu_requested.connect(func() -> void: host.get_node("MenuNavigation").return_to_level_select())
	else:
		host._commerce.main_menu_requested.connect(return_to_menu)
	hud.hotbar_selection_requested.connect(_use_hotbar)
	hud.combat_action_requested.connect(_combat_action)
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
	hud.update_gold(items.gold)
	hud.gold_label.text = str(items.gold)
	hud.gold_label.tooltip_text = "已保存金币 %d · 本轮变动 %+d\n通关保存金币与剩余道具；最终失败清空携带的金币与全部道具。" % [Profile.coins,items.pending_gold()]
	if host.practice_run:
		hud.gold_label.text = "试玩 %d" % items.gold
		hud.gold_label.tooltip_text = "试玩金币 %d · 可在本局商城使用，试玩结束后清零。" % items.gold
	hud.update_guard_rune(&"active" if items.guard_active else (&"ready" if items.guard_count > 0 else &"none"), 1 if items.guard_active else items.guard_count)
	var slots: Array = []
	for id in [Catalog.HEALTH_POTION, Catalog.ATTACK_RUNE, Catalog.GUARD_RUNE, Catalog.ENERGY_POTION, Catalog.REVIVAL_CARD]:
		var product := Catalog.get_item(id)
		slots.append({"id": StringName(product.key), "icon": Presenter.ICONS[id], "count": items.get_count(id), "tint": Presenter.TINTS[id]})
	hud.set_hotbar_data(slots)

func _use_hotbar(_index: int, key: StringName) -> void:
	if host._run_state != host.RunState.PLAYING or not player.can_process(): return
	var id := Presenter.item_id(key)
	if id >= 0:
		items.try_use_item(id)

func _combat_action(action: StringName, pressed: bool) -> void:
	if host._run_state != host.RunState.PLAYING or not player.can_process() or player.is_dead():
		return
	match action:
		&"attack":
			if pressed: player.get_node("MeleeAttack").try_attack()
		&"skill_1", &"switch_weapon":
			if pressed: player.get_node("WeaponLoadout").try_switch()
		&"reload_weapon":
			if pressed: player.get_node("WeaponLoadout").try_replenish()
		&"dodge":
			if pressed: player.try_dodge()
		&"character_skill":
			var ability := player.get_node("CharacterAbility")
			if pressed:
				ability.try_activate()
			elif ability.is_guarding():
				ability._finish_guard(true)

func _process(_delta: float) -> void:
	hud.update_energy_bar(player.energy, player.max_energy)
	hud.hp_state_label.tooltip_text = "角色护盾 %d/%d" % [player.shield, player.max_shield]
	hud.hp_state_label.text = hud.hp_state_label.text.split(" · ")[0] + " · 盾%d" % player.shield

func return_to_menu() -> void:
	host.request_scene_change("res://Main.tscn")
