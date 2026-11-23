extends RefCounted
## 局部平面都是 X/Z（图上向北对应 -Z）。每个房的几何、进房判定和桥口共用同一轮廓。

const CENTERS := {
	"A": Vector2(0, 0), "B": Vector2(0, -24), "C": Vector2(0, -48),
	"E": Vector2(0, -72), "F": Vector2(0, -96), "H": Vector2(0, -120),
	"I": Vector2(0, -144), "J": Vector2(0, -168), "D": Vector2(-26, -48),
	"K": Vector2(26, -72), "G": Vector2(-26, -96), "L": Vector2(26, -120),
}
const NAMES := {"A":"到达台", "B":"折尺装卸场", "C":"分度大厅", "D":"配重井",
	"E":"曝光记录室", "F":"折光栈道", "G":"邮轨检修台", "H":"百叶试车场",
	"I":"主穹顶", "J":"北侧升降台", "K":"旧镜室", "L":"夜班底片室"}
const LINKS := ["AB", "BC", "CE", "EF", "FH", "HI", "IJ", "CD", "EK", "FG", "HL"]
const OPTIONAL := ["D", "K", "G", "L"]
const OPEN_AT_START := ["AB", "CE", "CD"]
const OUTLINES := {
	"A": [Vector2(-6,-4.5), Vector2(6,-4.5), Vector2(4,4.5), Vector2(-4,4.5)],
	"B": [Vector2(-10.5,-8), Vector2(5,-8), Vector2(5,-5), Vector2(10.5,-5),
		Vector2(10.5,8), Vector2(-5,8), Vector2(-5,5), Vector2(-10.5,5)],
	"C": [Vector2(-8,-4), Vector2(-5,-4), Vector2(-4,-6.5), Vector2(4,-6.5),
		Vector2(7,-5), Vector2(7,-2.5), Vector2(3.5,2), Vector2(3.5,6.5),
		Vector2(-3.5,6.5), Vector2(-3.5,3.5), Vector2(-8,3.5)],
	"D": [Vector2(-7,-4.5), Vector2(-4.5,-7), Vector2(4,-7), Vector2(8,-4),
		Vector2(8,4), Vector2(4,7), Vector2(-4.5,7), Vector2(-7,4.5)],
	"E": [Vector2(-8,-7), Vector2(5,-7), Vector2(8.5,-4), Vector2(8.5,3.5),
		Vector2(4,7), Vector2(-3.5,7), Vector2(-7,3), Vector2(-8.5,-2)],
	"F": [Vector2(-11,-5.5), Vector2(-5,-5.5), Vector2(-5,-7), Vector2(11,-7),
		Vector2(11,4.5), Vector2(6,4.5), Vector2(6,7), Vector2(-11,7)],
	"G": [Vector2(-8,-2.5), Vector2(-6,-5), Vector2(-3,-7), Vector2(3,-7),
		Vector2(8,-4), Vector2(8,4), Vector2(3,7), Vector2(-3,7), Vector2(-7,4)],
	"H": [Vector2(-9.5,-2), Vector2(-7,-5.5), Vector2(-3.5,-7.5), Vector2(3.5,-7.5),
		Vector2(7.5,-5.8), Vector2(9.5,-3.3), Vector2(9.5,3.3), Vector2(6,6.2),
		Vector2(3,7.5), Vector2(-3,7.5), Vector2(-7,5.7), Vector2(-9.5,2.8)],
	"I": [Vector2(-11.5,-4), Vector2(-7,-8), Vector2(-3.5,-9.5), Vector2(3.5,-9.5),
		Vector2(8.5,-7), Vector2(11.5,-3.5), Vector2(11.5,2), Vector2(8.5,3.5),
		Vector2(8,6), Vector2(4,9.5), Vector2(-4,9.5), Vector2(-9,6), Vector2(-11.5,3)],
	"J": [Vector2(-6,-5), Vector2(6,-5), Vector2(4,5), Vector2(-4,5)],
	"K": [Vector2(-9,-5.5), Vector2(-7,-7.5), Vector2(7,-7.5), Vector2(9,-5.5),
		Vector2(9,5.5), Vector2(7,7.5), Vector2(-7,7.5), Vector2(-9,5.5)],
	"L": [Vector2(-8,-5), Vector2(-5.5,-7), Vector2(8,-7), Vector2(8,3),
		Vector2(5.5,3), Vector2(5.5,7), Vector2(-8,7)],
}

static func outline(id: String) -> PackedVector2Array:
	return PackedVector2Array(OUTLINES[id])

static func bounds(id: String) -> Rect2:
	var points := outline(id)
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	box.position += Vector2(CENTERS[id])
	return box

## 用桥的行进方向射出与外墙的交点，直接作为地板与桥板的接缝。
static func doorway(id: String, neighbor: String) -> Vector2:
	var center: Vector2 = CENTERS[id]
	var dir := center.direction_to(CENTERS[neighbor])
	var points := outline(id)
	for index in points.size():
		var hit = Geometry2D.segment_intersects_segment(Vector2.ZERO, dir * 30,
			points[index], points[(index + 1) % points.size()])
		if hit != null:
			return center + Vector2(hit)
	return center
