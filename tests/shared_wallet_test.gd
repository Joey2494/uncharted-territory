extends SceneTree
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	PROFILE.override_path = "res://.godot/shared-wallet-test.cfg"
	PROGRESS.override_path = "res://.godot/shared-wallet-progress.cfg"
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
		check(PROFILE.set_coins(500),"isolated starting wallet")
		change_scene_to_file(path)
		await frames(12)
		var host := current_scene
		var items = host._items
		var selector = host.get_node("MenuNavigation").character_select
		check(items.uses_shared_wallet and items.gold == 500,"campaign starts with existing wallet: "+path)
		selector.show_selection("lan")
		selector.get_node("%UnlockButton").pressed.emit()
		await frames()
		check(PROFILE.owns("lan") and PROFILE.coins == 400 and items.gold == 400,"actual character purchase charges same inventory balance")
		selector.hide()
		host._on_run_started()
		check(items.add_gold(37,"shared-pickup"),"normal pickup credits wallet")
		check(PROFILE.coins == 437 and items.gold == 437,"pickup immediately available for both types of purchase")
		check(not items.add_gold(37,"shared-pickup") and PROFILE.coins == 437,"duplicate reward cannot add coins again")
		host._commerce.open_shop()
		await frames()
		check(host._commerce.shop.get_node("%WalletLabel").text == "金币 437","actual shop displays shared wallet")
		check(items.try_purchase(6,1,host._commerce),"actual paused shop buys pistol ammunition")
		check(PROFILE.coins == 425 and items.gold == 425 and items.pistol_ammo == 16,"shop charges persistent character wallet once")
		selector.show_selection("iron")
		selector.get_node("%UnlockButton").pressed.emit()
		await frames()
		check(PROFILE.owns("iron") and PROFILE.coins == 275 and items.gold == 275,"character purchase after shopping uses remaining coins")
		check(host._commerce.shop.get_node("%WalletLabel").text == "金币 275","open shop updates after role purchase")
		selector.hide()
		check(not items.try_purchase(7,99,host._commerce) and PROFILE.coins == 275,"insufficient balance cannot overdraw")
		host._commerce.close_all()
		var good_path: String = PROFILE.override_path
		PROFILE.override_path = "res://.godot/no-wallet-%d/profile.cfg" % Time.get_ticks_usec()
		PROFILE._loaded_path = PROFILE.override_path
		check(not items.add_gold(9,"failed-credit") and not items.has_claimed("failed-credit") and items.gold == 275,"save failure rejects pickup and preserves retry")
		host._commerce.open_shop()
		var ammo: int = items.pistol_ammo
		check(not items.try_purchase(6,1,host._commerce) and items.pistol_ammo == ammo and items.gold == 275,"failed shop save grants no free items and keeps balance")
		check(not PROFILE.unlock_character("astra") and not PROFILE.owns("astra") and PROFILE.coins == 275,"failed character save restores balance and ownership")
		PROFILE.override_path = good_path
		PROFILE._loaded_path = good_path
		host._commerce.close_all()
		check(items.add_gold(9,"failed-credit") and items.gold == 284,"retry after fixing save credits exactly once")
		host._player.take_damage(999)
		check(PROFILE.coins == 284 and items.gold == 284,"death cannot clear shared wallet")
		PROFILE._loaded_path = ""
		PROFILE.ensure_loaded()
		check(PROFILE.coins == 284 and PROFILE.owns("lan") and PROFILE.owns("iron"),"saved wallet and roles reload together")
	paused = false
	change_scene_to_file("res://scenes/dungeon/Level04Practice.tscn")
	await frames(12)
	var practice := current_scene
	practice._on_run_started()
	check(not practice._items.uses_shared_wallet,"practice keeps isolated inventory")
	practice._items.add_gold(100)
	check(practice._items.gold == 100 and PROFILE.coins == 284,"practice cannot mint persistent coins")
	current_scene.queue_free()
	await frames()
	root.get_node("MusicManager").stop_music()
	print("SHARED_WALLET_RESULT checks=%d failed=%d" % [checks,failures])
	quit(1 if failures else 0)
