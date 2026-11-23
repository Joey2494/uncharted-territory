extends SceneTree
## Verify Ziyuan actors in Hongwei's real map, including Yu's character contracts.
const LEVEL = preload("res://scenes/dungeon/level04/Level04Campaign.tscn")
const FIELD = preload("res://scenes/skills/gravity_field.gd")
var checks := 0
var failures := 0
var level: Node3D
var combat: Node3D
var player: CharacterBody3D
func _initialize() -> void: run.call_deferred()
func frames(n := 3) -> void:
	for i in n: await physics_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)
func enter(room: String, at: Vector2) -> void:
	player.global_position = level.layout.room_center(room)+Vector3(at.x,0.06,at.y)
	combat.update_room(room,0.016)
func ids() -> Array:
	return combat._enemies.map(func(e): return e.enemy_id)
func clear(room: String) -> void:
	for tick in 8:
		for enemy in combat._enemies.duplicate(): enemy.take_damage(999)
		combat.update_room(room,6.1)
		await frames(12) # Shared flock damage protection lasts 0.15 real seconds.
	check(combat.is_clear(room),room+" clears after its whole roster and reinforcements")
func verify_spawns() -> void:
	for enemy in combat._enemies:
		var shapes: Array[Node] = enemy.find_children("*","CollisionShape3D",false,false)
		check(not shapes.is_empty(),"actual actor has a collision shape")
		if shapes.is_empty(): continue
		var body_shape: CollisionShape3D = shapes[0]
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = body_shape.shape
		query.transform = body_shape.global_transform
		query.collision_mask = 1
		check(enemy.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),enemy.enemy_id+" starts outside actual walls and equipment")
		check(enemy.get_script().resource_path.begins_with("res://addons/ziyuan_level04/") or enemy.get_script().resource_path.ends_with("observatory_witch.gd"),"uses Ziyuan level4 actor")
func run() -> void:
	level = LEVEL.instantiate()
	root.add_child(level)
	await frames()
	combat = level.combat
	player = level.player
	level.set_physics_process(false)
	player._invulnerability_remaining = 1000.0
	var boxes := get_nodes_in_group("breakable_cover")
	check(boxes.size() == 3,"original practice and B cover crates are retained")
	var box: StaticBody3D = boxes[0]
	player.global_position = box.global_position+Vector3(0,0.06,1.61)
	player.visuals.rotation.y = 0.0
	await frames()
	check(player.get_node("MeleeAttack").try_attack(),"exclusive short sword can attack map cover")
	await frames(35)
	check(box.hits_left == 2,"sword reaches crate face despite world-obstruction layer")
	var weapons = player.get_node("WeaponLoadout")
	check(weapons.try_switch(),"I equips the exclusive rune wand")
	await frames(14)
	check(weapons.try_attack(),"J fires the equipped rune wand")
	await frames(25)
	check(box.hits_left == 1,"exclusive staff projectile damages map cover")
	check(box.take_damage(999) and box.collision_layer == 0 and not box.visible,"final crate hit removes visual and physical cover together")
	check(combat.prepared_dome_boss.enemy_id == "witch" and not combat.prepared_dome_boss.visible and not combat.prepared_dome_boss.is_encounter_active(),"actual witch sleeps before entry")
	enter("B",Vector2(-3.8,3.3))
	check(ids() == ["dawn_shade","dawn_shade"],"B contains two dawn shades")
	verify_spawns()
	var shade = combat._enemies[0]
	var shade_receipt: String = shade.reward_source_id
	shade.global_position = level.layout.room_center("B")+Vector3(-6,0.06,-2)
	player.global_position = shade.global_position+Vector3(0,0,2)
	await frames()
	shade.take_damage(1)
	check(combat.enemy_count() == 2,"decoys never count towards sealed doors")
	var echoes := get_nodes_in_group("l4_enemies").filter(func(e): return e.has_method("is_decoy") and e.is_decoy())
	check(echoes.size() == 2,"nonlethal real shade damage creates two decoys")
	for echo in echoes:
		check(not echo.has_meta("combat_room_key"),"decoy cannot farm Iron shield passive")
	combat._status_requested(player,"dawn_blind",0.85,0.48)
	check(combat._blind.visible and combat._blind.color.a <= 0.48,"bounded world blind effect exists below HUD")
	paused = true
	combat.update_room("B",1.0)
	check(is_equal_approx(combat._blind_left,0.85),"pause freezes blind duration")
	paused = false
	combat.update_room("B",0.9)
	check(not combat._blind.visible,"blind expires without hiding controls")
	player.character_id = "astra"
	player.energy = 10.0
	await clear("B")
	check(is_equal_approx(player.energy,15.0),"Astra restores exactly five energy on formal room clear")
	combat.update_room("B",1.0)
	check(is_equal_approx(player.energy,15.0),"revisit cannot repeat Astra reward")
	check(level.inventory.gold == 44,"two real shade rewards plus one map supply reward; no decoy reward")
	var gold: int = level.inventory.gold
	combat._grant_enemy_reward(shade_receipt,16)
	check(level.inventory.gold == gold,"enemy reward receipt rejects duplicates")
	enter("D",Vector2(3.2,0))
	check(ids() == ["sun_puppet","sun_puppet"],"optional D contains two sun puppets")
	verify_spawns()
	player.character_id = "iron"
	player.shield = 0
	var puppet = combat._enemies[0]
	puppet.global_position = player.global_position+Vector3(0,0,-1)
	puppet.take_damage(999)
	player.get_node("CharacterAbility")._on_melee_hit(puppet,1)
	check(player.shield == 1,"Iron kill passive recognizes new formal enemy room")
	await clear("D")
	check(combat.set_cage(1),"cleared optional D still controls physical F cage")
	enter("F",Vector2(-3,3.9))
	check(ids() == ["iron_thistle","iron_thistle"],"F contains two rooted thistles")
	verify_spawns()
	await clear("F")
	combat.demo_done = true
	enter("H",Vector2(-3,0))
	check(ids() == ["raven_roost"],"H has one shared-life flock")
	verify_spawns()
	var flock = combat._enemies[0]
	flock.global_position = level.layout.room_center("H")+Vector3(0,0.05,4)
	player.global_position = flock.global_position+Vector3(0,0,1)
	await frames()
	var targets := FIELD.targets_in_radius(player,flock.global_position,4.0)
	check(targets.count(flock) == 1,"gravity resolves seven bird bodies to one enemy")
	for bird in flock._bird_boxes: check(bird.get_combat_actor() == flock,"bird hit forwards to shared combat actor")
	player.global_position = level.layout.room_center("H")+Vector3(-5,0.06,0)
	flock.global_position = player.global_position+Vector3(0,0,-0.5)
	flock._shared_hit_cd = 0.0
	player._invulnerability_remaining = 0.0
	var vitals: int = player.hp+player.shield
	var flock_hp: int = flock.hp
	combat._sweeps.H.begin(-1,false)
	combat.update_room("H",5.3)
	check(player.hp+player.shield == vitals-1 and flock.hp == flock_hp-2,"same shutter band affects player and new enemy at actual positions")
	player._invulnerability_remaining = 1000.0
	await clear("H")
	enter("I",Vector2(3,4))
	check(ids() == ["witch","iron_thistle"],"I uses witch plus actual thistle guard")
	verify_spawns()
	var witch = combat.boss_guard()
	check(witch == level.get_campaign_boss() and witch.is_in_group("bosses"),"shared boss HUD and skill immunity use the same witch")
	check(witch.begin_attack(witch.Move.GUARD),"witch casts native spore-guard skill")
	await frames()
	check(combat._minions.size() == 2 and witch._living_minions() == 2,"summoned guards registered with native witch lifecycle")
	for minion in combat._minions:
		check(minion.get_meta("is_summoned",false) and not minion.has_meta("combat_room_key"),"summon excluded from Iron passive and door roster")
	witch.hp = ceili(witch.max_hp*0.5)
	combat.update_room("I",0.016)
	check(combat.half_announced and witch.advancing and not combat._sweeps.I.active,"map half-health reposition pauses actual shutter")
	witch.global_position = witch.advance_goal
	witch._physics_process(0.016)
	combat.update_room("I",0.016)
	check(not witch.advancing and combat._sweeps.I.active,"reaching lever side resumes shutter")
	witch.take_damage(999)
	check(combat._minions.is_empty() and not level.is_completion_ready(),"witch death cleans summons while required thistle holds gate")
	await clear("I")
	await frames(90) # Physical doors finish lifting after clear authorization.
	check(level.is_completion_ready(),"complete roster grants map completion authorization")
	check(level.layout.passage_open("I","J"),"all formal enemies release actual map exit")
	combat._status_requested(player,"dawn_blind",0.85,0.48)
	combat._queue_minion("spore_guard",player.global_position)
	combat.stop()
	await frames()
	check(not combat._blind.visible and combat._minions.is_empty(),"stop invalidates deferred spawns and clears blindness")
	level.queue_free()
	await frames()
	root.get_node("MusicManager").stop_music()
	print("LEVEL04_ENEMY_INTEGRATION_RESULT checks=%d failed=%d" % [checks,failures])
	quit(1 if failures else 0)
