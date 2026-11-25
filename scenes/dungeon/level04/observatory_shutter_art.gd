extends "res://scenes/dungeon/level04/observatory_art_base.gd"
## Read-only test rig: visual angles follow the original shutter timing.
const PROJECTION = preload("res://scenes/dungeon/level04/calibration_projection.gdshader")
var blades: Array[MeshInstance3D] = []
var blue_parts: Array[Node3D] = []
var gears: Array[Node3D] = []
var turntable: Node3D
var projections: Node3D
var _layout: Node3D

func build(layout: Node3D) -> void:
	name = "ShutterTestArt"
	_layout = layout
	var room: Node3D = layout.get_node("H")
	room.add_child(self)
	# Keep the target floor, all three encounter thresholds and live sweep.
	_tracks()
	_platform()
	_shutter_bank()
	_console(Vector3(-7.35,0,-2.4),0.5)
	_console(Vector3(6.35,0,4.7),-0.55)
	_projection()
	_style_cover(room)
	_batch(self)

func _tracks() -> void:
	for radius: float in [5.48,5.73]:
		var track := _ring(self,Vector3(0,0.02,0),radius,0.045,BRASS)
		track.scale.x = 1.22
	for n in 96:
		var angle := n*TAU/96
		var at := Vector3(sin(angle)*5.6*1.22,0.028,-cos(angle)*5.6)
		var tick := _box(self,at,Vector3(0.025,0.018,0.24 if n%8 == 0 else 0.10),GOLD,true)
		tick.rotation.y = -angle
	# Fixed rim bogies indicate the former precision alignment mechanism.
	for side: float in [-1,1]:
		for z: float in [-2.9,2.9]:
			var at := Vector3(side*5.9,0.035,z)
			_box(self,at,Vector3(0.38,0.06,0.54),DARK,true)
			_ring(self,at+Vector3.UP*0.05,0.18,0.035,BRASS)

func _platform() -> void:
	turntable = Node3D.new()
	turntable.name = "RotatingTrialPlatform"
	turntable.position = Vector3(0,0.025,-0.4)
	add_child(turntable)
	var disc := CylinderMesh.new()
	disc.top_radius = 2.34
	disc.bottom_radius = 2.34
	disc.height = 0.025
	disc.radial_segments = 64
	disc.rings = 0
	_mesh(turntable,disc,Vector3.ZERO,STONE.darkened(0.22),true)
	_gear(turntable,Vector3(0,0.012,0),2.25,72,0.045)
	for radius: float in [1.95,1.24,0.48]: _ring(turntable,Vector3(0,0.025,0),radius,0.025,BRASS)
	for n in 8:
		var angle := n*TAU/8
		var at := Vector3(sin(angle)*1.55,0.033,cos(angle)*1.55)
		_box(turntable,at,Vector3(0.045,0.016,0.65),GOLD,true).rotation.y = angle
	_batch(turntable)

func _shutter_bank() -> void:
	var rig := Node3D.new()
	rig.name = "BrassLouverRig"
	rig.position = Vector3(0,0,-5.9)
	add_child(rig)
	# More than 2.5 m clearance above the original north-bound player route.
	for side: float in [-1,1]:
		_box(rig,Vector3(side*3.25,1.08,0),Vector3(0.64,2.16,0.70),STONE,false,true)
		_box(rig,Vector3(side*3.25,3.54,0),Vector3(0.28,3.0,0.32),BRASS,true,true)
		_box(rig,Vector3(side*3.25,2.16,0),Vector3(0.85,0.16,0.84),PALE.darkened(0.2),false,true)
		_box(rig,Vector3(side*3.25,4.96,0),Vector3(0.58,0.15,0.62),BRASS,true,true)
	_box(rig,Vector3(0,5.03,0),Vector3(7.0,0.18,0.48),DARK,true,true)
	for n in 7:
		var at := Vector3(0,2.75+n*0.32,0)
		var blade := _box(rig,at,Vector3(6.1,0.10,0.50),BRASS,true,true)
		blade.name = "RotatingLouver"
		blade.rotation.x = 0.30
		blades.append(blade)
		# Fine raised brass seams rotate with each worn louver.
		_box(blade,Vector3(0,0.057,0.19),Vector3(5.97,0.02,0.025),GOLD,true,true)
		var edge := _box(blade,Vector3(0,-0.055,0.23),Vector3(5.8,0.012,0.018),Color(0.45,0.76,0.92,0.30))
		edge.set_meta("ignore_shutter_overlay",true)
		blue_parts.append(edge)
	for side: float in [-1,1]:
		var wheel := Node3D.new()
		wheel.name = "LouverDriveGear"
		rig.add_child(wheel)
		wheel.position = Vector3(side*3.28,3.48,0.38)
		wheel.rotation.x = PI/2
		_gear(wheel,Vector3.ZERO,0.56,26,0.055)
		for n in 6:
			var angle := n*TAU/6
			_rod(wheel,Vector3.ZERO,Vector3(cos(angle)*0.47,0,sin(angle)*0.47),0.025,DARK)
		_batch(wheel)
		for mesh: MeshInstance3D in wheel.get_children():
			mesh.add_to_group("observatory_visual_occluders")
			mesh.set_meta("ignore_shutter_overlay",true)
		gears.append(wheel)

func _console(at: Vector3, yaw: float) -> void:
	var console := Node3D.new()
	console.name = "OpticalCalibrationConsole"
	console.position = at
	console.rotation.y = yaw
	add_child(console)
	_box(console,Vector3(0,0.3,0),Vector3(1.15,0.6,0.78),STONE,false,true)
	var top := Node3D.new()
	console.add_child(top)
	top.position = Vector3(0,0.70,0)
	top.rotation.x = 0.28
	_box(top,Vector3.ZERO,Vector3(1.38,0.11,0.95),BRASS,true,true)
	_box(top,Vector3(0,0.065,0),Vector3(1.22,0.025,0.77),DARK,false,true)
	for side: float in [-1,1]:
		_ring(top,Vector3(side*0.32,0.085,-0.1),0.19,0.026,GOLD,true)
		var needle := _box(top,Vector3(side*0.32,0.105,-0.1),Vector3(0.012,0.015,0.27),PALE,false,true)
		needle.rotation.y = side*0.65
		_box(top,Vector3(side*0.32,0.12,0.23),Vector3(0.09,0.10,0.10),BRASS,true,true)

func _projection() -> void:
	projections = Node3D.new()
	projections.name = "HarmlessCalibrationProjection"
	add_child(projections)
	for side: float in [-1,1]:
		var start := Vector3(side*2.8,3.0,-5.58)
		var end := Vector3(side*4.1,0.04,-2.15)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.035
		cone.bottom_radius = 0.32
		cone.height = start.distance_to(end)
		cone.radial_segments = 6
		cone.rings = 0
		var beam := _mesh(projections,cone,(start+end)*0.5,Color(0.50,0.78,0.96,0.10),false,0.18)
		beam.quaternion = Quaternion(Vector3.UP,(start-end).normalized())
		beam.set_meta("ignore_shutter_overlay",true)
		var core := _rod(projections,start,end,0.012,Color(0.72,0.90,1,0.21))
		core.set_meta("ignore_shutter_overlay",true)
		var plane := PlaneMesh.new()
		plane.size = Vector2(1.5,1.5)
		var reticle := _mesh(projections,plane,end,BLUE)
		var material := ShaderMaterial.new()
		material.shader = PROJECTION
		reticle.material_override = material
		reticle.set_meta("ignore_shutter_overlay",true)

func _style_cover(room: Node3D) -> void:
	for body in room.get_children():
		if not body is StaticBody3D or body.get_child_count()<2: continue
		var collision := body.get_child(0) as CollisionShape3D
		if collision == null or not collision.shape is CylinderShape3D: continue
		if not is_equal_approx(collision.shape.radius,0.77): continue
		for view in body.get_children():
			if view is MeshInstance3D: view.material_override = _mat(STONE)
		_ring(body,Vector3(0,0.66,0),0.78,0.035,BRASS)

func _process(delta: float) -> void:
	var world := _layout.get_parent()
	var combat := world.get_node_or_null("Combat")
	if combat == null or not combat.is_node_ready(): return
	var light: Node3D = combat._sweeps.get("H")
	if light == null: return
	var player := world.get_node_or_null("Player") as Node3D
	var nearby := player != null and player.global_position.distance_squared_to(global_position)<484
	var harmless: bool = not light.active or light.harmless
	projections.visible = nearby and harmless
	for part in blue_parts: part.visible = nearby and harmless
	if not nearby: return
	var locked: bool = light.active and not light.harmless and light.elapsed>=light.CHOOSE
	var target: float = (light.side*(0.44 if light.elapsed<light.CHOOSE else 0.82)) if light.active else 0.30
	for blade in blades: blade.rotation.x = move_toward(blade.rotation.x,target,delta*0.75)
	for i in gears.size():
		gears[i].quaternion = Quaternion(Vector3.RIGHT,PI/2)*Quaternion(Vector3.UP,blades[0].rotation.x*(1 if i == 0 else -1)*2.0)
	if not locked: turntable.rotation.y = wrapf(turntable.rotation.y+delta*0.045,-PI,PI)
