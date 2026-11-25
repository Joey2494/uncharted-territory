extends "res://scenes/dungeon/level04/observatory_art_base.gd"
## Transport workshop dressing reads the live cart; it never changes its route.
const IRON := Color("38474e")
const RUST := Color("695344")
var _mail: Node3D
var _previous := Vector3.ZERO
var _drive := 0.0
var _last_state := -1
var drive_gears: Array[Dictionary] = []
var indicators: Array[Dictionary] = []
var hooks: Array[Node3D] = []

func build(room: Node3D, mail: Node3D) -> void:
	name = "MailMaintenanceArt"
	room.add_child(self)
	_mail = mail
	_previous = mail.cart.global_position
	# Existing target floor, cart, route and station nodes stay authoritative.
	_transport_rails()
	_gantry(5.0,3.75)
	_gantry(-5.1,3.75)
	_hook(Vector3(0,2.45,2.6))
	_transmission()
	_tool_cabinet(Vector3(-6.3,0,-0.95))
	_tool_cabinet(Vector3(-6.1,0,1.9))
	_workbench()
	_controls()
	_cart_details()
	_batch(self)

func _fade_batch(parent: Node3D) -> void:
	_batch(parent)
	for view in parent.get_children():
		if view is MeshInstance3D:
			view.add_to_group("observatory_visual_occluders")
			view.set_meta("ignore_shutter_overlay",true)

func _transport_rails() -> void:
	# The northern pair follows the exact live departure path and rail height.
	var start: Vector3 = to_local(_mail.route[0]+Vector3.UP*0.65)
	var end: Vector3 = to_local(_mail.route[1]+Vector3.UP*0.65)
	var spur := Vector3(0,3.65,5.4)
	for side: float in [-1,1]:
		var offset := Vector3(side*0.19,0,0)
		_rod(self,spur+offset,start+offset,0.055,BRASS,true)
		_rod(self,start+offset,end+offset,0.055,BRASS,true)
		_rod(self,start+offset+Vector3.UP*0.10,end+offset+Vector3.UP*0.10,0.022,GOLD,true)
	for section in [[spur,start],[start,end]]:
		for n in 8:
			var point: Vector3 = section[0].lerp(section[1],n/7.0)
			_box(self,point,Vector3(0.61,0.07,0.12),IRON,true,true)
	# Flush repair rails form an abandoned service spur across the room floor.
	for side: float in [-1,1]:
		_box(self,Vector3(side*0.69,0.02,-0.3),Vector3(0.055,0.025,11.4),BRASS,true)
	for n in 14:
		_box(self,Vector3(0,0.013,-5.7+n*0.83),Vector3(1.62,0.022,0.10),DARK,true)

func _gantry(z: float, height: float) -> void:
	var frame := Node3D.new()
	frame.name = "TransportGantry"
	frame.position.z = z
	add_child(frame)
	for side: float in [-1,1]:
		_box(frame,Vector3(side*2.80,0.15,0),Vector3(0.72,0.30,0.76),STONE)
		_box(frame,Vector3(side*2.80,height/2,0),Vector3(0.21,height,0.24),IRON,true)
		for y: float in [0.45,height-0.35]:
			_box(frame,Vector3(side*2.80,y,0),Vector3(0.34,0.09,0.37),BRASS,true)
		_rod(frame,Vector3(side*2.80,height-0.8,0),Vector3(side*1.8,height,0),0.055,RUST)
	_box(frame,Vector3(0,height,0),Vector3(6.04,0.23,0.40),BRASS,true)
	_box(frame,Vector3(0,height+0.15,0),Vector3(6.20,0.065,0.47),IRON,true)
	_fade_batch(frame)

func _hook(at: Vector3) -> void:
	var hook := Node3D.new()
	hook.name = "SuspendedServiceHook"
	hook.position = at
	add_child(hook)
	hooks.append(hook)
	var link_mesh := TorusMesh.new()
	link_mesh.inner_radius = 0.052
	link_mesh.outer_radius = 0.077
	link_mesh.rings = 12
	link_mesh.ring_segments = 6
	for n in 5:
		var link := _mesh(hook,link_mesh,Vector3(0,0.37+n*0.115,0),BRASS,true)
		link.rotation.x = PI/2
		link.scale.z = 1.3
		if n%2: link.rotation.y = PI/2
	var path := [Vector3(0,0.36,0),Vector3(0,0.15,0),Vector3(-0.18,0.03,0),Vector3(-0.22,-0.16,0),Vector3(-0.05,-0.29,0),Vector3(0.15,-0.26,0),Vector3(0.27,-0.07,0),Vector3(0.21,0.10,0)]
	for i in range(path.size()-1): _rod(hook,path[i],path[i+1],0.052,IRON)
	_ring(hook,Vector3(0,0.20,0),0.09,0.025,BRASS).rotation.x = PI/2
	_fade_batch(hook)

func _transmission() -> void:
	var mount := Node3D.new()
	mount.name = "StoneMaintenanceDais"
	mount.position = Vector3(-4.4,0,-4.25)
	add_child(mount)
	_box(mount,Vector3(0,0.05,0),Vector3(2.55,0.10,1.25),STONE)
	_box(mount,Vector3(0,0.91,-0.35),Vector3(1.82,1.72,0.25),DARK)
	for side: float in [-1,1]:
		_box(mount,Vector3(side*0.89,0.92,-0.19),Vector3(0.075,1.75,0.05),BRASS,true)
	for spec in [Vector3(-0.42,0.91,0.38),Vector3(0.22,1.37,0.29),Vector3(0.48,0.60,0.46)]:
		var rotor := Node3D.new()
		rotor.name = "RailDriveGear"
		mount.add_child(rotor)
		rotor.position = Vector3(spec.x,spec.y,-0.14)
		rotor.rotation.x = PI/2
		_gear(rotor,Vector3.ZERO,spec.z,24,0.034)
		for n in 6:
			var angle := n*TAU/6
			_rod(rotor,Vector3.ZERO,Vector3(cos(angle)*spec.z*0.88,0,sin(angle)*spec.z*0.88),0.023,RUST)
		_fade_batch(rotor)
		drive_gears.append({"node":rotor,"ratio":(-1.0 if drive_gears.size()%2 else 1.0)/spec.z})
	_fade_batch(mount)

func _tool_cabinet(at: Vector3) -> void:
	var cabinet := Node3D.new()
	cabinet.name = "ToolLocker"
	cabinet.position = at
	cabinet.rotation.y = PI/2
	add_child(cabinet)
	_box(cabinet,Vector3(0,0.93,0),Vector3(1.32,1.86,0.72),STONE.darkened(0.18))
	_box(cabinet,Vector3(0,1.90,0),Vector3(1.43,0.08,0.83),BRASS,true)
	for side: float in [-1,1]:
		_box(cabinet,Vector3(side*0.31,1.18,0.37),Vector3(0.56,0.99,0.028),IRON,true)
		_box(cabinet,Vector3(side*0.11,1.18,0.405),Vector3(0.023,0.19,0.05),BRASS,true)
	for n in 2:
		_box(cabinet,Vector3(0,0.26+n*0.21,0.38),Vector3(1.15,0.17,0.028),DARK)
		_box(cabinet,Vector3(0,0.26+n*0.21,0.415),Vector3(0.24,0.024,0.05),BRASS,true)
	_fade_batch(cabinet)

func _workbench() -> void:
	var bench := Node3D.new()
	bench.name = "RailRepairWorkbench"
	bench.position = Vector3(4.65,0,4.6)
	add_child(bench)
	_box(bench,Vector3(0,0.33,0),Vector3(2.02,0.66,0.91),STONE)
	_box(bench,Vector3(0,0.70,0),Vector3(2.17,0.09,1.02),BRASS,true)
	_box(bench,Vector3(0,0.78,-0.29),Vector3(0.45,0.08,0.30),IRON,true)
	_box(bench,Vector3(0,0.87,-0.25),Vector3(0.14,0.13,0.17),DARK)
	_rod(bench,Vector3(-0.25,0.82,-0.22),Vector3(0.25,0.82,-0.22),0.018,GOLD)
	# Two spanners, a loose spur gear and an old clamping jig.
	for n in 2:
		var x := -0.64+n*1.21
		_rod(bench,Vector3(x,0.77,-0.16),Vector3(x+0.14,0.77,0.30),0.024,IRON)
		_ring(bench,Vector3(x+0.14,0.77,0.30),0.079,0.023,BRASS)
	_gear(bench,Vector3(0.15,0.78,0.22),0.17,16,0.022)
	_fade_batch(bench)
	for n in 5:
		var chip := _chip(Vector3(-4.8+n*0.42,0.016,4.9),0.32+0.06*(n%2),STONE.darkened(0.20))
		chip.rotation.y = n*0.7

func _controls() -> void:
	for id in ["mail_take","mail_send"]:
		var station: Node3D = _mail.level.get_node("Stations/"+id)
		var detail := Node3D.new()
		detail.name = "TransportControlHousing"
		station.add_child(detail)
		_box(detail,Vector3(0,0.27,0),Vector3(0.86,0.54,0.86),STONE)
		for side: float in [-1,1]:
			_box(detail,Vector3(side*0.34,0.24,0.44),Vector3(0.045,0.35,0.02),BRASS,true)
		var bar := _box(detail,Vector3(0,0.43,0.447),Vector3(0.30,0.026,0.015),BLUE)
		bar.material_override = bar.material_override.duplicate()
		bar.material_override.emission_enabled = true
		bar.material_override.emission = Color("6cbbdc")
		bar.material_override.emission_energy_multiplier = 0.35
		indicators.append({"material":bar.material_override,"id":id})
		_fade_batch(detail)

func _cart_details() -> void:
	var trolley := Node3D.new()
	trolley.name = "BrassTransportTrolley"
	_mail.cart.add_child(trolley)
	for side: float in [-1,1]:
		_box(trolley,Vector3(side*0.44,-0.20,0),Vector3(0.055,0.07,1.13),IRON,true)
		for z: float in [-0.42,0.42]:
			var wheel := _ring(trolley,Vector3(side*0.21,0.65,z),0.085,0.025,BRASS)
			wheel.rotation.z = PI/2
	for z: float in [-0.49,0.49]:
		_box(trolley,Vector3(0,-0.22,z),Vector3(0.91,0.06,0.07),BRASS,true)
	_fade_batch(trolley)

func _process(_delta: float) -> void:
	var at: Vector3 = _mail.cart.global_position
	var travelled := at.distance_to(_previous)
	_previous = at
	_drive = wrapf(_drive+travelled,-TAU,TAU)
	for gear: Dictionary in drive_gears:
		gear.node.quaternion = Quaternion(Vector3.RIGHT,PI/2)*Quaternion(Vector3.UP,_drive*gear.ratio)
	if _last_state != int(_mail.state):
		_last_state = int(_mail.state)
		for indicator: Dictionary in indicators:
			indicator.material.albedo_color = BLUE if _mail.available(indicator.id) else Color("46545a")
			indicator.material.emission_energy_multiplier = 0.35 if _mail.available(indicator.id) else 0.0
