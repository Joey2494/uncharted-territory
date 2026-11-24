extends RefCounted
## 局部平面都是 X/Z（图上向北对应 -Z）。每个房的几何、进房判定和桥口共用同一轮廓。

const CENTERS := {
	"A": Vector2(0, 0), "B": Vector2(0, -24), "C": Vector2(0, -48),
	"E": Vector2(19, -77), "F": Vector2(-19, -74), "H": Vector2(0, -116),
	"I": Vector2(-5, -144), "J": Vector2(-8, -168), "D": Vector2(-42, -48),
	"K": Vector2(41, -77), "G": Vector2(0, -93), "L": Vector2(23, -124),
}
const NAMES := {"A":"到达台", "B":"折尺装卸场", "C":"分度大厅", "D":"配重井",
	"E":"曝光记录室", "F":"折光栈道", "G":"邮轨检修台", "H":"百叶试车场",
	"I":"主穹顶", "J":"北侧升降台", "K":"旧镜室", "L":"夜班底片室"}
# 两侧门槛及折点均使用世界 X/Z；每一段末端沿垂直墙面的方向进入房间。
const LINKS := ["AB", "BC", "CE", "EF", "FH", "HI", "IJ", "CD", "EK", "FG", "HL",
	"CF", "DF", "GE", "EH", "LI"]
const PATHS := {
	"AB": [Vector2(0,-4.5), Vector2(0,-16)],
	"BC": [Vector2(0,-32), Vector2(0,-41.5)],
	"CE": [Vector2(8,-51.5), Vector2(19,-51.5), Vector2(19,-70)],
	"EF": [Vector2(10.5,-75), Vector2(-8,-75)],
	"FH": [Vector2(-25,-79.5), Vector2(-25,-112), Vector2(-10,-112)],
	"HI": [Vector2(-3,-123.5), Vector2(-3,-128.5), Vector2(-7.5,-128.5), Vector2(-7.5,-134)],
	"IJ": [Vector2(-8,-153.5), Vector2(-8,-163)],
	"CD": [Vector2(-8,-44.5), Vector2(-34,-44.5)],
	"EK": [Vector2(27.5,-77), Vector2(32,-77)],
	"FG": [Vector2(-14,-81), Vector2(-14,-93), Vector2(-8,-93)],
	"HL": [Vector2(10,-120), Vector2(15,-120)],
	"CF": [Vector2(-8,-51.5), Vector2(-26,-51.5), Vector2(-26,-67)],
	"DF": [Vector2(-44,-55), Vector2(-44,-74), Vector2(-30,-74)],
	"GE": [Vector2(8,-93), Vector2(14,-93), Vector2(14,-84)],
	"EH": [Vector2(24,-84), Vector2(24,-112), Vector2(10,-112)],
	"LI": [Vector2(23,-131), Vector2(23,-136.5), Vector2(4,-136.5)],
}
const OPTIONAL := ["D", "K", "G", "L"]
const OPEN_AT_START := ["AB", "CE", "CF", "CD"]
const OUTLINES := {
	"A": [Vector2(-6,-4.5), Vector2(6,-4.5), Vector2(4,4.5), Vector2(-4,4.5)],
	"B": [Vector2(-10.5,-8), Vector2(5,-8), Vector2(5,-5), Vector2(10.5,-5),
		Vector2(10.5,8), Vector2(-5,8), Vector2(-5,5), Vector2(-10.5,5)],
	"C": [Vector2(-8,-6.5), Vector2(8,-6.5), Vector2(8,3.5), Vector2(4.5,3.5),
		Vector2(3.5,6.5), Vector2(-8,6.5)],
	"D": [Vector2(-7,-4.5), Vector2(-4.5,-7), Vector2(4,-7), Vector2(8,-5),
		Vector2(8,6.5), Vector2(4,7), Vector2(-4.5,7), Vector2(-7,4.5)],
	"E": [Vector2(-8.5,-7), Vector2(8.5,-7), Vector2(8.5,4), Vector2(5,7),
		Vector2(-4,7), Vector2(-8.5,5)],
	"F": [Vector2(-11,-5.5), Vector2(-3,-5.5), Vector2(-3,-7), Vector2(11,-7),
		Vector2(11,4.5), Vector2(6,4.5), Vector2(6,7), Vector2(-11,7)],
	"G": [Vector2(-8,-3.5), Vector2(-4,-7), Vector2(3,-7), Vector2(8,-4),
		Vector2(8,4), Vector2(3,7), Vector2(-3,7), Vector2(-8,3.5)],
	"H": [Vector2(-10,-3.5), Vector2(-7,-7.5), Vector2(9,-7.5), Vector2(10,-7),
		Vector2(10,7), Vector2(6,8), Vector2(-6,8), Vector2(-10,7)],
	"I": [Vector2(-11.5,-4), Vector2(-7,-9.5), Vector2(3.5,-9.5),
		Vector2(8.5,-7), Vector2(11.5,-3.5), Vector2(11.5,2), Vector2(9,4),
		Vector2(9,10.5), Vector2(4,10.5), Vector2(2,10), Vector2(-7,10), Vector2(-11.5,5)],
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

## 房间之间可能有直角折廊。调用者总是按出发房到目标房的顺序读取。
static func bridge_path(a: String, b: String) -> PackedVector2Array:
	if PATHS.has(a + b):
		return PackedVector2Array(PATHS[a + b])
	var backwards := PackedVector2Array(PATHS[b + a])
	backwards.reverse()
	return backwards

static func doorway(id: String, neighbor: String) -> Vector2:
	return bridge_path(id, neighbor)[0]

## 在走廊最长直段的中点落闸，避开弯道两侧宽度不同的栏杆接头。
static func gate_segment(path: PackedVector2Array) -> int:
	var longest := 0
	for n in range(1, path.size()-1):
		if path[n].distance_squared_to(path[n+1]) > path[longest].distance_squared_to(path[longest+1]):
			longest = n
	return longest

static func maintenance_pickup() -> Vector2:
	return PATHS.DF[1]

## 角色先进入安全观察廊，再跨地面标线。F 多个门口与 H 两侧共用各自的内场。
static func inside_encounter(id: String, world_xz: Vector2) -> bool:
	var local := world_xz - Vector2(CENTERS[id])
	match id:
		"D": return local.x <= 3.5 and local.y >= -4.0
		"F": return absf(local.x) <= 8.1 and local.y >= -3.3 and local.y <= 4.1
		"H": return absf(local.x) <= 6.0 and local.y <= 3.0 and local.y >= -4.8
		"I": return local.y <= 5.5
	return false
