extends Node3D

signal room_changed(room_name: String, visited_count: int)
signal exit_reached
signal exit_unlocked

enum ExitState { LOCKED, OPENING, OPEN }

@onready var _player: CharacterBody3D = $Player

var _current_region: Node3D
var _visited: Dictionary = {}
var _exit_announced: bool = false
var _exit_state: ExitState = ExitState.LOCKED
@export var room_gold_rewards: Dictionary = {"EntranceHall": 20, "Crossroads": 15, "SupplyChamber": 15}
@export var enable_debug_shop_stands: bool = false


func _ready() -> void:
	if enable_debug_shop_stands:
		for item_id in preload("res://data/item_catalog.gd").ITEMS:
			var stand := preload("res://scenes/items/shop_stand.gd").new()
			stand.name = "Shop%d" % item_id
			stand.product_id = item_id
			stand.position = Vector3(-6.0 + item_id * 3.0, 0.0, -3.0)
			add_child(stand)
	_update_region()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player) or _player.is_dead():
		return
	_update_region()
	if not _exit_announced and is_exit_open() and is_player_in_exit_area():
		_exit_announced = true
		exit_reached.emit()


func unlock_exit() -> bool:
	if _exit_state != ExitState.LOCKED or not can_process() or _player.is_dead():
		return false
	var boss := get_node_or_null("RuinGatekeeper")
	if boss == null or not boss.is_dead():
		return false
	_exit_state = ExitState.OPENING
	$ExitGate/SealLabel.text = "出口封印解除中"
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($ExitGate/MeshInstance3D, "position:y", -3.6, 0.9)
	tween.finished.connect(_finish_exit_unlock)
	return true


func _finish_exit_unlock() -> void:
	if _player.is_dead() or not can_process():
		return
	$ExitGate/CollisionShape3D.set_deferred("disabled", true)
	$ExitGate.hide()
	$ExitTrigger/PortalGlow.show()
	$Doorways/BossExit/Banner.text = "出口已开启 ↑ 前往通关"
	$Doorways/MapExit/Banner.text = "地牢出口 · 进入通关"
	_exit_state = ExitState.OPEN
	exit_unlocked.emit()


func is_exit_open() -> bool:
	return _exit_state == ExitState.OPEN


func is_player_in_exit_area() -> bool:
	return is_instance_valid(_player) and not _player.is_dead() and $ExitTrigger.overlaps_body(_player)


func get_room_count() -> int:
	var count := 0
	for region in $Regions.get_children():
		if region.exploration_room and region.visible:
			count += 1
	return count


func get_visited_count() -> int:
	return _visited.size()


func get_region_at(point: Vector3) -> Node3D:
	for region in $Regions.get_children():
		if region.visible and region.contains_point(point):
			return region
	return null


func is_camera_target_relevant(actor: Node3D, player: Node3D) -> bool:
	var player_region := get_region_at(player.global_position)
	var actor_region := get_region_at(actor.global_position)
	if player_region != null and player_region == actor_region:
		return true
	# Show approaching combatants through a nearby doorway, without framing
	# remote rooms or revealing enemies through several intervening walls.
	if actor.global_position.distance_to(player.global_position) > 12.0:
		return false
	var start := player.global_position + Vector3.UP
	var end := Vector3(actor.global_position.x, start.y, actor.global_position.z)
	var ray := PhysicsRayQueryParameters3D.create(start, end, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _update_region() -> void:
	var region := get_region_at(_player.global_position)
	if region == null or not region.visible or not region.exploration_room or region == _current_region:
		return
	_current_region = region
	if not _visited.has(region.name) and room_gold_rewards.has(str(region.name)):
		preload("res://scenes/items/coin_pickup.gd").spawn(
			self, region.global_position + Vector3(1.2, 0.05, 1.2),
			int(room_gold_rewards[str(region.name)]), "room:" + str(region.name))
	_visited[region.name] = true
	room_changed.emit(region.display_name, _visited.size())
