extends Control
## Floor plan rendering in world X/Z coordinates, north is negative Z.
const GOLD := Color("f3ce78")
var snapshot := {}
var text_scale := 1.0
var label_rects: Array[Rect2] = []
var map_rect := Rect2()
var _factor := 1.0
var _origin := Vector2.ZERO
var zoom := 1.0
var pan := Vector2.ZERO
var _dragging := false
var label_names: Array[String] = []
var _font: Font = preload("res://scenes/ui/dungeon_font.tres")

func project(point: Vector2) -> Vector2:
	return _origin+(point-snapshot.bounds.position)*_factor

func _project_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points: result.append(project(point))
	return result

func _floor(entry: Dictionary, fill: Color, edge: Color) -> void:
	if entry.has("polygon"):
		var points := _project_polygon(entry.polygon)
		draw_colored_polygon(points,fill)
		points.append(points[0])
		draw_polyline(points,edge,1.2,true)
	else:
		var rect := Rect2(project(entry.bounds.position),entry.bounds.size*_factor)
		draw_rect(rect,fill)
		draw_rect(rect,edge,false,1.2)

func _gui_input(event: InputEvent) -> void:
	if not snapshot.get("observatory",false): return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: _dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			zoom = 1.0
			pan = Vector2.ZERO
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var previous := zoom
			zoom = clampf(zoom*(1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8),1,6)
			pan = (pan+size*0.5-event.position)*(zoom/previous)-size*0.5+event.position
		queue_redraw()
	elif event is InputEventMouseMotion and _dragging:
		pan += event.relative
		queue_redraw()


func _draw() -> void:
	if snapshot.is_empty(): return
	draw_style_box(_background(),Rect2(Vector2.ZERO,size))
	var usable := Rect2(Vector2(22,20),size-Vector2(44,40))
	_factor = minf(usable.size.x/snapshot.bounds.size.x,usable.size.y/snapshot.bounds.size.y)*zoom
	_origin = usable.position+(usable.size-snapshot.bounds.size*_factor)*0.5+pan
	map_rect = Rect2(_origin,snapshot.bounds.size*_factor)
	for path in snapshot.paths:
		var color := Color("426b68") if path.optional else Color("626657")
		if not path.open: color = Color("403a34")
		_floor(path,color,Color("827653") if path.open else Color("6c5145"))
	for room in snapshot.rooms:
		var edge := Color("82917c") if room.visited else Color("5c6155")
		if room.get("zone","") in ["敌人区域","交战中"]: edge = Color("b76d58")
		_floor(room,Color("273d3a") if room.optional else (Color("44483b") if room.visited else Color("272b27")),edge)
	for polygon: PackedVector2Array in snapshot.get("obstacles",[]):
		draw_colored_polygon(_project_polygon(polygon),Color("111510"))
	for device: Dictionary in snapshot.get("devices",[]):
		var at := project(device.point)
		var r := 2.5*text_scale
		draw_rect(Rect2(at-Vector2.ONE*r,Vector2.ONE*r*2),Color("bbac78") if device.available else Color("74796d"),false,1.4)
	for enemy: Dictionary in snapshot.get("enemies",[]):
		draw_circle(project(enemy.point),2.5*text_scale,Color("ed8a72"))
	label_rects.clear()
	label_names.clear()
	for lock in snapshot.locks:
		if lock.open: continue
		var point := project(lock.point)
		var radius := 3.0*text_scale
		draw_circle(point,radius+2,Color("151612"))
		draw_line(point-Vector2(radius,radius),point+Vector2(radius,radius),Color("c78f70"),2*text_scale,true)
		draw_line(point+Vector2(-radius,radius),point+Vector2(radius,-radius),Color("c78f70"),2*text_scale,true)
	for marker in _targets():
		var point := project(marker.point)
		var r := 7.0*text_scale
		var shape := PackedVector2Array([point+Vector2(0,-r),point+Vector2(r,0),point+Vector2(0,r),point+Vector2(-r,0),point+Vector2(0,-r)])
		draw_colored_polygon(shape,Color("171911"))
		draw_polyline(shape,GOLD,2*text_scale,true)
	var player := project(snapshot.player)
	draw_circle(player,7*text_scale,Color("122028"))
	draw_circle(player,4*text_scale,Color("73d5ec"))
	draw_line(player,player+Vector2(0,-12*text_scale),Color("73d5ec"),2*text_scale,true)
	for room in snapshot.rooms: _room_label(room)
	var font_size := roundi(12*text_scale)
	draw_string(_font,Vector2(size.x-50*text_scale,24*text_scale),"↑ 北",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("bcb9a0"))

func _room_label(room: Dictionary) -> void:
	if snapshot.get("observatory",false):
		_detailed_label(room)
		return
	var rect := Rect2(project(room.bounds.position),room.bounds.size*_factor)
	var font_size := roundi(12*text_scale)
	var width := maxf(font_size*2.2,rect.size.x-6)
	var lines: Array[String] = []
	var line := ""
	var caption := String(room.name)
	for character in caption:
		if not line.is_empty() and _font.get_string_size(line+character,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > width:
			lines.append(line)
			line = ""
		line += character
	if not line.is_empty(): lines.append(line)
	var step := ceilf(font_size*1.15)
	var dimensions := Vector2(width,lines.size()*step)
	var position := rect.get_center()-dimensions*0.5
	# Lift the room label away from the player's or main objective's marker.
	var marked := rect.has_point(project(snapshot.player))
	for marker in _targets():
		if rect.has_point(project(marker.point)): marked = true
	if marked:
		position.y = rect.position.y-dimensions.y-3
	position.x = clampf(position.x,4,size.x-dimensions.x-4)
	position.y = clampf(position.y,4,size.y-dimensions.y-4)
	var box := Rect2(position,dimensions)
	label_rects.append(box)
	draw_rect(box.grow(2),Color(0.035,0.044,0.039,0.92))
	for i in lines.size():
		draw_string(_font,position+Vector2(0,step*(i+0.8)),lines[i],HORIZONTAL_ALIGNMENT_CENTER,width,font_size,Color("c9d3c0") if room.visited else Color("a3aa99"))

func _targets() -> Array:
	if snapshot.target.is_empty(): return []
	return snapshot.target.get("markers",[snapshot.target])

func _get_tooltip(at_position: Vector2) -> String:
	if not snapshot.get("observatory",false): return ""
	for lock in snapshot.locks:
		if not lock.open and at_position.distance_to(project(lock.point)) < 9*text_scale:
			return lock.name+" · "+lock.reason
	for device: Dictionary in snapshot.get("devices",[]):
		if project(device.point).distance_to(at_position) < 8*text_scale:
			return device.name+(" · 可操作" if device.available else " · 暂不可用")
	for enemy: Dictionary in snapshot.get("enemies",[]):
		if project(enemy.point).distance_to(at_position) < 8*text_scale: return enemy.name
	var point: Vector2 = snapshot.bounds.position+(at_position-_origin)/_factor
	for i in snapshot.rooms.size():
		var room: Dictionary = snapshot.rooms[i]
		if Geometry2D.is_point_in_polygon(point,room.polygon) or label_rects[i].has_point(at_position):
			return room.name+" · "+("已到达" if room.visited else "未探索")+("\n"+room.zone if not room.zone.is_empty() else "")
	return ""

func _detailed_label(room: Dictionary) -> void:
	var rect := Rect2(project(room.bounds.position),room.bounds.size*_factor)
	var caption := String(room.name)+(" ✓" if room.get("done",false) else "")
	label_names.append(caption)
	if not Rect2(Vector2.ZERO,size).intersects(rect):
		label_rects.append(Rect2())
		return
	var font_size := roundi(12*text_scale)
	var dimensions := _font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)+Vector2(10,5)
	var candidates: Array[Vector2] = []
	var prefer_left: bool = room.id in ["D","F","H","I","J"]
	for step in [0,-1,1,-2,2,-3,3]:
		var y: float = rect.get_center().y-dimensions.y/2+step*(dimensions.y+6)
		for left in [prefer_left,not prefer_left]:
			candidates.append(Vector2(rect.position.x-dimensions.x-8 if left else rect.end.x+8,y))
	candidates.append(Vector2(rect.get_center().x-dimensions.x/2,rect.position.y-dimensions.y-6))
	candidates.append(Vector2(rect.get_center().x-dimensions.x/2,rect.end.y+6))
	# Additional slots let complete Chinese names fit in short or narrow windows.
	for y in range(5,int(size.y-dimensions.y),int(dimensions.y+6)):
		for x in [5.0,size.x-dimensions.x-5,(size.x-dimensions.x)/2]: candidates.append(Vector2(x,y))
	var best := Rect2()
	var best_cost := INF
	for at in candidates:
		at = at.clamp(Vector2(5,5),size-dimensions-Vector2(5,5))
		var box := Rect2(at,dimensions)
		var cost := box.get_center().distance_to(rect.get_center())
		for lock in snapshot.locks:
			if not lock.open and box.grow(6*text_scale).has_point(project(lock.point)): cost += 20000
		if box.grow(8*text_scale).has_point(project(snapshot.player)): cost += 20000
		for marker in _targets():
			if box.grow(9*text_scale).has_point(project(marker.point)): cost += 20000
		for used in label_rects:
			if used.grow(3).intersects(box): cost += 10000+used.intersection(box).get_area()*100
		for other in snapshot.rooms:
			var footprint := Rect2(project(other.bounds.position),other.bounds.size*_factor)
			if footprint.intersects(box): cost += footprint.intersection(box).get_area()*2
		if cost < best_cost:
			best_cost = cost
			best = box
	label_rects.append(best)
	var anchor := rect.get_center()
	var end := anchor.clamp(best.position,best.end)
	draw_line(anchor,end,Color(0.55,0.55,0.42,0.65),1,true)
	draw_rect(best.grow(2),Color(0.035,0.044,0.039,0.95))
	draw_string(_font,best.position+Vector2(5,font_size+1),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("c9d3c0") if room.visited else Color("a3aa99"))

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101913")
	style.border_color = Color("62583e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style
