extends SceneTree
## 快速枚举 16 种支线组合。--walk-mask=N 以真实输入行走，--west-first 切换零支线的起始翼。
## 战斗时通过敌人的受伤接口清除每一波；出怪、封门、扫光、掉落和解锁均由正式场景裁定。
const PREVIEW := "res://scenes/dungeon/level04/Level04Preview.tscn"
const MOVE := ["move_left","move_right","move_forward","move_backward"]
var level
var walking := false
var west_first := false
var keep_print_in_tray := false
var send_mail_late := false
var room_history: Array[String] = []
var battle_history: Array[String] = []
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
	west_first = "--west-first" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--walk-mask="):
			walking = true
			masks = [int(arg.get_slice("=",1))]
	for mask: int in masks:
		await route(mask)
		if failures: break
	if not walking and not failures:
		west_first = true
		await route(0)
		keep_print_in_tray = true
		send_mail_late = true
		await route(12)
		await failure_case()
	for a in MOVE+["sprint"]: Input.action_release(a)
	paused = false
	if is_instance_valid(current_scene): current_scene.queue_free()
	root.get_node("MusicManager").stop_music()
	await frames(15)
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
	check(level.combat.active_room == id,"跨入内场后启动战斗 "+id)
	await frames(2)
	check_battle_seals(id)
	for tick in 800:
		for guard in level.combat._enemies.duplicate():
			guard.take_damage(999)
		if level.combat.is_clear(id): break
		await physics_frame
	check(level.combat.is_clear(id),"清除包括增援在内的 "+id)
	await frames(80)

## 沿指定连桥逐段行走，弯角不会被寻路捷径替代。终点走进房内一米，仍可观察、撤回。
func cross(a: String, b: String) -> void:
	if failures: return
	check(level.layout.passage_open(a,b), "%s→%s 通路已开放" % [a,b])
	if failures: return
	var path: PackedVector2Array = level.PLAN.bridge_path(a,b)
	if walking:
		for vertex in path:
			await go_to(Vector3(vertex.x,0.06,vertex.y))
			if failures: return
	var inside := path[-1] + path[-2].direction_to(path[-1]) * 1.15
	await go_to(Vector3(inside.x,0.06,inside.y))
	check(level.current_room == b, "经 %s→%s 实际进入目标房间" % [a,b])
	if walking and b in ["F","H","I"] and not level.combat.is_clear(b):
		var outside := path[-1] + path[-1].direction_to(path[-2]) * 1.4
		await go_to(Vector3(outside.x,0.06,outside.y))
		check(level.current_room == "" and level.combat.active_room == "", b+" 入门观察后可退回走廊")
		await go_to(Vector3(inside.x,0.06,inside.y))

## 采样玩家真正进入的房间，区分走过外圈和在分岔点重复进同一房间。
func record_room() -> void:
	if not is_instance_valid(level): return
	var id: String = level.current_room
	if not id.is_empty() and (room_history.is_empty() or room_history[-1] != id):
		room_history.append(id)

func battles_started(id: String) -> void:
	battle_history.append(id)

func ray_hits_gate(gate: StaticBody3D, at: Vector3, axis: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = level.player.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(at-axis,at+axis,1,[level.player.get_rid()])
	return space.intersect_ray(ray).get("collider") == gate

## 验证实场房门自己的碰撞生效，防止逻辑显示锁门而实体仍能穿过。
func check_battle_seals(id: String) -> void:
	for link: String in level.EDGES:
		if not link.contains(id): continue
		var neighbor := link.replace(id,"")
		var path: PackedVector2Array = level.PLAN.bridge_path(id,neighbor)
		var tangent := path[0].direction_to(path[1])
		var gate: StaticBody3D = level.layout.get_node_or_null("Seal_"+id+neighbor)
		var at := Vector3(path[0].x,1.0,path[0].y)
		check(is_instance_valid(gate) and ray_hits_gate(gate,at,Vector3(tangent.x,0,tangent.y)), "战斗 %s 封住 %s 门口实体" % [id,neighbor])
		check(not level.layout.passage_open(id,neighbor),"战斗时地图同步封住 "+id+neighbor)

func check_trial_gates(open: bool) -> void:
	for wing: String in ["E","F"]:
		var gate: StaticBody3D = level.layout.get_node(wing+"H/Gate")
		check(level.layout.passage_open(wing,"H") == open, wing+" 到 H 的双条件")
		var solid := ray_hits_gate(gate,gate.global_position+Vector3.UP,gate.global_basis.z.normalized())
		check(solid != open, wing+" 到 H 的实体门与授权一致")

func calibrate() -> void:
	await use(&"p_safe")
	if failures: return
	for pair in [[0,4],[1,2],[2,5]]: level.puzzles.operate(&"digit",pair[0],pair[1])
	level.puzzles.operate(&"submit")
	check(level.puzzles.calibrated and not paused,"数字柜开门")
	await frames(75)

func mirrors() -> void:
	await cross("E","K")
	for action: StringName in [&"p_alpha",&"p_alpha",&"p_alpha",&"p_alpha",&"p_beta",&"p_chart"]:
		await use(action,Vector2(1,0))
	await cross("K","E")

func develop() -> void:
	await cross("H","L")
	check(not level.layout.passage_open("L","I"),"显影前侧门锁住")
	await use(&"p_lightbox")
	if failures: return
	level.puzzles.operate(&"plate",0,-1)
	level.puzzles.operate(&"plate",1,1)
	level.puzzles.operate(&"plate",2,-1)
	level.puzzles.operate(&"close")
	await frames(75)
	check(level.puzzles.film_developed and not level.puzzles.film_claimed and level.layout.passage_open("L","I"),"成片仍留在盘中时 I 侧门已开")
	if not keep_print_in_tray: await use(&"p_print")

func route(mask: int) -> void:
	await start()
	room_history.assign(["A"])
	battle_history.clear()
	if not physics_frame.is_connected(record_room): physics_frame.connect(record_room)
	level.combat.battle_started.connect(battles_started)
	check(level.current_room == "A" and level.visited.size() == 1,"初始房间与状态")
	await cross("A","B")
	await clear("B",1,3)
	await cross("B","C")
	if failures: return
	check(level.layout.passage_open("C","E") and level.layout.passage_open("C","F"),"C 同时开放两翼")
	check(not level.layout.passage_open("E","F"),"两翼完成前横桥关闭")
	check_trial_gates(false)
	var approach := "C"
	var expected := "ABC"
	if mask & 1:
		await cross("C","D")
		check(level.visited.has("D") and not level.optional_done("D"),"参观 D 不计支线成果")
		await go("D",6,0)
		check(level.combat.active_room == "","观察窗允许折返")
		await clear("D",3,0)
		check(not level.layout.passage_open("D","F"),"只清场未操作吊笼时检修门关闭")
		await use(&"left")
		await frames(75)
		await use(&"right")
		check(get_nodes_in_group("observatory_maintenance_supply").size() == 1, "反复换边只放置一瓶检修廊药剂")
		check(level.layout.passage_open("D","F"),"换边保留检修道")
		approach = "D"
		expected += "D"
	var west := west_first or (mask & 5) != 0
	var second := "E" if west else "F"
	if west:
		await cross(approach,"F")
		check(level.combat.active_room == "", "栈道西侧门口允许观察")
		await clear("F",-2,3)
		check_trial_gates(false)
		check(level.layout.passage_open("E","F") and level.layout.passage_open("G","E"),"清场放行横桥与货运廊")
		if mask & 4:
			await cross("F","G")
			check(not level.optional_done("G"),"经过 G 不计支线成果")
			if not send_mail_late:
				await use(&"mail_send")
				check(not level.mail.available(&"mail_take"),"发车后不能再次取药")
			await cross("G","E")
			expected += "FGE"
		else:
			await cross("F","E")
			expected += "FE"
		await calibrate()
		if mask & 2:
			await mirrors()
			expected += "KE"
	else:
		await cross("C","E")
		await calibrate()
		check_trial_gates(false)
		check(level.layout.passage_open("E","F") and not level.layout.passage_open("G","E"),"校准只提前放行横桥")
		expected += "E"
		if mask & 2:
			await mirrors()
			expected += "KE"
		await cross("E","F")
		check(level.combat.active_room == "", "栈道东侧门口允许观察")
		await clear("F",-2,3)
		expected += "F"
	if failures: return
	check_trial_gates(true)
	await cross(second,"H")
	await frames(370)
	check(level.combat.demo_done and level.combat.active_room == "","入口示范无伤且不封场")
	await clear("H",1,2)
	expected += "H"
	if send_mail_late:
		# 清场后再寄件，保证从 L 赶到门廊时邮车仍在途中；原路重访不会再发 H 奖励。
		var before: int = level.inventory.gold
		await cross("H","E")
		await cross("E","G")
		await use(&"mail_send")
		await cross("G","E")
		await cross("E","H")
		await go("H",1,2)
		check(level.combat.active_room == "" and level.inventory.gold == before, "H 内场重访不刷怪或发奖")
		expected += "EGEH"
	if mask & 8:
		await develop()
		if keep_print_in_tray:
			for stack in ["potion_count","energy_potion_count","rune_count","guard_count","pistol_ammo","coil_ammo","ammo"]:
				level.inventory.set(stack,level.inventory.Catalog.MAX_STACK)
		await cross("L","I")
		expected += "L"
	else: await cross("H","I")
	await go("I",0,8)
	check(level.combat.active_room == "","两条来路都能安全到达终战门廊")
	if send_mail_late:
		check(level.mail.state == level.mail.State.TRAVELLING and not level.mail.available(&"mail_receive"), "邮件未到且背包已满时可以越过终战门槛")
	elif mask & 4:
		for tick in 2400:
			if level.mail.available(&"mail_receive"): break
			await physics_frame
		await use(&"mail_receive",Vector2(-1,0))
		check(level.combat.active_room == "" and level.mail.state == level.mail.State.RECEIVED,"在同一安全门廊签收邮件")
	await clear("I",3,4)
	check(not level.finished,"清场后等待实际登台")
	await cross("I","J")
	await go("J",0,-2)
	if failures: return
	expected += "IJ"
	var bits := 0
	for i in 4: bits += (mask >> i) & 1
	var completed := bits - int(keep_print_in_tray and (mask & 8) != 0)
	check(level.won and level.finished,"实际出口结算 mask=%d" % mask)
	check(level.visited.size() == 8+bits and level.optional_count() == completed,"探索和成果独立 mask=%d" % mask)
	check("".join(room_history) == expected, "连续房间顺序：实际 %s，预期 %s" % ["".join(room_history),expected])
	check("".join(battle_history) == ("BDFHI" if mask & 1 else "BFHI"), "按顺序仅触发预期战斗，每场只触发一次")
	print("ROUTE ",mask," rooms=","".join(room_history)," visited=",level.visited.size()," optional=",level.optional_count()," walk=",walking)

## 故意放置到尚未解锁的 H 内场，检验物理路径之外的战斗前置同样拒绝跳关。
func check_partial_wing(calibrated_first: bool) -> void:
	await start()
	await clear("B",1,3)
	if calibrated_first:
		await calibrate()
		await mirrors()
	else:
		await clear("F",-2,3)
		await cross("F","G")
		await cross("G","E")
	check_trial_gates(false)
	await go("H",1,2)
	await frames(370)
	check(not level.combat.demo_done and level.combat.active_room == "", "只完成一翼不能经外圈触发 H")

func failure_case() -> void:
	await check_partial_wing(true)
	await check_partial_wing(false)
	await start()
	await go("B",1,3)
	await frames(5)
	check_battle_seals("B")
	await start()
	await go("J",0,-2)
	check(not level.finished,"绕过主线时登台不能结算")
	await clear("B",1,3)
	await clear("F",-2,3)
	var gold: int = level.inventory.gold
	await cross("F","C")
	await cross("C","F")
	await go("F",-2,3)
	check(level.combat.active_room == "" and level.combat.enemy_count() == 0 and level.inventory.gold == gold,"重访栈道不刷新敌人或金币")
	await cross("F","G")
	level.inventory.energy_potion_count = level.inventory.Catalog.MAX_STACK
	check(not level.use_station(&"mail_take") and not level.mail.chosen(),"背包满时可回来取货")
	level.inventory.energy_potion_count = 0
	check(level.use_station(&"mail_take") and not level.use_station(&"mail_send"),"直接取药和发车互斥")
	check(level.inventory.energy_potion_count == 1,"直接取药仅一次")
	level.player.take_damage(999)
	await frames(3)
	check(level.finished and not level.won and paused,"死亡优先并冻结场景")
