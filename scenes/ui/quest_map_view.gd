extends Control
## Floor plan rendering in world X/Z coordinates, north is negative Z.
const GOLD := Color("f3ce78")
var snapshot := {}
var text_scale := 1.0
var label_rects: Array[Rect2] = []
var map_rect := Rect2()
var _factor := 1.0
var _origin := Vector2.ZERO
var _font: Font = preload("res://scenes/ui/dungeon_font.tres")

func project(point: Vector2) -> Vector2:
	return _origin+(point-snapshot.bounds.position)*_factor

func _draw() -> void:
	if snapshot.is_empty(): return
	draw_style_box(_background(),Rect2(Vector2.ZERO,size))
	var usable := Rect2(Vector2(22,20),size-Vector2(44,40))
	_factor = minf(usable.size.x/snapshot.bounds.size.x,usable.size.y/snapshot.bounds.size.y)
	_origin = usable.position+(usable.size-snapshot.bounds.size*_factor)*0.5
	map_rect = Rect2(_origin,snapshot.bounds.size*_factor)
	for path in snapshot.paths:
		var color := Color("426b68") if path.optional else Color("626657")
		if not path.open: color = Color("403a34")
		if path.has("points"):
			var line := PackedVector2Array()
			for point: Vector2 in path.points: line.append(project(point))
			draw_polyline(line,color,maxf(2.0,3.5*_factor),true)
			continue
		var rect := Rect2(project(path.bounds.position),path.bounds.size*_factor)
		draw_rect(rect,color)
		draw_rect(rect,Color("827653") if path.open else Color("6c5145"),false,1.0)
	for room in snapshot.rooms:
		var rect := Rect2(project(room.bounds.position),room.bounds.size*_factor)
		draw_rect(rect,Color("273d3a") if room.optional else (Color("44483b") if room.visited else Color("272b27")))
		draw_rect(rect,Color("82917c") if room.visited else Color("5c6155"),false,1.2)
	label_rects.clear()
	for room in snapshot.rooms: _room_label(room)
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
	var font_size := roundi(12*text_scale)
	draw_string(_font,Vector2(size.x-50*text_scale,24*text_scale),"↑ 北",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("bcb9a0"))

func _room_label(room: Dictionary) -> void:
	var rect := Rect2(project(room.bounds.position),room.bounds.size*_factor)
	var font_size := roundi(12*text_scale)
	var width := maxf(font_size*2.2,rect.size.x-6)
	var lines: Array[String] = []
	var line := ""
	var caption := String(room.name)
	if snapshot.get("observatory",false):
		caption = room.id
		if room.optional: caption = "◇" + caption
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
	var distance := 9.0*text_scale
	var tip := ""
	for lock in snapshot.locks:
		var delta := at_position.distance_to(project(lock.point))
		if not lock.open and delta <= distance:
			distance = delta
			tip = "%s—%s · %s" % [lock.id[0],lock.id[1],lock.reason]
	if not tip.is_empty(): return tip
	for room in snapshot.rooms:
		var rect := Rect2(project(room.bounds.position),room.bounds.size*_factor)
		if rect.grow(2).has_point(at_position):
			return "%s %s · %s" % [room.id,room.name,"已到达" if room.visited else "未探索"]
	return ""

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101913")
	style.border_color = Color("62583e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style
