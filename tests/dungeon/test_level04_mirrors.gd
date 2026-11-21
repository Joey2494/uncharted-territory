extends SceneTree
## 使用真实输入和碰撞走过主线、支线与密室；两次开局使用相同的初始机关。
const PREVIEW := "res://scenes/dungeon/level04/Level04Preview.tscn"
var level: Node
var player: CharacterBody3D
var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", title)

func frames(n: int) -> void:
	for _i in n: await physics_frame

func walk(x: float, z: float) -> void:
	var goal := Vector2(x, z)
	for _i in 450:
		var offset := goal - Vector2(player.position.x, player.position.z)
		if offset.length() < 0.23: break
		var dir := offset.normalized()
		for pair in [["move_left", -dir.x], ["move_right", dir.x], ["move_forward", -dir.y], ["move_backward", dir.y]]:
			if pair[1] > 0:
				Input.action_press(pair[0], pair[1])
			else:
				Input.action_release(pair[0])
		await physics_frame
	for action in ["move_left","move_right","move_forward","move_backward"]: Input.action_release(action)
	check(Vector2(player.position.x, player.position.z).distance_to(goal) < 0.35 and player.position.y > -0.5, "可步行到达 " + str(goal))

func interact() -> void:
	check(player.get_node("ItemInventory").try_interact_nearest(), "最近目标 E 交互")

func start() -> void:
	paused = false
	change_scene_to_file(PREVIEW)
	await frames(6)
	level = current_scene
	player = level.get_node("Player")

func run() -> void:
	if not ResourceLoader.exists(PREVIEW):
		printerr("FAIL fourth preview missing")
		quit(1)
		return
	await start()
	await walk(0, -6.0)
	Input.action_press("move_forward")
	await frames(65)
	Input.action_release("move_forward")
	check(player.position.z > -8, "关闭的主门阻挡角色")
	await walk(0, 5.2)
	await walk(-2.5, 5.2)
	interact()
	await frames(70)
	await walk(0, 0)
	await walk(0, -13.5)
	check(level.finished and not level.reward_claimed(), "跳过密室可抵达出口")
	await start()
	await walk(0, 5.2)
	await walk(-2.5, 5.2)
	interact()
	await walk(0, 0)
	await walk(11, 0)
	await walk(15, 0.8)
	check(not level.inscription_lit and not level.vault_open(), "起始时铭文与密室均关闭")
	# 顺着初始光路先试接收器：光打在遮罩上，仍然不能打开柜门。
	await walk(15, -2.8)
	interact()
	check(not level.inscription_lit and not level.vault_open() and not level._solved, "显影前瞄准透镜仍锁定")
	await walk(20, -5.8)
	Input.action_press("move_forward")
	await frames(65)
	Input.action_release("move_forward")
	check(player.position.z > -7 and not level.reward_claimed(), "柜门实体阻挡且不可提前领奖")
	await walk(20, 0.8)
	await walk(15, 0.8)
	# 甲镜初始朝北，经过两个背面方向，再转至南壁。
	for _i in 2: interact()
	check(not level.inscription_lit, "镜背不能反射光")
	interact()
	check(level.inscription_lit and not level._solved, "光照南壁显影，未直接开门")
	# 调偏乙镜，再调甲镜指向北方。错误状态可通过继续旋转恢复。
	await walk(15, -2.8)
	interact()
	await walk(15, 0.8)
	interact()
	check(not level._solved, "只调对一面镜子不能解锁")
	await walk(15, -2.8)
	for _i in 3: interact()
	check(level._solved and not level.vault_open() and not level.station_available(&"claim"), "门完成升起前不能领奖")
	await frames(75)
	check(level.vault_open(), "经两镜正确反射后，门完成升起")
	await walk(20, -2.8)
	await walk(20, -8.8)
	interact()
	check(level.reward_claimed(), "进入领奖隔间获取奖励")
	var count: int = player.get_node("ItemInventory").rune_count
	player.get_node("ItemInventory").try_interact_nearest()
	check(player.get_node("ItemInventory").rune_count == count, "重复领取不加奖")
	await walk(20, 0)
	await walk(0, 0)
	await walk(0, -13.5)
	check(level.finished and level.reward_claimed(), "支线可返回主路并结算")
	print("level04 mirror paths: %d checks / %d failed" % [checks, failures])
	paused = false
	quit(1 if failures else 0)
