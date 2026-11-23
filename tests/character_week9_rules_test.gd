extends SceneTree
## Regression for docs/character-week9.md and the week9 change record.
const PLAYER = preload("res://scenes/player/Player.tscn")
const ENEMY = preload("res://scenes/enemies/MeleeEnemy.tscn")
var passed := 0
var failed := 0
var stage: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		print("FAIL: ", message)

func frames(count: int = 2) -> void:
	for i in count: await physics_frame

func player(id: String) -> CharacterBody3D:
	var actor := PLAYER.instantiate() as CharacterBody3D
	actor.character_id = id
	stage.add_child(actor)
	actor.set_physics_process(false)
	actor.get_node("CharacterAbility").set_physics_process(false)
	actor.get_node("EnergyShock").set_physics_process(false)
	actor.get_node("MeleeAttack").set_physics_process(false)
	return actor

func victim(actor: CharacterBody3D, room: String, summoned: bool = false) -> CharacterBody3D:
	var enemy := ENEMY.instantiate() as CharacterBody3D
	stage.add_child(enemy)
	enemy.position = actor.position + Vector3(0, 0, -1.5)
	enemy.set_physics_process(false)
	enemy.get_node("MeleeAttack").attack_enabled = false
	enemy.set_meta("combat_room_key", room)
	enemy.set_meta("is_summoned", summoned)
	return enemy

func kill_with_j(actor: CharacterBody3D, enemy: CharacterBody3D) -> void:
	enemy.hp = 1
	var attack := actor.get_node("MeleeAttack")
	attack._cooldown_remaining = 0.0
	check(attack.try_attack(), "J starts for killing blow")
	attack._physics_process(0.21)
	attack.cancel_attack()

func run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	for id in ["knight", "lan", "iron", "astra"]:
		var caster := player(id)
		var attack := caster.get_node("EnergyShock")
		check(caster.get_spell_cost() == 5.0, id + " K costs five energy")
		caster.energy = 4.99
		check(not attack.try_cast() and caster.energy == 4.99 and attack.get_cooldown_remaining() == 0.0, id + " below five rejects without spending or cooldown")
		caster.energy = 5.0
		check(attack.try_cast() and caster.energy == 0.0, id + " exactly five casts and spends five")
		caster.energy = 5.0
		check(not attack.try_cast() and caster.energy == 5.0, id + " cooldown retry cannot spend twice")
		attack._cooldown_remaining = 0.0
		caster.energy = 5.5
		check(attack.try_cast() and caster.energy == 0.5, id + " casting preserves fractional energy")
		caster.free()
	var knight := player("knight")
	var ability := knight.get_node("CharacterAbility")
	var spell := knight.get_node("EnergyShock")
	var melee := knight.get_node("MeleeAttack")
	check(knight.hp == 5 and knight.shield == 2 and knight.energy == 50.0, "Knight resources")
	check(not ability.try_activate() and ability.cooldown_remaining == 0.0, "full energy supply rejected without cooldown")
	knight.energy = 43.5
	check(melee.try_attack(), "Knight J starts")
	check(ability.try_activate() and knight.energy == 50.0, "supply clamps to cap")
	check(melee.is_attacking(), "supply preserves J action")
	check(ability.cooldown_remaining == 12.0, "supply starts 12 second cooldown")
	check(not ability.try_activate(), "supply cannot repeat during cooldown")
	melee.cancel_attack()
	knight.energy = 25.0
	check(spell.try_cast(), "Knight spell succeeds")
	ability.cooldown_remaining = 0.0
	var spell_cd: float = spell.get_cooldown_remaining()
	check(ability.try_activate() and spell.get_cooldown_remaining() == spell_cd and spell.is_action_locked(), "supply preserves K cooldown and lock")
	check(knight.energy == 30.0, "supply restores exactly 10 after five-energy K")
	knight.energy = 10.0
	knight._physics_process(0.5)
	check(knight.energy == 10.0, "idle time does not regenerate energy")
	knight._physics_process(1.0)
	check(knight.energy == 10.0, "energy stays spent after a longer idle interval")
	knight.shield = 1
	knight.hp = 3
	knight.heal(99)
	check(knight.hp == 5 and knight.shield == 1 and knight.energy == 10.0, "healing changes health only")
	knight.queue_free()
	await frames()

	var lan := player("lan")
	ability = lan.get_node("CharacterAbility")
	spell = lan.get_node("EnergyShock")
	melee = lan.get_node("MeleeAttack")
	check(lan.walk_speed == 5.2 and lan.move_speed == 8.5, "Lan movement stats")
	ability._physics_process(1.49)
	check(ability.prepared_remaining == 0.0, "preparation not early")
	check(melee.try_attack(), "J resets preparation")
	melee.cancel_attack()
	ability._physics_process(0.02)
	check(ability.prepared_remaining == 0.0, "J interrupts unfinished preparation")
	ability._physics_process(1.48)
	check(ability.prepared_remaining == 5.0, "idle unlocks one prepared shot")
	melee._cooldown_remaining = 0.0
	check(melee.try_attack() and ability.prepared_remaining == 5.0, "J preserves prepared shot")
	melee.cancel_attack()
	lan.energy = 0.0
	check(not spell.try_cast() and ability.prepared_remaining == 5.0, "failed K retains preparation")
	lan.energy = 50.0
	var shots: Array = []
	spell.released.connect(func(bolt: Node3D) -> void: shots.append(bolt))
	check(spell.try_cast(), "prepared K fires")
	check(shots[0]._damage == 3 and lan.energy == 45.0 and ability.prepared_remaining == 0.0, "prepared K damage and five-energy cost; consumed on release")
	var cd: float = spell.get_cooldown_remaining()
	check(ability.try_activate() and spell.get_cooldown_remaining() == cd, "focus does not reset current cooldown")
	check(is_equal_approx(spell.get_cooldown_duration(), 0.8 / 1.3), "focus spell interval")
	check(not ability.try_activate(), "focus cannot refresh itself")
	ability._on_dodge()
	check(ability.remaining == 4.0, "dodge preserves focus")
	ability._physics_process(4.0)
	check(ability.cooldown_remaining == 10.0, "focus cooldown starts on end")
	check(ability.prepared_remaining == 0.0, "preparation minimum six second interval")
	ability._physics_process(2.0)
	check(ability.prepared_remaining == 5.0, "preparation returns after six seconds")
	ability._physics_process(5.0)
	check(ability.prepared_remaining == 0.0, "preparation expires after five seconds")
	lan.queue_free()
	await frames()

	var iron := player("iron")
	ability = iron.get_node("CharacterAbility")
	check(ability.try_activate(), "Iron guard starts")
	ability._physics_process(0.5)
	check(ability.block_direct_hit(iron.position + Vector3.FORWARD, "attack1") and ability.precise, "precise guard includes first 0.6 seconds")
	ability.block_direct_hit(iron.position + Vector3.FORWARD, "attack1")
	check(ability.blocked_hits == 1, "same attack counted once")
	check(not ability.block_direct_hit(iron.position + Vector3.BACK, "back"), "rear cannot block")
	check(iron.shield == 2, "blocking does not spend shield")
	ability._finish_guard(true)
	check(ability.cooldown_remaining == 8.0, "counter cooldown eight seconds")
	ability.cooldown_remaining = 0.0
	ability.try_activate()
	ability._physics_process(0.61)
	ability.block_direct_hit(iron.position + Vector3.FORWARD, "late")
	check(not ability.precise, "late block not precise")
	ability._on_dodge()
	check(not ability.is_guarding() and ability.cooldown_remaining == 8.0, "dodge cancels guard with cooldown")
	var enemy := victim(iron, "room1")
	await frames()
	kill_with_j(iron, enemy)
	check(iron.shield == 2 and ability._shield_restored.is_empty(), "full shield kill spends no room allowance")
	enemy.queue_free()
	await frames()
	for i in 3:
		iron.shield = 0
		enemy = victim(iron, "room1")
		await frames()
		kill_with_j(iron, enemy)
		check(iron.shield == (1 if i < 2 else 0), "room restores at most two actual shield points")
		enemy.queue_free()
		await frames()
	enemy = victim(iron, "room2", true)
	await frames()
	kill_with_j(iron, enemy)
	check(iron.shield == 0, "summoned unit gives no shield")
	enemy.queue_free()
	await frames()
	enemy = victim(iron, "room2")
	await frames()
	kill_with_j(iron, enemy)
	check(iron.shield == 1, "different room has separate allowance")
	ability._on_melee_hit(enemy, 1)
	check(iron.shield == 1, "same killing blow cannot restore twice")
	enemy.queue_free()
	iron.queue_free()
	await frames()

	var astra := player("astra")
	ability = astra.get_node("CharacterAbility")
	check(astra.hp == 4 and astra.shield == 1 and astra.max_energy == 60.0 and astra.get_spell_cost() == 5.0, "Astra resources and uniform five-energy K")
	astra.energy = 20.0
	ability.complete_combat_room("boss_room")
	check(astra.energy == 25.0, "clear reward explicitly restores five energy")
	ability.complete_combat_room("boss_room")
	check(astra.energy == 25.0, "room reward cannot repeat")
	astra.energy = 60.0
	ability.complete_combat_room("full_room")
	astra.energy = 20.0
	ability.complete_combat_room("full_room")
	check(astra.energy == 20.0, "full energy clear reward is not stored")
	check(ability.try_activate() and not astra.get_node("EnergyShock").try_cast(), "Astra windup blocks K")
	ability._on_dodge()
	check(ability.remaining == 0.0 and ability.cooldown_remaining == 1.0 and get_nodes_in_group("gravity_fields").is_empty(), "cancelled windup creates no field")
	ability._physics_process(1.0)
	check(ability.try_activate(), "Astra can recast after short cancel cooldown")
	ability._physics_process(0.25)
	check(ability.cooldown_remaining == 14.0 and get_nodes_in_group("gravity_fields").size() == 1, "successful field starts fourteen second cooldown")
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	var field := get_nodes_in_group("gravity_fields")[0]
	var time: float = field.elapsed
	await frames(5)
	check(field.elapsed == time and ability.cooldown_remaining == 14.0, "dungeon freeze stops field and cooldown")
	stage.process_mode = Node.PROCESS_MODE_INHERIT
	astra.take_damage(99)
	await frames()
	check(get_nodes_in_group("gravity_fields").is_empty() and ability.remaining == 0.0, "death removes fields and active skill")
	astra.queue_free()
	await frames()
	astra = player("astra")
	ability = astra.get_node("CharacterAbility")
	var normal := victim(astra, "control_room")
	var elite := victim(astra, "control_room")
	normal.position = Vector3(1.5, 0, 0)
	elite.position = Vector3(-1.5, 0, 0)
	elite.set_meta("is_elite", true)
	var control_field := Node3D.new()
	control_field.set_script(preload("res://scenes/skills/gravity_field.gd"))
	control_field.source = astra
	stage.add_child(control_field)
	control_field.set_physics_process(false)
	await frames()
	control_field._physics_process(0.1)
	check(is_equal_approx(normal.position.x, 1.44), "normal pull speed is 0.6 metres per second")
	check(is_equal_approx(elite.position.x, -1.47), "elite pull speed is 0.3 metres per second")
	check(normal._slow_remaining > 0.0 and elite._slow_remaining > 0.0, "normal and elite both receive slow")
	control_field.queue_free()
	normal.queue_free()
	elite.queue_free()
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 2, 1)
	collider.shape = box
	wall.add_child(collider)
	stage.add_child(wall)
	wall.position = Vector3(0, 0.5, 0)
	await frames()
	check(ability.try_activate(), "invalid placement still allows initial windup")
	ability._physics_process(0.25)
	check(ability.cooldown_remaining == 1.0 and get_nodes_in_group("gravity_fields").is_empty(), "no legal field position gives only one second cooldown")
	stage.queue_free()
	await frames()
	await room_events()
	print("CHARACTER_WEEK9_RESULT passed=%d failed=%d" % [passed, failed])
	quit(1 if failed else 0)

func room_events() -> void:
	var map := preload("res://scenes/dungeon/DungeonTest.tscn").instantiate()
	map.get_node("Player").character_id = "astra"
	root.add_child(map)
	await frames()
	var actor := map.get_node("Player")
	actor.set_physics_process(false)
	actor.energy = 20.0
	map.begin_run()
	check(actor.energy == 20.0, "arrival room gives no clear energy")
	var progress := map.get_node("RoomProgress")
	progress.activate_room(&"l1_crossroads")
	map.get_node("MeleeEnemy").process_mode = Node.PROCESS_MODE_INHERIT
	map.get_node("MeleeEnemy").take_damage(99)
	check(actor.energy == 25.0, "formal combat clear grants five energy")
	progress.activate_room(&"l1_crossroads")
	check(actor.energy == 25.0, "reentering cleared room grants nothing")
	progress.activate_room(&"l1_boss")
	map.get_node("RuinGatekeeper").process_mode = Node.PROCESS_MODE_INHERIT
	map.get_node("RuinGatekeeper").take_damage(99)
	check(actor.energy == 30.0, "formal boss clear grants five energy")
	map.queue_free()
	await frames()
