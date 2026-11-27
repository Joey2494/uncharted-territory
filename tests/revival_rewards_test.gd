extends SceneTree
## Isolated profile; exercises real inventory/shop/death UI and authored map drops.
const Profile = preload("res://scripts/integration/player_profile.gd")
const Progress = preload("res://scripts/integration/campaign_progress.gd")
const Catalog = preload("res://data/item_catalog.gd")
const Rewards = preload("res://data/reward_balance.gd")
const Presenter = preload("res://scenes/items/commerce_presenter.gd")
const Characters = preload("res://scenes/player/character_catalog.gd")
var checks := 0
var failures := 0
var host

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)
func frames(n := 5) -> void:
	for i in n: await physics_frame

func load_run(path: String, cards := 2, role := "knight") -> void:
	paused = false
	var token := str(Time.get_ticks_usec())
	Profile.override_path = "user://revival-test-profile-" + token + ".cfg"
	Progress.override_path = "user://revival-test-progress-" + token + ".cfg"
	Profile.ensure_loaded()
	Profile.unlocked.assign(["knight", "lan", "iron", "astra"])
	Profile.inventory = {Catalog.REVIVAL_CARD:cards, Catalog.HEALTH_POTION:2, Catalog.GUARD_RUNE:1}
	Profile.coins = 1000
	Profile.set_selected_character(role)
	Characters.selected_id = role
	Characters.start_pending = false
	change_scene_to_file(path)
	await frames(12)
	host = current_scene
	host._on_run_started()
	await frames()
	check(host._run_state == host.RunState.PLAYING, "real run starts: " + path)

func die() -> void:
	host._player._invulnerability_remaining = 0
	host._player.take_damage(999)
	check(host._run_state == host.RunState.DYING, "lethal damage enters dying")
	var deadline := Time.get_ticks_msec() + 5000
	while host._run_state == host.RunState.DYING and Time.get_ticks_msec() < deadline:
		await physics_frame
	check(host._run_state == host.RunState.DEAD, "death animation reaches choice/result")

func run() -> void:
	if "--balance-only" in OS.get_cmdline_user_args():
		test_balance()
		print("REWARD_BALANCE_RESULT checks=%d failures=%d" % [checks, failures])
		quit(1 if failures else 0)
		return
	if "--placements-only" in OS.get_cmdline_user_args():
		await load_run("res://scenes/dungeon/Level04Run.tscn", 0)
		await test_fourth_mail()
		await load_run("res://scenes/dungeon/Level04Run.tscn", 0)
		await test_fourth_mail_take()
		current_scene.queue_free()
		root.get_node("MusicManager").stop_music()
		await frames()
		print("REVIVAL_PLACEMENTS_RESULT checks=%d failures=%d" % [checks, failures])
		quit(1 if failures else 0)
		return
	test_balance()
	var paths := ["res://Main.tscn", "res://scenes/dungeon/Level02Run.tscn", "res://scenes/dungeon/Level03Run.tscn", "res://scenes/dungeon/Level04Run.tscn"]
	for i in paths.size():
		await load_run(paths[i], 2, Characters.IDS[i])
		await test_revival()
	await load_run(paths[2], 0)
	await test_third_direction()
	await load_run(paths[3], 0)
	await test_fourth_mail()
	await load_run(paths[3], 0)
	await test_fourth_mail_take()
	await test_victory_carry(paths[2], paths[3])
	await load_run(paths[0], 0)
	await die()
	check(Profile.coins == 0 and Profile.inventory.is_empty() and host._items.gold == 0, "without a card, defeat forfeits old and new assets")
	check(not host._hud.get_result_screen().get_node("%ReviveButton").visible, "no card means no revival action")
	await test_failure_save()
	paused = false
	if is_instance_valid(current_scene): current_scene.queue_free()
	root.get_node("MusicManager").stop_music()
	await frames()
	print("REVIVAL_REWARDS_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func test_balance() -> void:
	check(Catalog.get_item(Catalog.REVIVAL_CARD).price == 500, "revival card costs 500 coins")
	check(Presenter.item_id(&"revival_card") == Catalog.REVIVAL_CARD, "shop/backpack share the stable ID")
	for level in range(1, 5):
		var max_value := 0.0
		var no_cards := true
		var nonempty := 0
		for roll in 100:
			var find := Rewards.random_find(level, roll)
			max_value = maxf(max_value, Rewards.value(find))
			no_cards = no_cards and not find.items.has(Catalog.REVIVAL_CARD)
			if find.gold > 0 or not find.items.is_empty(): nonempty += 1
		check(no_cards, "random finds never add extra cards")
		check(max_value <= 8.0, "all random finds are low-value supplies")
		check(nonempty <= 20, "at least 80 percent of random rolls produce nothing")
	for sequence in [["l1_crossroads", "l1_boss"], ["l2_hub", "l2_relay", "l2_antechamber", "l2_boss"], ["l3_C", "l3_E", "l3_F", "l3_I", "l3_G"], ["l4_B", "l4_D", "l4_F", "l4_H", "l4_I"]]:
		var previous := -1.0
		for id: String in sequence:
			var value := Rewards.value(Rewards.task(id))
			check(value > previous, "combat rewards increase with room difficulty: " + id)
			previous = value
	check(Rewards.value(Rewards.task("l2_archive")) > Rewards.value(Rewards.task("l1_puzzle")), "longer relay puzzle rewards more than the first rune sequence")
	check(Rewards.value(Rewards.task("l4_mirror")) > Rewards.value(Rewards.task("l4_calibration")), "optional double-mirror puzzle rewards more than calibration")
	check(Rewards.task("l4_mail").items == {Catalog.REVIVAL_CARD:1}, "right postal option contains only one revival card")
	check(Rewards.task("l4_mail_take").gold == 0 and Rewards.task("l4_mail").gold == 0, "neither postal choice awards coins")
	check(Rewards.value(Rewards.task("l4_mail_take")) == 500.0 and Rewards.value(Rewards.task("l4_mail_take")) == Rewards.value(Rewards.task("l4_mail")), "the item-only supply pack equals one revival card at catalog prices")
	check(48 + Rewards.value(Rewards.task("l4_H")) > 66 + Rewards.value(Rewards.task("l4_F")), "H total reward including reinforcements exceeds F total reward")
	var item_total := 0
	var empty_rooms := 0
	for id: String in Rewards.TASKS:
		# The user explicitly permits a larger, direct-to-bag postal choice.
		# Every other task retains the scarce world-drop budget.
		if id == "l4_mail_take": continue
		var count := 0
		for n: int in Rewards.task(id).items.values(): count += n
		item_total += count
		check(count <= 2, "a task never awards more than two consumables: " + id)
		if Rewards.task(id).items.is_empty(): empty_rooms += 1
	check(item_total <= 20 and empty_rooms >= 10, "authored drops have a small total budget and many rooms without items")

func test_revival() -> void:
	var items = host._items
	var player = host._player
	var card_count: int = items.revival_card_count
	check(not items.try_use_item(Catalog.REVIVAL_CARD) and items.revival_card_count == card_count, "alive player cannot waste a card")
	host._commerce.open_shop()
	await frames()
	var buy = host._commerce.shop.get_product_card(&"revival_card").get_buy_button()
	buy.pressed.emit()
	await frames()
	check(items.gold == 500 and items.revival_card_count == card_count + 1, "actual shop button buys one card for 500")
	host._commerce.close_all()
	items.gold = 499
	check(not items.try_purchase(Catalog.REVIVAL_CARD) and items.gold == 499 and items.revival_card_count == card_count + 1, "499 coins cannot buy or partially charge a revival card")
	items.gold = 500
	items.add_gold(37, "before_revival")
	var position: Vector3 = player.global_position
	var gold: int = items.gold
	var bag: Dictionary = items.get_snapshot().items.duplicate()
	await die()
	check(Profile.coins == 1000 and Profile.inventory[Catalog.REVIVAL_CARD] == 2, "death choice has not forfeited settled assets")
	check(items.gold == gold and player.revival_pending, "pending death retains all run gains")
	check(not host.restart_run() and not host.request_scene_change("res://Main.tscn"), "cannot bypass pending death choice via navigation")
	var screen = host._hud.get_result_screen()
	check(screen.get_node("%ReviveButton").visible and screen.get_node("%ForfeitButton").visible, "choice offers explicit use or forfeit")
	screen.get_node("%ReviveButton").pressed.emit()
	await frames()
	check(host._run_state == host.RunState.PLAYING and not player.is_dead() and player.hp == player.max_hp, "card restores active play and full health")
	check(player.global_position.distance_to(position) < 0.2 and items.gold == gold, "revival preserves location and gold")
	check(items.revival_card_count == card_count and items.potion_count == int(bag[Catalog.HEALTH_POTION]), "exactly one card consumed; other inventory preserved")
	check(player.is_invulnerable() and not player.take_damage(1), "revival protection rejects immediate follow-up damage")
	check(host._dungeon.can_process() and player.get_node("LocomotionAnimation").is_physics_processing(), "world progression and player animation resume")
	check(not items.try_use_revival_card(host), "repeat click cannot consume another card")
	check(player.get_node("MeleeAttack").try_attack(), "revived player can attack")
	await frames(35)
	await die()
	screen = host._hud.get_result_screen()
	screen.get_node("%ForfeitButton").pressed.emit()
	check(not player.revival_pending and host._failure_settled, "declining commits final defeat")
	check(items.gold == 0 and items.revival_card_count == 0 and items.potion_count == 0 and Profile.coins == 0 and Profile.inventory.is_empty(), "final defeat clears carried wallet and entire bag")
	check(Profile.owns(player.character_id), "defeat preserves character ownership")
	check(not items.try_use_revival_card(host), "forfeited card cannot revive")
	Profile._loaded_path = ""
	Profile.ensure_loaded()
	check(Profile.coins == 0 and Profile.inventory.values().all(func(n): return n == 0), "defeat remains cleared after profile reload")

func test_third_direction() -> void:
	var level = host._dungeon
	var player = host._player
	var card = level.get_node("Supplies/ServiceRevivalCard")
	check(not card.visible and card.item_type == Catalog.REVIVAL_CARD, "third-level bend starts with a hidden card")
	# Use real enemy damage to complete the maintenance-room roster.
	level._progress.activate_room(&"I")
	for enemy in level.get_node("Enemies").get_children():
		if enemy.get_meta("room", &"") == &"I":
			enemy.set_encounter_active(true)
			enemy.take_damage(999)
	check(level._progress.is_complete(&"I"), "maintenance monsters actually cleared")
	level._service = true
	level._refresh_world()
	level._previous_reward_position = Vector3(-49, 0, -23)
	player.global_position = Vector3(-49, 0.05, -24)
	level._update_revival_drop()
	check(not card.visible, "green approach from south does not reveal the card")
	level._previous_reward_position = Vector3(-42.3, 0, -24)
	player.global_position = Vector3(-41.8, 0.05, -24)
	level._update_revival_drop()
	check(not card.visible, "opposite horizontal approach does not reveal the card")
	level._previous_reward_position = Vector3(-41.8, 0, -24)
	player.global_position = Vector3(-42.3, 0.05, -24)
	level._update_revival_drop()
	check(card.visible and level._revival_revealed, "red I-to-west approach reveals one card")
	player.global_position = card.global_position + Vector3(0, 0.05, 0.8)
	await frames()
	check(card.try_collect(player) and host._items.revival_card_count == 1, "authored card is reachable and enters the backpack")
	await frames()
	player.global_position = Vector3(0, 0.05, 0)
	level._reset_armed = 4.0
	level._use_tide_control(&"reset")
	level._refresh_world()
	check(level.get_node_or_null("Supplies/ServiceRevivalCard") == null, "puzzle reset cannot respawn collected card")
	check(level._revival_revealed, "puzzle reset retains once-only reveal state")
	await test_active_encounter(3)

func test_fourth_mail() -> void:
	var level = host._dungeon
	level.combat._cleared["D"] = true
	check(level.use_station(&"right") and level.use_station(&"left"), "counterweight controls still operate")
	var cards := get_nodes_in_group("item_pickups").filter(func(n): return n.get("item_type") == Catalog.REVIVAL_CARD)
	check(cards.is_empty(), "counterweight well no longer generates a revival card")
	var right: Node3D = level.get_node("Stations/mail_send")
	check(right.caption.contains("复活卡") and not right.caption.contains("守护符文"), "pictured right mail control advertises the revival card")
	var previous_pickups := get_nodes_in_group("item_pickups").size()
	check(Rewards.scatter(level, "too_close_to_switch", 4, right.global_position), "random scatter records occupied approach as a once-only empty find")
	check(get_nodes_in_group("item_pickups").size() == previous_pickups, "random find cannot steal E from a nearby switch")
	host._player.global_position = right.global_position + Vector3(0, 0.05, 1.2)
	host._player.velocity = Vector3.ZERO
	await frames()
	check(host._items.try_interact_nearest() and level.mail.state == level.mail.State.TRAVELLING, "actual E interaction at the pictured control sends the mail")
	check(not level.use_station(&"mail_take") and not level.use_station(&"mail_send"), "right-side delivery excludes taking the left supply or resending")
	level.visited["H"] = true
	for tick in 10: level.mail.advance(100.0)
	check(level.mail.state == level.mail.State.ARRIVED, "postal cart reaches the dome")
	var receive: Node3D = level.get_node("Stations/mail_receive")
	host._player.global_position = receive.global_position + Vector3(-1.2, 0.05, 0)
	host._player.velocity = Vector3.ZERO
	await frames()
	host._items.revival_card_count = Catalog.MAX_STACK
	check(not level.use_station(&"mail_receive") and level.mail.state == level.mail.State.ARRIVED, "full card stack preserves unclaimed delivery")
	host._items.revival_card_count = 0
	var guards: int = host._items.guard_count
	var energy: int = host._items.energy_potion_count
	var gold: int = host._items.gold
	check(host._items.try_interact_nearest(), "actual E interaction signs for the mail")
	check(host._items.revival_card_count == 1 and host._items.energy_potion_count == energy and host._items.guard_count == guards and host._items.gold == gold, "delivery grants only one card, without potions, runes or coins")
	check(not level.use_station(&"mail_receive") and host._items.revival_card_count == 1, "mail cannot generate another card on repeat interaction")
	await test_active_encounter(4)

func test_fourth_mail_take() -> void:
	var level = host._dungeon
	var station: Node3D = level.get_node("Stations/mail_take")
	host._player.global_position = station.global_position + Vector3(0, 0.05, 1.2)
	host._player.velocity = Vector3.ZERO
	await frames()
	var items = host._items
	var gold: int = items.gold
	var energy: int = items.energy_potion_count
	var health: int = items.potion_count
	var attacks: int = items.rune_count
	var guards: int = items.guard_count
	items.energy_potion_count = Catalog.MAX_STACK
	check(not level.use_station(&"mail_take") and items.gold == gold and not level.mail.chosen() and items.potion_count == health and items.rune_count == attacks and items.guard_count == guards, "one full stack rejects the whole supply pack without partial items or receipt")
	items.energy_potion_count = energy
	check(items.try_interact_nearest(), "actual left-side E interaction collects the item-only supply pack")
	check(items.gold == gold and items.energy_potion_count == energy + 2 and items.potion_count == health + 2 and items.rune_count == attacks + 10 and items.guard_count == guards + 10 and items.revival_card_count == 0, "left side grants the complete 500-value pack without coins or revival cards")
	check(not level.use_station(&"mail_take") and not level.use_station(&"mail_send") and items.gold == gold, "repeat and opposite choices cannot grant another reward")

func test_active_encounter(level_id: int) -> void:
	var level = host._dungeon
	var player = host._player
	player.global_position = Vector3(-25, 0.05, 0) if level_id == 3 else level.layout.room_center("B") + Vector3(0, 0.05, 2)
	player.velocity = Vector3.ZERO
	await frames()
	var enemies: Array = []
	if level_id == 3:
		for enemy in level.get_node("Enemies").get_children():
			if enemy.get_meta("room", &"") == &"C": enemies.append(enemy)
	else:
		enemies.assign(level.combat._enemies)
	check(enemies.size() == 2, "real encounter spawns its required enemies before revival")
	if enemies.is_empty(): return
	enemies[0].take_damage(1)
	var remaining_hp: int = enemies[0].hp
	await die()
	host._hud.get_result_screen().get_node("%ReviveButton").pressed.emit()
	check(not player.is_dead() and enemies[0].hp == remaining_hp, "revival keeps the same wounded enemies")
	check(level._active_room == &"C" if level_id == 3 else level.combat.active_room == "B", "revival retains active encounter and sealed doors")
	for enemy in enemies: enemy.take_damage(999)
	await frames()
	check(level._progress.is_complete(&"C") if level_id == 3 else level.combat.is_clear("B"), "clearing enemies after revival completes and unlocks the same room")
	var ledger: Dictionary = level.get_meta("generated_task_rewards")
	check(ledger.has("level03_clear:C" if level_id == 3 else "observatory_encounter_B"), "post-revival clear records completion once without forcing a supply drop")

func test_victory_carry(third: String, fourth: String) -> void:
	await load_run(third, 1)
	check(host._items.try_purchase(Catalog.REVIVAL_CARD), "run can buy a second card")
	var receipt := "revival-carry-" + str(Time.get_ticks_usec())
	check(host._items.settle_backpack(receipt) and Profile.inventory[Catalog.REVIVAL_CARD] == 2 and Profile.coins == 500, "success saves purchased and dropped cards with coins")
	check(host._items.settle_backpack(receipt) and Profile.inventory[Catalog.REVIVAL_CARD] == 2, "success receipt does not duplicate cards")
	change_scene_to_file(fourth)
	await frames(12)
	host = current_scene
	check(host._items.revival_card_count == 2 and host._items.gold == 500, "next level loads carried cards and coins")

func test_failure_save() -> void:
	await load_run("res://Main.tscn", 1)
	var good_path: String = Profile.override_path
	Profile.override_path = "user://missing-revival-" + str(Time.get_ticks_usec()) + "/profile.cfg"
	Profile._loaded_path = Profile.override_path
	await die()
	host._decline_revival()
	check(not host._failure_settled and Profile.coins == 1000, "failed defeat save rolls back profile atomically")
	check(not host.request_scene_change("res://Main.tscn") and not host._transition_queued, "failed defeat save blocks navigation until retry")
	Profile.override_path = good_path
	Profile._loaded_path = good_path
	check(host._finalize_failure() and Profile.coins == 0 and Profile.inventory.is_empty(), "defeat save retries and clears once")
