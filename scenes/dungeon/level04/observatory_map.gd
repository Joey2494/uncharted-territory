extends Control
## Tab 路线图按实际桥廊绘制，悬停闸门可查看当前封锁原因。
const FONT := preload("res://scenes/ui/dungeon_font.tres")
const PLAN := preload("res://scenes/dungeon/level04/observatory_plan.gd")
const SHORT_NAMES := {"A":"到达台","B":"装卸场","C":"分度厅","D":"配重井","E":"曝光室","F":"折光栈道","G":"邮轨台","H":"试车场","I":"主穹顶","J":"升降台","K":"旧镜室","L":"底片室"}
var level: Node3D
var _locks: Array[Dictionary] = []
var _bounds := Rect2()

func _ready() -> void:
	_bounds = PLAN.bounds("A")
	for id: String in PLAN.CENTERS: _bounds = _bounds.merge(PLAN.bounds(id))

func _project(point: Vector2) -> Vector2:
	return Vector2(24,7)+(point-_bounds.position)/_bounds.size*(size-Vector2(48,14))

func _draw() -> void:
	if not is_instance_valid(level) or not level.is_node_ready(): return
	_locks.clear()
	for edge: String in PLAN.LINKS:
		var path := PLAN.bridge_path(edge[0],edge[1])
		var line := PackedVector2Array()
		for p in path: line.append(_project(p))
		var opened: bool = level.layout.passage_open(edge[0],edge[1])
		var optional := edge[0] in PLAN.OPTIONAL or edge[1] in PLAN.OPTIONAL
		var color := Color("#74c6b9") if optional else Color("#d2b37b")
		draw_polyline(line,color if opened else Color("#546064"),2,true)
		for lock in level.map_locks(edge):
			var at := _project(lock.point)
			_locks.append({"point":at,"edge":edge,"reason":lock.reason})
	for id: String in PLAN.CENTERS:
		var pos := _project(PLAN.CENTERS[id])
		var caption: String = id+" "+SHORT_NAMES[id]
		if id in PLAN.OPTIONAL: caption = ("✓" if level.optional_done(id) else "◇") + caption
		var target: bool = level.combat.is_clear("B") and ((id == "E" and not level.puzzles.calibrated) or (id == "F" and not level.combat.is_clear("F")))
		var width := FONT.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+8
		var rect := Rect2(pos-Vector2(width/2,8),Vector2(width,16))
		draw_rect(rect,Color("#665335") if target else (Color("#344448") if level.visited.has(id) else Color("#1c2425")))
		var color := Color("#87d3c2") if id in PLAN.OPTIONAL else Color("#e7c891")
		draw_rect(rect,Color("#7bdfee") if id == level.current_room else color.darkened(0.5),false,2 if id == level.current_room else 1)
		draw_string(FONT,rect.position+Vector2(0,12),caption,HORIZONTAL_ALIGNMENT_CENTER,width,12,color)
	for lock in _locks:
		var at: Vector2 = lock.point
		draw_line(at-Vector2(2,2),at+Vector2(2,2),Color("#e69d78"),1.5,true)
		draw_line(at+Vector2(-2,2),at+Vector2(2,-2),Color("#e69d78"),1.5,true)
	var player: Vector3 = level.player.global_position
	var dot := _project(Vector2(player.x,player.z))
	draw_circle(dot,3.5,Color("#162d38"))
	draw_circle(dot,2.3,Color("#7bdfee"))

func _get_tooltip(at_position: Vector2) -> String:
	var distance := 9.0
	var tip := ""
	for lock in _locks:
		var delta := at_position.distance_to(lock.point)
		if delta < distance:
			distance = delta
			tip = "%s—%s · %s" % [lock.edge[0],lock.edge[1],lock.reason]
	return tip
