extends SceneTree
## 以实体墙和区域网格验证第二关白盒接缝。
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
	var path := "res://scenes/dungeon/level02/Level02.tscn"
	check(ResourceLoader.exists(path), "第二关拥有可独立实例化的地图")
	if failures:
		finish()
		return
	var map = load(path).instantiate()
	root.add_child(map)
	check(map.get_room_count() == 8, "仅八个功能房计入探索数量")
	var specs := {
		"Arrival": [Vector3(0, 0, -5), Vector2(14, 12)],
		"Hub": [Vector3(0, 0, -26), Vector2(22, 18)],
		"Relay": [Vector3(28, 0, -26), Vector2(18, 14)],
		"Antechamber": [Vector3(14, 0, -45), Vector2(20, 16)],
		"Boss": [Vector3(14, 0, -69), Vector2(26, 24)],
		"Exit": [Vector3(14, 0, -89), Vector2(12, 8)],
		"Archive": [Vector3(-34, 0, -26), Vector2(16, 14)],
		"Vault": [Vector3(-34, 0, -52), Vector2(12, 10)]
	}
	for name in specs:
		var region = map.get_node("Regions/" + name)
		check(region.global_position == specs[name][0] and region.dimensions == specs[name][1], name + " 位置及尺寸")
		check(map.get_region_at(region.global_position) == region, name + " 空间查询")
	var regions: Array = map.get_node("Regions").get_children()
	check(regions.size() == 20, "八房与十二段走廊")
	for i in regions.size():
		for j in range(i + 1, regions.size()):
			check(not regions[i].get_world_bounds().intersects(regions[j].get_world_bounds()), "%s/%s 可见地板不重叠" % [regions[i].name, regions[j].name])
	verify_route_lengths(map)
	await verify_physics(map)
	map.queue_free()
	await process_frame
	finish()

func verify_route_lengths(map: Node3D) -> void:
	var corridors := ["ArrivalPass", "EastPass", "RelayPass", "BossPass", "ExitPass"]
	var lengths := [7.0, 9.0, 10.0, 5.0, 5.0]
	for index in corridors.size():
		var region = map.get_node("Regions/" + corridors[index])
		check(maxf(region.dimensions.x, region.dimensions.y) <= lengths[index], corridors[index] + " 过渡长度已压缩")
	# 以房间中心线及转角计入两条路，起点同为前厅，终点同为档案室入口。
	var main := ["Regions/Antechamber", "Gates/AntechamberSouth", "Regions/RelayElbow",
		"Gates/RelayNorth", "Regions/Relay", "Gates/RelayWest", "Gates/HubEast", "Regions/Hub", "Gates/HubWest"]
	var shortcut := ["Regions/Antechamber", "Gates/AntechamberWest", "Regions/ShortcutElbow",
		"Gates/HubNorth", "Regions/Hub", "Gates/HubWest"]
	check(map.has_node("Regions/RelayElbow"), "从回廊向北到转角，再向西进入前厅")
	if not map.has_node("Regions/RelayElbow"):
		return
	var shared_approach: float = map.get_node("Regions/ArchivePass").dimensions.x
	var main_length := route_length(map, main) + shared_approach
	var shortcut_length := route_length(map, shortcut) + shared_approach
	check(shortcut_length <= main_length * 0.70, "档案返程中心线缩短约三成：%.1f / %.1f 米" % [shortcut_length, main_length])
	for spec in [["RelayTurn", "RelayElbow"], ["BossApproach", "BossPass"],
			["ExitApproach", "ExitPass"], ["ArchiveApproach", "ArchivePass"], ["ArchiveReturn", "ShortcutElbow"]]:
		var sign := map.get_node_or_null("Signs/" + spec[0]) as Label3D
		check(sign != null and sign.visible and map.get_region_at(sign.global_position) == map.get_node("Regions/" + spec[1]),
			spec[0] + " 在对应走廊提供方向信息")

func route_length(map: Node3D, points: Array) -> float:
	var length := 0.0
	for i in range(1, points.size()):
		var start := map.get_node(points[i - 1]) as Node3D
		var finish_point := map.get_node(points[i]) as Node3D
		length += start.global_position.distance_to(finish_point.global_position)
	return length

## 检查每一道接缝的地板与实体通行。此套独立解锁用于隔离布局问题。
func verify_physics(map: Node3D) -> void:
	var seams := [
		[Vector3(0, 0, -11), Vector3.FORWARD, "Arrival"],
		[Vector3(0, 0, -17), Vector3.FORWARD, "HubSouth"],
		[Vector3(11, 0, -26), Vector3.RIGHT, "HubEast"],
		[Vector3(19, 0, -26), Vector3.RIGHT, "RelayWest"],
		[Vector3(28, 0, -33), Vector3.FORWARD, "RelayNorth"],
		[Vector3(28, 0, -42.5), Vector3.FORWARD, ""],
		[Vector3(25.5, 0, -45), Vector3.LEFT, ""],
		[Vector3(24, 0, -45), Vector3.LEFT, "AntechamberSouth"],
		[Vector3(14, 0, -53), Vector3.FORWARD, "AntechamberNorth"],
		[Vector3(14, 0, -57), Vector3.FORWARD, "BossSouth"],
		[Vector3(14, 0, -81), Vector3.FORWARD, "BossNorth"],
		[Vector3(14, 0, -85), Vector3.FORWARD, ""],
		[Vector3(-11, 0, -26), Vector3.LEFT, "HubWest"],
		[Vector3(-26, 0, -26), Vector3.LEFT, ""],
		[Vector3(-34, 0, -33), Vector3.FORWARD, "Vault"],
		[Vector3(-34, 0, -47), Vector3.FORWARD, ""],
		[Vector3(0, 0, -35), Vector3.FORWARD, "HubNorth"],
		[Vector3(0, 0, -42.5), Vector3.FORWARD, ""],
		[Vector3(2.5, 0, -45), Vector3.RIGHT, ""],
		[Vector3(4, 0, -45), Vector3.RIGHT, "AntechamberWest"]
	]
	var initially_locked := ["Arrival", "HubEast", "RelayNorth", "AntechamberNorth", "BossNorth", "Vault", "HubNorth", "AntechamberWest"]
	check(map.begin_run(), "布局可进入运行态")
	await physics_frame
	await physics_frame
	for seam in seams:
		var edge: Vector3 = seam[0]
		var axis: Vector3 = seam[1]
		var gate_name: String = seam[2]
		if not gate_name.is_empty():
			var gate := map.get_node("Gates/" + gate_name) as Node3D
			check(gate.position == edge, gate_name + " 实体门位于房间边界")
			var hit := ray(map, edge - axis + Vector3.UP, edge + axis + Vector3.UP)
			if gate_name in initially_locked:
				check(hit.get("collider") == gate, gate_name + " 初始锁有实体阻挡")
				if gate_name != "Arrival":
					check(gate.open_gate(), gate_name + " 布局用直接授权成功")
			else:
				check(hit.is_empty(), gate_name + " 初始可回退")
		for offset in [-0.2, 0.0, 0.2]:
			var sample: Vector3 = edge + axis * offset
			var floor_hit := ray(map, sample + Vector3.UP, sample - Vector3.UP)
			check(not floor_hit.is_empty() and is_zero_approx(floor_hit.position.y), "%s 地板接缝 Y=0 @ %.1f" % [edge, offset])
	await create_timer(1.05).timeout
	var player: CharacterBody3D = map.get_node("Player")
	for seam in seams:
		var edge: Vector3 = seam[0]
		var axis: Vector3 = seam[1]
		for direction in [-1.0, 1.0]:
			player.global_position = edge - axis * direction + Vector3.UP * 0.05
			var impact := player.move_and_collide(axis * direction * 2.0)
			check(impact == null, "%s 开放后可由玩家双向穿越 (%s)" % [edge, direction])
	for turn in [[Vector3(0, 0.05, -40), Vector3.RIGHT], [Vector3(28, 0.05, -40), Vector3.LEFT]]:
		var start: Vector3 = turn[0]
		var direction: Vector3 = turn[1]
		player.global_position = start
		var north_hit := player.move_and_collide(Vector3.FORWARD * 5.0)
		var side_hit := player.move_and_collide(direction * 5.0)
		check(north_hit == null and side_hit == null and player.global_position.is_equal_approx(start + (Vector3.FORWARD + direction) * 5.0), "实际玩家连续穿越转角 %s" % start)
	for cover_name in ["West", "East"]:
		var cover := map.get_node("Cover/" + cover_name) as StaticBody3D
		var collider := cover.get_node("CollisionShape3D") as CollisionShape3D
		var mesh := cover.get_node("Mesh") as MeshInstance3D
		check(collider.shape.size == mesh.mesh.size and ray(map, cover.position - Vector3(0, 0, 2), cover.position + Vector3(0, 0, 2)).get("collider") == cover,
			cover_name + " 掩体可见尺寸与实体一致")

func ray(map: Node3D, start: Vector3, finish: Vector3) -> Dictionary:
	return map.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start, finish, 1))

func finish() -> void:
	print("LEVEL02_LAYOUT: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
