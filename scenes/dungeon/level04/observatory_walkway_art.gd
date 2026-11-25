extends "res://scenes/dungeon/level04/observatory_art_base.gd"
## Visual suspension, glass deck and abyss. Original collision geometry is retained.
const PLAN = preload("res://scenes/dungeon/level04/observatory_plan.gd")
const DECK = preload("res://scenes/dungeon/level04/prismatic_walkway.gdshader")
var dressed_rails: Array[StaticBody3D] = []
var glass_surfaces: Array[MeshInstance3D] = []

func build(layout: Node3D) -> void:
	name = "WalkwayArt"
	var room: Node3D = layout.get_node("F")
	room.add_child(self)
	var surface := _deck_surface(room)
	_glass(surface,false)
	_dress_rails(room)
	for link: String in PLAN.LINKS:
		if not link.contains("F"): continue
		var bridge: Node3D = layout.get_node(link)
		_dress_rails(bridge)
		_glass(_deck_surface(bridge),true)
	_floor_frames()
	_suspension()
	_abyss()
	_prisms()
	_batch(self)

func _glass(view: MeshInstance3D, bridge: bool) -> void:
	var material := ShaderMaterial.new()
	material.shader = DECK
	var previous := view.material_override as ShaderMaterial
	if previous != null:
		for uniform: Dictionary in previous.shader.get_shader_uniform_list():
			var value: Variant = previous.get_shader_parameter(uniform.name)
			if value != null: material.set_shader_parameter(uniform.name,value)
	material.set_shader_parameter("background_finish",true)
	material.set_shader_parameter("bridge_mode",bridge)
	view.material_override = material
	glass_surfaces.append(view)

func _deck_surface(parent: Node3D) -> MeshInstance3D:
	# Bent corridor Decks have several collision children before the one mesh.
	for child in parent.get_node("Deck").get_children():
		if child is MeshInstance3D: return child
	push_error("Missing observatory Deck render surface: "+str(parent.get_path()))
	return null

func _dress_rails(parent: Node3D) -> void:
	for body in parent.get_children():
		if not body is StaticBody3D or body.get_child_count() < 2: continue
		var collision := body.get_child(0) as CollisionShape3D
		if collision == null or not collision.shape is BoxShape3D: continue
		var size: Vector3 = collision.shape.size
		if not is_equal_approx(size.x,0.30) or not is_equal_approx(size.y,1.5): continue
		dressed_rails.append(body)
		for child in body.get_children():
			if child is MeshInstance3D: child.hide()
		var trim := Node3D.new()
		trim.name = "CarvedBrassRail"
		body.add_child(trim)
		var length := size.z-0.06
		for height: float in [-0.12,0.70]:
			_box(trim,Vector3(0,height,0),Vector3(0.15,0.075,length),BRASS,true)
		_box(trim,Vector3(0,0.76,0),Vector3(0.19,0.045,length),GOLD,true)
		var bays := maxi(1,ceili(length/1.3))
		for n in range(bays+1):
			var z := -length/2+length*n/bays
			_box(trim,Vector3(0,0.28,z),Vector3(0.11,0.86,0.11),BRASS,true)
			_box(trim,Vector3(0,0.76,z),Vector3(0.23,0.10,0.23),GOLD,true)
		for n in bays:
			var z := -length/2+length*(n+0.5)/bays
			var span := length/bays*0.42
			var points := [Vector3(0,0.58,z),Vector3(0,0.27,z+span),Vector3(0,-0.03,z),Vector3(0,0.27,z-span)]
			for i in 4: _rod(trim,points[i],points[(i+1)%4],0.018,GOLD)
			var curl := _ring(trim,Vector3(0,0.27,z),0.12,0.014,BRASS)
			curl.rotation.z = PI/2
		_batch(trim)

func _floor_frames() -> void:
	for side: float in [-1,1]:
		for x: float in [2.94,4.66]:
			_box(self,Vector3(side*x,0.018,0),Vector3(0.045,0.025,10.3),BRASS,true)
		for n in 6:
			var z := -5.0+n*1.7
			_box(self,Vector3(side*3.8,0.021,z),Vector3(1.76,0.035,0.10),BRASS,true)
		for n in 6:
			var chip := _chip(Vector3(side*(8.9+0.2*sin(n)),0.015,-4.4+n*1.6),0.45+0.1*(n%3),STONE)
			chip.rotation.y = n*0.7
	# Worn bronze seams on the original two central partitions.
	for z: float in [-4.45,4.45]:
		_box(self,Vector3(0.8,1.72,z),Vector3(0.55,0.07,3.75),BRASS,true,true)
		for side: float in [-1,1]:
			_box(self,Vector3(0.8+side*0.265,0.85,z),Vector3(0.025,1.62,0.10),BRASS,true,true)

func _suspension() -> void:
	for x: float in [-8,-3.8,3.8,8]:
		_box(self,Vector3(x,-0.74,0),Vector3(0.22,0.4,13.3),DARK,true)
	for z: float in [-5.8,-1.0,4.0]:
		_box(self,Vector3(0,-0.9,z),Vector3(22,0.38,0.32),DARK,true)
		for side: float in [-1,1]:
			var end := Vector3(side*10.7,-0.8,z)
			var anchor := Vector3(side*7.8,-4.0,z)
			_rod(self,end,anchor,0.12,BRASS)
			_rod(self,anchor,Vector3(side*3.8,-0.85,z),0.10,BRASS)
			var gear := _ring(self,anchor,0.42,0.09,BRASS)
			gear.rotation.x = PI/2
	# Lower cradles are visible through both glass lanes.
	for side: float in [-1,1]:
		for n in 5:
			var at := Vector3(side*3.8,-2.1,-4.1+n*1.7)
			var prism := PrismMesh.new()
			prism.size = Vector3(0.75,0.9,0.48)
			_mesh(self,prism,at,Color(0.25,0.52,0.65,0.6),true,0.10).rotation.z = side*0.4
			_ring(self,at-Vector3(0,0.48,0),0.49,0.035,BRASS)

func _abyss() -> void:
	for tier in 3:
		var radius := 17.0+tier*4.5
		var y := -4.8-tier*4.0
		_ring(self,Vector3(0,y,0),radius,0.20,Color("1c303d").darkened(tier*0.12))
		for n in 8:
			var angle := n*TAU/8+0.17*tier
			var at := Vector3(cos(angle)*radius,y-1.4,sin(angle)*radius)
			_box(self,at,Vector3(1.1,3.1,1.1),Color("20323d").darkened(tier*0.18))
			_rod(self,at+Vector3(0,1.5,0),at+Vector3(-cos(angle)*3,-1.0,-sin(angle)*3),0.15,DARK)
	var depth := CylinderMesh.new()
	depth.top_radius = 34
	depth.bottom_radius = 34
	depth.height = 0.05
	depth.radial_segments = 64
	depth.rings = 0
	_mesh(self,depth,Vector3(0,-17,0),Color("101d29")).set_meta("observatory_background_surface","abyss")
	for side: float in [-1,1]:
		var wheel := Node3D.new()
		add_child(wheel)
		wheel.position = Vector3(side*14,-6.0,1.4)
		wheel.rotation.x = 0.55
		_gear(wheel,Vector3.ZERO,2.2,28,0.10)
		for i in 6:
			var angle := i*TAU/6
			_rod(wheel,Vector3.ZERO,Vector3(cos(angle)*2,0,sin(angle)*2),0.045,DARK)
		_batch(wheel)

func _prisms() -> void:
	for side: float in [-1,1]:
		var source := Vector3(side*11.65,0.6,-3.5)
		var target := Vector3(side*13.4,-6.5,4.2)
		_rod(self,Vector3(side*10.7,-0.8,-3.5),source,0.055,BRASS)
		var prism := PrismMesh.new()
		prism.size = Vector3(0.55,0.95,0.46)
		_mesh(self,prism,source,BLUE,true,0.25,true).rotation.z = side*0.35
		var beam := CylinderMesh.new()
		beam.top_radius = 0.045
		beam.bottom_radius = 0.32
		beam.height = source.distance_to(target)
		beam.radial_segments = 6
		beam.rings = 0
		var light := _mesh(self,beam,(source+target)*0.5,Color(0.50,0.78,0.96,0.13),false,0.30)
		light.quaternion = Quaternion(Vector3.UP,(source-target).normalized())
		_rod(self,source,target,0.013,Color(0.72,0.90,1.0,0.22))
