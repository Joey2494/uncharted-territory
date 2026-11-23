extends Node3D
## 白盒平面几何。地板拼片的公共边保留通行，其余边生成实体围栏。

const FONT = preload("res://scenes/ui/dungeon_font.tres")
var _stone := preload("res://scenes/dungeon/level03/tide_stone_visuals.gd").new()

const ROOMS := {
	&"A": Rect2(-6, 19, 12, 10),
	&"B": Rect2(-10, -10, 20, 20),
	&"C": Rect2(-32, -7, 14, 14),
	&"D": Rect2(-56, -7, 14, 14),
	&"E": Rect2(18, -7, 14, 14),
	&"F": Rect2(18, -31, 14, 14),
	&"G": Rect2(-7, -31, 14, 14),
	&"H": Rect2(40, -30, 12, 12),
	&"I": Rect2(-32, -31, 14, 14),
	&"J": Rect2(-6, -53, 12, 12),
}

const ROOM_NAMES := {
	&"A": "入口检修台", &"B": "中央潮井", &"C": "沉沙库", &"D": "折流廊",
	&"E": "浮栈战区", &"F": "蓄能工房", &"G": "中心闸庭", &"H": "溢流花园",
	&"I": "干涸维修井", &"J": "远航出口",
}

const ROUTES := {
	&"AB": [Rect2(-2.5, 10, 5, 9)],
	&"BC": [Rect2(-18, -2.5, 8, 5)],
	&"CD": [Rect2(-42, -2.5, 10, 5)],
	&"CI": [Rect2(-27.5, -17, 5, 10)],
	&"BE": [Rect2(10, -2.5, 8, 5)],
	&"EF": [Rect2(22.5, -17, 5, 10)],
	&"FH": [Rect2(32, -26.5, 8, 5)],
	&"FB": [Rect2(10, -26.5, 8, 5), Rect2(10, -21.5, 5, 17)],
	# 闸门北侧的战前整备位只连通 BG；与 G 房及门南侧均保留实体边界。
	&"BG": [Rect2(-2.5, -17, 5, 7), Rect2(-6.5, -16.8, 4, 2.7)],
	&"GJ": [Rect2(-2.5, -41, 5, 10)],
	&"ID": [Rect2(-51.5, -26.5, 19.5, 5), Rect2(-51.5, -21.5, 5, 14.5)],
}

const LOW_ROUTES := [&"BC", &"CD", &"CI", &"ID"]
const HIGH_ROUTES := [&"BE", &"EF", &"FH"]

class Room extends Node3D:
	var bounds: Rect2

	func get_world_bounds() -> Rect2:
		return Rect2(Vector2(global_position.x, global_position.z) - bounds.size / 2, bounds.size)

var _water: Dictionary = {}
var _float_decks: Dictionary = {}
var _outbound: Node3D
var _returning: Node3D
var _wire_off := Color("374551")
var _wall := _material(Color("293f49"))


func build(rooms: Node3D) -> void:
	var tiles: Array[Rect2] = []
	for id in ROOMS:
		var rect: Rect2 = ROOMS[id]
		tiles.append(rect)
		var room := Room.new()
		room.name = id
		room.bounds = rect
		room.position = _point(rect.get_center(), 0)
		rooms.add_child(room)
		var room_label := label(room, "%s  %s" % [id, ROOM_NAMES[id]], Vector3(-rect.size.x * 0.5 + 1.0, 0.09, -rect.size.y * 0.5 + 1.3), Color("e7f0ed"), true)
		room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var color := Color("59616a") if id in [&"A", &"B", &"G", &"J"] else Color("5f594b")
		if id in [&"E", &"F", &"H"]:
			color = Color("475e60")
		box(self, _point(rect.get_center(), -0.25), Vector3(rect.size.x, 0.5, rect.size.y), color, true)
	for id in ROUTES:
		for rect: Rect2 in ROUTES[id]:
			tiles.append(rect)
			var color := Color("8a7752") if id in LOW_ROUTES else Color("687d7a")
			if id == &"FB":
				color = Color("807651")
			box(self, _point(rect.get_center(), -0.25), Vector3(rect.size.x, 0.5, rect.size.y), color, true)
			if id in LOW_ROUTES or id in HIGH_ROUTES:
				_add_tidal_surface(id, rect)
	for rect in tiles:
		_build_edges(rect, tiles)
	# 岛状矮掩体给 C 和 E 提供两侧走位。中央通道和交互台前方保持净空。
	box(self, Vector3(-28, 0.48, 1.5), Vector3(1.9, 0.96, 1.2), Color("91816c"), true)
	box(self, Vector3(23.4, 0.4, -1.5), Vector3(1.7, 0.8, 2.2), Color("6e9392"), true)
	box(self, Vector3(27.5, 0.4, 1.6), Vector3(1.2, 0.8, 2), Color("6e9392"), true)
	box(self, Vector3(0, -0.7, -10), Vector3(118, 0.1, 94), Color("1b3037"))
	_build_conduits()


## 低水位退去水面，高水位升起浮栈。挡板状态另由同一潮位驱动。
func refresh(high: bool, outbound: bool, returning: bool) -> void:
	for id in _water:
		_water[id].visible = high
	for id in _float_decks:
		_float_decks[id].visible = high
	_outbound.visible = outbound
	_returning.visible = returning


func _add_tidal_surface(id: StringName, rect: Rect2) -> void:
	var water: Node3D = _water.get(id)
	if water == null:
		water = Node3D.new()
		_water[id] = water
		add_child(water)
	var middle := rect.get_center()
	box(water, _point(middle, 0.065), Vector3(rect.size.x, 0.1, rect.size.y), Color("1e718b"))
	if id not in HIGH_ROUTES:
		return
	var deck := Node3D.new()
	_float_decks[id] = deck
	add_child(deck)
	var across_x := rect.size.x > rect.size.y
	var length := rect.size.x if across_x else rect.size.y
	for i in range(floori(length / 0.8)):
		var offset := -length / 2.0 + 0.5 + i * 0.8
		var plank := middle + (Vector2(offset, 0) if across_x else Vector2(0, offset))
		var size := Vector3(0.65, 0.08, 4.8) if across_x else Vector3(4.8, 0.08, 0.65)
		box(deck, _point(plank, 0.14), size, Color("b3ab78"))


func _build_edges(rect: Rect2, tiles: Array[Rect2]) -> void:
	for axis in 2:
		for side in 2:
			var edge := rect.position[axis] if side == 0 else rect.end[axis]
			var other := 1 - axis
			var spans: Array[Vector2] = [Vector2(rect.position[other], rect.end[other])]
			for neighbor in tiles:
				var opposite := neighbor.end[axis] if side == 0 else neighbor.position[axis]
				if not is_equal_approx(opposite, edge):
					continue
				var clipped: Array[Vector2] = []
				for span in spans:
					if neighbor.end[other] <= span.x or neighbor.position[other] >= span.y:
						clipped.append(span)
						continue
					if neighbor.position[other] > span.x:
						clipped.append(Vector2(span.x, neighbor.position[other]))
					if neighbor.end[other] < span.y:
						clipped.append(Vector2(neighbor.end[other], span.y))
				spans = clipped
			for span in spans:
				var center := (span.x + span.y) / 2
				var length := span.y - span.x
				var loc := Vector3(edge, 0.57, center) if axis == 0 else Vector3(center, 0.57, edge)
				var size := Vector3(0.28, 1.15, length) if axis == 0 else Vector3(length, 1.15, 0.28)
				box(self, loc, size, _wall.albedo_color, true)


func _build_conduits() -> void:
	_outbound = Node3D.new()
	_returning = Node3D.new()
	add_child(_outbound)
	add_child(_returning)
	# 三角端口通 F，方形端口通 I。光路与踏板使用不同标识。
	# 供能线贴着实际走廊铺设，避免将悬空连线误认为一条可走的捷径。
	var outward := [Vector2(-49, 1.45), Vector2(24.6, 1.45), Vector2(24.6, -22)]
	var reverse := [Vector2(25, -22), Vector2(25, -24.8), Vector2(12.5, -24.8),
		Vector2(12.5, -6.8), Vector2(6.8, -6.8), Vector2(6.8, -1.4),
		Vector2(-49, -1.4), Vector2(-49, -0.6), Vector2(-25.6, -0.6), Vector2(-25.6, -22)]
	_wire(self, outward, _wire_off, 0.17, 0.18)
	_wire(self, reverse, _wire_off, 0.17, 0.18)
	_wire(_outbound, outward, Color("ffba58"), 0.21, 0.12)
	_wire(_returning, reverse, Color("67eddd"), 0.21, 0.12)
	label(self, "△ 东向端口 → F", Vector3(-49, 0.09, 2.5), Color("ffba58"), true)
	label(self, "□ 西向端口 → I", Vector3(-49, 0.09, -3.8), Color("67eddd"), true)


func _wire(parent: Node3D, points: Array, color: Color, y: float, width: float) -> void:
	for i in range(1, points.size()):
		var from: Vector2 = points[i - 1]
		var to: Vector2 = points[i]
		var vector := (to - from).abs()
		box(parent, _point((from + to) / 2, y), Vector3(vector.x + width, 0.04, vector.y + width), color)


func box(parent: Node3D, location: Vector3, size: Vector3, color: Color, solid := false) -> Node3D:
	var node := StaticBody3D.new() if solid else Node3D.new()
	node.position = location
	parent.add_child(node)
	if solid:
		node.collision_mask = 0
		add_shape(node, size, Vector3.ZERO)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	visual.mesh = mesh
	node.add_child(visual)
	if solid and (location.y < 0.0 or size.x < 0.4 or size.z < 0.4):
		visual.hide()
		_stone.dress(node, size, location.y < 0.0)
	elif solid:
		visual.hide()
		_stone.dress_prop(node, size)
	return node


func add_shape(body: CollisionObject3D, size: Vector3, offset: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.position = offset
	collider.shape = shape
	body.add_child(collider)


func label(parent: Node3D, content: String, point: Vector3, color: Color, flat := false) -> Label3D:
	var marker := Label3D.new()
	marker.text = content
	marker.position = point
	marker.modulate = color
	marker.font = FONT
	marker.font_size = 44
	marker.pixel_size = 0.010 if flat else 0.007
	marker.outline_size = 8
	if flat:
		marker.rotation.x = -PI / 2.0
	else:
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(marker)
	return marker


func _point(location: Vector2, height: float) -> Vector3:
	return Vector3(location.x, height, location.y)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
