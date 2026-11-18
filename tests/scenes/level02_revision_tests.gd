extends SceneTree
const Profile = preload("res://scripts/integration/player_profile.gd")
const Campaign = preload("res://scripts/integration/campaign_progress.gd")
const Shot = preload("res://scenes/skills/creature_projectile.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)
func frames(count := 3) -> void:
	for i in count: await physics_frame
	await process_frame
func host() -> Node:
	var n: Node = load("res://scenes/dungeon/Level02Run.tscn").instantiate()
	root.add_child(n)
	await frames()
	return n
func run() -> void:
	Profile.override_path = "res://.godot/revision_profile.cfg"
	Campaign.override_path = "res://.godot/revision_campaign.cfg"
	Profile.ensure_loaded()
	Profile.coins = 100
	Profile.settled_runs = []
	check(Profile.save(), "isolated test wallet saved")
	var h: Node = await host()
	var world: Node = h.get_node("DungeonTest")
	var player: CharacterBody3D = world.player
	var items: Node = player.get_node("ItemInventory")
	check(items.gold == 0 and Profile.coins == 100, "new run separates wallet and pending")
	h._on_run_started()
	check(items.add_gold(40), "pending coins collectible")
	check(Profile.coins == 100, "pickup never saves pending wallet")
	check(items.try_purchase(0) and items.gold == 30 and Profile.coins == 100, "shop cannot mutate permanent wallet")
	check(world.get_node("Enemies/Hub1").attack_kind == 0 and world.get_node("Enemies/Hub2").attack_kind == 0, "room one uses silk only")
	check(world.get_node("Enemies/Relay1").attack_kind == 1 and world.get_node("Enemies/Relay2").attack_kind == 1, "room two uses brood mothers")
	check(world.get_node("Enemies/Antechamber1").attack_kind == 0 and world.get_node("Enemies/Antechamber2").attack_kind == 1, "room three mixes both")
	# Abandon and reload leaves permanent balance untouched.
	h.queue_free()
	await frames()
	h = await host()
	world = h.get_node("DungeonTest")
	player = world.player
	items = player.get_node("ItemInventory")
	check(items.gold == 0 and Profile.coins == 100, "abandoned run loses pending coins")
	h._on_run_started()
	items.add_gold(23)
	player.take_damage(999)
	check(Profile.coins == 100 and h._run_state == h.RunState.DYING, "death cannot bank coins")
	h.queue_free()
	await frames()
	check(Profile.settle_run("unique-win", 23) and Profile.coins == 123, "success banks once")
	check(Profile.settle_run("unique-win", 23) and Profile.coins == 123, "duplicate success ignored")
	Profile._loaded_path = ""
	Profile.ensure_loaded()
	check(Profile.settle_run("unique-win", 23) and Profile.coins == 123, "settlement dedup survives profile reload")
	var old := Profile._loaded_path
	Profile._loaded_path = "res://missing_directory/no/profile.cfg"
	# ensure_loaded resolves override first, so point override to bad path too.
	Profile.override_path = Profile._loaded_path
	check(not Profile.settle_run("failed-win", 8) and Profile.coins == 123 and "failed-win" not in Profile.settled_runs, "save failure rolls back balance and idempotence marker")
	Profile.override_path = old
	Profile._loaded_path = old
	h = await host()
	h._on_run_started()
	world = h.get_node("DungeonTest")
	player = world.player
	player.set_physics_process(false)
	player.global_position = Vector3(0, 0.05, -28)
	await frames(5)
	for enemy in world.get_node("Enemies").get_children(): enemy.set_physics_process(false)
	var spider: Node = world.get_node("Enemies/Hub1")
	spider.set_physics_process(false)
	spider.global_position = Vector3(0, 0.05, -32)
	spider._aggro = true
	check(not spider.get_node("MeleeAttack").attack_enabled, "legacy melee disabled")
	await frames()
	check(spider.get_node("HealthLabel").visible, "engaged living spider bar appears")
	check(spider.get_node("HealthLabel")._bar.get_hp_text() == "HP %d/%d" % [spider.hp, spider.max_hp], "overhead HP uses real values instead of percentage")
	spider.get_node("HealthLabel").update_hp(2, spider.max_hp)
	check(spider.get_node("HealthLabel")._bar.get_hp_text() == "HP 2/%d" % spider.max_hp, "overhead HP updates after damage")
	spider.get_node("HealthLabel").update_hp(spider.hp, spider.max_hp)
	var before := world.get_tree().get_nodes_in_group("creature_hazards").size()
	spider._cooldown = 0
	spider._update_pursuit(1.0 / 60.0)
	check(world.get_tree().get_nodes_in_group("creature_hazards").size() == before + 1 and not spider._charging and not spider._warning.visible, "silk fires on first reaction tick without aim or warning")
	check(spider._cooldown < 1.0 and spider.move_speed >= 3.4 and spider.max_hp >= 4, "silk hunter has faster cadence, pursuit and higher health")
	var shot_count := world.get_tree().get_nodes_in_group("creature_hazards").size()
	spider._update_pursuit(1.0 / 60.0)
	check(world.get_tree().get_nodes_in_group("creature_hazards").size() == shot_count, "instant shot still respects recovery and cannot fire every frame")
	for hazard in world.get_tree().get_nodes_in_group("creature_hazards"):
		if world.is_ancestor_of(hazard): hazard.queue_free()
	await frames(2)
	player.shield = 0 # Isolate HP damage from the approved starting shield.
	var hp: int = player.hp
	var silk := Shot.new()
	world.add_child(silk)
	silk.global_position = player.global_position + Vector3(0, 0.85, -1.6)
	silk.setup(spider, player, Vector3.BACK, 0)
	check(silk._speed == 22.0, "single silk travels at increased speed")
	check(is_instance_valid(silk._silk) and silk._visual.get_child_count() == 0, "silk is one continuous strand with no energy-ball visual")
	await frames(20)
	check(player.hp < hp and player.web_remaining > 0, "real swept silk collision deals damage and applies web")
	check(player._web_visual.get_child_count() >= 40, "player wrap contains radial webs and encircling silk rings")
	player._invulnerability_remaining = 0
	player._dodge_invulnerability_remaining = 1
	var evaded := Shot.new()
	world.add_child(evaded)
	evaded.global_position = player.global_position + Vector3(0, 0.85, -1.0)
	evaded.setup(spider, player, Vector3.BACK, 0)
	hp = player.hp
	var web: float = player.web_remaining
	await frames(15)
	check(player.hp == hp and player.web_remaining <= web, "dodge blocks silk damage and web refresh")
	player._dodge_invulnerability_remaining = 0
	player._invulnerability_remaining = 0
	var baby := Shot.new()
	world.add_child(baby)
	baby.global_position = player.global_position + Vector3(0, 0.22, -1)
	baby.setup(spider, player, Vector3.BACK, 1)
	await frames(80)
	check(is_instance_valid(baby) and baby._attached, "broodling crawls onto player on physical contact")
	player._dodge_remaining = 0.2
	await frames(2)
	check(not is_instance_valid(baby), "roll removes attached broodling")
	player._dodge_remaining = 0
	spider.attack_kind = 1
	spider._release()
	var emerging = spider._offspring[0].get_ref()
	check(emerging._visual.position.y < 0 and emerging.collision_mask == 0 and emerging.collision_layer == 0, "broodlings begin underground before emerging into collision")
	check(spider._offspring.size() == 32, "mother summons thirty-two underground broodlings")
	spider._release()
	check(spider._offspring.size() == 64, "two waves accumulate sixty-four broodlings")
	spider._release()
	check(spider._offspring.size() == 64, "dense swarm has a bounded sixty-four-spider limit")
	var children: Array = spider._offspring.duplicate()
	spider.take_damage(999)
	await frames(2)
	check(not is_instance_valid(spider) or not spider.get_node("HealthLabel").visible, "dead spider bar disappears")
	check(children.all(func(w: WeakRef) -> bool: return not is_instance_valid(w.get_ref())), "mother death removes every summoned broodling")
	var boss: Node = world.boss
	boss.process_mode = Node.PROCESS_MODE_PAUSABLE
	boss.set_physics_process(false)
	player.hp = player.max_hp
	player.shield = 0
	player.global_position = boss.global_position + Vector3(0, 0, -3)
	player._invulnerability_remaining = 0
	hp = player.hp
	check(boss.begin_attack(boss.Attack.SHOCKWAVE), "scorpion accepts tail sweep")
	await frames(3)
	check(player.hp == hp, "tail windup causes no damage")
	boss._remaining = 0
	boss._physics_process(0.02)
	check(boss.state == boss.State.STRIKE, "windup enters explicit animated strike")
	for i in range(22): boss._tick_tail_strike(0.02)
	check(hp - player.hp == 3, "boss sweep deals three actual damage versus spiders one")
	var bar: Node = h.get_node("UILayer/BossHealthBar")
	check(bar.hp_label.text == "HP %d/%d" % [boss.hp, boss.max_hp], "boss HP readout is numeric above bar")
	check(boss.max_hp == 54 and boss.recovery_duration < 1 and boss.move_speed >= 3, "boss has stronger endurance, shorter recovery and faster pursuit")
	boss.state = boss.State.CHASE
	check(boss.begin_attack(boss.Attack.ENERGY), "boss accepts strengthened venom volley")
	boss._remaining = 0
	boss._physics_process(0.02)
	boss._tick_tail_strike(0.23)
	var venom: Array = []
	for hazard in world.get_tree().get_nodes_in_group("creature_hazards"):
		if hazard is Shot and hazard.kind == 2: venom.append(hazard)
	check(venom.size() == 5 and venom.all(func(n: Node) -> bool: return n.hit_damage == 2 and n._speed == 20), "five venom stingers inherit boss damage and projectile speed")
	player.hp = player.max_hp
	player._invulnerability_remaining = 0
	var center: Node = venom[2]
	player.global_position = center.global_position + center._direction * 1.8 - Vector3.UP * 0.8
	await frames(9)
	check(player.hp == player.max_hp - 2, "boss venom swept collision applies two real damage")
	for shot in venom:
		if is_instance_valid(shot): shot.queue_free()
	await frames(2)
	boss.state = boss.State.CHASE
	player.global_position = boss.global_position + Vector3(0, 0, -2)
	player.hp = player.max_hp
	player._invulnerability_remaining = 0
	boss.begin_attack(boss.Attack.COMBO)
	boss._remaining = 0
	boss._physics_process(0.02)
	boss._tick_tail_strike(0.23)
	check(player.hp == player.max_hp - 2, "boss tail needle deals two actual damage per strike")
	boss.take_damage(999)
	await frames()
	check(not h.get_node("UILayer/BossHealthBar").visible, "boss death hides HUD immediately")
	h.queue_free()
	await frames()
	print("REVISION_RESULT checks=%d failed=%d" % [checks, failures])
	quit(1 if failures else 0)



