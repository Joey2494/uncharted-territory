extends "res://scenes/dungeon/level04/observatory_art_base.gd"
## Abandoned metrology and heavy handling workshop. Original cover owns collision.
const IRON := Color("35464c")
const RUST := Color("6d5541")

func build(room: Node3D, tower: StaticBody3D) -> void:
	name = "LoadingWorkshopArt"
	room.add_child(self)
	# Keep the target's background floor and its actual Deck child structure.
	tower.get_node("Surface").material_override = _mat(STONE.darkened(0.12))
	_lifting_crane()
	_cargo_rack(Vector3(8.5,0,3.8))
	_calibration()
	_loose_parts()
	_batch(self)

func _fade_batch(parent: Node3D, merge := true) -> void:
	if merge: _batch(parent)
	for view in parent.get_children():
		if view is MeshInstance3D:
			view.add_to_group("observatory_visual_occluders")
			view.set_meta("ignore_shutter_overlay",true)

func _disc(parent: Node3D, at: Vector3, radius: float, height: float, ink: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 24
	shape.rings = 0
	return _mesh(parent,shape,at,ink,true)

func _lifting_crane() -> void:
	var crane := Node3D.new()
	crane.name = "HeavyLiftingCrane"
	add_child(crane)
	_box(crane,Vector3(4,1.80,1),Vector3(1.98,0.08,2.36),BRASS,true)
	for y in [0.3,0.8,1.3]:
		_box(crane,Vector3(4,y,2.14),Vector3(1.50,0.04,0.025),DARK)
	_disc(crane,Vector3(4,1.90,1),0.69,0.15,IRON)
	_ring(crane,Vector3(4,2.01,1),0.57,0.045,GOLD)
	_box(crane,Vector3(4,3.03,1),Vector3(0.47,2.10,0.47),BRASS,true)
	var pivot := Vector3(4,4.13,1)
	var tip := Vector3(7.7,4.13,-2.8)
	var side := pivot.direction_to(tip).cross(Vector3.UP)*0.26
	for sign_value: float in [-1,1]:
		_rod(crane,pivot+side*sign_value,tip+side*sign_value,0.085,BRASS)
		_rod(crane,pivot+side*sign_value+Vector3.UP*0.52,tip+side*sign_value,0.049,IRON)
	for n in 7:
		var p := pivot.lerp(tip,n/6.0)
		_rod(crane,p-side,p+side,0.045,GOLD)
		if n < 6: _rod(crane,p-side,pivot.lerp(tip,(n+1)/6.0)+side,0.026,RUST)
	# Parked chain ends above heads, outside the central fighting lane.
	for offset: float in [-0.09,0.09]:
		_rod(crane,tip+Vector3(offset,0,0),tip+Vector3(offset,-1.47,0),0.018,IRON)
	_box(crane,tip+Vector3(0,-1.48,0),Vector3(0.38,0.30,0.25),BRASS,true)
	var hook := Node3D.new()
	hook.name = "LoadingHook"
	crane.add_child(hook)
	hook.position = tip+Vector3(0,-1.72,0)
	var path := [Vector3(0,0.20,0),Vector3(0,0,0),Vector3(-0.19,-0.13,0),Vector3(-0.15,-0.34,0),Vector3(0.12,-0.38,0),Vector3(0.25,-0.16,0)]
	for i in range(path.size()-1): _rod(hook,path[i],path[i+1],0.045,IRON)
	_fade_batch(hook)
	var pulley_positions := [Vector3(3.59,2.45,1.34),Vector3(3.59,3.12,1.18),Vector3(7.7,4.18,-2.8)]
	for i in pulley_positions.size():
		var pulley := Node3D.new()
		pulley.name = "GearedHoistPulley%d" % i
		crane.add_child(pulley)
		pulley.position = pulley_positions[i]
		pulley.rotation.z = PI/2
		_gear(pulley,Vector3.ZERO,0.32,20,0.04)
		_ring(pulley,Vector3(0,0.025,0),0.21,0.035,IRON)
		_disc(pulley,Vector3.ZERO,0.09,0.14,GOLD)
		_fade_batch(pulley)
	# Separate jib members fade locally; a single merged AABB would erase the
	# whole diagonal crane whenever an actor passes anywhere below its span.
	_fade_batch(crane,false)

func _cargo_rack(at: Vector3) -> void:
	var rack := Node3D.new()
	rack.name = "InstrumentTransportRack"
	rack.position = at
	add_child(rack)
	for x: float in [-0.70,0.70]:
		for z: float in [-1.22,1.22]:
			_box(rack,Vector3(x,0.99,z),Vector3(0.10,1.98,0.10),BRASS,true)
	for y: float in [0.16,1.05,1.95]:
		_box(rack,Vector3(0,y,0),Vector3(1.52,0.08,2.64),IRON,true)
	for n in 3:
		var z := -0.8+n*0.8
		_ring(rack,Vector3(0,0.42,z),0.25,0.048,BRASS).rotation.z = PI/2
		_box(rack,Vector3(0,1.27,z),Vector3(0.72,0.32,0.47),STONE.darkened(0.2))
		_box(rack,Vector3(0,1.45,z),Vector3(0.78,0.025,0.06),GOLD,true)
	_rod(rack,Vector3(0.75,0.2,-1.2),Vector3(0.75,1.90,1.2),0.029,RUST)
	_fade_batch(rack)

func _calibration() -> void:
	var projection := Node3D.new()
	projection.name = "BlueWhiteCalibration"
	add_child(projection)
	for x: float in [-7.3,-2.7]:
		_box(projection,Vector3(x,0.023,-3.0),Vector3(0.026,0.012,2.2),BLUE)
	for z: float in [-4.1,-1.9]:
		_box(projection,Vector3(-5,0.023,z),Vector3(4.6,0.012,0.026),BLUE)
	for n in 17:
		_box(projection,Vector3(-7+n*0.25,0.025,-4.04),Vector3(0.016,0.009,0.10 if n%4 else 0.23),BLUE)
	for p in [Vector3(-7.3,0.025,-3),Vector3(-2.7,0.025,-3)]:
		_box(projection,p,Vector3(0.29,0.012,0.028),BLUE)
		_box(projection,p,Vector3(0.028,0.012,0.29),BLUE)
	for x: float in [-7.4,-2.4]:
		_box(projection,Vector3(x,0.15,-4.40),Vector3(0.22,0.30,0.28),BRASS,true)
		var lens := _box(projection,Vector3(x,0.31,-4.40),Vector3(0.10,0.02,0.13),BLUE)
		lens.material_override = _mat(BLUE,false,0.25)
	_batch(projection)

func _loose_parts() -> void:
	var parts := Node3D.new()
	parts.name = "AbandonedMetalComponents"
	add_child(parts)
	for n in 4:
		var bar := _box(parts,Vector3(4.9+n*0.42,0.055,6.4+(n%2)*0.16),Vector3(0.12,0.10,1.02),RUST,true)
		bar.rotation.y = -0.4+n*0.23
	_gear(parts,Vector3(7.6,0.09,6.4),0.39,24,0.038)
	_ring(parts,Vector3(-8.4,0.10,3.5),0.41,0.06,BRASS)
	for n in 4:
		var chip := _chip(Vector3(-9.2+n*0.42,0.008,3.6),0.32,STONE.darkened(0.22))
		chip.rotation.y = n*0.9
	_batch(parts)
