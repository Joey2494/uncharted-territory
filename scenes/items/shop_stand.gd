extends Node3D
## Small in-world purchase entry; a future shop UI calls the same inventory API.

const Catalog = preload("res://data/item_catalog.gd")
@export var product_id: int = 0
@export var interaction_distance: float = 1.8


func _ready() -> void:
	add_to_group("world_interactables")
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 0.8, 0.8)
	var material := StandardMaterial3D.new()
	var colors := [Color("#4fbe78"), Color("#e2b458"), Color("#4dbcca"), Color("#8c9ca8"), Color("#b87b5d")]
	material.albedo_color = colors[clampi(product_id, 0, colors.size() - 1)]
	box.material = material
	mesh.mesh = box
	mesh.position.y = 0.4
	add_child(mesh)
	var label := Label3D.new()
	label.position.y = 1.4
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font = preload("res://scenes/ui/dungeon_font.tres")
	label.font_size = 36
	label.pixel_size = 0.008
	var product := Catalog.get_item(product_id)
	label.text = "%s\n%d 金币" % [product.get("name", ""), product.get("price", 0)]
	add_child(label)


func can_interact(player: CharacterBody3D) -> bool:
	if not can_process() or not is_visible_in_tree() or not is_instance_valid(player):
		return false
	if player.is_dead() or not player.can_process() or player.get_node_or_null("ItemInventory") == null:
		return false
	if global_position.distance_to(player.global_position) > interaction_distance:
		return false
	var start := player.global_position + Vector3.UP * 0.8
	var end := Vector3(global_position.x, start.y, global_position.z)
	return get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(start, end, 1, [player.get_rid()])).is_empty()


func get_interaction_prompt() -> String:
	var product := Catalog.get_item(product_id)
	return "[E] 购买 %s · %d 金币" % [product.get("name", ""), product.get("price", 0)]


func try_interact(player: CharacterBody3D) -> bool:
	return can_interact(player) and player.get_node("ItemInventory").try_purchase(product_id)
