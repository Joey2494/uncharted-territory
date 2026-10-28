extends Node
## 一个房间调用一次；只转发事件，不负责房间计数或应用道具效果。
signal enemy_died(enemy: Node3D)
signal pickup_spawned(pickup: Area3D)
signal item_picked(item_type: String)
const EnemyScene = preload("res://scenes/enemies/enemy_base.tscn")

func spawn_enemies(spawn_points: Array, player: CharacterBody3D,
		container: Node3D = null, overrides: Dictionary = {}) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var target: Node3D = container
	if target == null:
		target = get_parent() as Node3D
	if not is_instance_valid(target) or not target.is_inside_tree():
		push_error("EnemySpawner: container 必须是已入树的 Node3D")
		return result
	for point in spawn_points:
		if not is_instance_valid(point) or not point is Marker3D:
			push_warning("EnemySpawner: 跳过无效的 Marker3D")
			continue
		var enemy: CharacterBody3D = EnemyScene.instantiate()
		enemy.player_ref = player
		enemy.stats_overrides = overrides.duplicate()
		enemy.enemy_died.connect(_on_enemy_died)
		enemy.pickup_spawned.connect(_on_pickup_spawned)
		enemy.position = target.to_local(point.global_position)
		target.add_child(enemy)
		result.append(enemy)
	return result

func _on_enemy_died(enemy: Node3D) -> void:
	enemy_died.emit(enemy)

func _on_pickup_spawned(pickup: Area3D) -> void:
	pickup.item_picked.connect(_on_item_picked)
	pickup_spawned.emit(pickup)

func _on_item_picked(item_type: String) -> void:
	item_picked.emit(item_type)
