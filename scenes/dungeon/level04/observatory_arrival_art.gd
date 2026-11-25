extends "res://scenes/dungeon/level04/observatory_art_base.gd"
## Arrival ceremony shares the observatory palette; all new geometry is visual.
const FONT := preload("res://scenes/ui/dungeon_font.tres")
const DIAL := Vector3(0,0,0.35)

func build(room: Node3D, plinth: StaticBody3D) -> void:
	name = "ArrivalArt"
	room.add_child(self)
	# The target's background pass owns the Deck material and room profile.
	plinth.get_node("Surface").material_override = _mat(STONE.darkened(0.10))
	_arch()
	_welcome_instrument()
	_floor_dial()
	for side: float in [-1,1]: _lamp(side)
	_transport_sign()
	_guide_light()
	for n in 5:
		var chip := _chip(Vector3(3.45+n*0.13,0.014,2.1-n*0.55),0.25+0.04*(n%2),STONE.darkened(0.18))
		chip.rotation.y = n*0.8
	_batch(self)

func _fade(parent: Node3D, merge := true) -> void:
	if merge: _batch(parent)
	for mesh in parent.get_children():
		if mesh is MeshInstance3D:
			mesh.add_to_group("observatory_visual_occluders")
			mesh.set_meta("ignore_shutter_overlay",true)

func _arch_block(parent: Node3D, a: float, b: float, ink: Color) -> void:
	var points: Array[Vector3] = []
	for z: float in [-0.42,0.42]:
		for spec in [Vector2(2.98,a),Vector2(3.64,a),Vector2(3.64,b),Vector2(2.98,b)]:
			points.append(Vector3(cos(spec.y)*spec.x,2.30+sin(spec.y)*spec.x,z))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for quad in [[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]:
		for index in [0,1,2,0,2,3]:
			var point := points[quad[index]]
			surface.set_uv(Vector2(point.x,point.y)*0.4)
			surface.add_vertex(point)
	surface.generate_normals()
	_mesh(parent,surface.commit(),Vector3.ZERO,ink,false,0,true)

func _arch() -> void:
	var arch := Node3D.new()
	arch.name = "MonumentalEntranceArch"
	arch.position.z = -3.65
	add_child(arch)
	for side: float in [-1,1]:
		for n in 4:
			_box(arch,Vector3(side*3.31,0.30+n*0.57,0),Vector3(0.66,0.55,0.79),STONE.darkened(0.025*(n%2)),false,true)
		_box(arch,Vector3(side*3.31,0.12,0),Vector3(0.98,0.24,1.04),DARK,false,true)
		_box(arch,Vector3(side*3.31,2.27,0),Vector3(0.91,0.19,1.00),PALE.darkened(0.2),false,true)
		_box(arch,Vector3(side*3.31,1.09,0.416),Vector3(0.075,1.69,0.035),BRASS,true,true)
	for n in 15:
		var a := n*PI/15+0.009
		var b := (n+1)*PI/15-0.009
		_arch_block(arch,a,b,STONE.lightened(0.055*(n%3)))
		for radius in [3.03,3.58]:
			var p := Vector3(cos(a)*radius,2.30+sin(a)*radius,0.445)
			var q := Vector3(cos(b)*radius,2.30+sin(b)*radius,0.445)
			_rod(arch,p,q,0.025,BRASS,true)
	var crest := Node3D.new()
	crest.name = "ObservatoryEntranceCrest"
	arch.add_child(crest)
	crest.position = Vector3(0,5.65,0.46)
	crest.rotation.x = PI/2
	_gear(crest,Vector3.ZERO,0.36,24,0.035)
	_ring(crest,Vector3(0,0.035,0),0.22,0.022,GOLD)
	var lens := SphereMesh.new()
	lens.radius = 0.105
	lens.height = 0.21
	lens.radial_segments = 16
	lens.rings = 8
	_mesh(crest,lens,Vector3.ZERO,BLUE,true,0.25)
	_fade(crest)
	# Each arch stone fades independently when the player walks beneath it.
	_fade(arch,false)

func _welcome_instrument() -> void:
	var instrument := Node3D.new()
	instrument.name = "BrassWelcomeInstrument"
	instrument.position = Vector3(-3.9,1.28,1.6)
	add_child(instrument)
	_ring(instrument,Vector3.ZERO,0.55,0.055,BRASS)
	for side: float in [-1,1]:
		_rod(instrument,Vector3(side*0.46,0.04,0),Vector3(side*0.46,0.76,0),0.045,BRASS)
	var iris := Node3D.new()
	iris.name = "WelcomeOpticalIris"
	instrument.add_child(iris)
	iris.position.y = 0.68
	iris.rotation.x = 0.96
	_gear(iris,Vector3.ZERO,0.56,32,0.04)
	_ring(iris,Vector3.ZERO,0.44,0.035,GOLD)
	for n in 8:
		var angle := n*TAU/8
		var leaf := _box(iris,Vector3(cos(angle)*0.28,0.035,sin(angle)*0.28),Vector3(0.24,0.038,0.12),BRASS,true)
		leaf.rotation.y = -angle+0.32
	_ring(iris,Vector3(0,0.065,0),0.19,0.025,BLUE)
	_fade(iris)
	_fade(instrument)

func _floor_dial() -> void:
	var dial := Node3D.new()
	dial.name = "ArrivalScaleInlay"
	add_child(dial)
	for radius in [1.72,2.05,2.21]: _ring(dial,DIAL+Vector3.UP*0.023,radius,0.022,BRASS)
	for n in 64:
		var angle := n*TAU/64
		var point := DIAL+Vector3(cos(angle),0,sin(angle))*2.13
		point.y = 0.029
		var tick := _box(dial,point,Vector3(0.22 if n%8 == 0 else 0.095,0.012,0.022),GOLD,true)
		tick.rotation.y = -angle
	for n in 4:
		var angle := n*PI/2
		var at := DIAL+Vector3(cos(angle),0,sin(angle))*1.55
		at.y = 0.026
		var needle := _box(dial,at,Vector3(0.20,0.012,0.08),BRASS,true)
		needle.rotation.y = -angle
	_batch(dial)

func _lamp(side: float) -> void:
	var lamp := Node3D.new()
	lamp.name = "MechanicalLampWest" if side < 0 else "MechanicalLampEast"
	lamp.position = Vector3(side*4.75,0,-2.20)
	add_child(lamp)
	_box(lamp,Vector3(0,0.16,0),Vector3(0.67,0.32,0.70),STONE)
	_box(lamp,Vector3(0,1.05,0),Vector3(0.28,1.65,0.30),DARK)
	for y: float in [0.38,1.60,2.25]:
		_box(lamp,Vector3(0,y,0),Vector3(0.45,0.09,0.45),BRASS,true)
	for x: float in [-0.20,0.20]:
		_rod(lamp,Vector3(x,1.65,-0.20),Vector3(x,2.25,-0.20),0.025,GOLD)
		_rod(lamp,Vector3(x,1.65,0.20),Vector3(x,2.25,0.20),0.025,GOLD)
	var prism := PrismMesh.new()
	prism.size = Vector3(0.21,0.46,0.21)
	_mesh(lamp,prism,Vector3(0,1.96,0),BLUE,true,0.40)
	_box(lamp,Vector3(0,2.34,0),Vector3(0.52,0.13,0.52),STONE)
	_fade(lamp)

func _transport_sign() -> void:
	var sign := Node3D.new()
	sign.name = "OldTransportSign"
	sign.position = Vector3(3.95,0,1.40)
	add_child(sign)
	_box(sign,Vector3(0,0.12,0),Vector3(0.78,0.24,0.62),STONE)
	_box(sign,Vector3(0,0.76,0),Vector3(0.12,1.30,0.12),BRASS,true)
	_box(sign,Vector3(0,1.52,0),Vector3(1.22,0.85,0.13),BRASS,true)
	_box(sign,Vector3(0,1.52,0.075),Vector3(1.09,0.73,0.025),DARK)
	var label := Label3D.new()
	label.font = FONT
	label.font_size = 32
	label.pixel_size = 0.0052
	label.text = "观测站 · 到达\n↑ 北行装卸场"
	label.modulate = GOLD.lightened(0.2)
	label.outline_size = 0
	label.position = Vector3(0,1.54,0.10)
	sign.add_child(label)
	_fade(sign)

func _guide_light() -> void:
	var guide := Node3D.new()
	guide.name = "BlueWhiteArrivalGuides"
	add_child(guide)
	for side: float in [-1,1]:
		# Beams stay at the sides of the approach, below the arch silhouette.
		_rod(guide,Vector3(side*4.60,1.94,-2.20),Vector3(side*2.70,0.07,-3.22),0.025,Color(0.54,0.82,0.96,0.12))
		for n in 4:
			var light := _box(guide,Vector3(side*0.77,0.031,-1.75-n*0.66),Vector3(0.035,0.012,0.36),BLUE)
			light.material_override = _mat(BLUE,false,0.20)
	for n in 2:
		var arrow := Vector3(0,0.035,-2.45-n*0.86)
		_rod(guide,arrow+Vector3(-0.20,0,0.16),arrow,0.014,Color(0.53,0.80,0.92,0.65))
		_rod(guide,arrow+Vector3(0.20,0,0.16),arrow,0.014,Color(0.53,0.80,0.92,0.65))
	_batch(guide)
