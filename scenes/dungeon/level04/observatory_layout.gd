extends Node3D
## 日晷观测站白盒。实体地板、全边界低栏与闸门沿同一平面拼接。
const PLAN := preload("res://scenes/dungeon/level04/observatory_plan.gd")
const GATE := preload("res://scenes/dungeon/components/ProgressionGate.tscn")
const FONT := preload("res://scenes/ui/dungeon_font.tres")
const ART := preload("res://scenes/dungeon/level04/observatory_architecture.gd")
const DECK := preload("res://scenes/dungeon/level04/observatory_deck.gdshader")
const WALL := Color("#364851")
const MAIN := Color("#dda969")
const SIDE := Color("#68d9cd")
const HALF_BRIDGE := 2.5
var _gates: Dictionary = {}
var _room_seals: Dictionary = {}
var _materials: Dictionary = {}
var _trial_signs: Array[Label3D] = []
var _wing_beacons: Array[MeshInstance3D] = []
var _bridge_signs: Dictionary = {}

func build() -> void:
	if not _gates.is_empty(): return
	for id: String in PLAN.CENTERS:
		_build_room(id)
	for link: String in PLAN.LINKS:
		_build_bridge(link)
	ART.dress(self)
	set_wing_lights(false, false)

func room_center(id: String) -> Vector3:
	var point: Vector2 = PLAN.CENTERS[id]
	return Vector3(point.x, 0, point.y)

func room_at(pos: Vector3) -> String:
	if absf(pos.y) > 3.5: return ""
	var point := Vector2(pos.x, pos.z)
	for id: String in PLAN.CENTERS:
		if Geometry2D.is_point_in_polygon(point - Vector2(PLAN.CENTERS[id]), PLAN.outline(id)):
			return id
	return ""

func room_bounds(id: String) -> Rect2:
	return PLAN.bounds(id)

func _key(a: String, b: String) -> String:
	return a + b if _gates.has(a + b) else b + a

func set_passage(a: String, b: String, open: bool) -> void:
	var gate = _gates.get(_key(a, b))
	if gate == null: return
	# 永久授权与临时封场复用同一实体门；放行时先松开战斗锁。
	gate.set_combat_locked(not open)
	if open: gate.open_gate()

## 战斗闸落在房间边界。玩家跨过内线后不能退到连接桥中射击。
func seal_room(id: String, locked: bool) -> void:
	for link: String in PLAN.LINKS:
		if not link.contains(id): continue
		var other := link.replace(id,"")
		var key := id + other
		var gate = _room_seals.get(key)
		if gate == null:
			if not locked: continue
			var path := PLAN.bridge_path(id,other)
			var at := path[0]
			var direction := at.direction_to(path[1])
			gate = GATE.instantiate()
			gate.name = "Seal_" + key
			gate.gate_id = StringName(key)
			gate.initially_open = true
			gate.show_lock_label = false
			gate.position = Vector3(at.x,0,at.y)
			gate.rotation.y = atan2(direction.x, direction.y)
			add_child(gate)
			_room_seals[key] = gate
		gate.set_combat_locked(locked)

## 返回实际尚未完全开启的每一道门。point 和平面图使用同一关卡坐标，room 为空表示桥闸。
func passage_locks(a: String, b: String) -> Array[Dictionary]:
	var locks: Array[Dictionary] = []
	_append_lock(locks,_gates.get(_key(a,b)),"")
	_append_lock(locks,_room_seals.get(a+b),a)
	_append_lock(locks,_room_seals.get(b+a),b)
	return locks

func _append_lock(locks: Array[Dictionary], gate, room: String) -> void:
	if gate == null or gate.is_open(): return
	var pos := to_local(gate.global_position)
	locks.append({"point": Vector2(pos.x,pos.z), "room": room})

func passage_open(a: String, b: String) -> bool:
	return _gates.has(_key(a,b)) and passage_locks(a,b).is_empty()

func _build_room(id: String) -> void:
	var room := Node3D.new()
	room.name = id
	add_child(room)
	room.position = room_center(id)
	var points := PLAN.outline(id)
	var side_room := id in PLAN.OPTIONAL
	var deck := Color("#536667") if side_room else Color("#6b6760")
	if id in ["H","I"]: deck = Color("#625955")
	if id == "L": deck = Color("#63575d")
	_build_deck(room, points, deck)
	var doors := PackedVector2Array()
	for link: String in PLAN.LINKS:
		if id in link:
			var neighbor := link.replace(id, "")
			doors.append(PLAN.doorway(id, neighbor) - Vector2(PLAN.CENTERS[id]))
	for n in points.size():
		var a := points[n]
		var b := points[(n + 1) % points.size()]
		var trim := SIDE if side_room else MAIN
		var dir := a.direction_to(b)
		var length := a.distance_to(b)
		var cuts: Array[float] = []
		for door in doors:
			if door.distance_to(Geometry2D.get_closest_point_to_segment(door,a,b)) < 0.02:
				cuts.append((door-a).dot(dir))
		cuts.sort()
		var start := 0.0
		for cut in cuts:
			if cut - HALF_BRIDGE > start:
				_rail(room, a + dir*start, a + dir*(cut-HALF_BRIDGE), trim)
			start = maxf(start, cut + HALF_BRIDGE)
		if length > start:
			_rail(room, a + dir*start, b, trim)
	# 屋名平贴门内侧地板，长距离移动时不会遮住敌人或界面。
	var local := Vector2(0, PLAN.bounds(id).size.y * 0.5 - 1.05)
	if side_room: local = Vector2(3.8 if id in ["D","G"] else -3.8, 2.85)
	ground_label(room, id + "  " + PLAN.NAMES[id], local, SIDE if side_room else MAIN)

## 凹多边形的渲染三角化与 Godot 的地板凸分解使用同一组顶点。
func _build_deck(parent: Node3D, points: PackedVector2Array, color: Color, path := PackedVector2Array()) -> void:
	var body := StaticBody3D.new()
	body.name = "Deck"
	body.collision_mask = 0
	parent.add_child(body)
	if path.is_empty():
		var collider := CollisionPolygon3D.new()
		collider.rotation.x = PI / 2
		collider.depth = 0.48
		collider.polygon = points
		collider.position.y = -0.24
		body.add_child(collider)
	else:
		# 转角处两段矩形桥板搭接；角色和垂直射线均能连续越过内外边缘。
		for n in range(path.size()-1):
			var dir := path[n].direction_to(path[n+1])
			var start := path[n] - dir*(0.12 if n == 0 else HALF_BRIDGE)
			var end := path[n+1] + dir*(0.12 if n+2 == path.size() else HALF_BRIDGE)
			var mid := (start+end)*0.5
			var slab := BoxShape3D.new()
			slab.size = Vector3(HALF_BRIDGE*2,0.48,start.distance_to(end))
			var collision := CollisionShape3D.new()
			collision.shape = slab
			collision.position = Vector3(mid.x,-0.24,mid.y)
			collision.rotation.y = atan2(dir.x,dir.y)
			body.add_child(collision)
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in Geometry2D.triangulate_polygon(points):
		top.set_normal(Vector3.UP)
		top.add_vertex(Vector3(points[index].x, 0, points[index].y))
	var mesh := MeshInstance3D.new()
	mesh.mesh = top.commit()
	mesh.material_override = _deck_material(color)
	body.add_child(mesh)

func _deck_material(color: Color) -> ShaderMaterial:
	var key := "plate-" + str(color.to_rgba32())
	if _materials.has(key): return _materials[key]
	var surface := ShaderMaterial.new()
	surface.shader = DECK
	surface.set_shader_parameter("plate_color",color)
	_materials[key] = surface
	return surface

func _rail(parent: Node3D, a: Vector2, b: Vector2, trim: Color) -> void:
	if a.distance_to(b) < 0.08: return
	var mid := (a + b) * 0.5
	var delta := b - a
	var side := solid(parent, Vector3(mid.x, 0.30, mid.y), Vector3(0.30, 1.5, delta.length() + 0.06), WALL)
	side.rotation.y = atan2(delta.x, delta.y)
	block(side, Vector3(0, 0.79, 0), Vector3(0.34, 0.08, delta.length()), trim.lerp(WALL,0.48))

## 折廊拐角的内外护栏分别相接。桥面多边形覆盖完整转角，闸门与战斗封条垂直于各自所在直段。
func _build_bridge(link: String) -> void:
	var a := link.left(1)
	var b := link.right(1)
	var path := PLAN.bridge_path(a,b)
	var bridge := Node3D.new()
	bridge.name = link
	add_child(bridge)
	var branch := a in PLAN.OPTIONAL or b in PLAN.OPTIONAL
	var ink := SIDE if branch else MAIN
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for n in path.size():
		var incoming := path[maxi(n-1,0)].direction_to(path[n])
		var outgoing := path[n].direction_to(path[mini(n+1,path.size()-1)])
		var offset := (incoming + outgoing).orthogonal() * HALF_BRIDGE
		left.append(path[n] + offset)
		right.append(path[n] - offset)
	for n in range(path.size()-1):
		_rail(bridge,left[n],left[n+1],ink)
		_rail(bridge,right[n],right[n+1],ink)
		var dir := path[n].direction_to(path[n+1])
		var length := path[n].distance_to(path[n+1])
		for mark in range(1,ceili(length/2.0)):
			var at := path[n] + dir * mark * 2.0
			var size := Vector3(0.38,0.025,0.38) if branch else Vector3(0.15,0.025,1.25)
			block(bridge,Vector3(at.x,0.018,at.y),size,ink).rotation.y = PI/4 if branch else atan2(dir.x,dir.y)
	right.reverse()
	left.append_array(right)
	_build_deck(bridge,left,Color("#465658"),path)
	for end in [a,b]:
		var other := b if end == a else a
		var from_end := PLAN.bridge_path(end,other)
		var outward := from_end[0].direction_to(from_end[1])
		var at := from_end[0] + outward.orthogonal()*2.18
		var sign := caption(bridge,("◇ " if branch else "▴ ") + PLAN.NAMES[other],Vector3(at.x,1.58,at.y))
		sign.modulate = ink.lightened(0.20)
		if other == "H" and end in ["E","F"]:
			_trial_signs.append(sign)
		elif other in ["E","F"] and end in ["E","F"]:
			_bridge_signs[other] = sign
	var n := PLAN.gate_segment(path)
	var middle := (path[n]+path[n+1])*0.5
	var direction := path[n].direction_to(path[n+1])
	var gate = GATE.instantiate()
	gate.name = "Gate"
	gate.gate_id = StringName(link)
	gate.initially_open = link in PLAN.OPEN_AT_START
	gate.show_lock_label = false
	gate.position = Vector3(middle.x,0,middle.y)
	gate.rotation.y = atan2(direction.x,direction.y)
	bridge.add_child(gate)
	_gates[link] = gate

## C 望向中庭可见两路读数；两翼的试车门显示同一缺项，横桥牌指向未完成的一翼。
func set_wing_lights(calibrated: bool, powered: bool) -> void:
	var ready_color := Color("#97fff1")
	for n in _wing_beacons.size():
		var lit := calibrated if n == 0 else powered
		_wing_beacons[n].material_override = material(ready_color if lit else WALL,lit)
	var reason := "待校准 · 待供能"
	if calibrated and powered: reason = "双翼就绪 · 进入试车场"
	elif calibrated: reason = "待供能 · 清除栈道守卫"
	elif powered: reason = "待校准 · 校准曝光柜"
	for sign in _trial_signs:
		sign.text = "▴ 百叶试车场\n" + reason
		sign.modulate = ready_color if calibrated and powered else MAIN
	for target: String in _bridge_signs:
		var pending := powered and not calibrated if target == "E" else calibrated and not powered
		var label: Label3D = _bridge_signs[target]
		label.text = ("◆ " if pending else "▴ ") + PLAN.NAMES[target]
		label.modulate = ready_color if pending else MAIN

func ground_label(parent: Node3D, content: String, pos: Vector2, ink: Color) -> Label3D:
	var label := caption(parent, content, Vector3(pos.x,0.045,pos.y))
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.rotation.x = -PI/2
	label.pixel_size = 0.015
	label.modulate = ink.lightened(0.20)
	return label

func material(color: Color, glowing := false) -> StandardMaterial3D:
	var key := str(color.to_rgba32()) + ("+" if glowing else "")
	if _materials.has(key): return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	if glowing:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.7
	_materials[key] = mat
	return mat

func block(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glowing := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material(color, glowing)
	parent.add_child(view)
	view.position = pos
	return view

func solid(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_mask = 0
	if pos.y >= 0.0: body.add_to_group("camera_occluders")
	parent.add_child(body)
	body.position = pos
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	block(body, Vector3.ZERO, size, color).name = "Surface"
	return body

func caption(parent: Node3D, content: String, pos: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = content
	label.font = FONT
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.pixel_size = 0.008
	label.modulate = Color("#fff1c4")
	label.outline_size = 6
	parent.add_child(label)
	label.position = pos
	return label

func beam(parent: Node3D, p: Vector2, q: Vector2, color: Color) -> void:
	var mid := (p + q) * 0.5
	var delta := (p - q).abs()
	var view := block(parent, Vector3(mid.x, 1.15, mid.y),
		Vector3(maxf(0.09, delta.x), 0.08, maxf(0.09, delta.y)), color, true)
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
