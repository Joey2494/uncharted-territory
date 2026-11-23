extends RefCounted
## Read-only first-level journal. Nothing here activates rooms, opens gates or grants rewards.

static func read(world: Node3D) -> Dictionary:
	var progress: Node = world.get_node("RoomProgress")
	var puzzle: Node = world.get_node("RunePuzzle")
	var courtyard_reached: bool = progress.get_room_state(&"l1_crossroads") > 0
	var boss_reached: bool = progress.get_room_state(&"l1_boss") > 0
	var guard_total: int = progress.get_total_enemies(&"l1_crossroads")
	var guards_defeated: int = guard_total-progress.get_remaining_enemies(&"l1_crossroads")
	var boss_total: int = progress.get_total_enemies(&"l1_boss")
	var bosses_defeated: int = boss_total-progress.get_remaining_enemies(&"l1_boss")
	var boss: Node = world.get_node_or_null("RuinGatekeeper")
	var boss_name: String = boss.boss_name if is_instance_valid(boss) else "遗迹守门者"
	var tasks: Array[Dictionary] = [
		_task("courtyard","穿过北门进入回廊中庭","穿过入口大厅北门，沿北侧走廊进入回廊中庭",int(courtyard_reached),1,courtyard_reached),
		_task("guard","击败中庭守卫","在回廊中庭击败 %d 名守卫，解除东侧主路封锁" % guard_total,guards_defeated,guard_total,progress.is_complete(&"l1_crossroads")),
		_task("hall","进入东侧守门者大厅","穿过中庭东侧主路闸门，进入守门者大厅",int(boss_reached),1,boss_reached),
		_task("boss","击败"+boss_name,"在守门者大厅击败 %s，共 %d 名" % [boss_name,boss_total],bosses_defeated,boss_total,progress.is_complete(&"l1_boss")),
		_task("gate","等待北侧出口闸门升起","等待北侧出口闸门完全升起后再通过",int(world.is_exit_open()),1,world.is_exit_open()),
		_task("exit","穿过归途出口","沿出口走廊进入归途出口，完成本关",int(world._exit_announced),1,world._exit_announced),
	]
	var targets := ["抵达回廊中庭 ×1","击败中庭守卫 ×%d" % guard_total,"进入守门者大厅 ×1","击败%s ×%d" % [boss_name,boss_total],"等待出口闸门开启 ×1","穿过归途出口 ×1"]
	for i in tasks.size(): tasks[i].target = targets[i]
	if not courtyard_reached and not world.get_node("Gates/EntranceGate").is_open():
		tasks[0].detail = "入口北门正在升起；开启后沿北侧走廊进入回廊中庭"
	if progress.is_complete(&"l1_crossroads") and not boss_reached and not world.get_node("Gates/CourtyardGate").is_open():
		tasks[2].detail = "中庭东侧主路闸门正在升起；开启后进入守门者大厅"
	var current := tasks.size()
	var completed: Array[String] = []
	for i in tasks.size():
		if tasks[i].done: completed.append(tasks[i].id)
		elif current == tasks.size(): current = i
	var optional: Array[Dictionary] = [
		_task("runes","观察石刻与符文图案","观察门楣石刻，对照 %d 块符文石的图案" % puzzle.CORRECT_SEQUENCE.size(),int(puzzle.progress),puzzle.CORRECT_SEQUENCE.size(),puzzle.is_solved()),
		_task("chest","开启密室奖励宝箱","[E] 开启暗门后的奖励宝箱 ×1",int(puzzle.is_reward_claimed()),1,puzzle.is_reward_claimed()),
	]
	if puzzle.state == puzzle.State.RESETTING: optional[0].detail = "顺序错误，等待符文复位后重试"
	elif puzzle.state == puzzle.State.OPENING: optional[0].detail = "符文已点亮，等待密室暗门开启"
	var region: Node3D = world.get_region_at(world.get_node("Player").global_position)
	var in_branch := is_instance_valid(region) and region.name in [&"SupplyChamber",&"SecretPassage",&"HiddenRewardRoom"]
	return {"tasks":tasks,"current":current,"completed":completed,"complete":current == tasks.size(),
		"optional":optional,"show_optional":in_branch or puzzle.is_solved()}

static func _task(id: String, title: String, detail: String, count: int, total: int, done: bool) -> Dictionary:
	return {"id":id,"title":title,"detail":detail,"count":count,"total":total,"done":done}
