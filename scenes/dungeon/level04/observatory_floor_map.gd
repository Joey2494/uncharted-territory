extends RefCounted
## Read-only snapshot: geometry, seals, devices and encounters share the live world.
const PLAN = preload("res://scenes/dungeon/level04/observatory_plan.gd")
static var _layout_id := 0
static var _floor_cache := {}

static func point(node: Node3D) -> Vector2:
	return Vector2(node.global_position.x,node.global_position.z)

static func read(world: Node3D) -> Dictionary:
	if _layout_id != world.layout.get_instance_id():
		_layout_id = world.layout.get_instance_id()
		_floor_cache.clear()
	var data := {"rooms":[],"paths":[],"locks":[],"devices":[],"enemies":[],"obstacles":[],"player":point(world.player),"location":"连接通道","target":{},"bounds":PLAN.bounds("A"),"observatory":true}
	for id: String in PLAN.CENTERS:
		var zone := ""
		if world.combat.ROSTERS.has(id):
			zone = "已清场" if world.combat.is_clear(id) else ("交战中" if world.combat.active_room == id else "敌人区域")
		data.rooms.append({"id":id,"name":PLAN.NAMES[id],"bounds":PLAN.bounds(id),"polygon":_floor_polygon(world.layout.get_node(id+"/Deck")),"visited":world.visited.has(id),"optional":id in PLAN.OPTIONAL,"done":world.optional_done(id),"zone":zone})
		data.bounds = data.bounds.merge(PLAN.bounds(id))
		_obstacles(world.layout.get_node(id),data.obstacles)
	var room: String = world.layout.room_at(world.player.position)
	if not room.is_empty(): data.location = PLAN.NAMES[room]
	for link: String in PLAN.LINKS:
		var polygon := _floor_polygon(world.layout.get_node(link+"/Deck"))
		var bounds := Rect2(polygon[0],Vector2.ZERO)
		for p in polygon: bounds = bounds.expand(p)
		data.paths.append({"id":link,"bounds":bounds,"polygon":polygon,"open":world.layout.passage_open(link[0],link[1]),"optional":link[0] in PLAN.OPTIONAL or link[1] in PLAN.OPTIONAL})
		data.bounds = data.bounds.merge(bounds)
		for lock: Dictionary in world.map_locks(link):
			lock.name = PLAN.NAMES[link[0]]+" ↔ "+PLAN.NAMES[link[1]]
			lock.reason = chinese_references(lock.reason)
			data.locks.append(lock)
		if room.is_empty() and Geometry2D.is_point_in_polygon(data.player,polygon):
			data.location = PLAN.NAMES[link[0]]+" ↔ "+PLAN.NAMES[link[1]]
	for station: Node3D in world.get_node("Stations").get_children():
		# Availability is read without can_process(): the map deliberately pauses play.
		var id := StringName(station.name)
		var available := false
		if String(id).begins_with("p_"): available = world.puzzles.available(id)
		elif String(id).begins_with("mail_"): available = world.mail.available(id)
		elif id in [&"left",&"right"]: available = world.combat.is_clear("D") and world.combat.active_room.is_empty()
		elif id == &"supply": available = not world.inventory.has_claimed("observatory_aid")
		elif id == &"shutter": available = world.combat.shutter_available()
		data.devices.append({"id":String(id),"point":point(station),"name":station.caption,"available":available})
	for enemy in world.combat._enemies + world.combat._minions:
		if is_instance_valid(enemy) and not enemy.is_dead():
			data.enemies.append({"point":point(enemy),"name":"存活敌人"})
	_obstacles(world.combat,data.obstacles)
	data.bounds = data.bounds.grow(3)
	return data

static func chinese_references(value: String) -> String:
	for pair in [["B 装卸场","折尺装卸场"],["E 曝光柜","曝光记录室曝光柜"],["F 栈道","折光栈道"],["D 吊笼","配重井吊笼"],["D 守卫","配重井守卫"],["H 试车场","百叶试车场"],["I 女巫","主穹顶女巫"],["L 灯台","夜班底片室灯台"]]:
		value = value.replace(pair[0],pair[1])
	# Letter IDs remain internal keys. Never show them as room names in the map.
	var reference := RegEx.new()
	reference.compile("\\b([A-L])(?=\\s|、|后|的|与|$)")
	var matches := reference.search_all(value)
	for index in range(matches.size()-1,-1,-1):
		var found: RegExMatch = matches[index]
		value = value.substr(0,found.get_start())+String(PLAN.NAMES[found.get_string(1)])+value.substr(found.get_end())
	return value

static func _floor_polygon(deck: Node3D) -> PackedVector2Array:
	var surface: MeshInstance3D
	for child in deck.get_children():
		if child is MeshInstance3D:
			surface = child
			break
	if surface == null: return PackedVector2Array()
	var key: int = surface.get_instance_id()
	var cached: Dictionary = _floor_cache.get(key,{})
	if cached.get("mesh") == surface.mesh.get_instance_id() and cached.get("transform") == surface.global_transform:
		return cached.polygon
	# Recover the outside boundary of the actual triangulated floor. This uses
	# the target's bent decks directly and never copies the old straight bridges.
	var vertices := {}
	var edges := {}
	var faces := surface.mesh.get_faces()
	for triangle in range(0,faces.size(),3):
		for edge in 3:
			var a: Vector3 = surface.global_transform*faces[triangle+edge]
			var b: Vector3 = surface.global_transform*faces[triangle+(edge+1)%3]
			var ka := str(Vector2i(roundi(a.x*10000),roundi(a.z*10000)))
			var kb := str(Vector2i(roundi(b.x*10000),roundi(b.z*10000)))
			vertices[ka] = Vector2(a.x,a.z)
			vertices[kb] = Vector2(b.x,b.z)
			var pair: Array = [ka,kb] if ka < kb else [kb,ka]
			var edge_key: String = pair[0]+":"+pair[1]
			if edges.has(edge_key): edges.erase(edge_key)
			else: edges[edge_key] = pair
	var neighbors := {}
	for edge: Array in edges.values():
		for index in 2:
			if not neighbors.has(edge[index]): neighbors[edge[index]] = []
			neighbors[edge[index]].append(edge[1-index])
	var polygon := PackedVector2Array()
	if neighbors.is_empty(): return polygon
	var first: String = neighbors.keys()[0]
	var current := first
	var previous := ""
	for step in neighbors.size():
		polygon.append(vertices[current])
		var next: String = neighbors[current][0]
		if next == previous: next = neighbors[current][1]
		previous = current
		current = next
		if current == first: break
	_floor_cache[key] = {"mesh":surface.mesh.get_instance_id(),"transform":surface.global_transform,"polygon":polygon}
	return polygon

static func _obstacles(node: Node, result: Array) -> void:
	if node is CollisionShape3D and node.get_parent() is StaticBody3D and not node.disabled:
		var shape: Shape3D = node.shape
		var points := PackedVector2Array()
		var height := 0.0
		if shape is BoxShape3D:
			height = shape.size.y
			for p in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				points.append(p*Vector2(shape.size.x,shape.size.z)*0.5)
		elif shape is CylinderShape3D:
			height = shape.height
			for i in 20: points.append(Vector2.from_angle(i*TAU/20)*shape.radius)
		# Omit floors and suspended cages; retain the obstacles that block movement.
		if not points.is_empty() and node.global_position.y+height*0.5 > 0.35 and node.global_position.y-height*0.5 < 1.2:
			for i in points.size():
				var p: Vector3 = node.global_transform*Vector3(points[i].x,0,points[i].y)
				points[i] = Vector2(p.x,p.z)
			result.append(points)
	for child in node.get_children(): _obstacles(child,result)
