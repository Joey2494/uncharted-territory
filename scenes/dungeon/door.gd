class_name Door
extends Area3D

## 门脚本（张宏伟 · 地牢生成 + 房间系统）
## 机制（参考元气骑士）：
##   关闭时红色门板 + 碰撞阻挡，玩家无法通过；
##   开门后门板隐藏、碰撞关闭；玩家穿过时按行进方向发 door_entered。
## direction: 1=前门（玩家向前 +z 时触发），-1=后门（玩家向后 -z 时触发）

signal door_entered(target_room_index: int)

## 本门通向的目标房间索引（生成器 setup 时设置）
@export var target_room_index: int = -1

## 门的朝向：1=前门，-1=后门（决定按哪个行进方向触发）
@export var direction: int = 1

var room: Node = null

var _is_open: bool = false
var _sealed: bool = false

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _blocker_collision: CollisionShape3D = $Blocker/BlockerCollision


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_closed()


func set_room(r: Node) -> void:
	room = r


func set_target(index: int) -> void:
	target_room_index = index


## 永久封死（第一个房间的入口门）
func seal() -> void:
	_sealed = true
	_is_open = false
	_apply_closed()


func open() -> void:
	if _sealed:
		return
	_is_open = true
	_apply_open()


func close() -> void:
	if _sealed:
		return
	_is_open = false
	_apply_closed()


func _apply_open() -> void:
	if _mesh:
		_mesh.visible = false
	if _blocker_collision:
		_blocker_collision.set_deferred("disabled", true)


func _apply_closed() -> void:
	if _mesh:
		_mesh.visible = true
	if _blocker_collision:
		_blocker_collision.set_deferred("disabled", false)


func _on_body_entered(body: Node3D) -> void:
	if not _is_open:
		return
	if not (body is CharacterBody3D):
		return
	# 按玩家进入侧判定行进方向（不依赖速度，停在门上也能判）
	var from_near_side: bool = body.global_position.z < global_position.z
	if direction == 1 and from_near_side:
		door_entered.emit(target_room_index)
	elif direction == -1 and not from_near_side:
		door_entered.emit(target_room_index)
