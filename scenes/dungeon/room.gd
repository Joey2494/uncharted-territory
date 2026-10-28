class_name Room
extends Node3D

## 房间脚本（张宏伟 · 地牢生成 + 房间系统）
## 职责：提供各类生成点查询 + 清敌开门逻辑
## 消费方：俞吉依（main）、字远（EnemySpawner/ItemSpawner）

signal room_cleared
signal door_entered(next_room_index: int)

## 本房间的敌人总数（由模板预设；整合后由 main 按敌人生成数校准）
@export var enemy_count: int = 2

var _door: Node = null


func _ready() -> void:
	_door = get_node_or_null("Door")
	if _door and _door.has_method("set_room"):
		_door.set_room(self)


## 敌人生成点（供字远 EnemySpawner 逐点生成敌人）
func get_enemy_spawn_points() -> Array[Marker3D]:
	var points: Array[Marker3D] = []
	for child in get_children():
		if child is Marker3D and child.name.begins_with("EnemySpawnPoint"):
			points.append(child)
	return points


## 玩家出生点（供俞吉依 main 放置玩家 / 传送）
func get_player_spawn_point() -> Marker3D:
	return get_node_or_null("PlayerSpawnPoint") as Marker3D


## 武器刷新点（供俞吉依 main 放置武器拾取物）
func get_weapon_spawn_point() -> Marker3D:
	return get_node_or_null("WeaponSpawnPoint") as Marker3D


## 道具生成点（兼容旧接口契约；当前返回武器刷新点）
func get_item_spawn_points() -> Array[Marker3D]:
	var points: Array[Marker3D] = []
	var weapon: Marker3D = get_weapon_spawn_point()
	if weapon:
		points.append(weapon)
	return points


## 敌人死亡回调（字远 enemy_died 信号连到这里）：计数减到 0 即开门
func on_enemy_died(_enemy: Node3D) -> void:
	enemy_count = maxi(enemy_count - 1, 0)
	if enemy_count == 0:
		open_door()


## 清敌后开门（同时广播 room_cleared）
func open_door() -> void:
	if _door and _door.has_method("open"):
		_door.open()
	room_cleared.emit()


## 生成器设置本房间出口指向的下一房间索引
func set_next_room_index(index: int) -> void:
	if _door:
		_door.next_room_index = index
