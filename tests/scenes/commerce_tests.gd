extends SceneTree

const Catalog = preload("res://data/item_catalog.gd")
const Presenter = preload("res://scenes/items/commerce_presenter.gd")
var passed := 0
var failed := 0
var main: Node3D
var ui: CanvasLayer
var inventory: Node3D
var player: CharacterBody3D


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	passed += int(condition)
	failed += int(not condition)
	print("PASS " if condition else "FAIL ", label)


func frames(count := 3) -> void:
	# SceneTree process_frame still runs while paused; physics timers do not.
	for i in range(count):
		await process_frame


func key(code: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	root.push_input(event)
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	root.push_input(event)


func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)


func new_main() -> void:
	main = preload("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	ui = main.get_node("CommerceLayer")
	player = main.get_node("DungeonTest/Player")
	inventory = player.get_node("ItemInventory")
	await frames()


func cleanup() -> void:
	main.queue_free()
	await frames()
	check(not paused, "scene cleanup releases owned pause")


func buy(id: int) -> void:
	ui.shop.get_product_card(StringName(Catalog.get_item(id).key)).get_buy_button().pressed.emit()


func _run() -> void:
	check(InputMap.has_action("open_shop"), "P action configured")
	check(Presenter.item_id(&"unknown") == -2, "unknown UI key never aliases melee or potion")
	for product in Catalog.get_products():
		check(Presenter.item_id(StringName(product.key)) == product.id, "catalog UI id roundtrip %s" % product.key)
	await new_main()
	check(not ui.shop.has_signal("backpack_requested") and not ui.backpack.has_signal("shop_requested"),
		"independent pages have no cross-navigation signals")
	check(ui.shop.get_node_or_null("Center/Card/Padding/Content/Tabs") == null
		and ui.backpack.get_node_or_null("Center/Card/Padding/Content/Tabs") == null,
		"shop and backpack have no combined navigation tabs")
	check(not ui.shortcut.visible, "shortcut hidden on title screen")
	check(main.get_node("DungeonTest").get_node_or_null("Shop0") == null, "default level has no placeholder stands")
	main.get_node("UILayer/StartScreen").shop_requested.emit()
	await frames()
	check(ui.shop.visible and paused, "title shop opens shared real panel")
	check(ui.shop.get_node("%WalletLabel").text == "金币 0", "title uses actual zero balance")
	check(ui.shop.get_product_card(&"health_potion").get_buy_button().disabled, "no mock startup funds")
	check(ui.shop.get_product_card(&"health_potion").get_buy_button().text == "金币不足", "title purchase explains insufficient gold")
	check(not inventory.add_gold(10), "menu allowance does not unlock rewards")
	check(not inventory.try_purchase(0), "normal API still rejects disabled gameplay")
	key(KEY_ESCAPE)
	await frames()
	check(ui.view == ui.View.NONE and not paused and main._run_state == main.RunState.MENU, "title shop returns to title")
	main.get_node("UILayer/StartScreen").backpack_requested.emit()
	await frames()
	check(ui.view == ui.View.BACKPACK and paused, "title has independent backpack entrance")
	check(not inventory._can_use_menu(ui, false), "title backpack cannot use gameplay items")
	key(KEY_P)
	check(ui.view == ui.View.BACKPACK, "P does not turn title backpack into shop")
	key(KEY_ESCAPE)
	await frames()
	check(ui.view == ui.View.NONE and not paused, "title backpack returns independently")
	main._on_run_started()
	check(ui.shortcut.visible and not paused, "in-game shortcut appears")
	inventory.grant_reward("commerce_test", {1: 2, 2: 2}, 200)
	player.hp -= 2
	inventory.try_use_rune()
	inventory._use_remaining = 0.0
	var buff: float = inventory.get_buff_remaining()
	var time: float = main._elapsed_seconds
	var position: Vector3 = player.position
	key(KEY_P)
	await frames()
	check(ui.view == ui.View.SHOP and paused, "physical P opens shop and pauses")
	check(not ui.shortcut.visible, "shortcut not interactive behind modal")
	check(ui.shop.get_node("%BackButton").text == "返回游戏", "direct shop return target")
	key(KEY_P, true)
	check(ui.view == ui.View.SHOP, "held P echo cannot toggle")
	await frames(10)
	check(player.position.is_equal_approx(position), "player frozen while shopping")
	check(is_equal_approx(buff, inventory.get_buff_remaining()), "buff timer frozen while shopping")
	check(is_equal_approx(time, main._elapsed_seconds), "run clock frozen while shopping")
	check(not player.get_node("MeleeAttack").try_attack(), "shopping blocks melee")
	check(not player.get_node("EnergyShock").try_cast(), "shopping blocks skill")
	check(not inventory.try_use_rune(), "shopping blocks gameplay item hotkeys")
	check(not inventory.try_spend_ammo(), "shopping blocks firearm ammo spending")
	check(not inventory.add_gold(50), "shopping never unfreezes reward pipeline")
	check(not inventory.try_purchase(0), "only modal purchase context bypasses pause")
	var ammo_button: Button = ui.shop.get_product_card(&"ammo").get_buy_button()
	check(ammo_button.disabled and ammo_button.text == "请先获得手炮", "ammo prerequisite shown")
	click(ui.shop.get_product_card(&"health_potion").get_buy_button())
	await frames()
	check(inventory.gold == 190 and inventory.potion_count == 1, "UI commits potion purchase exactly once")
	check(paused and not player.can_process(), "purchase never resumes physics")
	check(ui.shop.get_node("%WalletLabel").text == "金币 190", "shop wallet refreshed after commit")
	check(ui.wallet.text == "金币 190", "HUD wallet shares committed balance")
	check(main._hud.potion_button.text.ends_with("×1"), "HUD inventory refreshes while paused")
	check(not ui.shop.get_product_card(&"health_potion").get_buy_button().disabled, "refresh after transaction lock keeps buy enabled")
	check(ui.shop.get_product_card(&"health_potion")._owned.text == "已持有 1", "owned count refreshed")
	buy(1)
	buy(2)
	buy(3)
	buy(4)
	await frames()
	check(inventory.gold == 93, "all five purchase prices reconcile")
	check(inventory.owns_firearm and inventory.ammo == 18, "weapon and ammo purchased into real inventory")
	var firearm_button: Button = ui.shop.get_product_card(&"firearm").get_buy_button()
	check(firearm_button.disabled and firearm_button.text == "已拥有手炮", "duplicate weapon disabled")
	ui.shop.purchase_requested.emit(&"firearm")
	check(inventory.gold == 93 and inventory.ammo == 18, "stale duplicate intent cannot charge")
	ui.shop.purchase_requested.emit(&"unknown")
	check(inventory.gold == 93, "invalid UI id cannot charge")
	inventory.potion_count = Catalog.MAX_STACK
	ui._refresh()
	check(ui.shop.get_product_card(&"health_potion").get_buy_button().text == "背包已满", "full stack explained")
	ui.shop.purchase_requested.emit(&"health_potion")
	check(inventory.gold == 93 and inventory.potion_count == Catalog.MAX_STACK, "full inventory failure atomic")
	inventory.potion_count = 1
	inventory.gold = 0
	ui._refresh()
	check(ui.shop.get_product_card(&"health_potion").get_buy_button().text == "金币不足", "insufficient funds updates immediately")
	ui.shop.purchase_requested.emit(&"health_potion")
	check(inventory.gold == 0 and inventory.potion_count == 1, "insufficient buy preserves both fields")
	inventory.gold = 93
	var reentered := {"accepted": true}
	var nested := func(_snapshot: Dictionary) -> void:
		reentered.accepted = inventory.try_purchase(0, 1, ui)
	inventory.state_changed.connect(nested)
	ui.shop.purchase_requested.emit(&"health_potion")
	inventory.state_changed.disconnect(nested)
	await frames()
	check(not reentered.accepted and inventory.gold == 83, "modal transaction rejects synchronous reentry")
	ui.open_backpack()
	check(ui.view == ui.View.SHOP and not ui.backpack.visible, "shop cannot directly open backpack")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE)
	ui.pause_menu.backpack_requested.emit()
	await frames()
	check(ui.backpack.visible and not ui.shop.visible and paused, "pause menu independently opens backpack")
	check(ui.backpack.get_node("%BackButton").text == "返回暂停菜单", "backpack has its own return source")
	check(ui.backpack._items.size() == 5, "backpack shows five real owned item types")
	check(not inventory.try_purchase(0, 1, ui), "purchase permission revoked outside shop")
	ui.backpack._select_item(&"health_potion")
	ui.backpack.get_node("%UseButton").pressed.emit()
	await frames()
	check(player.hp == player.max_hp and inventory.potion_count == 1, "purchased potion usable through backpack")
	check(paused, "using backpack item leaves combat paused")
	ui.backpack._select_item(&"firearm")
	ui.backpack.get_node("%UseButton").pressed.emit()
	check(inventory.equipped_weapon == Catalog.FIREARM, "backpack equips real hand cannon")
	ui.backpack.get_node("%UseButton").pressed.emit()
	check(inventory.equipped_weapon == Catalog.MELEE, "backpack can return to melee")
	key(KEY_P)
	check(ui.view == ui.View.BACKPACK, "P cannot switch backpack to shop")
	ui.open_shop()
	check(ui.view == ui.View.BACKPACK, "shop API cannot replace open backpack")
	key(KEY_ESCAPE)
	check(ui.view == ui.View.NONE and paused and main.get_run_state() == main.RunState.PAUSED,
		"backpack returns to team pause menu")
	main._resume_playing()
	check(ui.view == ui.View.NONE and not paused, "independent backpack releases pause on resume")
	key(KEY_P)
	check(ui.view == ui.View.SHOP, "P opens shop after leaving backpack")
	key(KEY_P)
	await frames()
	check(ui.view == ui.View.NONE and not paused, "P closes direct shop")
	check(not inventory._can_use_menu(ui, true), "closed panel loses pause allowance")
	click(ui.shop_button)
	await frames()
	check(ui.shop.visible and paused, "upper-right button opens same shop")
	check(not player.get_node("MeleeAttack").is_attacking(), "clicking shortcut does not also attack")
	key(KEY_ESCAPE)
	await frames()
	check(not paused and ui.view == ui.View.NONE, "Esc from direct shop resumes game")
	key(KEY_ESCAPE)
	await frames()
	check(main.get_node("UILayer/RunOverlay/Modal").visible and paused, "Esc opens team pause menu")
	main.get_node("UILayer/RunOverlay/Modal/Center/Card/Content/ShopButton").pressed.emit()
	await frames()
	check(ui.shop.visible and ui.shop.get_node("%BackButton").text == "返回暂停菜单", "pause menu shop return target")
	key(KEY_ESCAPE)
	await frames()
	check(main.get_node("UILayer/RunOverlay/Modal").visible and paused, "shop back preserves team pause menu")
	key(KEY_P)
	check(ui.shop.visible and paused, "P from pause menu opens shop")
	key(KEY_P)
	check(main.get_node("UILayer/RunOverlay/Modal").visible and paused, "P shop close preserves pause")
	main._resume_playing()
	await frames()
	check(not paused and ui.view == ui.View.NONE, "resume restores gameplay")
	paused = true
	ui.open_shop()
	check(ui.view == ui.View.NONE and paused, "unrelated pause is not stolen")
	paused = false
	await test_layouts()
	ui.open_shop()
	ui.finish_run()
	check(not paused and ui.view == ui.View.NONE and not ui.shortcut.visible, "terminal run closes modal and disables shortcut")
	check(not inventory._can_use_menu(ui, true), "terminal run revokes menu allowance")
	await cleanup()
	await new_main()
	main._on_run_started()
	inventory.add_gold(10)
	main.set_paused(true)
	main.get_node("UILayer/RunOverlay/Modal/Center/Card/Content/RestartButton").pressed.emit()
	await frames(12)
	main = current_scene
	ui = main.get_node("CommerceLayer")
	inventory = main.get_node("DungeonTest/Player/ItemInventory")
	check(not paused and inventory.gold == 0 and ui.view == ui.View.NONE, "pause restart reloads without stale pause or funds")
	check(not ui.shortcut.visible and ui.view == ui.View.NONE, "restart clears all commerce panels")
	await cleanup()
	await new_main()
	main._on_run_started()
	player.take_damage(999)
	key(KEY_P)
	check(ui.view == ui.View.NONE and not ui.shortcut.visible, "death blocks shop shortcut")
	await cleanup()
	await new_main()
	main._on_run_started()
	ui.open_shop()
	check(paused, "cleanup test has open modal")
	await cleanup()
	await new_main()
	check(inventory.gold == 0 and inventory.potion_count == 0, "new run has no stale shop inventory")
	await cleanup()
	var sandbox := preload("res://scenes/dungeon/LevelTwoCombat.tscn").instantiate()
	root.add_child(sandbox)
	main = sandbox
	ui = sandbox.get_node("CommerceLayer")
	inventory = sandbox.get_node("World/Player/ItemInventory")
	check(ui.shortcut.visible, "level two exposes shop shortcut")
	check(sandbox.get_node("World").find_children("Shop*", "", false, false).is_empty(), "level two has no colored shop stands")
	key(KEY_P)
	await frames()
	buy(0)
	check(inventory.gold == 70 and inventory.potion_count == 4, "level two purchases from its own loadout")
	await cleanup()
	print("COMMERCE_RESULT passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)


func test_layouts() -> void:
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 720), Vector2i(720, 720)]:
		root.size = dimensions
		await frames(6)
		var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		var stats: Control = main.get_node("UILayer/HUD/Panel")
		var boss: Control = main.get_node("UILayer/BossHealthBar")
		var button_rect: Rect2 = ui.shop_button.get_global_rect()
		check(viewport.encloses(button_rect), "%s shortcut inside viewport" % dimensions)
		check(not stats.get_global_rect().intersects(button_rect), "%s shortcut avoids player HUD" % dimensions)
		check(not boss.get_global_rect().intersects(button_rect), "%s shortcut avoids Boss bar" % dimensions)
		var tutorial: Control = main.get_node("UILayer/TutorialOverlay/Card")
		check(not tutorial.get_global_rect().intersects(button_rect),
			"%s shortcut avoids team tutorial" % dimensions)
		ui.open_shop()
		await frames(6)
		check(viewport.encloses(ui.shop.get_node("%Card").get_global_rect()), "%s shop card fits" % dimensions)
		check(viewport.encloses(ui.shop.get_node("%BackButton").get_global_rect()), "%s shop close stays reachable" % dimensions)
		ui.close_all()
		ui.open_backpack()
		await frames(6)
		check(viewport.encloses(ui.backpack.get_node("%Card").get_global_rect()), "%s backpack fits" % dimensions)
		ui.close_all()
