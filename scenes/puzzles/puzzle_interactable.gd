extends StaticBody3D
## Shares the player's nearest-target E interaction with ordinary pickups.

@export_enum("日符文", "月符文", "星符文", "奖励宝箱") var interaction_kind: int = 0
@export_range(0.5, 3.0, 0.1) var interaction_distance: float = 1.8

@onready var _puzzle: Node3D = get_parent()

var _rune_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("world_interactables")
	if interaction_kind < 3:
		_rune_material = $RuneMesh.get_active_material(0).duplicate() as StandardMaterial3D
		$RuneMesh.material_override = _rune_material
		$Glow.material_override = _rune_material
		set_rune_state(false, false)


func can_interact(player: CharacterBody3D) -> bool:
	if not is_node_ready() or not can_process() or not is_visible_in_tree() or not is_instance_valid(player):
		return false
	if player.is_dead() or not player.can_process() or not _puzzle.is_interaction_available(interaction_kind):
		return false
	var offset := player.global_position - global_position
	if absf(offset.y) > 2.0 or Vector2(offset.x, offset.z).length() > interaction_distance:
		return false
	var start := player.global_position + Vector3.UP * 0.8
	var end := Vector3(global_position.x, start.y, global_position.z)
	var ray := PhysicsRayQueryParameters3D.create(start, end, 1, [get_rid(), player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func get_interaction_prompt() -> String:
	return _puzzle.get_interaction_prompt(interaction_kind)


func try_interact(player: CharacterBody3D) -> bool:
	if not can_interact(player):
		return false
	return _puzzle.claim_reward(player) if interaction_kind == 3 else _puzzle.activate_rune(interaction_kind, player)


func set_rune_state(lit: bool, failed: bool) -> void:
	if interaction_kind >= 3 or _rune_material == null:
		return
	var colors := [Color("e88d43"), Color("67cbea"), Color("ba9cf1")]
	var color: Color = colors[interaction_kind]
	if failed:
		color = Color("eb4d4d")
	elif lit:
		color = color.lerp(Color.WHITE, 0.4)
	_rune_material.albedo_color = color
	_rune_material.emission = color
	_rune_material.emission_energy_multiplier = 1.0 if lit or failed else 0.12
	$Glyph.modulate = color
	$Glyph.text = ["日", "月", "星"][interaction_kind] + ("\n已亮" if lit else "")
	$Glyph.position.y = 2.25 if lit else 1.9
