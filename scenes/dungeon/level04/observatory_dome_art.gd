extends "res://scenes/dungeon/level04/observatory_art_base.gd"
## Visual-only ancient observatory, cut away toward the combat camera.
func build(room: Node3D, island: Node3D) -> void:
	name = "DomeArt"
	room.add_child(self)
	# Preserve the target background floor and its combat-warning overlay.
	_floor()
	_shell()
	var engine := Node3D.new()
	engine.name = "AstronomicalEngine"
	island.add_child(engine)
	_instrument(engine)
	_optics()
	_batch(self)
	_batch(engine)

func _floor() -> void:
	# Thin inlays keep the existing navigation and damage-warning surfaces clear.
	_gear(self,Vector3(0,0.031,0),3.05,48,0.065)
	for radius in [3.55,6.7,7.02]: _ring(self,Vector3(0,0.022,0),radius,0.025,BRASS)
	for i in 64:
		var angle := TAU*i/64
		var p := Vector3(cos(angle),0.029,sin(angle))*6.84
		p.y = 0.029
		var tick := _box(self,p,Vector3(0.025,0.018,0.36 if i%4 == 0 else 0.15),GOLD,true)
		tick.rotation.y = PI/2-angle
	# Shallow chipped slabs and dark cracks sit at the perimeter, away from doors.
	for side in [-1,1]:
		for n in 7:
			var x: float = side*(8.1+0.24*sin(n*1.7))
			var z := -4.3+n*1.15
			var slab := _chip(Vector3(x,0.027,z),0.8+0.25*sin(n),PALE.darkened(0.2+0.04*(n%3)))
			slab.rotation.y = n*0.63
	for n in 11:
		var x := -7.8+n*1.45
		var z := -6.3+0.26*sin(n*2)
		var crack := _box(self,Vector3(x,0.018,z),Vector3(0.035,0.012,0.6+(n%3)*0.2),DARK)
		crack.rotation.y = n*0.83

func _dome_point(angle: float, elevation: float) -> Vector3:
	return Vector3(cos(angle)*10.85*cos(elevation),2.8+4.4*sin(elevation),sin(angle)*8.65*cos(elevation))

func _shell() -> void:
	# A missing southern hemisphere exposes the entire arena. Rear ribs and
	# broken roof segments still describe the original monumental dome.
	for i in 9:
		var angle := PI+i*PI/8
		for n in 6:
			_rod(self,_dome_point(angle,n*0.19),_dome_point(angle,(n+1)*0.19),0.095,BRASS,true)
		var foot := _dome_point(angle,0)
		if i not in [0,4,8]:
			_box(self,Vector3(foot.x,1.15,foot.z),Vector3(0.64,2.3,0.68),STONE,false,true)
			_box(self,Vector3(foot.x,2.48,foot.z),Vector3(0.86,0.22,0.89),PALE,false,true)
	for tier in [0.0,0.48,0.9]:
		for i in 24:
			_rod(self,_dome_point(PI+i*PI/24,tier),_dome_point(PI+(i+1)*PI/24,tier),0.06,BRASS,true)
	for i in 16:
		if i in [2,3,10,14]: continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for n in 4:
			var a := _dome_point(PI+i*PI/16,n*0.23)
			var b := _dome_point(PI+(i+1)*PI/16,n*0.23)
			var c := _dome_point(PI+(i+1)*PI/16,(n+1)*0.23)
			var d := _dome_point(PI+i*PI/16,(n+1)*0.23)
			if n == 3 and i%3 == 0: continue
			for p in [a,c,b,a,d,c]:
				surface.set_uv(Vector2(p.x,p.z)*0.25)
				surface.add_vertex(p)
		surface.generate_normals()
		var panel := _mesh(self,surface.commit(),Vector3.ZERO,STONE.darkened(0.08*(i%3)),false,0,true)
		panel.set_meta("observatory_background_surface","vault")
		var material: StandardMaterial3D = panel.material_override
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Open oculus: no opaque roof or glass across the sight line.
	_ring(self,Vector3(0,6.82,0),3.55,0.13,GOLD,true)
	_ring(self,Vector3(0,6.91,0),3.78,0.055,BRASS,true)
	for i in 12:
		var angle := i*TAU/12
		var at := Vector3(cos(angle)*3.66,6.88,sin(angle)*3.66)
		_box(self,at,Vector3(0.16,0.16,0.16),GOLD,true,true)

func _instrument(parent: Node3D) -> void:
	# Every addition remains inside the existing 2.3 m collision pedestal.
	for i in 12:
		var angle := i*TAU/12
		var panel := _box(parent,Vector3(cos(angle)*2.29,0,sin(angle)*2.29),Vector3(0.72,1.08,0.055),STONE)
		panel.rotation.y = PI/2-angle
		var staple := _box(parent,Vector3(cos(angle)*2.32,0.3,sin(angle)*2.32),Vector3(0.10,0.48,0.07),BRASS,true)
		staple.rotation.y = PI/2-angle
	_gear(parent,Vector3(0,0.98,0),2.05,40,0.075)
	_ring(parent,Vector3(0,1.08,0),1.81,0.06,GOLD)
	var sphere := SphereMesh.new()
	sphere.radius = 0.39
	sphere.height = 0.78
	sphere.radial_segments = 20
	sphere.rings = 10
	_mesh(parent,sphere,Vector3(0,1.96,0),BLUE,true,0.35)
	for spec in [Vector3(0.75,0,0.18),Vector3(-0.54,0.57,0),Vector3(0,0.2,1.15)]:
		var ring := _ring(parent,Vector3(0,1.96,0),1.63,0.045,GOLD)
		ring.rotation = spec
	_rod(parent,Vector3(0,0.8,0),Vector3(0,3.0,0),0.09,BRASS)
	for side in [-1,1]:
		_rod(parent,Vector3(side*1.95,1.04,0),Vector3(side*1.52,1.96,0),0.13,BRASS)
		_box(parent,Vector3(side*1.9,1.02,0),Vector3(0.28,0.22,0.5),PALE)
	for i in 24:
		var angle := i*TAU/24
		var mark := _box(parent,Vector3(cos(angle)*1.82,1.12,sin(angle)*1.82),Vector3(0.035,0.025,0.12),DARK)
		mark.rotation.y = PI/2-angle

func _optics() -> void:
	# Thin translucent prisms use no lights, particles or damage scripts.
	for pair in [[Vector3(-2.1,6.8,-0.8),Vector3(-5.8,0.05,-3.8)],[Vector3(1.8,6.8,-1.2),Vector3(5.8,0.05,-4.1)]]:
		var start: Vector3 = pair[0]
		var end: Vector3 = pair[1]
		var shape := CylinderMesh.new()
		shape.top_radius = 0.055
		shape.bottom_radius = 0.25
		shape.height = start.distance_to(end)
		shape.radial_segments = 6
		shape.rings = 0
		var ray := _mesh(self,shape,(start+end)*0.5,Color(0.62,0.86,1,0.15),false,0.5)
		ray.quaternion = Quaternion(Vector3.UP,(start-end).normalized())
		_rod(self,start,end,0.018,Color(0.8,0.94,1,0.32))
		_ring(self,end+Vector3.UP*0.015,0.4,0.015,Color(0.59,0.82,0.94,0.28))
		var prism := PrismMesh.new()
		prism.size = Vector3(0.42,0.62,0.35)
		_mesh(self,prism,start,BLUE,true,0.4,true).rotation.z = 0.3

