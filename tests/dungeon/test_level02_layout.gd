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
		"Arrival": [Vector3.ZERO, Vector2(14, 12)],
		"Hub": [Vector3(0, 0, -26), Vector2(22, 18)],
		"Relay": [Vector3(34, 0, -26), Vector2(18, 14)],
		"Antechamber": [Vector3(34, 0, -56), Vector2(20, 16)],
		"Boss": [Vector3(34, 0, -86), Vector2(26, 24)],
		"Exit": [Vector3(34, 0, -110), Vector2(12, 8)],
		"Archive": [Vector3(-34, 0, -26), Vector2(16, 14)],
		"Vault": [Vector3(-34, 0, -52), Vector2(12, 10)]
	}
	for name in specs:
		var region = map.get_node("Regions/" + name)
		check(region.global_position == specs[name][0] and region.dimensions == specs[name][1], name + " 位置及尺寸")
		check(map.get_region_at(region.global_position) == region, name + " 空间查询")
	var regions: Array = map.get_node("Regions").get_children()
	check(regions.size() == 18, "八房与十段走廊")
	for i in regions.size():
		for j in range(i + 1, regions.size()):
			check(not regions[i].get_world_bounds().intersects(regions[j].get_world_bounds()), "%s/%s 可见地板不重叠" % [regions[i].name, regions[j].name])
	await verify_physics(map)
	map.queue_free()
	await process_frame
	finish()

## 检查每一道接缝的地板与实体通行。此套独立解锁用于隔离布局问题。
func verify_physics(map: Node3D) -> void:
	var seams := [
		[Vector3(0, 0, -6), Vector3.FORWARD, "Arrival"],
		[Vector3(0, 0, -17), Vector3.FORWARD, "HubSouth"],
		[Vector3(11, 0, -26), Vector3.RIGHT, "HubEast"],
		[Vector3(25, 0, -26), Vector3.RIGHT, "RelayWest"],
		[Vector3(34, 0, -33), Vector3.FORWARD, "RelayNorth"],
		[Vector3(34, 0, -48), Vector3.FORWARD, "AntechamberSouth"],
		[Vector3(34, 0, -64), Vector3.FORWARD, "AntechamberNorth"],
		[Vector3(34, 0, -74), Vector3.FORWARD, "BossSouth"],
		[Vector3(34, 0, -98), Vector3.FORWARD, "BossNorth"],
		[Vector3(34, 0, -106), Vector3.FORWARD, ""],
		[Vector3(-11, 0, -26), Vector3.LEFT, "HubWest"],
		[Vector3(-26, 0, -26), Vector3.LEFT, ""],
		[Vector3(-34, 0, -33), Vector3.FORWARD, "Vault"],
		[Vector3(-34, 0, -47), Vector3.FORWARD, ""],
		[Vector3(0, 0, -35), Vector3.FORWARD, "HubNorth"],
		[Vector3(0, 0, -53.5), Vector3.FORWARD, ""],
		[Vector3(2.5, 0, -56), Vector3.RIGHT, ""],
		[Vector3(24, 0, -56), Vector3.RIGHT, "AntechamberWest"]
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
	var corner_start := Vector3(0, 0.05, -51)
	player.global_position = corner_start
	var north_hit := player.move_and_collide(Vector3(0, 0, -5))
	var east_hit := player.move_and_collide(Vector3(5, 0, 0))
	check(north_hit == null and east_hit == null and player.global_position.is_equal_approx(Vector3(5, 0.05, -56)), "实际玩家连续转弯穿越 L 形回环")
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
