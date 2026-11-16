extends Control
## Staggered primary/secondary actions. Future children use the smaller tier.
var _compact := false

func _ready() -> void:
	for child in get_children():
		if child is Control:
			child.visibility_changed.connect(_layout_tiles)
	_layout_tiles()

func set_compact_mode(compact: bool) -> void:
	if _compact == compact:
		return
	_compact = compact
	_layout_tiles()

func _layout_tiles() -> void:
	var scale_factor := 0.74 if _compact else 0.88
	var poses := {"MeleeCooldown": Vector3(108, 92, 104), "SkillCooldown": Vector3(122, 0, 80), "DodgeCooldown": Vector3(12, 76, 72), "CharacterCooldown": Vector3(12, 0, 56)}
	var extra := 0
	var extra_height := ceilf(maxi(0, get_child_count() - 4) / 2.0) * 64
	var height := 196.0 + extra_height
	for child in get_children():
		if not child is Control:
			continue
		var pose: Vector3
		if poses.has(child.name):
			pose = poses[child.name]
		else:
			pose = Vector3((extra % 2) * 64, -64 - floorf(extra / 2.0) * 64, 56)
			extra += 1
		child.set_anchors_preset(Control.PRESET_TOP_LEFT)
		child.set_badge_size(pose.z * scale_factor)
		child.position = Vector2(pose.x, pose.y + extra_height) * scale_factor
		height = maxf(height, child.position.y / scale_factor + pose.z)
	custom_minimum_size = Vector2(212, height) * scale_factor
