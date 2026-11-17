extends Node3D
## 通过共享背包的最近交互选择接入 E 键，沿途碰撞同时阻断隔墙操作。

const REACH := 1.85

var action: StringName
var caption := ""
var level: Node3D


func _ready() -> void:
	add_to_group("world_interactables")


func can_interact(player: CharacterBody3D) -> bool:
	if not can_process() or not player.can_process() or player.is_dead() or not level.station_available(action):
		return false
	var offset := player.global_position - global_position
	if absf(offset.y) > 1.25 or Vector2(offset.x, offset.z).length() > REACH:
		return false
	var origin := player.global_position + Vector3.UP
	var target := Vector3(global_position.x, origin.y, global_position.z)
	if origin.is_equal_approx(target):
		return true
	# 台体参与移动/弹道碰撞，但不能挡住玩家对本台的交互视线。
	var excluded: Array[RID] = [player.get_rid()]
	var body := get_node_or_null("Body") as StaticBody3D
	if body != null: excluded.append(body.get_rid())
	var ray := PhysicsRayQueryParameters3D.create(origin, target, 1, excluded)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func get_interaction_prompt() -> String:
	return "[E] " + caption


func try_interact(player: CharacterBody3D) -> bool:
	return can_interact(player) and level.use_station(action)
