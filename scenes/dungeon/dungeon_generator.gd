class_name DungeonGenerator
extends Node

## 地牢生成器（张宏伟 · 地牢生成 + 房间系统）
## 职责：随机选房间模板实例化，沿 Z 轴线性拼接，链接房间，补走廊地板，返回房间列表。
## 消费方：俞吉依（main 调用 generate() 拿到房间后放置玩家/敌人/武器）

const ROOM_TEMPLATES: Array[String] = [
	"res://scenes/dungeon/room_template_01.tscn",
	"res://scenes/dungeon/room_template_02.tscn",
	"res://scenes/dungeon/room_template_03.tscn",
]

const ROOM_SPACING: float = 12.0
const ROOM_DEPTH: float = 10.0


## 生成 room_count 个房间：随机选模板 → 沿 Z 轴每 ROOM_SPACING 排一个 → 链接 → 补走廊。
## 返回已实例化并挂在本节点下的房间列表（顺序 = 排列顺序）。
func generate(room_count: int) -> Array[Node3D]:
	var rooms: Array[Node3D] = []
	for i in room_count:
		var template_path: String = ROOM_TEMPLATES.pick_random()
		var room: Node3D = (load(template_path) as PackedScene).instantiate()
		room.position = Vector3(0, 0, i * ROOM_SPACING)
		room.name = "Room%d" % (i + 1)
		add_child(room)
		rooms.append(room)
	# 所有房间就位后再链接（门的目标 + 首房入口封死）
	for i in room_count:
		var prev: Room = rooms[i - 1] if i > 0 else null
		var next: Room = rooms[i + 1] if i < room_count - 1 else null
		rooms[i].setup(i, prev, next)
	# 相邻房间之间补走廊地板（地板 10 深，间距 12，留 2 的缝）
	for i in room_count - 1:
		_build_corridor(i)
	return rooms


## 走廊地板：中心在 Room(i+1) 与 Room(i+2) 正中间
func _build_corridor(i: int) -> void:
	var z: float = float(i) * ROOM_SPACING + ROOM_SPACING / 2.0
	var gap: float = ROOM_SPACING - ROOM_DEPTH
	var body := StaticBody3D.new()
	body.name = "Corridor%d" % (i + 1)

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(ROOM_DEPTH, 0.2, gap)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.46, 0.49, 1)
	box.material = mat
	mesh_inst.mesh = box
	body.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(ROOM_DEPTH, 0.2, gap)
	col.shape = shape
	body.add_child(col)

	body.position = Vector3(0, 0, z)
	add_child(body)
