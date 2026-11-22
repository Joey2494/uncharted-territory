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
var _materials: Dictionary = {}

func build() -> void:
	if not _gates.is_empty(): return
	for id: String in PLAN.CENTERS:
		_build_room(id)
	for link: String in PLAN.LINKS:
		_build_bridge(link)
	ART.dress(self)

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

func passage_open(a: String, b: String) -> bool:
	var gate = _gates.get(_key(a, b))
	return gate != null and gate.is_open()

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
		var cut := false
		for door in doors:
			if Geometry2D.get_closest_point_to_segment(door, a, b).distance_to(door) < 0.02:
				var dir := a.direction_to(b)
				_rail(room, a, door - dir * HALF_BRIDGE, trim)
				_rail(room, door + dir * HALF_BRIDGE, b, trim)
				cut = true
				break
		if not cut: _rail(room, a, b, trim)
	# 屋名平贴门内侧地板，长距离移动时不会遮住敌人或界面。
	var local := Vector2(0, PLAN.bounds(id).size.y * 0.5 - 1.05)
	if side_room: local = Vector2(3.8 if id in ["D","G"] else -3.8, 2.85)
	ground_label(room, id + "  " + PLAN.NAMES[id], local, SIDE if side_room else MAIN)

## 凹多边形的渲染三角化与 Godot 的地板凸分解使用同一组顶点。
func _build_deck(parent: Node3D, points: PackedVector2Array, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = "Deck"
	body.collision_mask = 0
	parent.add_child(body)
	var collider := CollisionPolygon3D.new()
	collider.rotation.x = PI / 2
	collider.depth = 0.48
	collider.polygon = points
	collider.position.y = -0.24
	body.add_child(collider)
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

func _build_bridge(link: String) -> void:
	var a := link.substr(0, 1)
	var b := link.substr(1, 1)
	var p := PLAN.doorway(a, b)
	var q := PLAN.doorway(b, a)
	var mid := (p + q) * 0.5
	var delta := q - p
	var bridge := Node3D.new()
	bridge.name = link
	add_child(bridge)
	bridge.position = Vector3(mid.x, 0, mid.y)
	# 桥的局部 +Z 始终沿主路或支路的去程；所有开口都是 5 米。
	bridge.rotation.y = atan2(delta.x, delta.y)
	var length := delta.length()
	var branch := b in PLAN.OPTIONAL
	var ink := SIDE if branch else MAIN
	var deck := solid(bridge, Vector3(0,-0.24,0), Vector3(5,0.48,length), Color("#465658"))
	deck.get_node("Surface").material_override = _deck_material(Color("#465658"))
	for x: float in [-HALF_BRIDGE, HALF_BRIDGE]:
		_rail(bridge, Vector2(x, -length/2), Vector2(x, length/2), ink)
	for i in range(1, ceili(length / 2.0)):
		var z := -length / 2 + i * 2.0
		if branch:
			block(bridge, Vector3(0,0.018,z), Vector3(0.38,0.025,0.38), ink).rotation.y = PI / 4
		else:
			block(bridge, Vector3(0,0.018,z), Vector3(0.15,0.025,1.35), ink)
	# 去程入口铭牌与回程的双短线分处两端，在岔路口可据颜色、纹样和地名选路。
	var forward_sign := caption(self, ("◇ " if branch else "▴ ") + PLAN.NAMES[b],
		Vector3(p.x,1.60,p.y) + bridge.basis.x * 2.18)
	forward_sign.modulate = ink.lightened(0.20)
	forward_sign.pixel_size = 0.014
	for step: float in [0.55, 0.95]:
		block(bridge, Vector3(-1.55,0.018,length/2-step), Vector3(0.65,0.024,0.12), ink)
	var gate = GATE.instantiate()
	gate.name = "Gate"
	gate.gate_id = StringName(link)
	gate.initially_open = link in PLAN.OPEN_AT_START
	gate.show_lock_label = false
	# 中心间的中点固定；房间不等深时，不能简单取地板边缘的中点。
	var gate_center: Vector3 = (room_center(a) + room_center(b)) * 0.5
	gate.position = bridge.transform.affine_inverse() * gate_center
	bridge.add_child(gate)
	_gates[link] = gate

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
