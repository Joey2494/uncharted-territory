extends SceneTree
## 第一关真实主场景集成：菜单、移动/闪避/弹体、清敌、Boss出口及重开。
var checks := 0
var failures := 0
var opened_events := 0
var exit_events := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",message)
func frames(count: int = 3) -> void:
	for i in count: await physics_frame
func new_game() -> Node:
	var g = load("res://Main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	return g

## 从房间内侧以真实玩家实体扫掠门洞，验证结果而非单看门状态。
func blocks_player(player: CharacterBody3D, gate: Node3D, outward: Vector3) -> bool:
	player.global_position = gate.global_position - outward * 1.5 + Vector3.UP * 0.05
	var collision := player.move_and_collide(outward * 3.0)
	return collision != null and collision.get_collider() == gate

## 终局会移除玩家物理体，改用门体所在世界中的实物射线。
func blocks_ray(gate: Node3D, outward: Vector3) -> bool:
	var center := gate.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(center - outward * 1.0, center + outward * 1.0, 1)
	var hit := gate.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") == gate

func run() -> void:
	var game = new_game()
	var d = game.get_node("DungeonTest")
	if not d.has_node("RoomProgress") or not d.has_node("Gates/CourtyardGate"):
		check(false,"主地图必须接入房间进度与实体顺序门")
		game.queue_free()
		await process_frame
		quit(1)
		return
	var p = d.get_node("Player")
	var progress = d.get_node("RoomProgress")
	var gate = d.get_node("Gates/CourtyardGate")
	var entry = d.get_node("Gates/EntranceGate")
	var enemy = d.get_node("MeleeEnemy")
	var boss = d.get_node("RuinGatekeeper")
	gate.opened.connect(func(_id: StringName) -> void: opened_events += 1)
	d.exit_unlocked.connect(func() -> void: exit_events += 1)
	await create_timer(0.15).timeout
	check(not entry.is_open() and not gate.is_open(), "菜单中不能开门")
	check(not progress.is_complete(&"l1_entrance"), "菜单不完成入口")
	game._on_run_started()
	game.get_node("DungeonTest").request_tutorial_skip()
	await create_timer(1.1).timeout
	check(entry.is_open(), "跳过教学后入口门正常开启")
	check(not gate.is_open(), "开始游戏不自动开中庭门")
	p.position = Vector3(0, 0.05, -17.24)
	await frames()
	check(progress.get_room_state(&"l1_crossroads") == progress.RoomState.UNVISITED, "距离门槛 1.24m 不激活中庭")
	check(not enemy.can_process() and not enemy.take_damage(1), "门槛处的休眠守卫拒绝伤害")
	var south = d.get_node_or_null("Gates/CourtyardSouthSeal")
	var west = d.get_node_or_null("Gates/CourtyardWestSeal")
	var boss_west = d.get_node_or_null("Gates/BossWestSeal")
	var boss_north = d.get_node_or_null("Gates/BossNorthSeal")
	check(south != null and west != null and boss_west != null and boss_north != null, "真实地图补齐中庭与 Boss 房全部门洞的实体封锁")
	if south == null or west == null or boss_west == null or boss_north == null:
		game.queue_free()
		await process_frame
		finish()
		return
	check(south.is_open() and west.is_open() and boss_west.is_open() and boss_north.is_open(), "纯战斗门待机时可通行")
	check(not blocks_player(p, south, Vector3.BACK), "战斗前南侧门洞允许实际通过")
	check(not boss.take_damage(999), "未进入 Boss 房时不能提前击败 Boss")
	p.position = Vector3(22, 0.05, -23)
	await frames()
	check(not boss.can_process() and boss_west.is_open(), "跳过前置房间不能激活 Boss 战斗")
	p.position = Vector3(0, 0.05, -17.26)
	await frames()
	check(progress.get_room_state(&"l1_crossroads") == progress.RoomState.ACTIVE and enemy.can_process(), "距门槛 1.26m 后激活中庭并唤醒敌人")
	check(blocks_player(p, south, Vector3.BACK) and blocks_player(p, west, Vector3.LEFT), "下降中的中庭南、西两门已阻挡实体")
	check(south.get_node("Visuals").position.y > 0.0, "战斗门从上方下降")
	paused = true
	var paused_height: float = south.get_node("Visuals").position.y
	await create_timer(0.25).timeout
	check(is_equal_approx(south.get_node("Visuals").position.y, paused_height), "暂停冻结下降过程")
	paused = false
	p.position = Vector3(0, 0.05, -18)
	await frames(8)
	Input.action_press("move_backward")
	check(p.try_dodge(), "朝下降中的南侧门可以发起真实闪避")
	var closing_bolt = load("res://scenes/skills/EnergyBolt.tscn").instantiate()
	d.add_child(closing_bolt)
	closing_bolt.global_position = Vector3(1.5, 1, -18)
	var closing_hits: Array[Node] = []
	closing_bolt.impacted.connect(func(body: Node) -> void: closing_hits.append(body))
	closing_bolt.launch(Vector3.BACK, 2, 60, 10, p)
	await create_timer(0.25).timeout
	Input.action_release("move_backward")
	check(south.state == south.State.CLOSING and p.position.z < -16.5, "下降中的门挡住真实闪避")
	check(closing_hits == [south], "下降中的门挡住真实高速弹体")
	p.position = Vector3(7.0, 0.05, -23)
	await frames()
	check(progress.get_room_state(&"l1_crossroads") == progress.RoomState.ACTIVE, "真实区域激活战斗房")
	p.move_and_collide(Vector3(4,0,0))
	check(p.position.x < 8.5, "玩家碰撞移动不能越过锁门")
	var bolt = load("res://scenes/skills/EnergyBolt.tscn").instantiate()
	d.add_child(bolt)
	bolt.global_position = Vector3(7,1,-23)
	var hit: Array[Node] = []
	bolt.impacted.connect(func(body: Node) -> void: hit.append(body))
	bolt.launch(Vector3.RIGHT,2,60,10,p)
	await create_timer(0.25).timeout
	check(hit.size() == 1 and hit[0] == gate, "高速法术弹体命中锁门")
	var enemy_start: Vector3 = enemy.position
	enemy.position = Vector3(7,0.05,-22)
	await frames()
	enemy.move_and_collide(Vector3(4,0,0))
	check(enemy.position.x < 8.5, "真实敌人不能穿门")
	enemy.position = enemy_start
	check(blocks_player(p, west, Vector3.LEFT), "战斗中无法退出到补给支线")
	check(not progress.is_complete(&"l1_crossroads"), "反复尝试离开不影响清敌状态")
	check(enemy.take_damage(999), "实际击杀中庭守卫")
	check(progress.is_complete(&"l1_crossroads"), "击杀按出生归属完成中庭")
	check(not gate.is_open(), "开门动画未结束不能报告可通行")
	check(blocks_player(p, south, Vector3.BACK), "重新升起过程中仍保留实体阻挡")
	enemy.died.emit()
	await create_timer(1.15).timeout
	check(gate.is_open() and opened_events == 1, "重复死亡只完成一次开门")
	check(south.is_open() and west.is_open(), "中庭清敌后同时开放南、西出口")
	check(not blocks_player(p, west, Vector3.LEFT), "清敌后可实际返回补给支线")
	p.position = Vector3(0, 0.05, -23)
	await frames()
	check(south.is_open() and west.is_open() and gate.is_open(), "重访已清房间不会再次封锁")
	p.position = Vector3(7,0.05,-23)
	await frames()
	p.move_and_collide(Vector3(5,0,0))
	check(p.position.x > 10, "开门后真实移动可通过")
	p.move_and_collide(Vector3(-5,0,0))
	check(p.position.x < 8, "已开放主线可退回")
	check(not d.is_exit_open(), "中庭清敌不打开Boss出口")
	p.position = Vector3(20.24,0.05,-23)
	await frames()
	check(not boss.can_process(), "Boss 房门槛内侧仍保持休眠")
	p.position = Vector3(22,0.05,-23)
	await frames()
	check(progress.get_room_state(&"l1_boss") == progress.RoomState.ACTIVE, "实际进入Boss区域激活")
	check(blocks_player(p, boss_west, Vector3.LEFT) and blocks_player(p, boss_north, Vector3.FORWARD), "Boss 房西门与北门下降时均阻挡玩家")
	var exit_gate: Node3D = d.get_node("ExitGate")
	check(blocks_ray(exit_gate, Vector3.FORWARD), "Boss 战斗时远端出口封印有实体碰撞")
	check(boss.take_damage(999), "真实Boss死亡")
	await create_timer(0.18).timeout
	check(exit_gate.get_node("Visuals").position.y > 0.0 and blocks_ray(exit_gate, Vector3.FORWARD), "远端封印向上抬升时保留碰撞")
	await create_timer(1.0).timeout
	check(d.is_exit_open() and exit_events == 1, "Boss出口仅开启一次")
	check(not blocks_ray(exit_gate, Vector3.FORWARD), "远端封印完全升起后物理通行")
	check(boss_west.is_open() and boss_north.is_open(), "Boss 清除后开放大厅两侧")
	check(game._run_state == game.RunState.PLAYING, "击败Boss尚未通关")
	p.position = Vector3(30,0.05,-45)
	await frames(6)
	check(game._run_state == game.RunState.VICTORY, "实际进入出口结算")
	game._on_restart_requested()
	game._on_restart_requested()
	await process_frame
	await process_frame
	game = current_scene
	d = game.get_node("DungeonTest")
	check(game._run_state == game.RunState.MENU, "真实重开返回开始菜单")
	check(not d.get_node("Gates/CourtyardGate").is_open(), "重开恢复中庭门")
	check(not d.is_exit_open(), "重开恢复出口封印")
	check(d.get_node("Gates/CourtyardSouthSeal").is_open() and d.get_node("Gates/BossNorthSeal").is_open(), "重开恢复纯战斗门的初始开态")
	check(d.has_node("MeleeEnemy") and not d.get_node("MeleeEnemy").is_dead() and not d.get_node("MeleeEnemy").can_process(), "重开恢复敌人的休眠初态")
	game._on_run_started()
	game.get_node("DungeonTest").request_tutorial_skip()
	p = d.get_node("Player")
	p.position = Vector3(6,0.05,-23)
	await frames()
	d.get_node("MeleeEnemy").take_damage(999)
	var opening_visual: Node3D = d.get_node("Gates/CourtyardGate/Visuals")
	await create_timer(0.15).timeout
	var opening_height := opening_visual.position.y
	p.take_damage(999)
	await create_timer(1.15).timeout
	check(not d.get_node("Gates/CourtyardGate").is_open(), "死亡打断打开过程并拒绝旧回调")
	check(is_equal_approx(opening_visual.position.y, opening_height) and opening_height > 0.0, "死亡冻结上升位置")
	check(blocks_ray(d.get_node("Gates/CourtyardGate"), Vector3.RIGHT), "死亡中断上升后门体仍有碰撞")
	game.queue_free()
	await process_frame
	# 死亡中断下降过程，禁止敌人继续推进，直到换一局。
	game = new_game()
	game._on_run_started()
	game.get_node("DungeonTest").request_tutorial_skip()
	d = game.get_node("DungeonTest")
	p = d.get_node("Player")
	p.position = Vector3(0,0.05,-23)
	await frames()
	south = d.get_node("Gates/CourtyardSouthSeal")
	var closing_visual: Node3D = south.get_node("Visuals")
	var closing_height := closing_visual.position.y
	p.take_damage(999)
	enemy = d.get_node("MeleeEnemy")
	check(not enemy.can_process() and not enemy.take_damage(999), "死亡停止战斗并拒绝清敌")
	await create_timer(1.15).timeout
	check(closing_height > 0.0 and is_equal_approx(closing_visual.position.y, closing_height), "死亡冻结下降位置")
	check(not south.is_open() and not d.get_node("RoomProgress").is_complete(&"l1_crossroads"), "死亡后战斗门保持阻挡且未完成房间")
	check(blocks_ray(south, Vector3.BACK), "死亡中断下降后门体仍有碰撞")
	game.queue_free()
	await process_frame
	# 与上面的真实击杀严格区分：只删除敌人，不能误认为清敌。
	game = new_game()
	game._on_run_started()
	game.get_node("DungeonTest").request_tutorial_skip()
	d = game.get_node("DungeonTest")
	d.get_node("Player").position = Vector3(0,0.05,-23)
	await frames()
	d.get_node("MeleeEnemy").queue_free()
	d.get_node("RuinGatekeeper").queue_free()
	await process_frame
	await create_timer(1.15).timeout
	check(not d.get_node("Gates/CourtyardGate").is_open(), "实际移除敌人不能开中庭门")
	check(not d.unlock_exit() and not d.is_exit_open(), "实际移除Boss不能开出口")
	game.queue_free()
	await process_frame
	# 真实地图的必需门丢失或被冻结后，房间应保持待机且敌人不能受伤。
	for freeze_required_gate in [false, true]:
		game = new_game()
		d = game.get_node("DungeonTest")
		var required_gate: Node3D = d.get_node("Gates/CourtyardWestSeal")
		if freeze_required_gate:
			required_gate.freeze_gate()
		else:
			required_gate.queue_free()
			await process_frame
		game._on_run_started()
		game.get_node("DungeonTest").request_tutorial_skip()
		d.get_node("Player").position = Vector3(0, 0.05, -23)
		await frames()
		progress = d.get_node("RoomProgress")
		enemy = d.get_node("MeleeEnemy")
		var condition := "冻结" if freeze_required_gate else "移除"
		check(progress.get_room_state(&"l1_crossroads") == progress.RoomState.UNVISITED, "必需门%s时拒绝激活房间" % condition)
		check(not enemy.can_process() and not enemy.take_damage(1), "必需门%s时守卫保持休眠" % condition)
		game.queue_free()
		await process_frame

	# 使用真实区域、进度控制器和敌人场景，确认错误配置失败时保持休眠。
	game = new_game()
	d = game.get_node("DungeonTest")
	var extra_enemy: Node = load("res://scenes/enemies/MeleeEnemy.tscn").instantiate()
	d.add_child(extra_enemy)
	progress = d.get_node("RoomProgress")
	progress.define_room(&"invalid_seals", [], &"enemies")
	var encounter: Node = load("res://scenes/dungeon/components/combat_room_encounter.gd").new()
	d.add_child(encounter)
	check(not encounter.configure(d.get_node("Player"), d.get_node("Regions/Crossroads"), progress, &"invalid_seals", [extra_enemy], []), "无必需门的配置失败")
	game._on_run_started()
	game.get_node("DungeonTest").request_tutorial_skip()
	check(not extra_enemy.can_process(), "无必需门的配置仍保持敌人休眠")
	game.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("GATE_INTEGRATION: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
