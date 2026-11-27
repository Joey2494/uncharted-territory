extends SceneTree
## Reproduce summoning after guards finish their death animation and are freed.
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func frames(count := 3) -> void:
	for i in count: await physics_frame
	await process_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)
func run() -> void:
	change_scene_to_file("res://addons/ziyuan_level04/Prototype.tscn")
	for i in 10: await process_frame
	var lab: Node = current_scene
	lab.player.set_physics_process(false)
	lab.player.global_position = Vector3(0, 0.05, 7)
	var boss: Node = lab._actors[0]
	boss.set_physics_process(false)
	for batch in 3:
		var first: Node = lab.spawn_enemy("spore_guard", Vector3(-6, 0.05, -3), true)
		var second: Node = lab.spawn_enemy("spore_guard", Vector3(-2, 0.05, -3), true)
		check(is_instance_valid(first) and is_instance_valid(second), "batch %d summons two guards after old objects were freed" % batch)
		if not is_instance_valid(first) or not is_instance_valid(second): break
		check(lab._actors.all(func(entry): return is_instance_valid(entry)) and lab._guards.size() == 2, "spawn cleans stale actor and guard references")
		check(boss._living_minions() == 2, "only living witch registers the new batch")
		first.set_physics_process(false)
		second.set_physics_process(false)
		first.take_damage(999)
		second.take_damage(999)
		await frames(30)
		check(not is_instance_valid(first) and not is_instance_valid(second), "death animation actually frees both guard objects")
		check(not lab._ended, "guard deaths do not finish the living boss encounter")
	var generation: int = lab._generation
	lab.load_wave(0)
	for actor in lab._actors: actor.set_physics_process(false)
	var count: int = lab._actors.size()
	lab._spawn_for_generation(generation, "spore_guard", Vector3(-6, 0.05, -3))
	check(lab._actors.size() == count, "old deferred summon cannot enter a restarted wave")
	await frames()
	# Simulate a queued request after its summoner has already left the tree.
	var new_boss: Node = lab._actors[0]
	new_boss.queue_free()
	await frames()
	check(lab.spawn_enemy("spore_guard", Vector3(-6, 0.05, -3), true) == null, "orphan guard request rejects a freed summoner")
	lab.queue_free()
	await frames()
	print("WITCH_RESUMMON_RESULT checks=%d failed=%d" % [checks, failures])
	quit(1 if failures else 0)
