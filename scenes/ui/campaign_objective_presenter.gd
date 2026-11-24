extends RefCounted
## Read-only journals for the existing campaign maps. No progression commands.
const LEGACY = preload("res://scenes/ui/objective_presenter.gd")

static func read(world: Node3D) -> Dictionary:
	var result := _fourth(world) if world.has_method("optional_count") else (_third(world) if world.has_method("get_storage_state") else _second(world))
	var completed: Array[String] = []
	var current: int = result.tasks.size()
	for i in result.tasks.size():
		if result.tasks[i].done: completed.append(result.tasks[i].id)
		elif current == result.tasks.size(): current = i
	# A live encounter takes precedence even if the player approached out of order.
	for i in result.tasks.size():
		if result.tasks[i].get("active",false) and not result.tasks[i].done:
			current = i
			break
	result.current = current
	result.completed = completed
	result.complete = completed.size() == result.tasks.size()
	if world.has_method("optional_count") and world.combat.is_clear("B") and world.combat.active_room == "":
		if not world.puzzles.calibrated and not world.combat.is_clear("F"):
			result.focus = _task("wings","从分度大厅选择一翼","东翼观察试片并校准曝光柜；西翼清除折光栈道守卫。完成任一目标即可过横桥。","校准曝光柜 · 清除栈道守卫",0,2,false)
	if world.has_method("get_storage_state") and not result.complete and world._active_room == &"":
		if world._high and world._storage == world.Storage.EMPTY and result.current in [1,2,3]:
			result.focus = _task("lower_first","检查中央潮井的潮位总控","返回中央潮井，观察水路与石刻，在潮位总控尝试调节通路","[E] 检查潮位总控 ×1",0,1,false)
	result.context = _context(world)
	return result

static func _context(world: Node3D) -> Dictionary:
	var context: Dictionary = LEGACY.read(world).duplicate(true)
	if world.has_method("optional_count"): return context
	if world.has_method("get_storage_state"):
		var conductor: String = ["导体在沉沙库","导体已取用","导体接入蓄能工房","导体接入维修井"][world._conductor]
		var energy: String = ["未蓄能","已蓄能","已泄压"][world._storage]
		context.resource_summary = "%s · %s\n%s" % ["高水位" if world._high else "低水位",conductor,energy]
	elif world.get_current_room_id() in [world.ARCHIVE,world.VAULT]:
		match world.puzzle.get_state():
			0: context.title = "检查断流档案室供能"
			1: context.title = "观察档案室机关与线路"
			2: context.title = "等待奖励密室暗门开启"
			3: context.title = "进入奖励密室领取奖励"
			4: context.title = "断流档案室奖励已领取"
	return context

static func _fourth(world: Node3D) -> Dictionary:
	var combat: Node = world.combat
	var tasks: Array[Dictionary] = []
	for room: String in ["B", "F", "H", "I"]:
		if room == "F":
			tasks.append(_task("calibrated", "校准东翼曝光柜", "到东翼曝光记录室观察曝光轮与试片。栈道清场后，可从横桥进入并使用对照片灯。", "校准曝光记录室密码柜 ×1", int(world.puzzles.calibrated), 1, world.puzzles.calibrated))
		var done: bool = combat.is_clear(room)
		var total: int = combat.ROSTERS[room].size() + (1 if combat.REINFORCEMENTS.has(room) else 0)
		var count := total if done else 0
		if combat.active_room == room:
			count = total - combat.enemy_count() - int(combat.REINFORCEMENTS.has(room) and not combat._reinforced)
		var hints := {"B":"从到达台向北进入装卸场，清场后前往分度大厅。","F":"从分度大厅西门或东翼横桥进入折光栈道。跨入内场后，清除守卫及增援。","H":"双翼已就绪。东西试车门均可进入，先在入口观察扫光，再跨线作战。","I":"直走穹顶或经底片室绕行。进门后可先领邮包，越过门廊再迎战女巫与近卫。"}
		var task := _task("combat_" + room, "清除" + world.NAMES[room] + "守卫", hints[room], "击败守卫 ×%d" % total, maxi(0, count), total, done)
		task.active = combat.active_room == room
		tasks.append(task)
	tasks.append(_task("gate", "等待北侧升降台通路开启", "清除主穹顶完整守卫名单后，等待实体闸门完全开启", "等待北侧闸门开启 ×1", int(world.is_exit_open()), 1, world.is_exit_open()))
	tasks.append(_task("exit", "登上北侧升降台", "穿过主穹顶北门，到升降台中央离站", "抵达升降台中央 ×1", int(world.won), 1, world.won))
	return {"tasks": tasks, "chapter": "穿越日晷观测站", "ending": "已登上北侧升降台，完成观测站主线"}

static func _task(id: String, title: String, detail: String, target: String, count: int, total: int, done: bool) -> Dictionary:
	return {"id":id,"title":title,"detail":detail,"target":target,"count":count,"total":total,"done":done}

static func _arrival(world: Node, progress: Node, room: StringName, id: String, title: String, detail: String, target: String) -> Dictionary:
	var reached: bool = progress.get_room_state(room) > 0
	return _task(id,title,detail,target,int(reached),1,reached)

static func _battle(progress: Node, room: StringName, id: String, title: String, target: String) -> Dictionary:
	var total: int = progress.get_total_enemies(room)
	var task := _task(id,title,"击败本室的 %d 名敌人，解除通路封锁" % total,target,total-progress.get_remaining_enemies(room),total,progress.is_complete(room))
	task.active = progress.get_room_state(room) == 1
	return task

static func _second(world: Node3D) -> Dictionary:
	var p: Node = world.progress
	var boss_name: String = world.boss.boss_name if is_instance_valid(world.boss) else "灾厄巨蝎"
	var tasks: Array[Dictionary] = [
		_arrival(world,p,world.HUB,"hub_arrival","穿过北门进入分流中庭","从到达平台沿北侧通道进入分流中庭","进入分流中庭 ×1"),
		_battle(p,world.HUB,"hub","击败分流中庭守卫","击败中庭守卫 ×%d" % p.get_total_enemies(world.HUB)),
		_arrival(world,p,world.RELAY,"relay_arrival","进入东侧导能回廊","穿过中庭东侧闸门，进入导能回廊","进入导能回廊 ×1"),
		_battle(p,world.RELAY,"relay_guards","击败导能回廊守卫","击败导能守卫 ×%d" % p.get_total_enemies(world.RELAY)),
		_task("relay","启动导能核心","在导能回廊靠近导能核心，按 E 启动主路供能","[E] 启动导能核心 ×1",int(world.relay_activated),1,world.relay_activated),
		_arrival(world,p,world.ANTECHAMBER,"ante_arrival","进入共鸣前厅","沿导能回廊北侧主路进入共鸣前厅","进入共鸣前厅 ×1"),
		_battle(p,world.ANTECHAMBER,"ante","击败共鸣前厅守卫","击败前厅守卫 ×%d" % p.get_total_enemies(world.ANTECHAMBER)),
		_arrival(world,p,world.BOSS,"boss_arrival","进入北侧巨蝎大厅","穿过前厅北侧闸门，进入巨蝎大厅","进入巨蝎大厅 ×1"),
		_battle(p,world.BOSS,"boss","击败"+boss_name,"击败%s ×%d" % [boss_name,p.get_total_enemies(world.BOSS)]),
		_task("gate","等待北侧出口闸门升起","闸门完全开启后，再沿北侧通道前往出口","等待出口闸门开启 ×1",int(world.is_exit_open()),1,world.is_exit_open()),
		_task("exit","穿过北侧遗迹出口","沿北侧出口通道进入出口，离开本关","穿过遗迹出口 ×1",int(world._exit_recorded),1,world._exit_recorded),
	]
	return {"tasks":tasks,"chapter":"穿越蜘蛛巢穴","ending":"已穿过遗迹出口，成功离开蜘蛛巢穴"}

static func _third(world: Node3D) -> Dictionary:
	var p: Node = world._progress
	var charged: bool = world._storage >= world.Storage.STORED
	var released: bool = world._storage == world.Storage.RELEASED
	var obtained: bool = world._conductor != world.Conductor.RACK
	var east: bool = world._conductor == world.Conductor.EAST or charged
	var west: bool = world._conductor == world.Conductor.WEST or released
	var high: bool = (world._high and east) or charged
	var lowered: bool = (charged and not world._high) or released
	var reached: bool = &"B" in world._visited
	var boss: Node = world.get_campaign_boss()
	var boss_name: String = boss.boss_name if is_instance_valid(boss) else "沙缚王"
	var tasks: Array[Dictionary] = [
		_task("control","进入中央潮井","从入口检修台前往中央潮井，找到潮位总控","找到中央潮井潮位总控 ×1",int(reached),1,reached),
		_battle(p,&"C","c_guards","进入沉沙库，击败守卫","击败沉沙库守卫 ×%d" % p.get_total_enemies(&"C")),
		_task("conductor","在沉沙库托架取用导体","在沉沙库找到导体托架，靠近后按 E 取用导体","[E] 取用导体 ×1",int(obtained),1,obtained),
		_task("east","检查折流廊导向台","前往折流廊，观察导向台的石刻与接口符号，按 E 尝试调整连接","[E] 调整折流导向台 ×1",int(east),1,east),
		_task("high","调节中央潮井的潮位总控","返回中央潮井，观察潮位总控与浮栈变化，寻找通往浮栈战区的路线","[E] 调节潮位总控 ×1",int(high),1,high),
		_battle(p,&"E","e_guards","击败浮栈战区守卫","击败浮栈守卫 ×%d" % p.get_total_enemies(&"E")),
		_battle(p,&"F","f_guards","击败蓄能工房守卫","击败工房守卫 ×%d" % p.get_total_enemies(&"F")),
		_task("charge","检查蓄能工房的蓄能器","清除工房守卫后，观察蓄能器及周边线路，按 E 尝试操作","[E] 操作蓄能器 ×1",int(charged),1,charged),
		_task("highwalk","拉动蓄能工房维修手柄","在蓄能工房找到高架与维修门手柄，按 E 操作并观察通路变化","[E] 拉动维修手柄 ×1",int(world._highwalk),1,world._highwalk),
		_task("low","检查中央潮井的潮位总控","从蓄能工房返回中央潮井，观察水路与总控石刻，寻找维修井通路","[E] 检查潮位总控 ×1",int(lowered),1,lowered),
		_task("west","返回折流廊检查回流连接","返回折流廊，观察回流刻纹与导向台接口，按 E 尝试调整连接","[E] 检查回流连接 ×1",int(west),1,west),
		_battle(p,&"I","i_guards","清除干涸维修井的双链执刑官","击败双链执刑官 ×%d" % p.get_total_enemies(&"I")),
		_task("release","检查干涸维修井的泄压装置","前往干涸维修井，观察泄压装置与周边回流刻纹，按 E 尝试操作","[E] 操作泄压装置 ×1",int(released),1,released),
		_battle(p,&"G","g_guards","在中心闸庭击败%s" % boss_name,"击败%s ×%d" % [boss_name,p.get_total_enemies(&"G")]),
		_task("gate","等待远航出口闸门升起","最终守卫清除后，等待实体出口闸门完全开启","等待远航闸门开启 ×1",int(world.is_exit_open()),1,world.is_exit_open()),
		_task("exit","穿过远航出口","完成维修井泄压与中心闸庭清场后，穿过远航出口","穿过远航出口 ×1",int(world._exit_recorded),1,world._exit_recorded),
	]
	# Water/orientation can be reversed and all puzzle state can be reset.
	# Correct the current action instead of leaving a stale gold checkmark.
	if not released:
		if world._high and (not obtained or not east):
			var index := 2 if not obtained else 3
			tasks[index].title = "检查中央潮井的潮位总控"
			tasks[index].target = "[E] 检查潮位总控后" + ("取用沉沙库导体" if not obtained else "检查折流廊导向台")
		elif charged and world._highwalk and world._high:
			tasks[9].done = false
			tasks[9].count = 0
	return {"tasks":tasks,"chapter":"解开古墓潮汐机关","ending":"已完成泄压与最终清场，成功穿过远航出口"}
