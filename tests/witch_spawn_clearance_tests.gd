extends SceneTree
const Factory = preload("res://addons/ziyuan_level04/factory.gd")
var failures := 0
var checks := 0
var lab: Node
var witch: Node
var player: Node
var captured: Array[Vector3] = []
func _initialize() -> void: run.call_deferred()
func frames(count := 3) -> void:
	for i in count: await physics_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)
func horizontal(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
func clear_shape(at: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.6
	shape.height = 1.3
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 7
	query.transform.origin = at + Vector3.UP * 0.7
	return lab.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
func run() -> void:
	change_scene_to_file("res://addons/ziyuan_level04/Prototype.tscn")
	for i in 10: await process_frame
	await frames(6)
	lab = current_scene
	player = lab.player
	player.set_physics_process(false)
	for actor in lab._actors:
		actor.set_encounter_active(false)
		actor.queue_free()
	lab._actors.clear()
	await frames()
	witch = Factory.create("witch", player)
	lab.arena.add_child(witch)
	witch.position = Vector3(-5, 0.05, -5)
	witch.set_encounter_active(true)
	witch.set_physics_process(false)
	witch.summon_requested.connect(func(_id: String, at: Vector3): captured.append(at))
	player.position = Vector3(-5, 0.05, -3)
	await frames()
	check(witch.begin_attack(witch.Move.GUARD), "summon windup accepted")
	# Move into a previously selected slot during windup.
	player.position = witch._mark_positions[0]
	await frames()
	witch._physics_process(witch._remaining)
	check(captured.size() == 2, "occupied preferred slot relocates instead of overlapping player")
	if captured.size() == 2:
		for at in captured:
			check(horizontal(at, player.position) >= 1.25, "summon clears current player position")
			check(horizontal(at, witch.position) >= 1.7 and clear_shape(at), "summon clears cloak and world geometry")
		check(horizontal(captured[0], captured[1]) >= 1.35, "same batch reserves separate guard slots")
	var blocked: Dictionary = witch.find_minion_spawn(Vector3.ZERO)
	check(not blocked.is_empty() and clear_shape(blocked.position), "pillar-occupied slot finds clear supported floor")
	var edge: Dictionary = witch.find_minion_spawn(Vector3(13, 0.05, 11))
	check(edge.is_empty() or clear_shape(edge.position), "blocked corner relocates safely or rejects summon")
	witch._spawn_pool(player.position + Vector3.UP * 1.7)
	var pools := get_nodes_in_group("l4_hazards").filter(func(node): return node.has_method("overlaps_band"))
	check(pools.size() == 1 and is_equal_approx(pools[0].global_position.y, 0.03), "upper-body spore contact places residue on floor rather than over characters")
	witch._spawn_pool(Vector3(0, 3.5, 0))
	check(witch._pools.size() == 1, "spore cannot leave floating residue on top of pillar")
	var spawner := preload("res://addons/ziyuan_level04/enemy_spawner.gd").new()
	lab.arena.add_child(spawner)
	spawner.boss = witch
	spawner._player = player
	var preferred := Vector3(-7, 0.05, -3)
	player.position = preferred
	await frames()
	spawner._spawn_guard(spawner._generation, "spore_guard", preferred)
	spawner._spawn_guard(spawner._generation, "spore_guard", preferred)
	check(spawner.guards.size() == 2, "creation-time check supports two same-frame requests")
	if spawner.guards.size() == 2:
		var first: Node = spawner.guards[0]
		var second: Node = spawner.guards[1]
		first.set_physics_process(false)
		second.set_physics_process(false)
		check(horizontal(first.position, second.position) >= 1.35, "same-frame creations cannot stack before physics synchronization")
		check(horizontal(first.global_position, player.position) >= 1.25, "deferred spawn rechecks moving player")
		check(first.collision_mask == 7 and witch.collision_mask == 7, "guards collide with witch and one another")
		await frames()
		var before: Vector3 = first.global_position
		first.move_and_collide(second.global_position - first.global_position)
		check(horizontal(first.global_position, second.global_position) > 1.0, "moving guard stops against another guard")
		first.global_position = before
		first.move_and_collide(player.global_position - first.global_position)
		check(horizontal(first.global_position, player.global_position) >= 0.9, "guard lunge cannot place its body inside the player")
		first.global_position = before
		first.move_and_collide(witch.global_position - first.global_position)
		check(horizontal(first.global_position, witch.global_position) >= 1.45, "guard cannot hide inside the witch cloak")
		first.global_position = before
		first._visual.pose(first.State.STRIKE, 0.5, 0.0, 0.0)
		check(is_zero_approx(first._visual._body.position.z), "lunge mesh does not advance beyond physics body")
	# No supported floor means no summon, even if the requested coordinates are empty.
	var center: Vector3 = witch.arena_center
	witch.arena_center = Vector3(50, 0, 40)
	check(witch.find_minion_spawn(Vector3(50, 0.05, 40)).is_empty(), "unsupported arena rejects forced summon")
	witch.arena_center = center
	spawner.clear_encounter()
	lab.queue_free()
	await frames()
	print("WITCH_CLEARANCE_RESULT checks=%d failed=%d" % [checks, failures])
	quit(1 if failures else 0)
