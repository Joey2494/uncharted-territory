extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func frames(n: int = 6) -> void:
	for i in n: await physics_frame
	await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)
func key(code: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	event.echo = false
	Input.parse_input_event(event)
	await frames(1)

func run() -> void:
	var profile = preload("res://scripts/integration/player_profile.gd")
	profile.override_path = "res://.godot/swap_room_profile.cfg"
	if FileAccess.file_exists(profile.override_path): DirAccess.remove_absolute(profile.override_path)
	profile.ensure_loaded()
	profile.set_coins(150)
	profile.unlock_character("iron")
	preload("res://scripts/integration/campaign_progress.gd").override_path = "res://.godot/swap_room_campaign.cfg"
	preload("res://scenes/player/character_catalog.gd").selected_id = "iron"
	change_scene_to_file("res://Main.tscn")
	await frames()
	var main := current_scene
	var world := main.get_node("DungeonTest")
	var player := world.get_node("Player")
	var inventory := player.get_node("ItemInventory")
	var guard := player.get_node("Visuals/Model/Knight")
	var boss := world.get_node("RuinGatekeeper")
	var boss_model := boss.get_node("Visuals/Model/Barbarian")
	check(not guard.find_children("Barbarian_*", "MeshInstance3D", true, false).is_empty(), "guard receives former Boss body")
	check(guard.find_child("IronRoundShield", true, false) != null, "guard receives a round defensive shield")
	check(guard.find_child("IronHelm", true, false) == null, "guard no longer has bronze helmet")
	check(boss_model.find_child("IronHelm", true, false) != null, "first Boss receives bronze helmet body")
	check(boss_model.find_children("Barbarian_*", "MeshInstance3D", true, false).is_empty(), "first Boss no longer uses old human body")
	check(boss_model.find_child("BossAxe", true, false) != null, "new Boss body supports two-handed weapon socket")
	check(player.max_hp == 6 and boss.max_hp == 24, "swap preserves combat health scales")
	check(world.get_node("EntrancePotion").item_type == inventory.HEALTH_POTION, "opening room contains actual potion")
	check(world.get_region_at(world.get_node("EntrancePotion").global_position) == world.get_node("Regions/EntranceHall"), "new potion is in opening room")
	check(world.has_node("SupplyPotion"), "branch potion retained")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_I
	check(event.is_action("switch_weapon"), "I binds switch_weapon")
	main._on_run_started()
	await frames(10)
	await key(KEY_I)
	check(inventory.equipped_weapon == inventory.Catalog.MELEE and not inventory.owns_firearm, "I without a gun cannot fabricate equipment")
	check(inventory.grant_reward("test_gun", {inventory.FIREARM: 1}), "actual firearm reward received")
	var initial_ammo: int = inventory.ammo
	await key(KEY_I)
	check(inventory.equipped_weapon == inventory.FIREARM, "physical I equips firearm")
	await key(KEY_J)
	check(inventory.ammo == initial_ammo - 1, "J fires after I and spends exactly one bullet")
	await key(KEY_I, true)
	check(inventory.equipped_weapon == inventory.FIREARM, "key repeat does not toggle weapon")
	await key(KEY_I)
	check(inventory.equipped_weapon == inventory.Catalog.MELEE, "second I returns to melee")
	main.set_paused(true)
	await key(KEY_I)
	check(inventory.equipped_weapon == inventory.Catalog.MELEE, "paused I cannot change equipment")
	main.set_paused(false)
	check(player.try_dodge(), "dodge starts")
	await key(KEY_I)
	check(inventory.equipped_weapon == inventory.Catalog.MELEE, "dodge blocks weapon changes")
	await frames(60)
	var ability := player.get_node("CharacterAbility")
	check(ability.try_activate(), "swapped human guard raises shield")
	await key(KEY_I)
	check(inventory.equipped_weapon == inventory.Catalog.MELEE, "guard stance blocks weapon changes")
	ability.cancel()
	var tutorial := main.get_node("RunBindings/TutorialController")
	tutorial.index = 5
	player.global_position = world.get_node("EntrancePotion").global_position + Vector3(0, 0, 0.6)
	await frames()
	check(inventory.try_interact_nearest(), "opening potion can be picked up with real interaction")
	await frames()
	check(inventory.potion_count == 1 and player.hp < player.max_hp, "heal lesson uses one real potion, no extra grant")
	check(inventory.try_use_potion(), "opening potion can complete heal lesson")
	await frames(20)
	check(tutorial.index == 6 and not tutorial.finished, "rune lesson remains pending after healing")
	check(inventory.rune_count == 0 and not main._hud.get_node("%TutorialPrompt").visible, "no free rune or early rune overlay in opening room")
	await key(KEY_F)
	check(tutorial.index == 6 and not tutorial.finished, "F before encounter cannot complete rune lesson")
	main.set_paused(true)
	player.global_position = world.get_node("AttackRune").global_position + Vector3(0, 0, 0.7)
	await frames()
	check(not tutorial._rune_encountered, "pause cannot trigger branch encounter")
	main.set_paused(false)
	await frames()
	check(main._hud._tutorial_message == "rune_pickup", "branch rune first prompts E pickup")
	check(inventory.try_interact_nearest(), "actual branch rune collected")
	await frames()
	check(inventory.rune_count == 1 and main._hud._tutorial_message == "rune", "pickup enables F usage lesson")
	await key(KEY_F)
	check(tutorial.finished and inventory.rune_count == 0 and inventory.get_buff_remaining() > 0, "real F use completes rune lesson and applies buff")
	check(not main._hud.get_node("%TutorialPrompt").visible, "final lesson overlay clears")
	player.global_position = Vector3(0, 0.05, -23)
	await frames(8)
	world.get_node("MeleeEnemy").take_damage(1000)
	await frames(72)
	player.global_position = Vector3(22, 0.05, -23)
	await frames(8)
	check(boss.can_process(), "normal room progression activates bronze Boss")
	check(boss.get_node("MeleeAttack").try_attack(), "bronze Boss can perform original heavy attack")
	await frames(3)
	check(not boss_model.get_node("Rig_Medium/Skeleton3D/GatekeeperShield").visible, "Boss shield stows during two-handed swing")
	boss.get_node("MeleeAttack").cancel_attack()
	boss._begin_charge(Vector3.FORWARD)
	await frames(3)
	check(boss_model._visor_material.albedo_color == Color("df7445"), "Boss charging changes visor warning color")
	boss._begin_recovery()
	player._invulnerability_remaining = 0
	player.take_damage(100)
	await frames(75)
	check(main._run_state == main.RunState.DEAD, "swapped guard death animation completes")
	current_scene = null
	main.free()
	await frames()
	print("SWAP ROOM CONTROLS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
