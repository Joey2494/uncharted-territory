extends "res://scenes/items/item_pickup.gd"

@export_range(1, 1000, 1) var amount: int = 10
@export var source_id: String = ""


static func spawn(world: Node3D, point: Vector3, value: int, reward_id: String) -> Node3D:
	if value <= 0 or reward_id.is_empty():
		return null
	# The scene owns this ledger; death/reload creates a fresh run.
	var generated: Dictionary = world.get_meta("generated_coin_rewards", {})
	if generated.has(reward_id):
		return null
	generated[reward_id] = true
	world.set_meta("generated_coin_rewards", generated)
	var pickup: Node3D = load("res://scenes/items/GoldCoins.tscn").instantiate()
	pickup.amount = value
	pickup.source_id = reward_id
	world.add_child(pickup)
	pickup.global_position = point
	return pickup


func get_display_name() -> String:
	return "金币 ×%d" % amount


func try_collect(player: CharacterBody3D) -> bool:
	if not can_collect(player):
		return false
	_collected = true
	var inventory := player.get_node("ItemInventory")
	if not inventory.add_gold(amount, source_id if not source_id.is_empty() else str(get_path())):
		_collected = false
		return false
	inventory.feedback.emit("获得 %d 金币" % amount)
	hide()
	set_deferred("monitorable", false)
	queue_free()
	return true
