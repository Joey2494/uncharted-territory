extends SceneTree
## 中庭吐丝蜘蛛首次发现玩家后，失去射线会绕过掩体，重新看见玩家才会发射蛛丝。

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
	var shots: Array[int] = []
	guard.attack_resolved.connect(func(kind: int, _strike: int) -> void: shots.append(kind))
	player.global_position = Vector3(x, 0.05, -27)
	for frame in 6:
		await physics_frame
	check(guard.can_process() and shots.has(0), cover_name + " 守卫首次看见玩家后实际吐丝")
	map.get_node("Enemies/" + other_name).process_mode = Node.PROCESS_MODE_DISABLED
	for previous in get_nodes_in_group("creature_hazards"):
		previous.set_physics_process(false)
		previous.queue_free()
	shots.clear()
	player.global_position = Vector3(x, 0.05, -21)
	var start: Vector3 = guard.global_position + Vector3.UP
	var finish := player.global_position + Vector3.UP
	var ray := PhysicsRayQueryParameters3D.create(start, finish, 1)
	var vitality: int = player.hp + player.shield
	check(map.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == map.get_node("Cover/" + cover_name), cover_name + " 实体掩体阻断直线")
	# 记录第二轮走位。东侧还会横移一次，检验蜘蛛追踪移动目标后重新选择发射位置。
	for frame in 190:
		if move_target and frame == 25:
			player.global_position.x += 1.1
		await physics_frame
	check(shots.size() >= 2 and absf(guard.global_position.x - start.x) > 0.65,
		cover_name + " 蜘蛛绕到掩体侧方并恢复吐丝")
	check(player.hp + player.shield == vitality, cover_name + " 石挡边缘仍能挡下擦边的蛛丝")
	# 真实蛛丝有半径；玩家走出掩体后再测命中，不能把最初见面时的缠绕计入。
	shots.clear()
	player.global_position.x = signf(x) * 7.45
	for frame in 140:
		await physics_frame
		if shots.has(0) and player.hp + player.shield < vitality and player.web_remaining > 0:
			break
	check(shots.has(0) and player.hp + player.shield < vitality and player.web_remaining > 0,
		cover_name + " 玩家露出身体后，新发射的蛛丝造成伤害及缠绕")
	map.queue_free()
	await process_frame
