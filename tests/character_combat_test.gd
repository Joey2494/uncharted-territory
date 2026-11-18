extends SceneTree

const CATALOG = preload("res://scenes/player/character_catalog.gd")
var checks: int = 0
var failures: int = 0

class Dummy:
	extends CharacterBody3D
	var received: int = 0
	func take_damage(amount: int) -> bool:
		received += amount
		return true

class ControlledDummy:
	extends Dummy
	var control: float = 0.0
	var slow: float = 0.0
	func apply_control(duration: float) -> void:
		control = duration
	func apply_slow(duration: float) -> void:
		slow = duration

func dummy(parent: Node3D, offset: Vector3, controllable: bool) -> CharacterBody3D:
	var body: CharacterBody3D = ControlledDummy.new() if controllable else Dummy.new()
	body.collision_layer = 4
	body.collision_mask = 1
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.2
	collider.shape = shape
	collider.position.y = 0.8
	body.add_child(collider)
	parent.add_child(body)
	body.position = offset
	return body

func _initialize() -> void:
	var profile = preload("res://scripts/integration/player_profile.gd")
	profile.override_path = "res://.godot/fixture_character_combat_test.cfg"
	if FileAccess.file_exists(profile.override_path): DirAccess.remove_absolute(profile.override_path)
	profile.ensure_loaded()
	profile.set_coins(430)
	for character in ["lan", "iron", "astra"]: profile.unlock_character(character)

	run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ", description)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	preload("res://scripts/integration/campaign_progress.gd").override_path = "res://.godot/test_progress.cfg"
	var attack_event := InputEventKey.new()
	attack_event.physical_keycode = KEY_J
	check(attack_event.is_action("attack"), "J maps to attack")
	attack_event.physical_keycode = KEY_K
	check(attack_event.is_action("skill_1"), "K maps to spell")
	attack_event.physical_keycode = KEY_L
	check(attack_event.is_action("character_skill"), "L maps to unique ability")
	for id in ["lan", "iron", "astra"]:
		print("CHARACTER phase: ", id)
		CATALOG.selected_id = id
		preload("res://scripts/integration/player_profile.gd").set_selected_character(id)
		var main := load("res://Main.tscn").instantiate() as Node3D
		root.add_child(main)
		await frames(3)
		var player := main.get_node("DungeonTest/Player") as CharacterBody3D
		var skill := player.get_node("EnergyShock")
		var ability := player.get_node("CharacterAbility")
		var melee := player.get_node("MeleeAttack")
		check(player.character_id == id, id + " selection applied before initialization")
		check(player.hp == CATALOG.definition(id).hp, id + " full health")
		check(player.energy == CATALOG.definition(id).energy, id + " full energy")
		check(player.get_node_or_null("Visuals/Model/Knight/Rig_Medium/Skeleton3D") != null, id + " shared rig contract")
		check(not skill.try_cast(), id + " menu blocks spell")
		check(not ability.try_activate(), id + " menu blocks ability")
		main._on_run_started()
		await frames(4)
		check(main._run_state == main.RunState.PLAYING, id + " starts game")
		player.energy = 0.0
		check(not skill.try_cast(), id + " energy shortage rejects spell")
		check(skill.get_cooldown_remaining() == 0.0, id + " shortage has no cooldown")
		check(melee.try_attack(), id + " J works at zero energy")
		check(not skill.try_cast(), id + " K cannot erase J damage window")
		await frames(35)
		player.energy = player.max_energy
		var before: float = player.energy
		check(skill.try_cast(), id + " K casts")
		check(player.get_spell_cost() == 5.0 and is_equal_approx(before - player.energy, 5.0), id + " K consumes exactly five energy")
		check(not skill.try_cast(), id + " cooldown prevents double cast")
		check(not melee.try_attack(), id + " J respects cast release window")
		await frames(15)
		check(melee.try_attack(), id + " J resumes after cast")
		await frames(60)
		check(player.energy > before - player.get_spell_cost(), id + " energy recovers")
		check(ability.try_activate(), id + " unique ability activates")
		if id == "lan":
			check(ability.is_focused(), "Lan focus active")
			check(skill.get_cooldown_duration() < 0.8, "Lan faster spell")
			check(ability.cooldown_remaining == 0.0, "focus cooldown starts after effect")
		elif id == "iron":
			check(not melee.try_attack() and not skill.try_cast(), "guard locks attacks")
			var shield_before: int = player.shield
			check(not player.take_direct_damage(1, player.global_position + ability._guard_direction * 2.0), "front hit blocked")
			check(player.shield == shield_before and ability.precise, "precise block preserves shield")
			check(player.take_direct_damage(1, player.global_position - ability._guard_direction * 2.0), "back hit accepted")
			check(player.shield == shield_before - 1, "back hit consumes shield")
			ability._finish_guard(true)
			check(ability.cooldown_remaining == 8.0, "guard cooldown on counter")
		else:
			check(ability.is_casting(), "Astra windup")
			check(not skill.try_cast() and not melee.try_attack(), "Astra windup locks attacks")
			await frames(20)
			check(get_nodes_in_group("gravity_fields").size() == 1, "Astra creates independent field")
			check(player.get_spell_cost() == 5.0, "Astra shares the five-energy spell cost")
		var energy_before: float = player.energy
		var active_before: float = ability.remaining
		main.get_node("DungeonTest").process_mode = Node.PROCESS_MODE_DISABLED
		await frames(15)
		check(player.energy == energy_before and ability.remaining == active_before, id + " freeze stops resources and ability")
		main.get_node("DungeonTest").process_mode = Node.PROCESS_MODE_INHERIT
		await frames(200)
		if id == "astra":
			check(get_nodes_in_group("gravity_fields").is_empty(), "field expires")
		player._invulnerability_remaining = 0.0
		check(player.take_damage(100), id + " lethal damage accepted")
		check(player.is_dead(), id + " death state")
		check(not skill.try_cast() and not ability.try_activate(), id + " death blocks skills")
		await frames(70)
		check(main._run_state == main.RunState.DEAD, id + " death animation reaches result")
		main.free()
		await frames(2)
	print("CHARACTER phase: area")
	await verify_area_combat()
	print("CHARACTER phase: restart")
	await verify_selection_restart()
	print("CHARACTER COMBAT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func verify_area_combat() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	stage.position = Vector3(1000, 0, 1000)
	var player := load("res://scenes/player/PlayerAstra.tscn").instantiate() as CharacterBody3D
	stage.add_child(player)
	player.set_physics_process(false)
	var open_target := dummy(stage, Vector3(0, 0, -1.5), true)
	var wall_target := dummy(stage, Vector3(1.8, 0, 0), true)
	var boss_target := dummy(stage, Vector3(-1.5, 0, 0), false)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 2, 2)
	collider.shape = shape
	wall.add_child(collider)
	stage.add_child(wall)
	wall.position = Vector3(0.9, 1, 0)
	await frames(3)
	var field := Node3D.new()
	field.set_script(preload("res://scenes/skills/gravity_field.gd"))
	field.source = player
	stage.add_child(field)
	var boss_position := boss_target.global_position
	await frames(195)
	check(open_target.received == 5, "field applies exactly 3 ticks plus burst")
	check(open_target.position.z > -1.5, "field pulls ordinary enemy")
	check(open_target.slow == 0.1, "field applies slow")
	check(wall_target.received == 0, "field damage respects wall")
	check(is_equal_approx(wall_target.position.x, 1.8), "field pull respects wall")
	check(boss_target.received == 5, "boss receives field damage")
	check(boss_target.global_position == boss_position, "boss is not pulled")
	check(get_nodes_in_group("gravity_fields").is_empty(), "field cleans up after burst")
	var ability := player.get_node("CharacterAbility")
	check(ability.try_activate(), "Astra starts cancelable cast")
	ability._on_dodge()
	check(ability.remaining == 0.0 and ability.cooldown_remaining == 1.0, "Astra cancel receives short cooldown")
	await frames(20)
	check(get_nodes_in_group("gravity_fields").is_empty(), "canceled cast does not spawn field")
	player.character_id = "lan"
	ability.cooldown_remaining = 0.0
	check(ability.try_activate(), "Lan starts focus")
	ability._on_dodge()
	check(ability.is_focused(), "Lan dodge retains focus")
	ability.cancel()
	player.character_id = "iron"
	ability.cooldown_remaining = 0.0
	check(ability.try_activate(), "Iron starts guard")
	check(ability.block_direct_hit(player.global_position + Vector3.FORWARD), "Iron accepts front block")
	var before: int = open_target.received
	ability._finish_guard(true)
	check(open_target.received == before + 3, "guard counter uses blocked hit bonus")
	check(open_target.control == 0.5, "precise counter stuns ordinary enemy")
	stage.free()
	await frames(2)

func verify_selection_restart() -> void:
	CATALOG.selected_id = "iron"
	preload("res://scripts/integration/player_profile.gd").set_selected_character("iron")
	var main := load("res://Main.tscn").instantiate() as Node3D
	root.add_child(main)
	current_scene = main
	await frames(3)
	main.get_node("UILayer/StartScreen").select_character("astra")
	preload("res://scripts/integration/player_profile.gd").set_selected_character("astra")
	main._on_run_started()
	main._on_run_started()
	await frames(12)
	main = current_scene as Node3D
	var player := main.get_node("DungeonTest/Player")
	check(player.character_id == "astra", "menu selection recreates requested character")
	check(main._run_state == main.RunState.PLAYING, "selection starts once after reload")
	check(main.get_node("DungeonTest")._player == player, "map binds new player")
	check(main.get_node("DungeonTest/Camera3D")._target == player, "camera binds new player")
	check(main.get_node("DungeonTest/RuinGatekeeper")._target == player, "boss binds new player")
	player.energy = 0.0
	main.set_paused(true)
	main._on_restart_requested()
	await frames(12)
	main = current_scene as Node3D
	player = main.get_node("DungeonTest/Player")
	check(main._run_state == main.RunState.MENU, "restart returns to menu")
	check(player.character_id == "astra" and player.energy == 60.0, "restart retains selected character with full energy")
	check(get_nodes_in_group("gravity_fields").is_empty(), "restart leaves no field")
	current_scene = null
	main.free()
	await frames(2)
