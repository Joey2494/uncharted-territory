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
	gate.opened.connect(func(_id: StringName) -> void: opened_events += 1)
	d.exit_unlocked.connect(func() -> void: exit_events += 1)
	await create_timer(0.15).timeout
	check(not entry.is_open() and not gate.is_open(), "菜单中不能开门")
	check(not progress.is_complete(&"l1_entrance"), "菜单不完成入口")
	game._on_run_started()
	await create_timer(1.1).timeout
	check(entry.is_open(), "开始后入口门正常开启")
	check(not gate.is_open(), "开始游戏不自动开中庭门")
	p.position = Vector3(7.0, 0.05, -23)
	await frames()
	check(progress.get_room_state(&"l1_crossroads") == progress.RoomState.ACTIVE, "真实区域激活战斗房")
	p.move_and_collide(Vector3(4,0,0))
	check(p.position.x < 8.5, "玩家碰撞移动不能越过锁门")
	p.position = Vector3(7.0,0.05,-23)
	await create_timer(0.15).timeout
	Input.action_press("move_right")
	check(p.try_dodge(), "实际闪避可触发")
	await create_timer(0.28).timeout
	Input.action_release("move_right")
	check(p.position.x < 8.5, "实际闪避不能穿门")
	var bolt = load("res://scenes/skills/EnergyBolt.tscn").instantiate()
	d.add_child(bolt)
	bolt.global_position = Vector3(7,1,-23)
	var hit: Array[Node] = []
	bolt.impacted.connect(func(body: Node) -> void: hit.append(body))
	bolt.launch(Vector3.RIGHT,2,60,10,p)
	await create_timer(0.25).timeout
	check(hit.size() == 1 and hit[0] == gate, "高速法术弹体命中锁门")
	var enemy = d.get_node("MeleeEnemy")
	var enemy_start: Vector3 = enemy.position
	enemy.position = Vector3(7,0.05,-22)
	await frames()
	enemy.move_and_collide(Vector3(4,0,0))
	check(enemy.position.x < 8.5, "真实敌人不能穿门")
	enemy.position = enemy_start
	p.position = Vector3(-26,0.05,-23)
	await frames()
	check(not gate.is_open(), "探索支线不能冒充清敌")
	check(not progress.is_complete(&"l1_crossroads"), "到达多区域不影响完成状态")
	check(enemy.take_damage(999), "实际击杀中庭守卫")
	check(progress.is_complete(&"l1_crossroads"), "跨房击杀仍按出生归属完成")
	check(not gate.is_open(), "开门动画未结束不能报告可通行")
	enemy.died.emit()
	await create_timer(1.15).timeout
	check(gate.is_open() and opened_events == 1, "重复死亡只完成一次开门")
	p.position = Vector3(7,0.05,-23)
	await frames()
	p.move_and_collide(Vector3(5,0,0))
	check(p.position.x > 10, "开门后真实移动可通过")
	p.move_and_collide(Vector3(-5,0,0))
	check(p.position.x < 8, "已开放主线可退回")
	check(not d.is_exit_open(), "中庭清敌不打开Boss出口")
	p.position = Vector3(22,0.05,-23)
	await frames()
	check(progress.get_room_state(&"l1_boss") == progress.RoomState.ACTIVE, "实际进入Boss区域激活")
	var boss = d.get_node("RuinGatekeeper")
	check(boss.take_damage(999), "真实Boss死亡")
	await create_timer(1.15).timeout
	check(d.is_exit_open() and exit_events == 1, "Boss出口仅开启一次")
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
	check(d.has_node("MeleeEnemy") and not d.get_node("MeleeEnemy").is_dead(), "重开恢复敌人")
	game._on_run_started()
	p = d.get_node("Player")
	p.position = Vector3(6,0.05,-23)
	await frames()
	d.get_node("MeleeEnemy").take_damage(999)
	p.take_damage(999)
	await create_timer(1.15).timeout
	check(not d.get_node("Gates/CourtyardGate").is_open(), "死亡打断打开过程并拒绝旧回调")
	game.queue_free()
	await process_frame
	# Boss在玩家踏入大厅之前被击败，死亡动画释放实例后仍应保留正式击杀记录。
	game = new_game()
	game._on_run_started()
	d = game.get_node("DungeonTest")
	p = d.get_node("Player")
	d.get_node("MeleeEnemy").take_damage(999)
	p.position = Vector3(0,0.05,-23)
	await frames()
	boss = d.get_node("RuinGatekeeper")
	check(boss.take_damage(999), "进入Boss房前记录正式死亡")
	check(not game.get_node("UILayer/HUD").item_message.text.contains("正在解除"), "提前击杀不能错误宣告出口正在开启")
	boss.queue_free()
	await process_frame
	check(not d.is_exit_open(), "未进入Boss区域时不完成房间")
	p.position = Vector3(22,0.05,-23)
	await frames()
	await create_timer(1.15).timeout
	check(d.is_exit_open(), "Boss死亡后节点已释放仍可完成主线")
	game.queue_free()
	await process_frame
	# 与上面的真实击杀严格区分：只删除敌人，不能误认为清敌。
	game = new_game()
	game._on_run_started()
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
	print("GATE_INTEGRATION: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
