extends SceneTree
## 同一个验收入口支持快速枚举 16 种组合，以及 --walk-mask=N 驱动角色沿实体路线行走。
## 战斗时通过敌人的受伤接口清除每一波；出怪、封门、扫光、掉落和解锁均由正式场景裁定。
const PREVIEW := "res://scenes/dungeon/level04/Level04Preview.tscn"
const MOVE := ["move_left","move_right","move_forward","move_backward"]
var level
var walking := false
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",message)

func frames(n: int) -> void:
	for i in n: await physics_frame

func wait_handoff(path: String, previous_id := 0) -> void:
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path and current_scene.get_instance_id() != previous_id and root.get_node_or_null("LoadingScreen") == null:
			await frames(3)
			return
	check(false, "异步加载完成：" + path)

func run() -> void:
	var masks := range(16)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--walk-mask="):
			walking = true
			masks = [int(arg.get_slice("=",1))]
	for mask: int in masks:
		await route(mask)
		if failures: break
	if not walking and not failures: await failure_case()
	for a in MOVE+["sprint"]: Input.action_release(a)
	paused = false
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames(4)
	print("OBSERVATORY_ROUTES: %d checks, %d failures; input_walk=%s" % [checks,failures,walking])
	quit(1 if failures else 0)

func start() -> void:
	paused = false
	change_scene_to_file(PREVIEW)
	await frames(5)
	level = current_scene

func point(id: String, x: float, z: float) -> Vector3:
	return level.layout.room_center(id)+Vector3(x,0.06,z)

func go_to(world: Vector3) -> void:
	if failures: return
	if not walking:
		level.player.position = world
		level.player.velocity = Vector3.ZERO
		await frames(3)
		return
	# 只使用地图上的障碍和地面寻找路线。最终移动走玩家的 WASD、奔跑和物理碰撞。
	var p: Vector3 = level.player.position
	var start_cell := Vector2i(roundi(2*p.x),roundi(2*p.z))
	var end_cell := Vector2i(roundi(2*world.x),roundi(2*world.z))
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(start_cell,Vector2i.ONE).expand(end_cell).grow(14)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.47
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	query.exclude = [level.player.get_rid()]
	var space: PhysicsDirectSpaceState3D = level.player.get_world_3d().direct_space_state
	for x in range(grid.region.position.x,grid.region.end.x):
		for z in range(grid.region.position.y,grid.region.end.y):
			var at := Vector3(x*0.5,0.58,z*0.5)
			query.transform = Transform3D(Basis.IDENTITY,at)
			var ray := PhysicsRayQueryParameters3D.create(at,at-Vector3.UP*1.2,1,query.exclude)
			grid.set_point_solid(Vector2i(x,z),space.intersect_ray(ray).is_empty() or not space.intersect_shape(query,1).is_empty())
	grid.set_point_solid(start_cell,false)
	var path: Array[Vector2i] = []
	if not grid.is_point_solid(end_cell): path = grid.get_id_path(start_cell,end_cell)
	check(not path.is_empty(),"实际通路 %s → %s" % [start_cell,end_cell])
	if failures: return
	Input.action_press("sprint")
	for cell: Vector2i in path:
		var target := Vector2(cell)*0.5
		for tick in 34:
			var pos: Vector3 = level.player.position
			var offset := target-Vector2(pos.x,pos.z)
			if offset.length() < 0.19 or level.finished: break
			var v := offset.normalized()
			var axes := [-v.x,v.x,-v.y,v.y]
			for k in 4:
				if axes[k] > 0.01: Input.action_press(MOVE[k],axes[k])
				else: Input.action_release(MOVE[k])
			if tick == 33: check(false,"角色被阻挡 %s → %s" % [pos,target])
			await physics_frame
		if failures or level.finished: break
	for a in MOVE+["sprint"]: Input.action_release(a)
	await frames(2)

func go(id: String, x: float, z: float) -> void:
	await go_to(point(id,x,z))

func use(id: StringName, approach := Vector2(0,1)) -> void:
	if failures: return
	var station: Node3D = level.get_node("Stations/"+String(id))
	await go_to(station.position+Vector3(approach.x*1.35,0.06,approach.y*1.35))
	if failures: return
	check(station.can_interact(level.player),"可以靠近操作 "+String(id))
	check(level.inventory.try_interact_nearest(),"操作 "+String(id))
	await frames(2)

func clear(id: String, x: float, z: float) -> void:
	await go(id,x,z)
	if failures: return
	for tick in 800:
		for guard in level.combat._enemies.duplicate():
			guard.take_damage(999)
		if level.combat.is_clear(id): break
		await physics_frame
	check(level.combat.is_clear(id),"清除包括增援在内的 "+id)
	await frames(80)

func route(mask: int) -> void:
	await start()
	check(level.current_room == "A" and level.visited.size() == 1,"初始房间与状态")
	await clear("B",1,3)
	await go("C",0,0)
	if mask & 1:
		await go("D",6,0)
		check(level.combat.active_room == "","观察窗允许折返")
		await clear("D",3,0)
		await use(&"left",Vector2(0,1))
		await go("C",0,0)
	await use(&"p_safe")
	if failures: return
	level.puzzles.operate(&"digit",0,4)
	level.puzzles.operate(&"digit",1,2)
	level.puzzles.operate(&"digit",2,5)
	level.puzzles.operate(&"submit")
	check(level.puzzles.calibrated and not paused,"数字柜开门")
	await frames(75)
	if mask & 2:
		for action: StringName in [&"p_alpha",&"p_alpha",&"p_alpha",&"p_alpha",&"p_beta",&"p_chart"]:
			await use(action,Vector2(1,0))
		await go("E",1,1)
	await clear("F",-2,3)
	if mask & 4:
		await use(&"mail_send")
		check(not level.mail.available(&"mail_take"),"发车后不能再次取药")
		await go("F",-2,1)
	await go("H",0,6)
	await frames(370)
	check(level.combat.demo_done and level.combat.active_room == "","入口示范无伤且不封场")
	await clear("H",1,2)
	if mask & 8:
		await use(&"p_lightbox")
		if failures: return
		level.puzzles.operate(&"plate",0,-1)
		level.puzzles.operate(&"plate",1,1)
		level.puzzles.operate(&"plate",2,-1)
		level.puzzles.operate(&"close")
		await use(&"p_print")
		await go("H",0,0)
	await go("I",0,8)
	check(level.combat.active_room == "","终战门廊允许返回")
	if mask & 4:
		await frames(800)
		await use(&"mail_receive",Vector2(-1,0))
	await clear("I",3,4)
	await go("J",0,-2)
	var bits := 0
	for i in 4: bits += (mask >> i) & 1
	check(level.won and level.finished,"真实出口结算 mask=%d" % mask)
	check(level.visited.size() == 8+bits and level.optional_count() == bits,"探索和成果独立 mask=%d" % mask)
	print("ROUTE ",mask," visited=",level.visited.size()," optional=",level.optional_count()," walk=",walking)

func failure_case() -> void:
	await start()
	await go("B",1,3)
	await frames(5)
	var space: PhysicsDirectSpaceState3D = level.player.get_world_3d().direct_space_state
	for z in [-8.0,8.0]:
		var mouth := point("B",0,z)+Vector3.UP
		var line := PhysicsRayQueryParameters3D.create(mouth-Vector3.BACK,mouth+Vector3.BACK,1)
		check(not space.intersect_ray(line).is_empty(),"作战时房门在门槛阻止玩家退入连接桥")
	await start()
	await go("J",0,-2)
	check(not level.finished,"绕过主线时登台不能结算")
	await go("G",1,1)
	level.inventory.energy_potion_count = level.inventory.Catalog.MAX_STACK
	check(not level.use_station(&"mail_take") and not level.mail.chosen(),"背包满时可回来取货")
	level.inventory.energy_potion_count = 0
	check(level.use_station(&"mail_take") and not level.use_station(&"mail_send"),"直接取药和发车互斥")
	check(level.inventory.energy_potion_count == 1,"直接取药仅一次")
	level.player.take_damage(999)
	await frames(3)
	check(level.finished and not level.won and paused,"死亡优先并冻结场景")
