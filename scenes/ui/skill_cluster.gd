extends Control
## Keep J anchored to the bottom-right; secondary actions follow an even arc.
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
	var poses := {"MeleeCooldown": Vector3(140,140,104)}
	var center := Vector2(192,192)
	var orbit := {"DodgeCooldown":180.0,"CharacterCooldown":210.0,"SwitchCooldown":240.0,"ReplenishCooldown":270.0}
	for action in orbit:
		var point := center+Vector2.from_angle(deg_to_rad(orbit[action]))*156.0
		poses[action] = Vector3(point.x-36.0,point.y-36.0,72.0)
	poses["SkillCooldown"] = poses["SwitchCooldown"] # Retired spell badge stays hidden.
	var extra := 0
	var extra_height := ceilf(maxi(0, get_child_count() - poses.size()) / 2.0) * 64
	var height := 244.0 + extra_height
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
	custom_minimum_size = Vector2(244, height) * scale_factor
