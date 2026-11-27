extends SceneTree
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
const CATALOG = preload("res://data/item_catalog.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	PROFILE.override_path = "res://.godot/permanent-backpack-test.cfg"
	PROGRESS.override_path = "res://.godot/permanent-backpack-progress.cfg"
	run.call_deferred()
func frames(n := 8) -> void:
	for i in n: await physics_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)
func run() -> void:
	for path in ["res://Main.tscn","res://scenes/dungeon/Level02Run.tscn","res://scenes/dungeon/Level03Run.tscn","res://scenes/dungeon/Level04Run.tscn"]:
		PROFILE.ensure_loaded()
		PROFILE.unlocked.assign(["knight"])
		PROFILE.set_selected_character("knight")
		PROFILE.inventory = {0:2,1:1,2:1,5:1,6:3,7:5}
		PROFILE.set_coins(500)
		PROFILE.save()
		change_scene_to_file(path)
		await frames(12)
		var host := current_scene
		var items = host._items
		var selector = host.get_node("MenuNavigation").character_select
		check(items.gold == 500 and items.potion_count == 2 and items.coil_ammo == 5,"saved wallet and backpack load: "+path)
		selector.show_selection("lan")
		selector.get_node("%UnlockButton").pressed.emit()
		await frames()
		check(PROFILE.owns("lan") and PROFILE.coins == 400 and items.gold == 400,"character and shop use same permanent coins")
		selector.hide()
		host._on_run_started()
		check(items.add_gold(37,"run-gold") and items.gold == 437 and PROFILE.coins == 400,"run gold is visible but not banked")
		check(not items.add_gold(37,"run-gold") and items.gold == 437,"duplicate run reward rejected")
		check(items.add_item(0,3) and items.potion_count == 5 and PROFILE.inventory[0] == 2,"run items stay outside permanent backpack")
		host._commerce.open_shop()
		await frames()
		check(host._commerce.shop.get_node("%WalletLabel").text == "金币 437","shop shows same spendable run balance")
		check(items.try_purchase(6,1,host._commerce),"actual shop buys correct ammo")
		check(items.gold == 425 and PROFILE.coins == 400 and items.pistol_ammo == 19 and PROFILE.inventory[6] == 3,"purchase is part of temporary run backpack")
		host._commerce.close_all()
		host._player.take_damage(999)
		check(items.gold == 0 and items.potion_count == 0 and items.pistol_ammo == 0,"final defeat clears the complete carried wallet and backpack")
		check(PROFILE.coins == 0 and PROFILE.inventory.is_empty(),"defeat saves the forfeiture of prior-level and current assets")
		change_scene_to_file(path)
		await frames(12)
		host = current_scene
		items = host._items
		check(items.gold == 0 and items.potion_count == 0 and items.pistol_ammo == 0,"restart cannot restore forfeited assets")
		# Independent success fixture, after verifying that the failed bag stayed empty.
		PROFILE.inventory = {0:2,1:1,2:1,5:1,6:3,7:5}
		PROFILE.set_coins(400)
		items.discard_run()
		host._on_run_started()
		check(items.gold == 400 and items.potion_count == 2 and items.pistol_ammo == 3,"success fixture loads settled assets")
		check(items.add_gold(50,"success-gold") and items.add_item(0,3) and items.add_item(7,6),"successful-run candidate rewards")
		host._commerce.open_shop()
		check(items.try_purchase(5,1,host._commerce),"successful-run shop purchase")
		host._commerce.close_all()
		host._player.take_damage(host._player.shield+1)
		check(items.try_use_potion() and items.potion_count == 4,"used item is absent from eventual success backpack")
		var receipt: String = path+":success:"+str(Time.get_ticks_usec())
		check(items.settle_backpack(receipt),"success saves wallet and backpack together")
		check(PROFILE.coins == 435 and PROFILE.inventory[0] == 4 and PROFILE.inventory[5] == 2 and PROFILE.inventory[7] == 11,"success retains unconsumed old/new and purchased items")
		check(items.pending_gold() == 0 and items.gold == 435,"success consumes pending delta once")
		check(items.settle_backpack(receipt) and PROFILE.coins == 435 and PROFILE.inventory[0] == 4,"repeat success receipt does not duplicate items or money")
		PROFILE._loaded_path = ""
		PROFILE.ensure_loaded()
		check(PROFILE.coins == 435 and PROFILE.inventory[0] == 4 and PROFILE.inventory[7] == 11,"permanent backpack survives profile reload")
		check(items.add_gold(9,"retry-gold") and items.add_item(2,2),"new pending assets before simulated save failure")
		var good_path: String = PROFILE.override_path
		PROFILE.override_path = "res://.godot/missing-bag-%d/profile.cfg" % Time.get_ticks_usec()
		PROFILE._loaded_path = PROFILE.override_path
		var retry_id: String = receipt+":retry"
		check(not items.settle_backpack(retry_id),"failed atomic save rejects entire settlement")
		check(PROFILE.coins == 435 and PROFILE.inventory[2] == 1 and retry_id not in PROFILE.settled_runs,"failed save rolls back wallet, backpack and receipt together")
		check(items.gold == 444 and items.guard_count == 3,"failed save keeps complete pending reward for retry")
		PROFILE.override_path = good_path
		PROFILE._loaded_path = good_path
		check(items.settle_backpack(retry_id) and PROFILE.coins == 444 and PROFILE.inventory[2] == 3,"retry saves pending coins and items exactly once")
		change_scene_to_file(path)
		await frames(12)
		check(current_scene._items.gold == 444 and current_scene._items.potion_count == 4,"next scene loads all successful-run assets")
	# Lan's free starting reserve must never be duplicated into the saved bag.
	PROFILE.set_selected_character("lan")
	change_scene_to_file("res://Main.tscn")
	await frames(12)
	var lan = current_scene._items
	current_scene._on_run_started()
	check(lan.pistol_ammo == 19 and lan.coil_ammo == 23,"Lan receives persistent reserves plus temporary starter supply")
	check(lan.settle_backpack("lan-free-"+str(Time.get_ticks_usec())) and PROFILE.inventory[6] == 3 and PROFILE.inventory[7] == 11,"unused starter ammunition cannot farm permanent stacks")
	# An item-only settlement must block navigation even with zero spendable gold.
	change_scene_to_file("res://Main.tscn")
	await frames(12)
	var item_host := current_scene
	item_host._on_run_started()
	item_host._items.gold = 0
	item_host._items.add_item(0,1)
	item_host._run_state = item_host.RunState.VICTORY
	item_host._settled = false
	item_host._run_result = {"settlement_ok":false,"wallet_balance":PROFILE.coins}
	item_host._hud.show_win_screen(item_host._run_result,false)
	var valid_path: String = PROFILE.override_path
	PROFILE.override_path = "res://.godot/no-item-only-%d/profile.cfg" % Time.get_ticks_usec()
	PROFILE._loaded_path = PROFILE.override_path
	check(item_host._items.gold == 0 and not item_host.request_scene_change("res://Main.tscn") and not item_host._transition_queued,"failed item-only settlement cannot silently leave result screen")
	check(not item_host._settled and item_host._items.potion_count == 5 and PROFILE.inventory[0] == 4,"failed navigation preserves pending item and original permanent bag")
	PROFILE.override_path = valid_path
	PROFILE._loaded_path = valid_path
	item_host.retry_settlement()
	check(item_host._settled and PROFILE.coins == 0 and PROFILE.inventory[0] == 5,"item-only retry commits entire run transaction once")
	await frames()
	# Restore the confirmed fixture for the independent practice isolation check.
	PROFILE.inventory[0] = 4
	PROFILE.set_coins(444)
	change_scene_to_file("res://scenes/dungeon/Level04Practice.tscn")
	await frames(12)
	var practice := current_scene
	practice._on_run_started()
	practice._items.add_gold(100)
	practice._items.add_item(0,5)
	check(not practice._items.uses_shared_wallet and PROFILE.coins == 444 and PROFILE.inventory[0] == 4,"practice never changes permanent wallet or bag")
	current_scene.queue_free()
	await frames()
	root.get_node("MusicManager").stop_music()
	print("PERMANENT_BACKPACK_RESULT checks=%d failed=%d" % [checks,failures])
	quit(1 if failures else 0)
