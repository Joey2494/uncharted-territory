extends RefCounted
## Visual-only adapter. The target architecture, puzzles and sweeps are intact.
const COUNTERWEIGHT := preload("res://scenes/dungeon/level04/observatory_counterweight_art.gd")
const EXPOSURE := preload("res://scenes/dungeon/level04/observatory_exposure_art.gd")
const SHUTTER := preload("res://scenes/dungeon/level04/observatory_shutter_art.gd")
const DOME := preload("res://scenes/dungeon/level04/observatory_dome_art.gd")

func apply(level: Node3D) -> void:
	var layout: Node3D = level.get_node("Layout")
	if not layout.has_node("D/CounterweightWellArt"): COUNTERWEIGHT.new().build(layout)
	if not layout.has_node("E/ExposureArchiveArt"): EXPOSURE.new().build(layout.get_node("E"),level.get_node("Puzzles"))
	if not layout.has_node("H/ShutterTestArt"): SHUTTER.new().build(layout)
	if not layout.has_node("I/DomeArt"): DOME.new().build(layout.get_node("I"),layout.get_node("I/InstrumentIsland"))
	_finish_surfaces(level)
	sync_warning_surfaces(level)

func _finish_surfaces(level: Node3D) -> void:
	# Reuse the installed wall textures, normals and palette for original tagged
	# shaft/vault surfaces. Never rebatch these meshes or replace room floors.
	var background: RefCounted = level.get_node("WorldEnvironment").finish
	for spec in [["D",3],["I",8]]:
		for view: MeshInstance3D in level.layout.get_node(spec[0]).find_children("*","MeshInstance3D",true,false):
			var kind: String = view.get_meta("observatory_background_surface","")
			if kind not in ["shaft","masonry","vault"]: continue
			view.set_meta("ignore_shutter_overlay",true)
			if view.get_meta("observatory_background_finished",false): continue
			var material := background._walls[spec[1]].duplicate() as StandardMaterial3D
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			if kind == "shaft": material.albedo_color = Color("798c9d")
			view.material_override = material
			view.set_meta("observatory_background_finished",true)

func sync_warning_surfaces(level: Node3D) -> void:
	# Setup ran before deferred art creation. Reuse the same live effects on
	# eligible new floor details, while honoring the old visual exclusion flag.
	# No sweep state, timing, targeting or damage code is replaced.
	for room: String in ["H","I"]:
		var light: Node3D = level.combat._sweeps[room]
		for view: MeshInstance3D in level.layout.find_children("*","MeshInstance3D",true,false):
			if view.get_meta("ignore_shutter_overlay",false):
				if view.material_overlay == light.effect: view.material_overlay = null
				continue
			if not view.get_meta("observatory_art_detail",false): continue
			var offset := view.global_position-light.global_position
			if absf(offset.x) <= light.radii.x+1.0 and absf(offset.z) <= light.radii.y+1.0:
				view.material_overlay = light.effect
