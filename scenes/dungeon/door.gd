class_name Door
extends Area3D

## 门脚本（张宏伟 · 地牢生成 + 房间系统）
## 职责：清敌后开门（视觉反馈），玩家走进门触发 door_entered 传送信号
## 消费方：俞吉依（main 收到信号后传送玩家）

signal door_entered(next_room_index: int)

## 本门通向的下一房间索引（生成器设置；最后一个房间为 -1 / 超范围，由 main 判定胜利）
@export var next_room_index: int = -1

## 所属房间引用（room.gd 在 _ready 时注入）
var room: Node = null

var _is_open: bool = false

@onready var _mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func set_room(r: Node) -> void:
	room = r


## 开门：隐藏红色门板（视觉反馈：门消失 = 可通行）
func open() -> void:
	if _is_open:
		return
	_is_open = true
	if _mesh:
		_mesh.visible = false


func _on_body_entered(body: Node3D) -> void:
	# 只有门打开（房间已清空）且是玩家（CharacterBody3D）时才触发传送
	if not _is_open:
		return
	if room and room.enemy_count > 0:
		return
	if body is CharacterBody3D:
		door_entered.emit(next_room_index)
