extends SceneTree
## Real physics regression: first contact consumes every enemy projectile, even on invulnerability.
const Bolt3 = preload("res://addons/ziyuan_level03/bone_projectile.gd")
const Bolt4 = preload("res://addons/ziyuan_level04/spore_projectile.gd")
const Spore = preload("res://addons/ziyuan_level04/spore_mark.gd")
const Vine = preload("res://addons/ziyuan_level04/vine_sweep.gd")
const Hazard = preload("res://addons/ziyuan_level04/room_hazard.gd")
const Creature = preload("res://scenes/skills/creature_projectile.gd")
var checks := 0
var failures := 0
var arena: Node3D
var source: Source
var player: Target
var wall: StaticBody3D

class Source extends CharacterBody3D:
	var definition := {"damage": 2}
	var arena_center := Vector3.ZERO
	var arena_size := Vector2(20, 12)
	var pools := 0
	func is_dead() -> bool: return false
	func is_encounter_active() -> bool: return true
	func can_see(at: Vector3) -> bool:
		return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, at + Vector3.UP, 1)).is_empty()
	func _spawn_pool(_at: Vector3) -> void: pools += 1

class Inventory extends Node:
	var guard_active := false

class Target extends CharacterBody3D:
	var hp := 20
	var immune := false
	var webs := 0
	func is_dead() -> bool: return false
	func take_damage(amount: int) -> bool:
		if immune: return false
		hp -= amount
		return true
	func take_direct_damage(amount: int, _at: Vector3) -> bool: return take_damage(amount)
	func apply_web(_seconds: float) -> void: webs += 1

func _initialize() -> void: run.call_deferred()
func frames(count := 3) -> void:
	for i in count: await physics_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)
func shape(body: CollisionObject3D, size: Vector3, offset := Vector3.ZERO) -> void:
	var node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	node.shape = box
	node.position = offset
	body.add_child(node)
func reset(blocked: bool, immune := false) -> void:
	for child in arena.get_children():
		if child not in [source, player, wall]: child.queue_free()
	wall.position = Vector3(0, 2, 0) if blocked else Vector3(20, 2, 0)
	player.position = Vector3(0, 0, 3)
	player.hp = 20
	player.immune = immune
	source.position = Vector3(0, 0, -3)
	source.pools = 0
	await frames()
func projectile(kind: int) -> Node3D:
	var actor: Node3D
	if kind == 0: actor = Bolt3.new()
	elif kind == 1: actor = Bolt4.new()
	else: actor = Creature.new()
	arena.add_child(actor)
	actor.position = Vector3(0, 0.85, -2)
	if kind < 2: actor.launch(source, player, Vector3.BACK, 1)
	else:
		actor.setup(source, player, Vector3.BACK, 0 if kind == 2 else (2 if kind == 3 else 1))
		if kind == 4:
			actor._emerge_remaining = 0.0
			actor.collision_layer = 4
			actor.collision_mask = 3
	return actor
func run() -> void:
	arena = Node3D.new()
	root.add_child(arena)
	source = Source.new()
	arena.add_child(source)
	source.collision_layer = 4
	player = Target.new()
	arena.add_child(player)
	player.collision_layer = 2
	shape(player, Vector3(0.8, 1.8, 0.8), Vector3.UP * 0.9)
	var inventory := Inventory.new()
	inventory.name = "ItemInventory"
	player.add_child(inventory)
	wall = StaticBody3D.new()
	arena.add_child(wall)
	wall.collision_layer = 1
	shape(wall, Vector3(8, 4, 0.4))
	for kind in 5:
		for blocked in [true, false]:
			await reset(blocked)
			var actor := projectile(kind)
			await frames(160 if kind == 4 else 90)
			check(not is_instance_valid(actor), "projectile %d disappears on %s" % [kind, "wall" if blocked else "player"])
			check(player.hp == (20 if blocked else 19), "projectile %d applies damage only at unobstructed contact" % kind)
		await reset(false, true)
		var actor := projectile(kind)
		await frames(160 if kind == 4 else 90)
		check(not is_instance_valid(actor) and player.hp == 20, "projectile %d is consumed by immune player" % kind)
	for blocked in [true, false]:
		await reset(blocked)
		var spore := Spore.new()
		arena.add_child(spore)
		spore.launch(source, player, player.position, 0.9)
		await frames(65)
		check(not is_instance_valid(spore), "arc spore disappears at contact")
		check(player.hp == (20 if blocked else 18), "arc spore respects obstruction")
		check(source.pools == (0 if blocked else 1), "wall impact cannot spawn a pool behind cover")
		await reset(blocked)
		var vine := Vine.new()
		arena.add_child(vine)
		vine.launch(source, player, 0)
		await frames(100)
		check(not is_instance_valid(vine) and player.hp == (20 if blocked else 18), "vine stops at first wall or player")
	await reset(true)
	var fast_spore := Spore.new()
	arena.add_child(fast_spore)
	fast_spore.launch(source, player, player.position, 0.9)
	fast_spore.set_physics_process(false)
	fast_spore._physics_process(1.0)
	check(fast_spore.is_queued_for_deletion() and not fast_spore.visible and player.hp == 20, "long frame cannot tunnel an arc spore through a wall")
	fast_spore._physics_process(1.0)
	check(source.pools == 0, "repeated tick cannot resolve a consumed spore twice")
	await reset(false)
	var thorn := Hazard.new()
	arena.add_child(thorn)
	thorn.launch(source, player, "thorns", player.position)
	await frames()
	check(not is_instance_valid(thorn) and player.hp == 18, "thorn contact bursts then disappears")
	await reset(true)
	var heat := Hazard.new()
	arena.add_child(heat)
	heat.launch(source, player, "heat", Vector3(0, 0, -3))
	# Check the wall-facing segments have disappeared while the rest still expands.
	await frames(45)
	check(is_instance_valid(heat) and heat._blocked.size() > 0 and player.hp == 20, "wall consumes heat-wave segments before player")
	await reset(false)
	heat = Hazard.new()
	arena.add_child(heat)
	heat.launch(source, player, "heat", Vector3(0, 0, -3))
	for i in 95:
		await frames(1)
		if not is_instance_valid(heat): break
	check(not is_instance_valid(heat) and player.hp == 18, "heat bursts and disappears on player")
	var effects := get_nodes_in_group("l4_transient")
	check(effects.size() > 0, "impact produces visible transient particles")
	await reset(false)
	var camera := Camera3D.new()
	arena.add_child(camera)
	camera.position = Vector3(0, 10, 13)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	root.size = Vector2i(1280, 720)
	var factory := preload("res://addons/ziyuan_level04/factory.gd")
	var guard := factory.create("spore_guard", player)
	var witch := factory.create("witch", player)
	for actor in [guard, witch]:
		arena.add_child(actor)
		actor.set_encounter_active(true)
		actor.set_physics_process(false)
	guard._aggro = true
	guard.position = Vector3(-2, 0, 0)
	witch.position = Vector3(2, 0, 0)
	await frames()
	var small: Node = guard.get_node("HealthLabel")
	var large: Node = witch.get_node("HealthLabel")
	small._process(0.0)
	large._process(0.0)
	check(small.position.y < 1.2 and large.position.y > 3.0, "health anchors match small guard and tall boss models")
	check(small._bar.size.x < large._bar.size.x and small._bar.size.x <= 48, "small guard receives shorter HP bar")
	check(small._bar.visible and large._bar.visible, "size-fitted bars remain visible")
	var width: float = large._bar.size.x
	camera.position *= 1.6
	camera.look_at(Vector3.ZERO)
	large._process(0.0)
	check(large._bar.size.x < width, "bar width follows projected model size with camera distance")
	var anchor: Vector3 = small.position
	guard._visual.pose(2, 1.0, 0.0, 0.0)
	small._process(0.0)
	check(small.position == anchor, "windup animation cannot make HP anchor jitter")
	guard.take_damage(1)
	check(small._current == guard.hp, "size fitting preserves HP updates")
	arena.queue_free()
	await frames()
	print("ENEMY_IMPACT_RESULT checks=%d failed=%d" % [checks, failures])
	quit(1 if failures else 0)
