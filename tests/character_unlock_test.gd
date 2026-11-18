extends SceneTree
## Verify actual character-menu purchases against success-only wallet settlement.
const Profile = preload("res://scripts/integration/player_profile.gd")
const Catalog = preload("res://scenes/player/character_catalog.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func frames(n := 8) -> void:
	for i in n: await physics_frame
	await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)
func run() -> void:
	Profile.override_path = "res://.godot/unlock_test.cfg"
	if FileAccess.file_exists(Profile.override_path): DirAccess.remove_absolute(Profile.override_path)
	preload("res://scripts/integration/campaign_progress.gd").override_path = "res://.godot/unlock_campaign.cfg"
	Profile.ensure_loaded()
	check(Profile.coins == 0 and Profile.unlocked == ["knight"], "fresh profile has only free original")
	Catalog.selected_id = "astra"
	change_scene_to_file("res://Main.tscn")
	await frames()
	var main := current_scene
	check(main._player.character_id == "knight" and main._player.max_hp == 5 and main._player.shield == 2, "free Knight uses the approved starting attributes")
	var selector: Control = main.get_node("MenuNavigation").character_select
	main._start_screen.start_button.pressed.emit()
	for id in ["lan", "iron", "astra"]:
		selector.show_selection(id)
		check(selector.get_node("%ConfirmButton").disabled and selector.get_node("%UnlockButton").visible, "locked selection cannot confirm")
		selector.get_node("%ConfirmButton").pressed.emit()
		check(not main.get_node("MenuNavigation").level_select.visible and main.get_run_state() == main.RunState.MENU, "locked character cannot reach level selection")
		check(not Profile.unlock_character(id) and Profile.coins == 0, "insufficient currency changes nothing")
	selector.back_requested.emit()
	main._on_run_started()
	await frames()
	main.get_node("RunBindings/TutorialController").skip()
	check(main._items.add_gold(500, "unlock_fixture_reward"), "inventory receives pending gold")
	check(Profile.coins == 0, "pending gold cannot buy permanent characters")
	check(Profile.settle_run("unlock-fixture-win", main._items.gold) and Profile.coins == 500, "successful settlement makes earnings available")
	main.get_node("RunBindings").return_to_menu()
	await frames(15)
	main = current_scene
	selector = main.get_node("MenuNavigation").character_select
	check(main._items.gold == 0 and Profile.coins == 500, "menu reload keeps permanent wallet and resets run gold")
	main._start_screen.start_button.pressed.emit()
	for id in ["lan", "iron", "astra"]:
		var before := Profile.coins
		selector.show_selection(id)
		selector.get_node("%UnlockButton").pressed.emit()
		check(Profile.owns(id) and Profile.coins == before - Profile.PRICES[id], "menu unlock charges exactly once")
		check(not selector.get_node("%ConfirmButton").disabled and main._items.gold == 0, "unlock refreshes confirmation without changing run gold")
		selector._purchase()
		check(Profile.coins == before - Profile.PRICES[id], "duplicate purchase does not spend again")
	check(Profile.coins == 70, "all prices reconcile")
	Profile._loaded_path = ""
	Profile.ensure_loaded()
	check(Profile.coins == 70 and Profile.unlocked.size() == 4, "ownership and wallet survive reload")
	selector.get_node("%ConfirmButton").pressed.emit()
	main.get_node("MenuNavigation").level_select.get_level_button(&"level1").pressed.emit()
	await frames(15)
	main = current_scene
	check(main.get_run_state() == main.RunState.PLAYING and main._player.character_id == "astra", "purchased role reaches actual gameplay")
	check(main._player.get_node("CharacterAbility").try_activate(), "purchased role ability works")
	await frames(20)
	check(get_nodes_in_group("gravity_fields").size() == 1, "purchased skill produces a field")
	main.queue_free()
	await frames(3)
	root.get_node("MusicManager").stop_music()
	await create_timer(0.15).timeout
	print("CHARACTER UNLOCK: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
