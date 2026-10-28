class_name DungeonGenerator
extends Node

## 地牢生成器（张宏伟 · 地牢生成 + 房间系统）
## 职责：随机选房间模板实例化，沿 Z 轴线性拼接，返回房间列表
## 消费方：俞吉依（main 调用 generate() 拿到房间后放置玩家/敌人/武器）

const ROOM_TEMPLATES: Array[String] = [
	"res://scenes/dungeon/room_template_01.tscn",
	"res://scenes/dungeon/room_template_02.tscn",
	"res://scenes/dungeon/room_template_03.tscn",
]

## 房间间距：房间外宽 12（地板 10 + 两侧墙厚 0.5×2 + 门洞缝隙），沿 Z 轴等距排列，门洞正好对齐
const ROOM_SPACING: float = 12.0


## 生成 room_count 个房间：随机选模板 → 实例化 → 沿 Z 轴每 ROOM_SPACING 排一个。
## 返回已实例化并挂在本节点下的房间列表（顺序 = 排列顺序）。
func generate(room_count: int) -> Array[Node3D]:
	var rooms: Array[Node3D] = []
	for i in room_count:
		var template_path: String = ROOM_TEMPLATES.pick_random()
		var room: Node3D = (load(template_path) as PackedScene).instantiate()
		room.position = Vector3(0, 0, i * ROOM_SPACING)
		if room.has_method("set_next_room_index"):
			room.set_next_room_index(i + 1)
		room.name = "Room%d" % (i + 1)
		add_child(room)
		rooms.append(room)
	return rooms
