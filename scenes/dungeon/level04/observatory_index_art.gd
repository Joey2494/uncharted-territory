extends "res://scenes/dungeon/level04/observatory_art_base.gd"
## Decorative precision control hub: flush rotating mechanisms, clear doorways.
var rotors: Array[Dictionary] = []
var _layout: Node3D
const DIAL_CENTER := Vector3(0,0,-0.75)

func build(layout: Node3D) -> void:
	name = "IndexHallArt"
	_layout = layout
	var room: Node3D = layout.get_node("C")
	room.add_child(self)
	# Keep the target's floor, wing signs, beacons and all doorway geometry.
	_scale_floor()
	_mechanism()
	_pillars()
	_console(Vector3(-6.25,0,-0.65),0.13)
	_console(Vector3(4.6,0,-0.75),-0.35)
	_chains()
	_batch(self)

func _scale_floor() -> void:
	for spec in [Vector2(3.44,0.065),Vector2(3.13,0.026),Vector2(2.96,0.018)]:
		_ring(self,DIAL_CENTER+Vector3.UP*0.021,spec.x,spec.y,BRASS)
	for i in 120:
		var angle := i*TAU/120
		var length := 0.31 if i%10 == 0 else (0.19 if i%5 == 0 else 0.095)
		var at := DIAL_CENTER+Vector3(sin(angle)*3.30,0.026,-cos(angle)*3.30)
		var tick := _box(self,at,Vector3(0.026 if i%10 else 0.045,0.016,length),GOLD,true)
		tick.rotation.y = -angle
	for i in 12:
		var angle := i*TAU/12
		var number := Label3D.new()
		number.text = str(i*30)+"°"
		number.font = preload("res://scenes/ui/dungeon_font.tres")
		number.font_size = 32
		number.pixel_size = 0.007
		number.modulate = GOLD.darkened(0.14)
		number.outline_size = 0
		number.no_depth_test = false
		number.position = DIAL_CENTER+Vector3(sin(angle)*2.83,0.031,-cos(angle)*2.83)
		number.rotation.x = -PI/2
		add_child(number)
	# Four fixed index needles and subdued luminous reference marks.
	for i in 4:
		var angle := i*TAU/4
		var at := DIAL_CENTER+Vector3(sin(angle)*3.65,0.03,-cos(angle)*3.65)
		_box(self,at,Vector3(0.14,0.025,0.14),BRASS,true).rotation.y = angle+PI/4
		_box(self,at+Vector3.UP*0.018,Vector3(0.065,0.01,0.065),Color(0.42,0.72,0.84,0.5)).rotation.y = angle+PI/4

func _disc(parent: Node3D, radius: float, height: float, at: Vector3, ink: Color) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 64
	shape.rings = 0
	_mesh(parent,shape,at,ink,true)

func _rotor(at: Vector3, radius: float, teeth: int, speed: float) -> Node3D:
	var rotor := Node3D.new()
	rotor.name = "PrecisionRotor"
	add_child(rotor)
	rotor.position = at
	_gear(rotor,Vector3.ZERO,radius,teeth,0.043)
	_ring(rotor,Vector3(0,0.008,0),radius*0.77,0.028,GOLD)
	for i in 6:
		var angle := i*TAU/6
		_rod(rotor,Vector3(0,0.006,0),Vector3(sin(angle)*radius*0.84,0.006,cos(angle)*radius*0.84),0.022,BRASS)
	_disc(rotor,radius*0.19,0.035,Vector3(0,0.025,0),GOLD)
	_batch(rotor)
	rotors.append({"node":rotor,"speed":speed})
	return rotor

func _mechanism() -> void:
	# Less than ten centimetres of visual relief; the original flat floor owns collision.
	_disc(self,1.72,0.018,DIAL_CENTER+Vector3.UP*0.016,DARK)
	var dial := _rotor(DIAL_CENTER+Vector3.UP*0.046,1.60,80,0.08)
	_disc(dial,1.43,0.018,Vector3(0,0.008,0),STONE.darkened(0.28))
	for radius in [0.53,0.91,1.30]: _ring(dial,Vector3(0,0.025,0),radius,0.022,GOLD)
	for i in 8:
		var angle := i*TAU/8
		var at := Vector3(sin(angle)*0.90,0.039,cos(angle)*0.90)
		var aperture := _box(dial,at,Vector3(0.12,0.008,0.52),BRASS,true)
		aperture.rotation.y = -angle
		_box(dial,at+Vector3.UP*0.007,Vector3(0.04,0.006,0.22),Color(0.31,0.61,0.73,0.25)).rotation.y = -angle
	_disc(dial,0.20,0.034,Vector3(0,0.04,0),BRASS)
	_ring(dial,Vector3(0,0.064,0),0.14,0.014,Color(0.55,0.84,1.0,0.8))
	_batch(dial)
	_rotor(Vector3(-2.28,0.048,-0.75),0.59,30,-0.08*80/30)
	_rotor(Vector3(-2.28,0.048,-1.87),0.49,25,0.08*80/25)
	_rotor(Vector3(-1.45,0.048,-2.75),0.68,34,-0.08*80/34)

func _pillars() -> void:
	# Shift edge details clear of the target's CE/CF/CD entrances and wing signs.
	for spec in [Vector3(-5.3,0,4.8),Vector3(7.0,0,1.7),Vector3(-6.9,0,1.9),Vector3(-2.95,0,5.0),Vector3(2.95,0,5.0)]:
		_box(self,spec+Vector3.UP*0.12,Vector3(0.58,0.24,0.58),DARK,false,true)
		_box(self,spec+Vector3.UP*1.00,Vector3(0.39,1.65,0.43),STONE,false,true)
		_box(self,spec+Vector3.UP*1.87,Vector3(0.59,0.14,0.6),PALE.darkened(0.25),false,true)
		for n in 9:
			_box(self,spec+Vector3(0,0.39+n*0.15,0.225),Vector3(0.23 if n%3 == 0 else 0.13,0.012,0.012),BRASS,true,true)
		_box(self,spec+Vector3(0.13,1.0,0.228),Vector3(0.018,1.28,0.012),BRASS,true,true)
		_box(self,spec+Vector3(0,1.9,0),Vector3(0.17,0.025,0.17),Color(0.36,0.63,0.78,0.38),false,true).rotation.y = PI/4

func _console(at: Vector3, yaw: float) -> void:
	var console := Node3D.new()
	console.name = "MechanicalConsole"
	add_child(console)
	console.position = at
	console.rotation.y = yaw
	_box(console,Vector3(0,0.29,0),Vector3(1.38,0.58,0.70),STONE,false,true)
	var panel := Node3D.new()
	console.add_child(panel)
	panel.position.y = 0.67
	panel.rotation.x = 0.27
	_box(panel,Vector3.ZERO,Vector3(1.55,0.10,0.85),BRASS,true,true)
	_box(panel,Vector3(0,0.058,0),Vector3(1.40,0.022,0.70),DARK,false,true)
	for i in 3:
		var at_gauge := Vector3((i-1)*0.40,0.08,-0.06)
		_ring(panel,at_gauge,0.14,0.021,GOLD,true)
		var hand := _box(panel,at_gauge+Vector3.UP*0.022,Vector3(0.014,0.014,0.20),Color(0.60,0.84,0.96,0.8),false,true)
		hand.rotation.y = -0.75+i*0.50
		_box(panel,Vector3((i-1)*0.40,0.09,0.24),Vector3(0.07,0.08,0.08),BRASS,true,true)
	for side: float in [-1,1]:
		_rod(console,Vector3(side*0.61,0.57,0.35),Vector3(side*0.61,0.78,0.55),0.025,BRASS,true)
		var wheel := _ring(console,Vector3(side*0.61,0.80,0.55),0.10,0.023,GOLD,true)
		wheel.rotation.x = PI/2

func _chains() -> void:
	# Suspended edge machinery never spans the central player route or a doorway.
	for at in [Vector3(-6.9,0,1.6),Vector3(6.9,0,0.8),Vector3(-5.3,0,4.8)]:
		_box(self,at+Vector3.UP*4.55,Vector3(0.70,0.15,0.45),DARK,false,true)
		for i in 14:
			var link := _ring(self,at+Vector3.UP*(1.85+i*0.195),0.095,0.017,BRASS,true)
			link.scale = Vector3(0.72,1,1.28)
			link.rotation.x = PI/2
			if i%2: link.rotation.y = PI/2
		var pulley := _ring(self,at+Vector3.UP*4.45,0.30,0.065,BRASS,true)
		pulley.rotation.x = PI/2
		_rod(self,at+Vector3(-0.43,4.45,0),at+Vector3(0.43,4.45,0),0.05,GOLD,true)

func _process(delta: float) -> void:
	var player := _layout.get_parent().get_node_or_null("Player") as Node3D
	if player == null or player.global_position.distance_squared_to(global_position) > 400: return
	for rotor: Dictionary in rotors:
		rotor.node.rotation.y = wrapf(rotor.node.rotation.y+rotor.speed*delta,-PI,PI)
