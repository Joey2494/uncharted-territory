extends Control
## 按实际方位画地图。未访问房间保留轮廓，当前位置和支线完成分别标记。
const FONT := preload("res://scenes/ui/dungeon_font.tres")
var level: Node3D

func _draw() -> void:
	if not is_instance_valid(level): return
	var boxes := {}
	var step := minf(40.0,size.y/8.1)
	var w := minf(116.0,(size.x-18)/3.2)
	for id in level.NAMES:
		var anchor: Vector3 = level.layout.room_center(id)
		var center := Vector2(size.x*0.5+signf(anchor.x)*(w+8),size.y-step*0.55+anchor.z/24.0*step)
		boxes[id] = Rect2(center-Vector2(w*0.5,step*0.35),Vector2(w,step*0.7))
	for edge: String in level.EDGES:
		draw_line(boxes[edge[0]].get_center(),boxes[edge[1]].get_center(),Color("#7d9196"),1.5,true)
	for id in boxes:
		var visited: bool = level.visited.has(id)
		var color := Color("#edc584") if id in level.MAIN else Color("#73cabc")
		var rect: Rect2 = boxes[id]
		if visited: draw_rect(rect,Color("#324652"))
		draw_rect(rect,color if visited else Color("#60727a"),false,2.4 if id == level.current_room else 1.0)
		var marker := "●" if id == level.current_room else ("✓" if level.optional_done(id) else "")
		draw_string(FONT,rect.position+Vector2(0,rect.size.y*0.5+5),marker+id+" "+level.NAMES[id],HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,13,color)
