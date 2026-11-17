extends RefCounted
## A read-only view of the real map, enemy roster and puzzle states.
const PUZZLE = preload("res://scenes/puzzles/energy_relay/energy_relay_puzzle.gd")

static func read(world: Node3D) -> Dictionary:
	var room: StringName = world.get_current_room_id()
	var progress: Node = world.progress
	var puzzle: Node = world.puzzle
	var state: int = puzzle.get_state()
	var completed: Array[String] = []
	for id in [world.HUB,world.RELAY,world.ANTECHAMBER,world.BOSS]:
		if progress.is_complete(id): completed.append(String(id))
	if world.relay_activated: completed.append("relay")
	if world.shortcut_unlocked: completed.append("shortcut")
	if puzzle.is_maintenance_connected(): completed.append("maintenance")
	if state >= PUZZLE.State.OPENING: completed.append("routing")
	if state == PUZZLE.State.CLAIMED: completed.append("reward")
	var status := {"id":"", "title":"", "category":"当前任务",
		"progress":"探索 %d/%d" % [world.get_visited_count(),world.get_room_count()], "completed":completed}
	if room in [world.ARCHIVE,world.VAULT]:
		status.category = "支线任务"
		status.id = "puzzle:%d" % state
		match state:
			PUZZLE.State.SUPPLY_OFF:
				status.title = "启动回廊主供能"
				status.progress = "未供电"
			PUZZLE.State.READY:
				status.title = "为双接收器供能" if puzzle.is_maintenance_connected() else "过桥接通检修线"
				status.progress = "门锁 %d/2" % [puzzle.get_core_count(&"a") + puzzle.get_core_count(&"b")]
			PUZZLE.State.OPENING:
				status.title = "等待密室开启"
				status.progress = "开启中"
			PUZZLE.State.OPEN:
				status.title = "领取密室奖励"
				status.progress = "待领取"
			PUZZLE.State.CLAIMED:
				status.category = "当前任务"
				status.title = "返回主路继续探索"
				status.progress = "支线完成"
		return status
	if room == world.BOSS and not progress.is_complete(room):
		status.id = "boss"
		status.title = "击败" + (world.boss.boss_name if is_instance_valid(world.boss) else "大厅首领")
		status.progress = "0/1"
		return status
	if room in [world.HUB,world.RELAY,world.ANTECHAMBER] and not progress.is_complete(room):
		status.id = "combat:"+String(room)
		status.title = {world.HUB:"肃清中庭守卫",world.RELAY:"肃清导能守卫",world.ANTECHAMBER:"肃清前厅守卫"}[room]
		var total: int = progress.get_total_enemies(room)
		status.progress = "%d/%d" % [total-progress.get_remaining_enemies(room),total]
		return status
	if progress.is_complete(world.BOSS):
		status.id = "exit"
		status.title = "前往遗迹出口"
		status.progress = "出口已开启" if world.get_node("Gates/BossNorth").is_open() else "通路开启中"
	elif world.relay_activated:
		status.id = "travel:boss"
		status.title = "前往灾厄大厅" if progress.is_complete(world.ANTECHAMBER) else "进入共鸣前厅"
	elif progress.is_complete(world.RELAY):
		status.id = "activate:relay"
		status.title = "启动导能核心"
		status.progress = "待激活"
	elif progress.is_complete(world.HUB):
		status.id = "travel:relay"
		status.title = "前往导能回廊"
	else:
		status.id = "travel:hub"
		status.title = "前往分流中庭"
	return status
