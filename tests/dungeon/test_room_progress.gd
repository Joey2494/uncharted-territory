extends SceneTree
## 房间状态单元测试：事件顺序、归属、重复死亡与缺失敌人配置。
class Enemy extends Node:
	signal died
	var dead := false
	func is_dead() -> bool: return dead
	func die() -> void:
		dead = true
		died.emit()
var checks := 0
var failures := 0
var completions: Array[StringName] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)
func run() -> void:
	var path := "res://scenes/dungeon/components/room_progress_controller.gd"
	if not ResourceLoader.exists(path):
		check(false, "房间进度控制器尚未实现")
		quit(1)
		return
	var c = load(path).new()
	root.add_child(c)
	c.room_completed.connect(func(id: StringName) -> void: completions.append(id))
	check(c.define_room(&"entry", [], &"arrival"), "定义入口")
	check(not c.define_room(&"entry", [], &"arrival"), "拒绝重复ID")
	check(not c.define_room(&"bad", [&"missing"], &"enemies"), "拒绝不存在的前置")
	check(c.define_room(&"combat", [&"entry"], &"enemies", 2), "定义战斗房")
	check(c.define_room(&"boss", [&"combat"], &"enemies", 1), "定义Boss房")
	check(not c.define_room(&"lesson", [], &"unsupported"), "拒绝未支持的房间目标")
	check(c.define_room(&"empty", [], &"enemies", 1), "空战斗房配置")
	check(c.define_room(&"deleted", [], &"enemies", 1), "异常删除用例房间")
	var a := Enemy.new()
	var b := Enemy.new()
	var boss := Enemy.new()
	var deleted := Enemy.new()
	for e in [a,b,boss,deleted]: root.add_child(e)
	check(c.register_enemy(&"combat",a), "登记第一个敌人")
	check(not c.register_enemy(&"combat",a), "拒绝重复登记")
	check(not c.register_enemy(&"boss",a), "敌人不能同时属于另一房间")
	check(c.register_enemy(&"combat",b), "登记第二个敌人")
	check(c.seal_enemy_roster(&"combat"), "完成名单登记")
	check(not c.register_enemy(&"combat",boss), "封存名单后不能加敌人")
	check(c.register_enemy(&"boss",boss), "Boss登记")
	check(c.seal_enemy_roster(&"boss"), "Boss名单封存")
	check(c.register_enemy(&"deleted",deleted), "异常删除敌人登记")
	check(c.seal_enemy_roster(&"deleted"), "异常删除名单封存")
	check(not c.seal_enemy_roster(&"empty"), "空战斗房不能正常封存")
	check(not c.activate_room(&"combat"), "入口未完成不能激活后房")
	a.die()
	check(not c.is_complete(&"combat"), "激活前死亡不能直接完成")
	check(c.activate_room(&"entry"), "激活入口")
	check(c.is_complete(&"entry"), "到达目标完成")
	check(c.activate_room(&"combat"), "前置满足后激活")
	check(c.get_remaining_enemies(&"combat") == 1, "记录激活前的有效死亡")
	a.died.emit()
	check(c.get_remaining_enemies(&"combat") == 1, "重复死亡不重复扣数")
	b.died.emit()
	check(not c.is_complete(&"combat"), "未真正死亡的信号不能清敌")
	b.die()
	check(c.is_complete(&"combat"), "清敌完成")
	c.activate_room(&"combat")
	b.died.emit()
	check(completions.count(&"combat") == 1, "回访和重复事件只完成一次")
	c.activate_room(&"empty")
	check(not c.is_complete(&"empty"), "错误零敌人房间保持未完成")
	c.activate_room(&"deleted")
	deleted.queue_free()
	await process_frame
	check(not c.is_complete(&"deleted"), "直接移除节点不算击杀")
	c.process_mode = Node.PROCESS_MODE_DISABLED
	check(not c.activate_room(&"boss"), "暂停时不能推进")
	c.process_mode = Node.PROCESS_MODE_INHERIT
	check(c.activate_room(&"boss"), "恢复后可以激活")
	c.stop_run()
	boss.die()
	check(not c.is_complete(&"boss"), "死亡终局后不推进")
	check(not c.activate_room(&"entry"), "终局拒绝新请求")
	for node in [a,b,boss,c]: node.queue_free()
	await process_frame
	print("ROOM_PROGRESS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
