extends Area3D

@export_enum("生命药剂", "攻击强化符文") var item_type: int = 0
@export_range(0.5, 3.0, 0.1) var interaction_distance: float = 1.5

@onready var _visuals: Node3D = $Visuals

var _collected: bool = false
var _elapsed: float = 0.0
var _base_height: float


func _ready() -> void:
	_base_height = _visuals.position.y
	$NameLabel.text = get_display_name()


func _process(delta: float) -> void:
	_elapsed += delta
	_visuals.rotation.y += delta
	_visuals.position.y = _base_height + sin(_elapsed * 2.5) * 0.1


func get_display_name() -> String:
	return "生命药剂" if item_type == 0 else "攻击强化符文"


func can_collect(player: CharacterBody3D) -> bool:
	if _collected or not can_process() or not is_instance_valid(player):
		return false
	if player.is_dead() or player.get_node_or_null("ItemInventory") == null:
		return false
	var offset := player.global_position - global_position
	if Vector2(offset.x, offset.z).length() > interaction_distance:
		return false
	var start := player.global_position + Vector3.UP * 0.8
	var finish := Vector3(global_position.x, start.y, global_position.z)
	var ray := PhysicsRayQueryParameters3D.create(start, finish, 1, [player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func try_collect(player: CharacterBody3D) -> bool:
	if not can_collect(player):
		return false
	# Reserve before emitting inventory signals, so repeat requests cannot dupe it.
	_collected = true
	if not player.get_node("ItemInventory").add_item(item_type):
		_collected = false
		return false
	hide()
	set_deferred("monitorable", false)
	queue_free()
	return true
