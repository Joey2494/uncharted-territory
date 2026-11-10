extends SceneTree
## 独立验证顺序门的真实物理阻挡、暂停与终局取消，不依赖整关敌人接线。

const GATE_PATH := "res://scenes/dungeon/components/ProgressionGate.tscn"
var checks := 0
var failures := 0
var started_ids: Array[StringName] = []
var opened_ids: Array[StringName] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ", message)

func wait_physics() -> void:
	await physics_frame
	await physics_frame

func blocked(world: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 1.5, 2), Vector3(0, 1.5, -2), 1)
	return not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## 用 CharacterBody 的真实扫掠移动验证门，覆盖玩家/敌人共同依赖的墙体层。
func make_actor(world: Node3D) -> CharacterBody3D:
	var actor := CharacterBody3D.new()
	actor.collision_layer = 2
	actor.collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	collider.shape = capsule
	actor.add_child(collider)
	world.add_child(actor)
	actor.position = Vector3(0, 1, 2)
	return actor

func run() -> void:
	if not ResourceLoader.exists(GATE_PATH):
		check(false, "顺序门场景必须存在并实现物理开门生命周期")
		finish()
		return
	var scene: PackedScene = load(GATE_PATH)
	var world := Node3D.new()
	root.add_child(world)
	var gate = scene.instantiate()
	gate.gate_id = &"test_gate"
	gate.locked_message = "清除测试守卫"
	check(not gate.open_gate(), "未进入场景树时拒绝开门")
	world.add_child(gate)
	gate.opening_started.connect(func(id: StringName): started_ids.append(id))
	gate.opened.connect(func(id: StringName):
		opened_ids.append(id)
		check(not blocked(world), "opened 事件时物理通路已真正开放")
	)
	var actor := make_actor(world)
	await wait_physics()
	check(gate is StaticBody3D, "门是实体 StaticBody3D")
	check(gate.state == gate.State.CLOSED and not gate.is_open(), "初态锁定")
	check(gate.is_in_group("camera_occluders"), "门支持相机遮挡淡化")
	check(gate.get_node("Visuals/LockedLabel").text == "清除测试守卫", "锁定提示使用配置文本")
	check(blocked(world), "锁定门阻挡近战与弹体所用墙体射线")
	actor.move_and_collide(Vector3(0, 0, -4))
	check(actor.position.z > 0.3, "高速实体移动不能穿过锁门")
	check(gate.open_gate(), "第一次开门请求接受")
	check(not gate.open_gate(), "动画中重复请求拒绝")
	check(started_ids == [&"test_gate"], "开门开始事件只发一次且携带稳定 ID")
	check(blocked(world), "动画开始仍保留完整碰撞")
	await create_timer(0.2).timeout
	check(gate.get_node("Visuals").position.y > 0.0, "顺序门向上升起")
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var paused_height: float = gate.get_node("Visuals").position.y
	await create_timer(1.0).timeout
	check(is_equal_approx(gate.get_node("Visuals").position.y, paused_height), "祖先暂停冻结门体动画")
	check(gate.state == gate.State.OPENING and opened_ids.is_empty(), "暂停不提前宣布开放")
	check(blocked(world), "暂停中的开门仍有物理阻挡")
	world.process_mode = Node.PROCESS_MODE_INHERIT
	await create_timer(1.0).timeout
	await wait_physics()
	check(gate.is_open() and opened_ids == [&"test_gate"], "恢复后只完成一次")
	check(not gate.open_gate(), "完全打开后拒绝重复请求")
	check(not gate.get_node("Visuals").visible and gate.visible, "隐藏完整视觉与标签但保留根节点")
	check(not blocked(world), "开门后射线可以通过")
	actor.position = Vector3(0, 1, 2)
	actor.move_and_collide(Vector3(0, 0, -4))
	check(actor.position.z < -1.9, "开门后实体可通行")
	gate.queue_free()
	await process_frame
	gate = scene.instantiate()
	world.add_child(gate)
	await wait_physics()
	check(gate.state == gate.State.CLOSED and blocked(world), "重新实例化恢复锁定和碰撞")
	check(gate.get_node("Visuals").visible, "重新实例化恢复完整视觉")
	gate.opened.connect(func(id: StringName): opened_ids.append(id))
	world.process_mode = Node.PROCESS_MODE_DISABLED
	check(not gate.open_gate(), "已暂停的世界拒绝新开门请求")
	world.process_mode = Node.PROCESS_MODE_INHERIT
	check(gate.open_gate(), "新实例可正常开始")
	await create_timer(0.2).timeout
	gate.cancel_opening()
	await create_timer(1.0).timeout
	await wait_physics()
	check(gate.state == gate.State.CLOSED and blocked(world), "取消恢复锁定与实体碰撞")
	check(gate.get_node("Visuals").visible and is_zero_approx(gate.get_node("Visuals").position.y), "取消恢复初始视觉")
	check(opened_ids.size() == 1, "取消后旧 Tween 不发出 opened")
	gate.cancel_opening()
	check(gate.state == gate.State.CLOSED, "重复取消保持锁定")
	gate.hide()
	check(not gate.open_gate(), "隐藏的异常门状态拒绝开门")
	gate.show()
	gate.opening_duration = 0.01
	check(gate.open_gate(), "短动画仍经过完整开放生命周期")
	# 捕获视觉完成、物理确认尚未发出 opened 的窗口，检验异步回调代际保护。
	while gate.get_node("Visuals").visible:
		await process_frame
	check(gate.state == gate.State.OPENING, "隐藏门体不等于物理开放完成")
	gate.cancel_opening()
	await wait_physics()
	await wait_physics()
	check(gate.state == gate.State.CLOSED and blocked(world), "物理确认前取消也恢复碰撞")
	check(opened_ids.size() == 1, "物理确认前取消不遗留 opened 回调")
	gate.opening_duration = 0.2
	check(gate.open_gate(), "取消后仍可接受新的有效请求")
	await create_timer(0.05).timeout
	paused = true
	paused_height = gate.get_node("Visuals").position.y
	await create_timer(0.3).timeout
	check(is_equal_approx(gate.get_node("Visuals").position.y, paused_height), "SceneTree 暂停冻结门动画")
	check(gate.state == gate.State.OPENING and opened_ids.size() == 1, "SceneTree 暂停不会发出 opened")
	paused = false
	await create_timer(0.3).timeout
	await wait_physics()
	check(gate.is_open() and opened_ids.size() == 2, "SceneTree 恢复后可完成新一轮开门")
	# G02 一类复合门先被授权进度，再临时战斗闭锁；反向动画从当前高度续接。
	check(gate.set_combat_locked(true), "开放后可施加战斗锁")
	await create_timer(0.07).timeout
	check(gate.state == gate.State.CLOSING and blocked(world), "门下降时已阻挡射线")
	var reversal_height: float = gate.get_node("Visuals").position.y
	check(gate.set_combat_locked(false), "战斗结束释放战斗锁")
	check(is_equal_approx(gate.get_node("Visuals").position.y, reversal_height), "反向动画不跳变")
	await create_timer(0.25).timeout
	await wait_physics()
	check(gate.is_open() and opened_ids.size() == 3, "反向开门废弃旧下降回调")
	gate.queue_free()
	await process_frame
	gate = scene.instantiate()
	gate.opening_duration = 0.08
	world.add_child(gate)
	check(gate.set_combat_locked(true) and gate.open_gate(), "闭锁中接受进度开门授权")
	await create_timer(0.15).timeout
	check(not gate.is_open() and blocked(world), "战斗锁仍阻止门开启")
	check(gate.set_combat_locked(false), "可单独释放战斗锁")
	await create_timer(0.2).timeout
	await wait_physics()
	check(gate.is_open() and not blocked(world), "两个锁均解除才开放")
	world.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("GATE_LIFECYCLE: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
