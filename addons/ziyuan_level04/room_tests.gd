extends SceneTree
const Factory = preload("factory.gd")
const Catalog = preload("room_catalog.gd")
var passed := 0
var failed := 0
var lab: Node
var player: Node
func _initialize() -> void: run.call_deferred()
func frames(n := 3) -> void:
	for i in n: await physics_frame
	await process_frame
func check(ok: bool, message: String) -> void:
	passed += int(ok)
	failed += int(not ok)
	print("PASS " if ok else "FAIL ", message)
func fresh(id: String) -> Node:
	lab.encounter.clear_encounter()
	await frames()
	player.global_position = Vector3(-5, 0.05, 4)
	player.hp = 24
	player._invulnerability_remaining = 0
	player._dodge_invulnerability_remaining = 0
	player.clear_room_status()
	var actor := Factory.create(id, player)
	lab.arena.add_child(actor)
	actor.global_position = Vector3(-5, 0.05, -3)
	return actor
func hazards(source: Node) -> Array[Node]:
	var result: Array[Node] = []
	for node in get_nodes_in_group("l4_hazards"):
		if node.get("_source") != null and node._source.get_ref() == source: result.append(node)
	return result
func run() -> void:
	change_scene_to_file("res://addons/ziyuan_level04/FourRooms.tscn")
	for i in 8: await process_frame
	lab = current_scene
	player = lab.player
	player.set_physics_process(false)
	check(Catalog.ROOMS.size() == 4, "four room definitions exist")
	for id in ["dawn_shade", "sun_puppet", "iron_thistle", "raven_roost"]:
		var actor := await fresh(id)
		check(actor.is_required_enemy() and not actor.is_boss() and not actor.is_encounter_active(), id + " starts dormant and counts as normal enemy")
		check(not actor.take_damage(1) and not actor.bind_target(null), id + " rejects dormant damage and invalid target")
		actor.set_encounter_active(true)
		actor.set_physics_process(false)
		check(actor.has_signal("enemy_died") and actor.has_signal("reward_requested") and actor.has_signal("hp_changed"), id + " exposes integration signals")
		actor.set_encounter_active(false)
		actor.queue_free()
	await frames()
	var shade := await fresh("dawn_shade")
	shade.set_encounter_active(true)
	shade.set_physics_process(false)
	var reward: Array[int] = []
	var deaths: Array[Node] = []
	shade.reward_requested.connect(func(_id: String, coins: int): reward.append(coins))
	shade.enemy_died.connect(func(enemy: Node3D): deaths.append(enemy))
	check(shade.take_damage(1) and shade._echoes.size() == 2, "shade splits two decoys on nonlethal hit")
	check(shade.hp == 7, "split preserves real body damage")
	var echo: Node = shade._echoes[0].get_ref()
	check(echo.is_decoy() and not echo.is_required_enemy() and echo.definition.gold == 0, "decoy has no room or reward responsibility")
	check(shade._visual.get_child_count() == echo._visual.get_child_count(), "decoy uses the same visual structure")
	shade.take_damage(1)
	check(shade._echoes.size() == 2, "repeated hits cannot grow unbounded decoys")
	echo.take_damage(1)
	check(echo.is_dead() and reward.is_empty(), "one hit dissolves echo without reward")
	shade.global_position = Vector3(-5, 0.05, 1)
	shade.perform_attack()
	check(player.blind_remaining > 0 and player.blind_remaining <= 1.2, "morning blind applies bounded duration")
	player._physics_process(1.3)
	player.set_physics_process(false)
	check(player.blind_remaining == 0, "morning blind recovers naturally")
	shade.global_position = Vector3(0, 0.05, -3)
	player.global_position = Vector3(0, 0.05, 3)
	shade.perform_attack()
	check(player.blind_remaining == 0, "central solid pillar blocks morning blind")
	shade.take_damage(999)
	check(reward == [16] and deaths.size() == 1 and not shade.take_damage(999), "shade death and reward emit once")
	await frames(20)
	check(get_nodes_in_group("l4_enemies").filter(func(node): return node.get("enemy_id") == "dawn_echo").is_empty(), "real shade death cleans all surviving echoes")
	var puppet := await fresh("sun_puppet")
	puppet.set_encounter_active(true)
	puppet.set_physics_process(false)
	puppet.perform_attack()
	check(hazards(puppet).size() == 1 and hazards(puppet)[0].kind == "heat", "puppet directly emits a heat wave")
	var heat: Node = hazards(puppet)[0]
	heat.set_physics_process(false)
	player.global_position = Vector3(-5, 0.05, 0)
	player.hp = 24
	player._invulnerability_remaining = 0
	heat._physics_process(0.7)
	check(player.hp == 23, "heat wave crossing applies actual damage")
	player._invulnerability_remaining = 0
	heat._physics_process(0.05)
	check(player.hp == 23, "one wave cannot hit twice")
	puppet.global_position = Vector3(0, 0.05, -3)
	player.global_position = Vector3(0, 0.05, 3)
	puppet.perform_attack()
	var blocked_heat: Node = hazards(puppet).back()
	blocked_heat.set_physics_process(false)
	blocked_heat._physics_process(1.3)
	check(player.hp == 23, "central solid pillar blocks heat damage")
	puppet.set_encounter_active(false)
	await frames()
	check(hazards(puppet).is_empty(), "stop removes puppet owned hazards")
	puppet.queue_free()
	var thistle := await fresh("iron_thistle")
	thistle.set_encounter_active(true)
	thistle.set_physics_process(false)
	check(thistle.definition.speed == 0 and thistle.collision_mask == 3, "thistle is rooted and physically blocks player")
	thistle.perform_attack()
	check(hazards(thistle).size() == 7, "thistle directly fires seven solid needles")
	await frames(65)
	check(player.hp == 23, "solid needle actually collides with the shared player")
	thistle._clear_owned()
	await frames()
	thistle.perform_attack()
	check(hazards(thistle).size() == 6, "thistle alternates into six active thorn clumps")
	var thorn: Node = hazards(thistle)[0]
	thorn.set_physics_process(false)
	player.global_position = thorn.global_position
	player.hp = 24
	player._invulnerability_remaining = 0
	thorn._physics_process(0.2)
	check(player.hp == 23, "active thorn clump hurts on contact")
	thistle.take_damage(999)
	await frames()
	check(hazards(thistle).is_empty(), "thistle death removes owned needles and thorn clumps")
	var flock := await fresh("raven_roost")
	flock.set_encounter_active(true)
	flock.set_physics_process(false)
	check(flock._bird_boxes.size() == 7 and flock.collision_layer == 0, "flock has seven hittable birds and no invisible center hitbox")
	check(flock._bird_boxes[0].take_damage(1) and flock.hp == 11, "hitting one bird damages shared flock health")
	check(not flock._bird_boxes[1].take_damage(1) and flock.hp == 11, "same swing on multiple birds does not multiply damage")
	flock.perform_attack()
	check(flock._cycle == 1 and flock._dive_age == 0, "flock opens with scattered ambush")
	flock._update_flock(0.4)
	var spread: float = flock._visual.birds[0].global_position.distance_to(flock._visual.birds[3].global_position)
	flock.perform_attack()
	flock._update_flock(0.4)
	check(flock._cycle == 2 and flock._visual.birds[0].global_position.distance_to(flock._visual.birds[3].global_position) < spread, "second flock attack gathers birds tightly")
	player.hp = 24
	player._invulnerability_remaining = 0
	flock._update_flock(0.5)
	check(player.hp == 23, "gathered flock swept contact deals damage once through player protection")
	flock.take_damage(999) # 共享受击冷却仍开启，先通过物理计时推进。
	flock._shared_hit_cd = 0
	flock.take_damage(999)
	check(flock._bird_boxes.all(func(node): return node.is_dead()), "all bird proxies become dead with the shared actor")
	await frames(20)
	# 连续四房、单次清场、暂停和重试。
	for index in 4:
		lab.load_wave(index)
		await frames()
		check(lab.wave == index and lab.encounter.living_count() == Catalog.ROOMS[index].spawns.size(), "room %d loads configured actors" % (index + 1))
		var actor: Node = lab.encounter.actors[0]
		paused = true
		var clock: float = actor._clock
		await create_timer(0.06).timeout
		check(actor._clock == clock, "room %d pause freezes actors" % (index + 1))
		paused = false
		for enemy in lab.encounter.actors:
			enemy._shared_hit_cd = 0
			enemy.take_damage(999)
		await frames()
		check(lab._ended and lab.encounter.living_count() == 0, "room %d clears with only required actors" % (index + 1))
		if index < 3:
			lab._advance_room()
			check(lab.wave == index + 1, "cleared room advances on explicit action")
	lab.load_wave(0)
	await frames()
	check(not lab._ended and lab.encounter.living_count() == 2 and player.blind_remaining == 0, "retry restores room and clears blindness")
	player.set_physics_process(false)
	player.take_damage(999)
	await frames(40)
	lab.load_wave(3)
	for i in 8: await process_frame
	lab = current_scene
	player = lab.player
	check(not player.is_dead() and lab.wave == 3 and lab.encounter.living_count() == 1, "retry after player death reloads requested fourth room")
	lab.encounter.clear_encounter()
	await frames()
	var adapter := preload("room_encounter.gd").new()
	lab.arena.add_child(adapter)
	var spots: Array[Vector3] = [Vector3(50, 0.05, 40)]
	check(not adapter.spawn_at_positions(player, 4, "invalid", spots, Vector3.ZERO), "adapter rejects out of range room index")
	check(adapter.spawn_at_positions(player, 2, "translated:room3", spots, Vector3(50, 0, 40)), "ordinary room adapter accepts translated arena")
	var translated: Node = adapter.actors[0]
	check(translated.global_position == spots[0] and translated._clamp(Vector3(100, 0, 100)) == Vector3(61.5, 0.05, 49.5), "translated bounds and spawn positions stay in the room")
	adapter.clear_encounter()
	adapter.queue_free()
	await frames()
	print("LEVEL04_FOUR_ROOMS_TEST_RESULT passed=%d failed=%d" % [passed, failed])
	quit(1 if failed else 0)
