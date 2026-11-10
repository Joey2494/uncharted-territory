extends SceneTree

const Catalog = preload("res://data/item_catalog.gd")
const PlayerScene = preload("res://scenes/player/Player.tscn")
const EnemyScene = preload("res://scenes/enemies/MeleeEnemy.tscn")
const ColossusScene = preload("res://scenes/bosses/RuinColossus.tscn")
const SentinelScene = preload("res://scenes/enemies/RuinSentinel.tscn")
const Coins = preload("res://scenes/items/coin_pickup.gd")

var passed := 0
var failed := 0
var world: Node3D
var player: CharacterBody3D
var inventory: Node3D
var observed := {}


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		print("FAIL ", label)


func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
	await process_frame


func make_wall(point: Vector3, dimensions: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.position = point
	wall.collision_layer = 1
	wall.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions
	collision.shape = box
	wall.add_child(collision)
	world.add_child(wall)
	return wall


func setup_world() -> void:
	world = Node3D.new()
	root.add_child(world)
	make_wall(Vector3(0, -0.25, 0), Vector3(100, 0.5, 100))
	player = PlayerScene.instantiate()
	player.name = "Player"
	player.position = Vector3(0, 0.05, 0)
	world.add_child(player)
	inventory = player.get_node("ItemInventory")
	await frames(3)


func cleanup() -> void:
	world.queue_free()
	await frames(2)


func _run() -> void:
	await setup_world()
	test_catalog_and_transactions()
	test_items_and_guard()
	await test_firearm()
	await cleanup()
	await test_first_level_rewards()
	await setup_world()
	await test_sentinel()
	await test_colossus()
	await cleanup()
	await test_main_lifecycle()
	print("WEEK9_RESULT passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)


func test_catalog_and_transactions() -> void:
	check(Catalog.get_products().size() == 5, "five configured products")
	check(Catalog.get_item(999).is_empty(), "unknown product rejected")
	var product := Catalog.get_item(0)
	product.price = -100
	check(Catalog.get_item(0).price == 10, "catalog returns isolated copies")
	check(inventory.gold == 0 and inventory.ammo == 0, "new run starts empty")
	check(inventory.equipped_weapon == Catalog.MELEE, "existing starting melee preserved")
	check(not inventory.add_gold(-1), "negative gold rejected")
	check(not inventory.add_gold(0), "zero gold rejected")
	check(not inventory.try_purchase(0), "insufficient balance rejected")
	check(inventory.gold == 0 and inventory.potion_count == 0, "failed buy does not mutate")
	check(inventory.add_gold(200, "source_a"), "gold granted")
	check(not inventory.add_gold(200, "source_a"), "gold source claimed once")
	check(inventory.gold == 200, "duplicate did not add gold")
	check(not inventory.grant_reward("bad", {0: 1, 99: 1}, 10), "invalid bundle rejected atomically")
	check(inventory.gold == 200 and inventory.potion_count == 0, "invalid bundle no partial grants")
	check(not inventory.has_claimed("bad"), "failed bundle source remains retryable")
	check(not inventory.try_purchase(-1), "invalid purchase id")
	check(not inventory.try_purchase(0, -1), "negative purchase quantity")
	check(not inventory.try_purchase(0, 0), "zero purchase quantity")
	check(not inventory.try_purchase(0, 100), "oversized purchase quantity")
	check(not inventory.try_purchase(4), "ammo requires weapon")
	check(inventory.try_purchase(0, 2), "bulk potion purchase")
	check(inventory.gold == 180 and inventory.potion_count == 2, "bulk purchase cost and count")
	check(inventory.try_purchase(1), "rune purchase")
	check(inventory.try_purchase(2), "guard purchase")
	check(inventory.try_purchase(3), "firearm purchase")
	check(inventory.owns_firearm and inventory.ammo == 12, "weapon grants initial ammunition")
	check(not inventory.try_purchase(3), "duplicate weapon purchase rejected")
	check(inventory.try_purchase(4), "ammo refill purchase")
	check(inventory.ammo == 18 and inventory.gold == 83, "all configured costs reconcile")
	var snapshot: Dictionary = inventory.get_snapshot()
	snapshot.items[0] = 900
	check(inventory.potion_count == 2, "inventory snapshots are isolated")
	observed["nested_purchase"] = true
	var callback := func(_state: Dictionary) -> void:
		observed["nested_purchase"] = inventory.try_purchase(0)
	inventory.state_changed.connect(callback)
	check(inventory.try_purchase(0), "outer purchase commits")
	check(not observed.nested_purchase and inventory.gold == 73, "signal reentry cannot buy twice")
	inventory.state_changed.disconnect(callback)
	inventory.potion_count = Catalog.MAX_STACK
	check(not inventory.try_purchase(0) and inventory.gold == 73, "full stack rejects without charging")
	inventory.potion_count = 3
	inventory.ammo = Catalog.MAX_STACK - 5
	check(not inventory.try_purchase(4), "full ammo stack rejects pack")
	check(not inventory.grant_reward("weapon_overflow", {3: 1}), "weapon reward respects ammo cap")
	check(not inventory.has_claimed("weapon_overflow"), "full reward remains unclaimed")
	inventory.ammo = 18
	check(inventory.grant_reward("second_weapon", {3: 1}), "duplicate weapon reward converts to ammo")
	check(inventory.get_count(3) == 1 and inventory.ammo == 30, "weapon ownership stays unique")
	inventory.gold = Catalog.MAX_GOLD
	check(not inventory.add_gold(1), "currency cap enforced")
	inventory.gold = 73


func test_items_and_guard() -> void:
	check(not inventory.try_use_potion() and inventory.potion_count == 3, "full health preserves potion")
	player.hp -= 1
	observed["heal_reentry"] = true
	var on_heal := func(_hp: int, _max: int) -> void:
		observed["heal_reentry"] = inventory.try_use_potion()
	player.hp_changed.connect(on_heal)
	check(inventory.try_use_potion(), "potion heals missing health")
	check(player.hp == player.max_hp and inventory.potion_count == 2, "heal clamps at maximum")
	check(not observed.heal_reentry, "heal callback cannot recursively consume")
	player.hp_changed.disconnect(on_heal)
	check(not inventory.try_use_rune(), "shared use cooldown blocks second item")
	inventory._use_remaining = 0
	check(inventory.try_use_rune(), "attack rune activates")
	check(player.get_attack_damage(2) == 4 and inventory.rune_count == 0, "buff changes damage and consumes rune")
	inventory.add_item(1)
	inventory._use_remaining = 0
	check(inventory.try_use_rune() and inventory.get_multiplier() == 2, "refresh does not stack multiplier")
	inventory._physics_process(inventory.rune_duration + 0.1)
	check(inventory.get_multiplier() == 1 and inventory.get_buff_remaining() == 0, "buff expires")
	inventory._use_remaining = 0
	check(inventory.try_use_guard(), "guard activates")
	check(inventory.guard_count == 0 and inventory.guard_active, "guard rune consumed on activation")
	inventory.add_item(2)
	inventory._use_remaining = 0
	check(not inventory.try_use_guard() and inventory.guard_count == 1, "active guard cannot be overwritten")
	player._dodge_invulnerability_remaining = 0.2
	check(not player.take_damage(2) and inventory.guard_active, "dodge does not spend guard")
	player._dodge_invulnerability_remaining = 0
	check(not player.take_damage(0) and inventory.guard_active, "zero damage does not spend guard")
	observed["guard_reentry"] = true
	var on_guard := func(active: bool) -> void:
		if not active:
			observed["guard_reentry"] = player.take_damage(1)
	inventory.guard_changed.connect(on_guard)
	check(player.take_damage(3), "guard accepts incoming hit")
	check(player.hp == player.max_hp and not inventory.guard_active, "guard absorbs whole hit")
	check(not observed.guard_reentry, "guard reserves invulnerability before callbacks")
	inventory.guard_changed.disconnect(on_guard)
	check(not player.take_damage(3), "same contact window cannot hit twice")
	player._invulnerability_remaining = 0
	check(player.take_damage(1) and player.hp == player.max_hp - 1, "later hit damages health")
	player.hp = player.max_hp
	player._invulnerability_remaining = 0
	check(inventory.try_equip(3), "equip owned firearm")
	check(inventory.try_equip(-1), "switch back to melee")
	check(not inventory.try_equip(999), "invalid weapon rejected")
	inventory._use_remaining = 0
	inventory.try_use_rune()
	var coins_before: int = inventory.gold
	world.process_mode = Node.PROCESS_MODE_DISABLED
	check(not inventory.try_purchase(0), "disabled world blocks purchases")
	check(not inventory.add_gold(1), "disabled world blocks reward mutation")
	check(not inventory.try_use_guard(), "disabled world blocks item use")
	check(not inventory.try_equip(3), "disabled world blocks equipment")
	check(inventory.gold == coins_before, "paused transactions preserve balance")
	world.process_mode = Node.PROCESS_MODE_INHERIT


func test_firearm() -> void:
	player.global_position = Vector3(0, 0.05, 0)
	player.visuals.rotation.y = 0
	var enemy: CharacterBody3D = EnemyScene.instantiate()
	enemy.name = "GunTarget"
	enemy.position = Vector3(0, 0.05, -3)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.get_node("MeleeAttack").attack_enabled = false
	await frames()
	var gun := player.get_node("Firearm")
	var melee := player.get_node("MeleeAttack")
	inventory.try_equip(3)
	inventory.ammo = 2
	check(melee.try_attack(), "normal attack routes to equipped gun")
	check(not melee.is_attacking() and inventory.ammo == 1, "shot does not also swing")
	check(not gun.try_fire() and inventory.ammo == 1, "shot cooldown prevents duplicate spend")
	await frames(25)
	check(enemy.hp == 1, "projectile applies firearm damage exactly once")
	var wall := make_wall(Vector3(0, 1, -1.5), Vector3(2, 2, 0.3))
	await frames()
	check(gun.try_fire(), "second shot can fire at wall")
	await frames(25)
	check(enemy.hp == 1, "world wall blocks firearm projectile")
	check(inventory.ammo == 0, "two shots consume two rounds")
	check(not gun.try_fire() and inventory.ammo == 0, "empty gun cannot fire or underflow")
	inventory.ammo = 1
	player._dodge_remaining = 0.1
	check(not gun.try_fire() and inventory.ammo == 1, "dodge blocks gun")
	player._dodge_remaining = 0
	inventory.try_equip(-1)
	check(not gun.try_fire(), "unequipped gun cannot fire")
	wall.queue_free()
	enemy.queue_free()
	await frames()


func test_first_level_rewards() -> void:
	world = preload("res://scenes/dungeon/DungeonTest.tscn").instantiate()
	world.enable_debug_shop_stands = true
	root.add_child(world)
	player = world.get_node("Player")
	inventory = player.get_node("ItemInventory")
	var enemy := world.get_node("MeleeEnemy")
	enemy.set_physics_process(false)
	world.get_node("RuinGatekeeper").set_physics_process(false)
	await frames()
	var count := get_nodes_in_group("coin_pickups").size()
	check(count == 1, "designated entrance generates coins")
	player.global_position = Vector3(0, 0.05, -23)
	world._update_region()
	check(get_nodes_in_group("coin_pickups").size() == count + 1, "designated courtyard generates coins")
	player.global_position = Vector3(0, 0.05, 4)
	world._update_region()
	player.global_position = Vector3(0, 0.05, -23)
	world._update_region()
	check(get_nodes_in_group("coin_pickups").size() == count + 1, "reentering room never duplicates coins")
	check(enemy.take_damage(99), "enemy death accepted")
	check(not enemy.take_damage(99), "repeated death rejected")
	check(get_nodes_in_group("coin_pickups").size() == count + 2, "enemy creates one coin pickup")
	var coin: Area3D = get_nodes_in_group("coin_pickups").back()
	player.global_position = coin.global_position + Vector3(0, 0, 1)
	await frames()
	check(coin.try_collect(player), "coin pickup credits wallet")
	check(not coin.try_collect(player), "same pickup cannot be claimed twice")
	check(inventory.gold == 12, "enemy coin amount correct")
	var wall := make_wall(Vector3(0, 1, 2), Vector3(3, 2, 0.4))
	var blocked: Area3D = Coins.spawn(world, Vector3(0, 0.05, 1.5), 10, "blocked_coin")
	player.global_position = Vector3(0, 0.05, 2.5)
	await frames()
	check(not blocked.try_collect(player), "coin pickup cannot pass through wall")
	wall.queue_free()
	await frames()
	check(blocked.try_collect(player), "coin collectible after obstruction removed")
	var puzzle := world.get_node("RunePuzzle")
	for kind in [1, 2, 0]:
		player.global_position = puzzle._runes[kind].global_position + Vector3(0, 0.05, 1.3)
		puzzle._input_remaining = 0
		await frames()
		check(puzzle.activate_rune(kind, player), "rune sequence step %d" % kind)
	check(puzzle.state == puzzle.State.OPENING, "correct runes open hidden room")
	puzzle._finish_opening()
	count = get_nodes_in_group("coin_pickups").size()
	puzzle._finish_opening()
	check(get_nodes_in_group("coin_pickups").size() == count, "repeat opening cannot duplicate secret gold")
	var secret_coins: Array = get_nodes_in_group("coin_pickups").filter(func(item: Node) -> bool: return item.source_id.begins_with("secret:"))
	check(secret_coins.size() == 1 and secret_coins[0].amount == 40, "opening secret generates configured gold")
	player.global_position = puzzle.get_node("RewardChest").global_position + Vector3(0, 0.05, 1.3)
	await frames()
	inventory.ammo = Catalog.MAX_STACK
	check(not puzzle.claim_reward(player), "full inventory preserves chest")
	check(not puzzle.is_reward_claimed() and inventory.potion_count == 0, "chest grant has no partial state")
	inventory.ammo = 0
	check(puzzle.claim_reward(player), "upgraded hidden chest claim")
	check(not puzzle.claim_reward(player), "hidden chest claimed once")
	check(inventory.potion_count == 2 and inventory.rune_count == 2 and inventory.guard_count == 1, "hidden consumables exceed ordinary supply")
	check(inventory.owns_firearm and inventory.ammo == 12, "hidden chest includes loaded weapon")
	var stand := world.get_node("Shop0")
	player.global_position = stand.global_position + Vector3(0, 0.05, 1)
	await frames()
	check(stand.try_interact(player), "in-world merchant calls purchase API")
	check(inventory.gold == 12 and inventory.potion_count == 3, "merchant deducted price and added item")
	player.global_position += Vector3(10, 0, 0)
	check(not stand.try_interact(player), "merchant distance gate")
	await cleanup()


func test_sentinel() -> void:
	var sentinel: CharacterBody3D = SentinelScene.instantiate()
	sentinel.name = "Sentinel"
	sentinel.position = Vector3(0, 0.05, -5)
	world.add_child(sentinel)
	await frames(2)
	check(sentinel._charging and sentinel._warning.visible, "sentinel telegraphs before shooting")
	check(player.hp == player.max_hp, "sentinel warning causes no damage")
	var remaining: float = sentinel._shot_remaining
	world.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(5)
	check(is_equal_approx(remaining, sentinel._shot_remaining), "paused telegraph timer stays frozen")
	world.process_mode = Node.PROCESS_MODE_INHERIT
	sentinel.take_damage(1)
	await frames(2)
	check(not sentinel._charging, "sentinel damage interrupts charge")
	await frames(110)
	check(player.hp < player.max_hp, "sentinel ranged projectile damages player")
	sentinel.take_damage(99)
	await frames(2)
	check(get_nodes_in_group("enemy_projectiles").is_empty(), "sentinel death cancels live projectiles")
	sentinel.queue_free()
	player.hp = player.max_hp
	player._invulnerability_remaining = 0
	await frames()


func test_colossus() -> void:
	var boss: CharacterBody3D = ColossusScene.instantiate()
	boss.name = "RuinColossus"
	boss.position = Vector3(0, 0.05, -3)
	world.add_child(boss)
	boss.set_physics_process(false)
	await frames()
	check(boss.begin_attack(boss.Attack.SHOCKWAVE), "colossus shockwave begins")
	check(boss.state == boss.State.WINDUP and boss._disc.visible, "shockwave has visible warning")
	check(player.hp == player.max_hp, "shockwave has no early damage")
	check(not boss.begin_attack(boss.Attack.ENERGY), "cannot replace committed attack")
	boss._physics_process(boss.shock_windup + 0.01)
	check(player.hp == player.max_hp - 2, "shockwave damages once inside radius")
	check(boss.state == boss.State.RECOVER, "shockwave exposes recovery window")
	boss._physics_process(0.05)
	check(player.hp == player.max_hp - 2, "recovery does not repeat damage")
	check(boss.take_damage(2) and boss.hp == boss.max_hp - 2, "boss vulnerable during recovery")
	boss.state = boss.State.CHASE
	player.hp = player.max_hp
	player._invulnerability_remaining = 0
	var wall := make_wall(Vector3(0, 1, -1.5), Vector3(4, 2, 0.3))
	await frames()
	boss.begin_attack(boss.Attack.SHOCKWAVE)
	boss._physics_process(boss.shock_windup + 0.01)
	check(player.hp == player.max_hp, "shockwave cannot damage through wall")
	wall.queue_free()
	await frames()
	boss.state = boss.State.CHASE
	boss.begin_attack(boss.Attack.SHOCKWAVE)
	player.global_position = Vector3(10, 0.05, 0)
	await frames()
	boss._physics_process(boss.shock_windup + 0.01)
	check(player.hp == player.max_hp, "escaping warning avoids shockwave")
	player.global_position = Vector3(0, 0.05, 0)
	await frames()
	boss.state = boss.State.CHASE
	check(boss.begin_attack(boss.Attack.ENERGY), "energy attack begins")
	boss._physics_process(boss.energy_windup + 0.01)
	var bolts := get_nodes_in_group("enemy_projectiles")
	check(bolts.size() == 3, "energy attack emits three projectiles")
	for bolt in bolts:
		check(bolt.collision_mask == 3 and not bolt.is_in_group("player_projectiles"), "hostile projectile faction mask")
		bolt.queue_free()
	await frames()
	boss.state = boss.State.CHASE
	check(boss.begin_attack(boss.Attack.COMBO), "combo begins")
	observed["combo"] = 0
	boss.attack_resolved.connect(func(kind: int, _index: int) -> void:
		if kind == boss.Attack.COMBO: observed["combo"] += 1)
	player._invulnerability_remaining = 0
	for i in range(3):
		boss._physics_process(boss.combo_windup + 0.01)
		player._invulnerability_remaining = 0
	check(observed.combo == 3 and boss.state == boss.State.RECOVER, "combo resolves three telegraphed strikes then recovery")
	check(player.hp == player.max_hp - 3, "combo strike damage applies per distinct hit")
	boss.state = boss.State.CHASE
	boss.begin_attack(boss.Attack.ENERGY)
	boss._physics_process(boss.energy_windup + 0.01)
	boss.state = boss.State.CHASE
	boss.begin_attack(boss.Attack.SHOCKWAVE)
	check(boss.take_damage(999), "boss death during warning")
	check(boss.is_dead() and not boss._warning.visible, "boss death cancels warning")
	check(not boss.take_damage(1), "boss death is idempotent")
	var coins: Array = get_nodes_in_group("coin_pickups").filter(func(item: Node) -> bool: return item.source_id.begins_with("boss:"))
	check(coins.size() == 1 and coins[0].amount == 80, "boss drops gold once")
	await frames(3)
	check(get_nodes_in_group("enemy_projectiles").is_empty(), "boss death cancels flying energy attacks")


func test_main_lifecycle() -> void:
	var main_scene := preload("res://Main.tscn")
	var main: Node3D = main_scene.instantiate()
	root.add_child(main)
	world = main
	player = main.get_node("DungeonTest/Player")
	inventory = player.get_node("ItemInventory")
	check(not inventory.add_gold(10), "start menu blocks gameplay transactions")
	main._on_run_started()
	check(inventory.add_gold(50), "starting run enables economy")
	inventory.add_item(2)
	inventory.try_use_guard()
	main.get_node("DungeonTest/RuinGatekeeper").take_damage(999)
	await frames(65)
	var dungeon := main.get_node("DungeonTest")
	check(dungeon.is_exit_open(), "original boss still unlocks exit")
	player.global_position = Vector3(30, 0.05, -45)
	await frames(5)
	check(main._run_state == main.RunState.VICTORY, "entering unlocked exit still wins")
	check(not inventory.try_purchase(0), "victory freezes economy")
	await cleanup()
	main = main_scene.instantiate()
	root.add_child(main)
	world = main
	player = main.get_node("DungeonTest/Player")
	inventory = player.get_node("ItemInventory")
	check(inventory.gold == 0 and not inventory.guard_active and not inventory.owns_firearm, "fresh main resets per-run economy")
	main._on_run_started()
	inventory.add_item(1)
	inventory.try_use_rune()
	player.take_damage(999)
	check(inventory.get_buff_remaining() == 0 and not inventory.guard_active, "death clears temporary effects")
	check(not inventory.add_item(0) and not inventory.try_purchase(0), "dead player cannot mutate inventory")
	await frames(160)
	check(main._run_state == main.RunState.DEAD, "original death animation reaches result screen")
	await cleanup()
