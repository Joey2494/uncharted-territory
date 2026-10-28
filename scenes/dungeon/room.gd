class_name Room
extends Node3D

## 房间脚本（张宏伟 · 地牢生成 + 房间系统）
## 机制（参考元气骑士）：
##   玩家进入有敌人的房间 → 前后门全部关闭（困住）；
##   清空敌人 → 全部门打开并广播 room_cleared，可前进也可回已探索房间。

signal room_cleared
signal door_entered(target_room_index: int)
## 玩家身体进入房间区域（RoomArea）时发出，携带本房间索引——消费方据此确定"当前房间"
signal player_entered_room(room_index: int)

## 本房间的敌人总数（模板预设；整合后由 main 按实际生成数校准）
@export var enemy_count: int = 2

var _front_door: Node = null
var _back_door: Node = null
var _room_area: Area3D = null
var _prev_room: Room = null
var _next_room: Room = null
var _index: int = 0
var _cleared: bool = false


func _ready() -> void:
	_front_door = get_node_or_null("FrontDoor")
	_back_door = get_node_or_null("BackDoor")
	_room_area = get_node_or_null("RoomArea")
	if _front_door:
		_front_door.set_room(self)
		_front_door.door_entered.connect(_on_door_relayed)
	if _back_door:
		_back_door.set_room(self)
		_back_door.door_entered.connect(_on_door_relayed)
	if _room_area:
		_room_area.body_entered.connect(_on_room_area_body_entered)


## 生成器在所有房间就位后调用：链接前后房间、设置门的目标、封死首房入口
func setup(index: int, prev: Room, next: Room) -> void:
	_index = index
	_prev_room = prev
	_next_room = next
	if _front_door:
		_front_door.set_target(index + 1)
	if _back_door:
		_back_door.set_target(index - 1)
	if prev == null and _back_door:
		_back_door.seal()


func _on_door_relayed(target: int) -> void:
	door_entered.emit(target)


## 玩家进入房间内部：标记为当前房间；若敌人未清，关闭所有门（困住）
func _on_room_area_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		player_entered_room.emit(_index)
		if not _cleared:
			if _back_door:
				_back_door.close()
			if _front_door:
				_front_door.close()


## 敌人死亡回调（字远 enemy_died 信号连到这里）
func on_enemy_died(_enemy: Node3D) -> void:
	enemy_count = maxi(enemy_count - 1, 0)
	if enemy_count == 0 and not _cleared:
		_cleared = true
		_on_cleared()


func _on_cleared() -> void:
	if _front_door:
		_front_door.open()
	if _back_door:
		_back_door.open()
	room_cleared.emit()
	# 联动下一房间的后门（通道打开）
	if _next_room:
		_next_room.on_previous_room_cleared()


## 前一房间已清空：打开本房间后门（玩家可进入；进入后若有敌人会再关上）
func on_previous_room_cleared() -> void:
	if not _cleared and _back_door:
		_back_door.open()


## 敌人/玩家/武器生成点查询
func get_enemy_spawn_points() -> Array[Marker3D]:
	var points: Array[Marker3D] = []
	for child in get_children():
		if child is Marker3D and child.name.begins_with("EnemySpawnPoint"):
			points.append(child)
	return points


func get_player_spawn_point() -> Marker3D:
	return get_node_or_null("PlayerSpawnPoint") as Marker3D


func get_weapon_spawn_point() -> Marker3D:
	return get_node_or_null("WeaponSpawnPoint") as Marker3D
