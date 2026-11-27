extends SceneTree
const Progress = preload("res://scripts/integration/campaign_progress.gd")
const Characters = preload("res://scenes/player/character_catalog.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var profile = preload("res://scripts/integration/player_profile.gd")
	profile.override_path = "res://.godot/fixture_integration_modules_test.cfg"
	if FileAccess.file_exists(profile.override_path): DirAccess.remove_absolute(profile.override_path)
	profile.ensure_loaded()
	profile.set_coins(430)
	for character in ["lan", "iron", "astra"]: profile.unlock_character(character)
	run.call_deferred()
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", description)
func frames(count: int = 3) -> void:
	for i in count: await physics_frame
	await process_frame

func run() -> void:
	Progress.override_path = "res://.godot/integration_progress.cfg"
	if FileAccess.file_exists(Progress.override_path): DirAccess.remove_absolute(Progress.override_path)
	var progress := Progress.new()
	for level_id in [&"level1", &"level2", &"level3", &"level4"]:
		check(progress.is_unlocked(level_id), "test build opens " + String(level_id))
	progress.complete(1)
	check(Progress.new().is_unlocked(&"level2"), "completion persists unlock")
	for level in [1, 2]:
		for id in ["knight", "lan", "iron", "astra"]:
			Characters.selected_id = id
			preload("res://scripts/integration/player_profile.gd").set_selected_character(id)
			var main := load("res://Main.tscn" if level == 1 else "res://scenes/dungeon/Level02Run.tscn").instantiate() as Node3D
			root.add_child(main)
			await frames()
			var player := main.get_node("DungeonTest/Player")
			var hud := main.get_node("UILayer/HUD")
			var items := player.get_node("ItemInventory")
			var menu := main.get_node("CommerceLayer")
			check(main.level_id == level and player.character_id == id, "level and character initialized")
			check(hud.has_node("ResourcesPanel") and hud.has_node("Hotbar"), "Tang authored HUD present")
			check(not player.can_process(), "menu freezes world")
			main._on_run_started()
			await frames(8)
			check(player.can_process() and main._run_state == main.RunState.PLAYING, "campaign starts")
			check(hud.energy_bar.value == player.energy, "HUD binds actual energy")
			items.gold = 0
			items._publish_state()
			items.add_gold(100)
			await frames()
			check(hud.gold_label.text == "本局 100", "HUD binds actual pending gold")
			check(main.set_paused(true), "pause accepted")
			await frames()
			check(menu.pause_menu.visible, "Tang pause menu shown")
			check(not player.get_node("EnergyShock").try_cast(), "pause blocks combat")
			var energy: float = player.energy
			await frames(10)
			check(player.energy == energy, "pause freezes energy")
			menu.open_shop()
			await frames()
			check(menu.view == menu.View.SHOP, "pause opens Tang shop")
			check(items.try_purchase(items.FIREARM, 1, menu), "purchase uses real inventory")
			check(items.gold < 100 and items.owns_firearm, "purchase deducts currency")
			menu.shop.backpack_requested.emit()
			check(menu.view == menu.View.BACKPACK and paused, "Tang shop tab opens backpack with pause intact")
			menu.backpack.shop_requested.emit()
			check(menu.view == menu.View.SHOP and paused, "Tang backpack tab returns to shop")
			menu.close_panel()
			await frames()
			check(paused and main._run_state == main.RunState.PAUSED, "shop preserves host pause")
			check(menu.pause_menu.visible, "return restores Tang pause")
			main.set_paused(false)
			await frames()
			check(not paused and player.can_process(), "resume restores world")
			check(items.try_equip(items.FIREARM), "firearm equips")
			check(player.get_node("Firearm").try_fire(), "J firearm backend fires")
			check(player.get_node("Firearm").get_cooldown_remaining() > 0, "firearm cooldown authoritative")
			if level == 1:
				var tutorial := main.get_node("RunBindings/TutorialController")
				check(tutorial.active, "Tang lesson prompt active")
				tutorial.complete("spell")
				check(tutorial.index == 0, "out of order lesson ignored")
				tutorial.skip()
				check(tutorial.finished and not hud.get_node("%TutorialPrompt").visible, "skip clears lesson prompt")
			else:
				check(main.get_node("DungeonTest/Boss").max_hp == 36, "balanced scorpion Boss is present")
				check(main.get_node("DungeonTest/Enemies/Relay2").get_script().resource_path.ends_with("spider_combat.gd") and main.get_node("DungeonTest/Enemies/Relay2").attack_kind == 1, "brood mother uses the current campaign enemy contract")
			player._invulnerability_remaining = 0.0
			items.guard_active = false
			player.take_damage(100)
			await frames(75)
			check(main._run_state == main.RunState.DEAD, "death animation completes into result")
			check(not menu._enabled, "death closes commerce")
			main.free()
			await frames()
	root.get_node("MusicManager").stop_music()
	await create_timer(0.2).timeout
	print("INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
