extends RefCounted
## Selective optical/transport art, applied after the target's live setup.
const WALKWAY := preload("res://scenes/dungeon/level04/observatory_walkway_art.gd")
const MAIL := preload("res://scenes/dungeon/level04/observatory_mail_art.gd")
const MIRROR := preload("res://scenes/dungeon/level04/observatory_mirror_art.gd")
const DARKROOM := preload("res://scenes/dungeon/level04/observatory_darkroom_art.gd")

func apply(level: Node3D) -> void:
	var layout: Node3D = level.get_node("Layout")
	if not layout.has_node("F/WalkwayArt"): WALKWAY.new().build(layout)
	if not layout.has_node("G/MailMaintenanceArt"): MAIL.new().build(layout.get_node("G"),level.get_node("Mail"))
	if not layout.has_node("K/MirrorRoomArt"): MIRROR.new().build(layout.get_node("K"),level.get_node("Puzzles"))
	if not layout.has_node("L/NightDarkroomArt"): DARKROOM.new().build(layout.get_node("L"),level.get_node("Puzzles"))
	# Keep the tagged abyss surface outside material batching and use the same
	# background treatment as the restored well and the original courtyard.
	for view: MeshInstance3D in layout.get_node("F/WalkwayArt").find_children("*","MeshInstance3D",true,false):
		if view.get_meta("observatory_background_surface","") != "abyss": continue
		if view.get_meta("observatory_background_finished",false): continue
		var material := ShaderMaterial.new()
		material.shader = level.get_node("WorldEnvironment").finish.ABYSS
		view.material_override = material
		view.set_meta("ignore_shutter_overlay",true)
		view.set_meta("observatory_background_finished",true)
