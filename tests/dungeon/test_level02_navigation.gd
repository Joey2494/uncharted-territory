extends SceneTree
## 中庭守卫锁定玩家后，要实际绕过掩体并命中另一侧的玩家。

const MAP := preload("res://scenes/dungeon/level02/Level02.tscn")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func run() -> void:
	await verify_cover("West", "Hub1", "Hub2", -5.0, false)
	await verify_cover("East", "Hub2", "Hub1", 5.0, true)
	print("LEVEL02_NAVIGATION: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func verify_cover(cover_name: String, guard_name: String, other_name: String, x: float, move_target: bool) -> void:
	var map := MAP.instantiate()
	root.add_child(map)
	map.begin_run()
	var player: CharacterBody3D = map.get_node("Player")
	var guard = map.get_node("Enemies/" + guard_name)
	player.global_position = Vector3(x, 0.05, -27)
	for frame in 6:
		await physics_frame
	check(guard.can_process() and guard.state == guard.State.CHASE, cover_name + " 守卫亲眼发现玩家")
	map.get_node("Enemies/" + other_name).process_mode = Node.PROCESS_MODE_DISABLED
	var hits: Array[Node] = []
	guard.get_node("MeleeAttack").hit_detected.connect(func(target: Node, _amount: int) -> void: hits.append(target))
	player.global_position = Vector3(x, 0.05, -21)
	var start: Vector3 = guard.global_position + Vector3.UP
	var finish := player.global_position + Vector3.UP
	var ray := PhysicsRayQueryParameters3D.create(start, finish, 1)
	check(map.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == map.get_node("Cover/" + cover_name), cover_name + " 实体掩体阻断直线")
	for frame in 330:
		if move_target and frame == 25:
			player.global_position.x += 1.1
		if hits.has(player):
			break
		await physics_frame
	check(hits.has(player) and guard.global_position.z > -23.2, "%s 守卫绕过掩体并用真实近战命中玩家，末位置 %s" % [cover_name, guard.global_position])
	map.queue_free()
	await process_frame
