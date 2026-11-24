extends RefCounted
## Physical floor plans and the journal's current location. Never executes a task.
const TIDE = preload("res://scenes/dungeon/level03/tide_layout.gd")
const OBSERVATORY = preload("res://scenes/dungeon/level04/observatory_plan.gd")

static func clean_name(value: String) -> String:
	var parts := value.split(" · ",true,1)
	return parts[1] if parts.size() == 2 and parts[0].length() == 1 else value

static func read(world: Node3D, status: Dictionary, level: int) -> Dictionary:
	var player: Node3D = world.get_node("Player")
	var rooms: Array[Dictionary] = []
	var paths: Array[Dictionary] = []
	var locks: Array[Dictionary] = []
	if level == 4:
		for id: String in OBSERVATORY.CENTERS:
			rooms.append({"id":id,"name":OBSERVATORY.NAMES[id],"bounds":OBSERVATORY.bounds(id),"visited":world.visited.has(id),"optional":id in OBSERVATORY.OPTIONAL})
		for link: String in OBSERVATORY.LINKS:
			var a := link.substr(0,1)
			var b := link.substr(1,1)
			var points := OBSERVATORY.bridge_path(a,b)
			var segment := OBSERVATORY.gate_segment(points)
			var opened: bool = world.layout.passage_open(a,b)
			var rect := Rect2(points[0],Vector2.ZERO)
			for point in points: rect = rect.expand(point)
			paths.append({"id":link,"points":points,"bounds":rect.grow(2),"open":opened,"optional":a in OBSERVATORY.OPTIONAL or b in OBSERVATORY.OPTIONAL})
			locks.append({"point":points[segment].lerp(points[segment+1],0.5),"open":opened,"reason":world.passage_lock_reason(link),"id":link})
	elif level == 3:
		for id in TIDE.ROOMS:
			var node: Node3D = world.get_node("Rooms/"+String(id))
			rooms.append({"id":String(id),"name":TIDE.ROOM_NAMES[id],"bounds":node.get_world_bounds(),"visited":id in world._visited,"optional":id == &"H"})
		for id in TIDE.ROUTES:
			var barrier: Node3D = world.get_node_or_null("Barriers/"+String(id))
			var opened: bool = barrier.is_open() if barrier != null and barrier.has_method("is_open") else (not barrier.get_node("View").visible if barrier != null else true)
			for rect: Rect2 in TIDE.ROUTES[id]: paths.append({"id":String(id),"bounds":rect,"open":opened,"optional":id in [&"FH",&"ID"]})
		for group in [world.get_node("Barriers"),world.get_node("CombatGates")]:
			for gate in group.get_children():
				var opened: bool = gate.is_open() if gate.has_method("is_open") else not gate.get_node("View").visible
				locks.append({"point":_point(gate),"open":opened})
	else:
		for region in world.get_node("Regions").get_children():
			# Do not reveal the castle's concealed corridor or reward room early.
			if not region.visible: continue
			if not region.exploration_room:
				paths.append({"id":String(region.name),"bounds":region.get_world_bounds(),"open":true,"optional":region.optional_branch})
			else:
				var visited: bool = world._visited.has(region.name) if level == 1 else world._visited.has(world._room_ids.get(region,&""))
				rooms.append({"id":String(region.name),"name":clean_name(region.display_name),"bounds":region.get_world_bounds(),"visited":visited,"optional":region.optional_branch})
		for gate in world.get_node("Gates").get_children(): locks.append({"point":_point(gate),"open":gate.is_open()})
		if level == 1: locks.append({"point":_point(world.get_node("ExitGate")),"open":world.is_exit_open()})
	var target := goal(world,status,level)
	var bounds := Rect2(_point(player),Vector2.ONE)
	var location := "连接通道"
	for room in rooms:
		bounds = bounds.merge(room.bounds)
		if room.bounds.has_point(_point(player)): location = room.name
	for path in paths: bounds = bounds.merge(path.bounds)
	return {"rooms":rooms,"paths":paths,"locks":locks,"player":_point(player),"location":location,"target":target,"bounds":bounds.grow(3),"observatory":level == 4}

static func goal(world: Node3D, status: Dictionary, level: int) -> Dictionary:
	if status.is_empty() or status.get("complete",false): return {}
	var task: Dictionary = status.get("focus",status.tasks[status.current])
	var id: String = task.id
	var destinations: Dictionary
	if level == 4:
		if id == "wings":
			return {"id":id,"name":"东翼 / 西翼","point":OBSERVATORY.CENTERS.E,"action":task.target,"quantity":"任选先后","markers":[{"id":"E","point":OBSERVATORY.CENTERS.E},{"id":"F","point":OBSERVATORY.CENTERS.F}]}
		var room: String = {"combat_B":"B","calibrated":"E","combat_F":"F","combat_H":"H","combat_I":"I","gate":"J","exit":"J"}.get(id,"")
		return {"id":id,"name":OBSERVATORY.NAMES[room],"point":OBSERVATORY.CENTERS[room],"action":task.title,"quantity":"%d/%d" % [task.count,task.total]} if not room.is_empty() else {}
	elif level == 1:
		destinations = {"courtyard":["Regions/Crossroads","回廊中庭"],"guard":["Regions/Crossroads","回廊中庭"],"hall":["Regions/BossArena","守门者大厅"],"boss":["Regions/BossArena","守门者大厅"],"gate":["ExitGate","守门者大厅 · 出口闸门"],"exit":["ExitTrigger","归途出口"]}
	elif level == 2:
		destinations = {"hub_arrival":["Regions/Hub","分流中庭"],"hub":["Regions/Hub","分流中庭"],"relay_arrival":["Regions/Relay","导能回廊"],"relay_guards":["Regions/Relay","导能回廊"],"relay":["Devices/Relay","导能回廊 · 导能核心"],"ante_arrival":["Regions/Antechamber","共鸣前厅"],"ante":["Regions/Antechamber","共鸣前厅"],"boss_arrival":["Regions/Boss","巨蝎大厅"],"boss":["Regions/Boss","巨蝎大厅"],"gate":["Gates/BossNorth","巨蝎大厅 · 北侧出口闸门"],"exit":["ExitArea","出口"]}
	else:
		destinations = {"control":["Stations/tide","中央潮井 · 潮位总控"],"c_guards":["Rooms/C","沉沙库"],"conductor":["Stations/conductor","沉沙库 · 导体托架"],"east":["Stations/director","折流廊 · 折流导向台"],"high":["Stations/tide","中央潮井 · 潮位总控"],"e_guards":["Rooms/E","浮栈战区"],"f_guards":["Rooms/F","蓄能工房"],"charge":["Stations/charge","蓄能工房 · 蓄能器"],"highwalk":["Stations/highwalk","蓄能工房 · 维修手柄"],"low":["Stations/tide","中央潮井 · 潮位总控"],"west":["Stations/director","折流廊 · 折流导向台"],"release":["Stations/release","干涸维修井 · 泄压装置"],"g_guards":["Rooms/G","中心闸庭"],"gate":["Barriers/GJ","远航出口 · 闸门"],"exit":["Rooms/ExitTrigger","远航出口"],"lower_first":["Stations/tide","中央潮井 · 潮位总控"]}
	if level == 3:
		destinations["i_guards"] = ["Rooms/I","干涸维修井"]
	if not destinations.has(id): return {}
	var entry: Array = destinations[id]
	var node: Node3D = world.get_node_or_null(entry[0])
	return {"id":id,"name":entry[1],"point":_point(node),"action":task.title,"quantity":"%d/%d" % [task.count,task.total]} if node != null else {}

static func _point(node: Node3D) -> Vector2:
	return Vector2(node.global_position.x,node.global_position.z)
