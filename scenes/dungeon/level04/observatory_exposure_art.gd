extends "res://scenes/dungeon/level04/observatory_art_base.gd"
## Optical archive dressing. The original phase plates and safe own every clue.
const PROJECTION = preload("res://scenes/dungeon/level04/calibration_projection.gdshader")
var _instrument: Node3D
var index_collar: Node3D
var projections: Node3D
var record_drum: Node3D
var cabinets: Array[Node3D] = []
var exposure_units: Array[Node3D] = []

func build(room: Node3D, instrument: Node3D) -> void:
	name = "ExposureArchiveArt"
	room.add_child(self)
	_instrument = instrument
	# The current background owns the floor; the target puzzle owns all clues.
	for x: float in [-5.6,-3.0,2.6,5.2]: _cabinet(Vector3(x,0,-5.9))
	for spec in [Vector3(-5.6,2.8,-6.15),Vector3(-3,2.8,-6.15),Vector3(2.6,2.8,-6.15)]: _hanging_record(spec)
	for z: float in [-1.0,1.2,3.4]: _exposure_unit(Vector3(-6.2,0,z))
	_recording_table()
	_specimens()
	_original_controls()
	_projection()
	_batch(self)

func _fade_batch(parent: Node3D) -> void:
	_batch(parent)
	for view in parent.get_children():
		if view is MeshInstance3D:
			view.add_to_group("observatory_visual_occluders")
			view.set_meta("ignore_shutter_overlay",true)

func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, ink: Color, metal := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 0
	return _mesh(parent,mesh,at,ink,metal)

func _cabinet(at: Vector3) -> void:
	var cabinet := Node3D.new()
	cabinet.name = "StoneArchiveCabinet"
	cabinet.position = at
	add_child(cabinet)
	cabinets.append(cabinet)
	_box(cabinet,Vector3(0,0.99,0),Vector3(1.36,1.98,0.66),STONE)
	_box(cabinet,Vector3(0,2.02,0),Vector3(1.48,0.10,0.74),PALE.darkened(0.24))
	for row in 5:
		var y := 0.25+row*0.34
		_box(cabinet,Vector3(0,y,0.348),Vector3(1.14,0.28,0.035),DARK)
		_box(cabinet,Vector3(0,y+0.105,0.373),Vector3(1.12,0.017,0.018),BRASS,true)
		_box(cabinet,Vector3(0,y,0.395),Vector3(0.28,0.033,0.055),BRASS,true)
		_box(cabinet,Vector3(0.39,y,0.375),Vector3(0.16,0.06,0.01),PALE.darkened(0.4))
	for side: float in [-1,1]:
		_box(cabinet,Vector3(side*0.59,0.98,0.36),Vector3(0.045,1.8,0.025),BRASS,true)
	_fade_batch(cabinet)

func _hanging_record(at: Vector3) -> void:
	var record := Node3D.new()
	record.name = "SuspendedObservationScroll"
	record.position = at
	add_child(record)
	_rod(record,Vector3(-0.6,0.67,0),Vector3(0.6,0.67,0),0.055,BRASS)
	_rod(record,Vector3(-0.55,-0.64,0.02),Vector3(0.55,-0.64,0.02),0.062,BRASS)
	for side: float in [-1,1]:
		_rod(record,Vector3(side*0.48,0.68,0),Vector3(side*0.48,1.00,0),0.014,BRASS)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in 8:
		var y := -0.62+n*0.155
		var next_y := y+0.155
		var z := 0.055+0.035*cos(n*0.8)
		var next_z := 0.055+0.035*cos((n+1)*0.8)
		for p in [Vector3(-0.49,y,z),Vector3(0.49,y,z),Vector3(0.49,next_y,next_z),Vector3(-0.49,y,z),Vector3(0.49,next_y,next_z),Vector3(-0.49,next_y,next_z)]:
			surface.set_uv(Vector2(p.x+0.5,p.y))
			surface.add_vertex(p)
	surface.generate_normals()
	var sheet := _mesh(record,surface.commit(),Vector3.ZERO,Color("a9a089"))
	sheet.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Continuous optical diagrams and ruled traces, never extra countable stars.
	for n in 6:
		_box(record,Vector3(-0.08,0.40-n*0.11,0.105),Vector3(0.58-0.035*(n%3),0.009,0.006),DARK)
	var diagram := _ring(record,Vector3(0,-0.39,0.11),0.13,0.009,BRASS)
	diagram.rotation.x = PI/2
	_rod(record,Vector3(-0.30,-0.39,0.11),Vector3(0.30,-0.39,0.11),0.006,DARK)
	_fade_batch(record)

func _exposure_unit(at: Vector3) -> void:
	var unit := Node3D.new()
	unit.name = "BrassExposureInstrument"
	unit.position = at
	add_child(unit)
	exposure_units.append(unit)
	_box(unit,Vector3(0,0.27,0),Vector3(0.84,0.54,1.18),STONE)
	_box(unit,Vector3(0,0.57,0),Vector3(0.95,0.07,1.28),BRASS,true)
	for z: float in [-0.34,0.34]:
		_box(unit,Vector3(0,0.70,z),Vector3(0.14,0.24,0.12),BRASS,true)
	var barrel := _cylinder(unit,Vector3(0,0.88,0),0.22,0.70,BRASS,true)
	barrel.rotation.z = PI/2
	for x: float in [-0.36,0.02,0.33]:
		var collar := _ring(unit,Vector3(x,0.88,0),0.24,0.028,GOLD)
		collar.rotation.z = PI/2
	var lens := _cylinder(unit,Vector3(0.365,0.88,0),0.175,0.016,Color(0.39,0.69,0.85,0.75))
	lens.rotation.z = PI/2
	_box(unit,Vector3(-0.30,0.63,0.43),Vector3(0.18,0.035,0.23),DARK)
	for z: float in [-0.43,0.43]:
		_ring(unit,Vector3(0.14,0.64,z),0.085,0.017,BRASS)
	_fade_batch(unit)

func _recording_table() -> void:
	var table := Node3D.new()
	table.name = "MechanicalRecordingDesk"
	table.position = Vector3(5.6,0,4.0)
	table.rotation.y = -0.12
	add_child(table)
	_box(table,Vector3(0,0.36,0),Vector3(2.16,0.72,0.92),STONE)
	_box(table,Vector3(0,0.76,0),Vector3(2.34,0.10,1.04),BRASS,true)
	_box(table,Vector3(0,0.82,0.1),Vector3(1.75,0.016,0.54),Color("a19c87"))
	for n in 8:
		_box(table,Vector3(-0.18,0.834,-0.07+n*0.05),Vector3(1.12,0.004,0.006),DARK)
	for side: float in [-1,1]:
		var spool := _cylinder(table,Vector3(side*0.84,0.94,0),0.11,0.65,BRASS,true)
		spool.rotation.x = PI/2
	record_drum = Node3D.new()
	record_drum.name = "RecordDrum"
	table.add_child(record_drum)
	record_drum.position = Vector3(-0.84,0.95,0.42)
	record_drum.rotation.x = PI/2
	_gear(record_drum,Vector3.ZERO,0.19,18,0.018)
	_batch(record_drum)
	for view: MeshInstance3D in record_drum.get_children():
		view.add_to_group("observatory_visual_occluders")
		view.set_meta("ignore_shutter_overlay",true)
	_rod(table,Vector3(-0.20,0.86,-0.30),Vector3(0.10,1.08,0.02),0.018,BRASS)
	_rod(table,Vector3(0.10,1.08,0.02),Vector3(0.22,0.85,0.16),0.009,DARK)
	_fade_batch(table)

func _specimens() -> void:
	var bench := Node3D.new()
	bench.name = "PrismSpecimenShelf"
	bench.position = Vector3(-4.1,0,4.4)
	bench.rotation.y = 0.25
	add_child(bench)
	_box(bench,Vector3(0,0.35,0),Vector3(1.90,0.70,0.70),STONE)
	_box(bench,Vector3(0,0.73,0),Vector3(2.05,0.07,0.85),BRASS,true)
	for n in 3:
		var x := (n-1)*0.56
		_ring(bench,Vector3(x,0.79,0),0.19,0.024,GOLD)
		var prism := PrismMesh.new()
		prism.size = Vector3(0.24,0.40+n*0.06,0.26)
		var view := _mesh(bench,prism,Vector3(x,1.0,0),BLUE,true,0.22)
		view.rotation.y = 0.25+n*0.65
	_fade_batch(bench)

func _original_controls() -> void:
	var dial: Node3D = _instrument.level.get_node("Stations/p_dial")
	var base := Node3D.new()
	base.name = "ExposureWheelHousing"
	dial.add_child(base)
	_box(base,Vector3(0,0.29,0),Vector3(1.12,0.58,1.10),STONE)
	_cylinder(base,Vector3(0,0.64,0),0.59,0.06,BRASS,true)
	_fade_batch(base)
	index_collar = Node3D.new()
	index_collar.name = "ExposureIndexCollar"
	dial.add_child(index_collar)
	index_collar.position.y = 0.70
	_gear(index_collar,Vector3.ZERO,0.54,36,0.024)
	_batch(index_collar)
	var safe: Node3D = _instrument.level.get_node("Stations/p_safe")
	var casing := Node3D.new()
	casing.name = "ArchiveSafeHousing"
	safe.add_child(casing)
	_box(casing,Vector3(0,0.28,0),Vector3(1.14,0.56,0.90),STONE)
	for side: float in [-1,1]:
		_box(casing,Vector3(side*0.47,0.26,0.46),Vector3(0.05,0.42,0.025),BRASS,true)
	_fade_batch(casing)
	# Ornament follows the original opening hood instead of covering its controls.
	var trim := Node3D.new()
	trim.name = "HingedSafeTrim"
	_instrument.hood.add_child(trim)
	for side: float in [-1,1]:
		_box(trim,Vector3(side*0.59,0,0.437),Vector3(0.026,0.61,0.018),GOLD,true)
		_box(trim,Vector3(0,side*0.30,0.437),Vector3(1.17,0.025,0.018),GOLD,true)
	_fade_batch(trim)

func _projection() -> void:
	projections = Node3D.new()
	projections.name = "ArchiveScaleProjection"
	add_child(projections)
	var plate := PlaneMesh.new()
	plate.size = Vector2(2.0,2.0)
	var view := _mesh(projections,plate,Vector3(3.8,0.024,4.3),BLUE)
	var material := ShaderMaterial.new()
	material.shader = PROJECTION
	view.material_override = material
	view.set_meta("ignore_shutter_overlay",true)
	var source := Vector3(5.0,1.0,4.4)
	var target := Vector3(3.8,0.03,4.3)
	var ray := _rod(projections,source,target,0.009,Color(0.52,0.81,1.0,0.18))
	ray.set_meta("ignore_shutter_overlay",true)

func _process(delta: float) -> void:
	var player: Node3D = _instrument.level.player
	var nearby := player.global_position.distance_squared_to(global_position)<400
	projections.visible = nearby
	if not nearby: return
	index_collar.rotation.y = lerp_angle(index_collar.rotation.y,float(_instrument.exposure)*TAU/3,1.0-exp(-4.0*delta))
	record_drum.quaternion = Quaternion(Vector3.RIGHT,PI/2)*Quaternion(Vector3.UP,index_collar.rotation.y*0.35)
