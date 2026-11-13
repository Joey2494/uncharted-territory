extends SceneTree
## 实际房间激活、镜头投影及物理遮挡回归。

const LEVEL := preload("res://scenes/dungeon/level02/Level02.tscn")
const BOSS_SCRIPT := preload("res://scenes/bosses/ruin_colossus.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var map := LEVEL.instantiate()
	viewport.add_child(map)
	var player := map.get_node("Player") as CharacterBody3D
	var camera := map.get_node("Camera3D") as Camera3D
	check(map.begin_run(), "正式地图可进入运行态")
	for room in ["Hub", "Relay", "Antechamber", "Boss"]:
		var region = map.get_node("Regions/" + room)
		player.global_position = region.global_position + Vector3.UP * 0.05
		await settle()
		var id: StringName = map.get_current_room_id()
		check(map.progress.get_room_state(id) == map.progress.RoomState.ACTIVE, room + " 实际触发战斗")
		check(is_equal_approx(camera.rotation_degrees.x, -44.0), room + " 固定低俯角")
		var bounds: Rect2 = region.get_world_bounds()
		var corners := [bounds.position, Vector2(bounds.position.x, bounds.end.y),
			Vector2(bounds.end.x, bounds.position.y), bounds.end]
		var top := 4.8 if room == "Boss" else 2.8
		var warning_margin := 3.7 if room == "Boss" else 0.0
		for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(720, 720)]:
			viewport.size = dimensions
			await settle()
			var camera_transform := camera.get_camera_transform()
			for corner: Vector2 in corners:
				check(fits(camera, Vector3(corner.x, 0.04, corner.y)), "%s %s 战场地面覆盖 %s" % [room, dimensions, corner])
				var outer := corner + (corner - bounds.get_center()).sign() * warning_margin
				check(fits(camera, Vector3(outer.x, top, outer.y)), "%s %s 角色轮廓覆盖 %s" % [room, dimensions, outer])
			player.global_position = Vector3(bounds.position.x + 0.9, 0.05, bounds.end.y - 0.9)
			await settle()
			check(camera.get_camera_transform().is_equal_approx(camera_transform), room + " 玩家及敌人移动时取景不变")
			if room == "Hub":
				var wall := map.get_node("Regions/Hub/Geometry/Walls/SouthWall1") as StaticBody3D
				check(wall.get_node("CollisionShape3D").disabled == false, "前景墙淡出保留碰撞")
				var faded := false
				for mesh in wall.find_children("*", "MeshInstance3D", true, false):
					faded = faded or (mesh.material_override != null and mesh.material_override.albedo_color.a < 0.25)
				check(faded, "玩家靠近南墙时淡出墙面")
		if room == "Boss":
			var boss := map.get_node("Boss") as BOSS_SCRIPT
			boss.set_physics_process(false)
			for kind in [BOSS_SCRIPT.Attack.SHOCKWAVE, BOSS_SCRIPT.Attack.ENERGY, BOSS_SCRIPT.Attack.COMBO]:
				boss.state = BOSS_SCRIPT.State.CHASE
				check(boss.begin_attack(kind), "真实巨蝎预警启动 %d" % kind)
				for mesh: MeshInstance3D in [boss._disc] + boss._lanes:
					if not mesh.visible:
						continue
					for index in 8:
						var point := mesh.global_transform * mesh.mesh.get_aabb().get_endpoint(index)
						if bounds.has_point(Vector2(point.x, point.z)):
							check(fits(camera, point), "巨蝎 %d 预警覆盖 %s" % [kind, point])
		var enemies := {"Hub": ["Enemies/Hub1", "Enemies/Hub2"],
			"Relay": ["Enemies/Relay1", "Enemies/Relay2"],
			"Antechamber": ["Enemies/Antechamber1", "Enemies/Antechamber2", "Enemies/Antechamber3"],
			"Boss": ["Boss"]}
		for path in enemies[room]:
			check(map.get_node(path).take_damage(999), path + " 实际清敌")
		await settle()
		var old_position := camera.global_position
		player.global_position = region.global_position + Vector3(2, 0.05, 2)
		await settle()
		check(not camera.global_position.is_equal_approx(old_position), room + " 清场恢复探索跟随")
		if room == "Relay":
			check(map.perform_control(&"relay", player), "清场后激活供能")
	viewport.queue_free()
	await process_frame
	print("LEVEL02_CAMERA: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func settle() -> void:
	for frame in 4:
		await physics_frame
		await process_frame

func fits(camera: Camera3D, point: Vector3) -> bool:
	if camera.is_position_behind(point):
		return false
	var projection := camera.unproject_position(point) / camera.get_viewport().get_visible_rect().size
	return camera.get_safe_frame().grow(0.001).has_point(projection)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)
