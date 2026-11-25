extends "res://scenes/dungeon/level04/observatory_art_base.gd"
## Abstract negatives never reproduce or reveal the original photographic clues.
const FILM = preload("res://scenes/dungeon/level04/hanging_negative.gdshader")
const DARK_FLOOR = preload("res://scenes/dungeon/level04/darkroom_floor.gdshader")
var _instrument: Node3D
var hanging_films: Array[MeshInstance3D] = []
var racks: Array[Node3D] = []
var local_lights: Array[OmniLight3D] = []
var _status: StandardMaterial3D
var _last_developed := false

func build(room: Node3D, instrument: Node3D) -> void:
	name = "NightDarkroomArt"
	room.add_child(self)
	_instrument = instrument
	var material := ShaderMaterial.new()
	material.shader = DARK_FLOOR
	for view in room.get_node("Deck").get_children():
		if not view is MeshInstance3D: continue
		var previous := view.material_override as ShaderMaterial
		if previous != null:
			for uniform: Dictionary in previous.shader.get_shader_uniform_list():
				var value: Variant = previous.get_shader_parameter(uniform.name)
				if value != null: material.set_shader_parameter(uniform.name,value)
		view.material_override = material
	# Fit the existing racks beside the new five-metre LI doorway.
	_rack(Vector3(-4.4,0,-6.05))
	_rack(Vector3(4.4,0,-6.05))
	for z: float in [-2.1,0.0,2.1]: _cabinet(Vector3(6.85,0,z))
	_exposure_unit(Vector3(-6.3,0,-3.3))
	_exposure_unit(Vector3(-6.3,0,5.65))
	_sink()
	_original_tables()
	_lighting()
	_batch(self)

func _fade_batch(parent: Node3D) -> void:
	_batch(parent)
	for view in parent.get_children():
		if view is MeshInstance3D:
			view.add_to_group("observatory_visual_occluders")
			view.set_meta("ignore_shutter_overlay",true)

func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, ink: Color, metal := false) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 24
	shape.rings = 0
	return _mesh(parent,shape,at,ink,metal)

func _rack(at: Vector3) -> void:
	var rack := Node3D.new()
	rack.name = "BrassDevelopingRack"
	rack.position = at
	rack.scale.x = 0.64
	add_child(rack)
	racks.append(rack)
	for side: float in [-1,1]:
		_box(rack,Vector3(side*2.40,0.10,0),Vector3(0.42,0.20,0.55),DARK)
		_rod(rack,Vector3(side*2.40,0.20,0),Vector3(side*2.40,3.25,0),0.052,BRASS)
		_box(rack,Vector3(side*2.40,3.24,0),Vector3(0.20,0.09,0.22),GOLD,true)
	_rod(rack,Vector3(-2.40,3.18,0),Vector3(2.40,3.18,0),0.055,BRASS)
	_rod(rack,Vector3(-2.40,1.43,0),Vector3(2.40,1.43,0),0.024,BRASS)
	for n in 4:
		var x := -1.72+n*1.14
		_rod(rack,Vector3(x,3.18,0),Vector3(x,2.95,0),0.012,GOLD)
		_box(rack,Vector3(x,2.95,0.025),Vector3(0.13,0.13,0.045),BRASS,true)
		var film := PlaneMesh.new()
		film.orientation = PlaneMesh.FACE_Z
		film.size = Vector2(0.64,1.27)
		var sheet := _mesh(rack,film,Vector3(x,2.29,0.035),Color(0.2,0.3,0.4,0.24))
		var material := ShaderMaterial.new()
		material.shader = FILM
		sheet.material_override = material
		sheet.set_meta("ignore_shutter_overlay",true)
		hanging_films.append(sheet)
	# Shader film stays in a child holder so static metal batching is separate.
	for sheet: MeshInstance3D in hanging_films:
		if sheet.get_parent() == rack:
			var holder := Node3D.new()
			rack.add_child(holder)
			sheet.reparent(holder)
	_fade_batch(rack)

func _cabinet(at: Vector3) -> void:
	var cabinet := Node3D.new()
	cabinet.name = "MechanicalFilmCabinet"
	cabinet.position = at
	cabinet.rotation.y = -PI/2
	add_child(cabinet)
	_box(cabinet,Vector3(0,1.02,0),Vector3(1.42,2.04,0.77),STONE.darkened(0.22))
	_box(cabinet,Vector3(0,2.09,0),Vector3(1.56,0.10,0.86),BRASS,true)
	for n in 6:
		var y := 0.24+n*0.29
		_box(cabinet,Vector3(0,y,0.40),Vector3(1.21,0.23,0.025),DARK)
		_box(cabinet,Vector3(0,y,0.435),Vector3(0.29,0.026,0.07),BRASS,true)
		_box(cabinet,Vector3(0.43,y,0.42),Vector3(0.16,0.065,0.01),PALE.darkened(0.48))
	var wheel := _ring(cabinet,Vector3(-0.48,1.01,0.46),0.15,0.025,BRASS)
	wheel.rotation.x = PI/2
	_fade_batch(cabinet)

func _exposure_unit(at: Vector3) -> void:
	var unit := Node3D.new()
	unit.name = "PrecisionExposureHead"
	unit.position = at
	add_child(unit)
	_box(unit,Vector3(0,0.28,0),Vector3(0.92,0.56,0.85),STONE.darkened(0.24))
	_box(unit,Vector3(0,0.59,0),Vector3(1.05,0.07,0.96),BRASS,true)
	_rod(unit,Vector3(-0.22,0.63,0),Vector3(-0.22,1.17,0),0.055,BRASS)
	var barrel := _cylinder(unit,Vector3(0.10,1.14,0),0.20,0.56,BRASS,true)
	barrel.rotation.z = PI/2
	var lens := _cylinder(unit,Vector3(0.39,1.14,0),0.15,0.02,Color(0.30,0.59,0.78,0.68))
	lens.rotation.z = PI/2
	var rim := _ring(unit,Vector3(0.40,1.14,0),0.21,0.025,GOLD)
	rim.rotation.z = PI/2
	_ring(unit,Vector3(0.22,0.66,0.27),0.11,0.018,BRASS)
	_fade_batch(unit)

func _sink() -> void:
	var bench := Node3D.new()
	bench.name = "StoneRinseBench"
	bench.position = Vector3(-6.3,0,3.65)
	add_child(bench)
	_box(bench,Vector3(0,0.30,0),Vector3(1.80,0.60,1.00),STONE.darkened(0.25))
	_box(bench,Vector3(0,0.63,0),Vector3(1.97,0.07,1.12),BRASS,true)
	_box(bench,Vector3(0,0.674,0),Vector3(1.63,0.02,0.79),DARK)
	_box(bench,Vector3(0,0.69,0),Vector3(1.43,0.008,0.62),Color(0.12,0.26,0.35,0.5))
	for side: float in [-1,1]:
		_box(bench,Vector3(side*0.86,0.71,0),Vector3(0.06,0.15,0.91),BRASS,true)
		_box(bench,Vector3(0,0.71,side*0.46),Vector3(1.74,0.15,0.06),BRASS,true)
	_rod(bench,Vector3(0,0.67,-0.42),Vector3(0,1.05,-0.42),0.024,BRASS)
	_rod(bench,Vector3(0,1.05,-0.42),Vector3(0,1.05,-0.21),0.024,BRASS)
	_fade_batch(bench)

func _original_tables() -> void:
	var box: Node3D = _instrument.level.get_node("Stations/p_lightbox")
	for view in box.get_children():
		if view is MeshInstance3D and view.mesh is BoxMesh and view.mesh.size.is_equal_approx(Vector3(2.1,0.18,1.2)):
			view.material_override = _mat(Color("74564d"),true)
	var stone := Node3D.new()
	stone.name = "StoneDevelopingTable"
	box.add_child(stone)
	_box(stone,Vector3(0,0.30,0),Vector3(2.02,0.60,1.11),STONE.darkened(0.20))
	for side: float in [-1,1]:
		_box(stone,Vector3(side*1.04,0.68,0),Vector3(0.055,0.08,1.16),BRASS,true)
		_box(stone,Vector3(0,0.68,side*0.57),Vector3(2.06,0.08,0.05),BRASS,true)
	var bar := _box(stone,Vector3(0,0.42,0.57),Vector3(0.38,0.035,0.018),Color("813c37"))
	bar.material_override = bar.material_override.duplicate()
	_status = bar.material_override
	_fade_batch(stone)
	var tray: Node3D = _instrument.level.get_node("Stations/p_print")
	var support := Node3D.new()
	support.name = "StonePrintTray"
	tray.add_child(support)
	_box(support,Vector3(0,0.26,0),Vector3(1.48,0.52,0.91),STONE.darkened(0.22))
	_box(support,Vector3(0,0.55,0),Vector3(1.63,0.06,1.00),BRASS,true)
	_box(support,Vector3(0,0.59,0),Vector3(1.44,0.015,0.82),DARK)
	_fade_batch(support)

func _lighting() -> void:
	for x: float in [-6.0,6.0]:
		var at := Vector3(x,3.18,-5.94)
		var cage := _ring(self,at,0.16,0.028,BRASS,true)
		cage.rotation.x = PI/2
		var bulb := SphereMesh.new()
		bulb.radius = 0.095
		bulb.height = 0.19
		bulb.radial_segments = 16
		bulb.rings = 8
		_mesh(self,bulb,at,Color("9b3734"),false,0.5,true)
		var light := OmniLight3D.new()
		light.position = at+Vector3(0,0,0.25)
		light.light_color = Color("a63b36")
		light.light_energy = 0.35
		light.omni_range = 2.2
		light.shadow_enabled = false
		add_child(light)
		local_lights.append(light)
	var blue := OmniLight3D.new()
	blue.position = Vector3(-5.7,1.15,3.65)
	blue.light_color = Color("5d9ac5")
	blue.light_energy = 0.30
	blue.omni_range = 2.7
	blue.shadow_enabled = false
	add_child(blue)
	local_lights.append(blue)
	for n in 2:
		var view := _box(self,Vector3(-5.95+n*0.42,0.72,3.7),Vector3(0.03,0.008,0.42),Color(0.34,0.65,0.86,0.18))
		view.rotation.y = -0.35

func _process(_delta: float) -> void:
	var nearby: bool = _instrument.level.player.global_position.distance_squared_to(global_position)<361
	for light in local_lights: light.visible = nearby
	if _instrument.film_developed != _last_developed:
		_last_developed = _instrument.film_developed
		_status.albedo_color = Color("6d98b0") if _last_developed else Color("813c37")
