extends SceneTree
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
var failures := 0
var checks := 0
func _initialize() -> void:
	PROFILE.override_path = "res://.godot/weapon_campaign_profile.cfg"
	PROGRESS.override_path = "res://.godot/weapon_campaign_progress.cfg"
	run.call_deferred()
func frames(count: int = 4) -> void:
	for i in count: await physics_frame
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL ",message)
func run() -> void:
	for path in ["res://Main.tscn","res://scenes/dungeon/Level02Run.tscn","res://scenes/dungeon/Level03Run.tscn","res://scenes/dungeon/Level04Run.tscn"]:
		change_scene_to_file(path)
		await frames(8)
		var host := current_scene
		host._on_run_started()
		await frames()
		var player := host.get_node("DungeonTest/Player")
		var items := player.get_node("ItemInventory")
		var weapons := player.get_node("WeaponLoadout")
		check(weapons.slots.size() == 2,"campaign loadout "+path)
		items.add_gold(120)
		host._commerce.open_shop()
		await frames()
		var products := preload("res://scenes/items/commerce_presenter.gd").products(items,host._commerce)
		check(products.size() == 6,"four supplies and two ammo types")
		check(preload("res://data/item_catalog.gd").get_item(102).is_empty(),"weapons removed from catalog")
		for product in products: check(product.category != "装备" and not String(product.id).begins_with("weapon_"),"no weapon shop entry")
		check(items.try_purchase(6,1,host._commerce),"pistol ammo purchase while paused")
		check(items.try_purchase(7,1,host._commerce),"coil ammo purchase while paused")
		check(items.pistol_ammo == 16 and items.coil_ammo == 12,"ammo purchased into separate reserves")
		check(weapons.slots[0].id == "traveler" and weapons.slots[1].id == "rune","shopping preserves exclusive loadout")
		check(not items.try_purchase(102,1,host._commerce),"stale weapon purchase rejected")
		check(items.gold == 90,"rejected purchase cannot charge coins")
		host._commerce.close_all()
		await frames()
		check(not weapons.replace_current(preload("res://scenes/weapons/weapon_catalog.gd").state("pistol")),"exclusive loadout rejects cross-character equipment")
		var active_before: int = weapons.active
		host.get_node("UILayer/HUD").switch_cooldown.get_node("%ActivateButton").pressed.emit()
		check(weapons.active == 1-active_before,"I badge click switches the weapon")
		check(not weapons.try_switch(),"I badge preserves switch cooldown")
		await frames(14)
		check(weapons.try_attack(),"staff attack works in campaign")
		await frames(15)
		items.energy_potion_count = 1
		items._use_remaining = 0
		player.energy = player.max_energy-25
		var before: float = player.energy
		var refill_hud := host.get_node("UILayer/HUD")
		refill_hud._update_combat_cooldowns()
		check(not refill_hud.replenish_cooldown.get_node("%ActivateButton").disabled,"staff K badge is available with a mana potion")
		refill_hud.replenish_cooldown.get_node("%ActivateButton").pressed.emit()
		check(is_equal_approx(player.energy,before+20) and items.energy_potion_count == 0,"mana potion restores blue bar once")
		var hud := host.get_node("UILayer/HUD")
		check(hud.weapon_hint.text.is_empty(),"no extra keyboard prompt strip")
		print("CAMPAIGN_WEAPON_OK ",path)
	PROFILE.ensure_loaded()
	if "lan" not in PROFILE.unlocked: PROFILE.unlocked.append("lan")
	PROFILE.set_selected_character("lan")
	change_scene_to_file("res://Main.tscn")
	await frames(12)
	var gun_host = current_scene
	gun_host._on_run_started()
	await frames()
	var gun_weapons := gun_host.get_node("DungeonTest/Player/WeaponLoadout")
	var gun_items := gun_host.get_node("DungeonTest/Player/ItemInventory")
	var gun_hud := gun_host.get_node("UILayer/HUD")
	gun_weapons.slots[0].ammo = 6
	gun_hud._update_combat_cooldowns()
	check(gun_hud.replenish_cooldown.ability_name == "补充弹药","gun K badge shows ammunition action")
	check(not gun_hud.replenish_cooldown.get_node("%ActivateButton").disabled,"gun K badge is available with reserve ammo")
	gun_hud.replenish_cooldown.get_node("%ActivateButton").pressed.emit()
	check(gun_weapons.reload_remaining > 0 and gun_items.pistol_ammo == 16,"gun K click starts reload without charging early")
	await frames(78)
	check(gun_weapons.slots[0].ammo == 8 and gun_items.pistol_ammo == 14 and gun_items.coil_ammo == 12,"gun K click loads only matching ammo")
	PROFILE.set_selected_character("knight")
	current_scene.queue_free()
	await frames()
	print("WEAPON_CAMPAIGN_RESULT checks=%d failed=%d" % [checks,failures])
	quit(1 if failures else 0)
