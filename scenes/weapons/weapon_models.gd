extends RefCounted
## Original modeled assets: bevelled blades, machined guns and separate staff crowns.
## Y is the blade/staff axis; grip origin matches KayKit handslot.r.
static func material(color: String, metal: float = 0.0, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.metallic = metal
	m.roughness = 0.3 if metal > 0 else 0.68
	if glow:
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 0.25
	return m

static func part(root: Node3D, name: String, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = name
	n.mesh = mesh
	n.material_override = mat
	n.position = at
	root.add_child(n)
	return n

static func box(root: Node3D, name: String, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	# Eight-sided cross sections give the housing real chamfers, including highlights.
	var w := size.x * 0.5
	var d := size.z * 0.5
	var b := minf(w,d) * 0.25
	var outline := PackedVector2Array([Vector2(-w+b,-d),Vector2(w-b,-d),Vector2(w,-d+b),Vector2(w,d-b),Vector2(w-b,d),Vector2(-w+b,d),Vector2(-w,d-b),Vector2(-w,-d+b)])
	return part(root,name,prism(outline,size.y),at,mat)

static func prism(outline: PackedVector2Array, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var j := (i+1)%outline.size()
		var a := Vector3(outline[i].x,-height/2,outline[i].y)
		var b := Vector3(outline[j].x,-height/2,outline[j].y)
		var c := b+Vector3.UP*height
		var d := a+Vector3.UP*height
		for v in [a,c,b,a,d,c,Vector3(0,height/2,0),c,d,Vector3(0,-height/2,0),a,b]: st.add_vertex(v)
	st.generate_normals()
	return st.commit()

static func cylinder(root: Node3D, name: String, radius: float, height: float, at: Vector3, mat: Material, top: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 24
	return part(root,name,mesh,at,mat)

static func ring(root: Node3D, name: String, radius: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius*0.80
	mesh.outer_radius = radius
	mesh.rings = 24
	mesh.ring_segments = 8
	return part(root,name,mesh,at,mat)

static func gem(root: Node3D, name: String, radius: float, height: float, at: Vector3, mat: Material) -> void:
	var a := cylinder(root,name,radius,height*0.62,at+Vector3.UP*height*0.19,mat,0.0)
	a.mesh.radial_segments = 6
	var b := cylinder(root,name+"Base",0,height*0.38,at-Vector3.UP*height*0.31,mat,radius)
	b.mesh.radial_segments = 6

static func flame(root: Node3D, at: Vector3, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var widths := [0.075,0.11,0.09,0.07,0.08,0.055,0.035,0.015,0.0]
	for row in 8:
		for i in 12:
			var vertices: Array[Vector3] = []
			for corner in [Vector2i(row,i),Vector2i(row+1,i),Vector2i(row+1,i+1),Vector2i(row,i),Vector2i(row+1,i+1),Vector2i(row,i+1)]:
				var t: float = corner.x/8.0
				var angle: float = corner.y*TAU/12.0+t*2
				vertices.append(Vector3(sin(t*7)*0.06+cos(angle)*widths[corner.x],t*0.57,sin(angle)*widths[corner.x]*0.65))
			for v in vertices: st.add_vertex(v)
	st.generate_normals()
	part(root,"CurvedFlame",st.commit(),at,mat)

static func create(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Weapon_"+id
	var steel := material("b6c9d7",0.85)
	var edge := material("edf5f8",0.75)
	var dark := material("283747",0.8)
	var gold := material("c3944f",0.8)
	var wood := material("513328")
	var leather := material("302529")
	var color: Color = preload("res://scenes/weapons/weapon_catalog.gd").DATA[id].color
	var glow := material(color.to_html(false),0.2,true)
	if id in ["traveler","guard"]:
		var guard: bool = id == "guard"
		var length := 0.75 if guard else 0.94
		# Blade has a raised central ridge and separate bevel faces, tapering to a point.
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var width := 0.145 if guard else 0.088
		for sign_z in [-1.0,1.0]:
			for sign_x in [-1.0,1.0]:
				var a := Vector3(width*sign_x,0.24,0)
				var b := Vector3(width*sign_x*0.72,length,0)
				var c := Vector3(0,length+0.19,0)
				var ridge := Vector3(0,0.24,0.036*sign_z)
				var tip_ridge := Vector3(0,length,0.024*sign_z)
				var verts: Array = [a,b,tip_ridge,a,tip_ridge,ridge,b,c,tip_ridge]
				if sign_x*sign_z < 0: verts.reverse()
				for v in verts: st.add_vertex(v)
		st.generate_normals()
		part(root,"ForgedDiamondBlade",st.commit(),Vector3.ZERO,steel)
		box(root,"Crossguard",Vector3(0.48 if guard else 0.38,0.075,0.12),Vector3(0,0.20,0),gold if not guard else dark)
		for side in [-1,1]:
			var quillon := box(root,"Quillon",Vector3(0.10,0.16,0.10),Vector3(side*0.22,0.23,0),gold if guard else steel)
			quillon.rotation.z = side*0.4
		cylinder(root,"LeatherGrip",0.052,0.27,Vector3(0,0.015,0),leather)
		for i in 8: ring(root,"GripBinding",0.055,Vector3(0,-0.10+i*0.031,0),gold if guard else wood)
		gem(root,"Pommel",0.075,0.14,Vector3(0,-0.18,0),gold if guard else steel)
		box(root,"Fuller",Vector3(0.019,0.48,0.008),Vector3(0,0.57,0.035),dark)
		if guard: gem(root,"OathSapphire",0.043,0.12,Vector3(0,0.27,0.07),glow)
	elif id in ["pistol","coil"]:
		var coil: bool = id == "coil"
		box(root,"Receiver",Vector3(0.17,0.19,0.64 if coil else 0.38),Vector3(0,0.18,-0.12),dark)
		box(root,"Slide",Vector3(0.18,0.09,0.44),Vector3(0,0.30,-0.14),steel)
		var grip := box(root,"Grip",Vector3(0.14,0.29,0.17),Vector3(0,0.01,0.055),leather)
		grip.rotation.x = -0.20
		for i in 6: box(root,"GripSerration",Vector3(0.148,0.012,0.13),Vector3(0,-0.10+i*0.038,0.07),dark)
		var trigger := ring(root,"TriggerGuard",0.105,Vector3(0,0.04,-0.11),dark)
		trigger.rotation.z = PI/2
		box(root,"Trigger",Vector3(0.02,0.08,0.025),Vector3(0,0.07,-0.12),steel)
		var barrel := cylinder(root,"Barrel",0.062,0.30 if coil else 0.17,Vector3(0,0.20,-0.49 if coil else -0.39),steel)
		barrel.rotation.x = PI/2
		var muzzle := cylinder(root,"MuzzleBore",0.044,0.012,Vector3(0,0.20,-0.65 if coil else -0.48),leather)
		muzzle.rotation.x = PI/2
		for i in 5: box(root,"SlideSerration",Vector3(0.186,0.012,0.012),Vector3(0,0.27,0.01+i*0.025),dark)
		for z in [-0.29,0.04]: box(root,"IronSight",Vector3(0.03,0.04,0.03),Vector3(0,0.36,z),gold)
		if coil:
			box(root,"ShoulderStock",Vector3(0.12,0.16,0.36),Vector3(0,0.20,0.37),dark)
			box(root,"StockPad",Vector3(0.18,0.25,0.07),Vector3(0,0.17,0.56),leather)
			box(root,"EnergyCell",Vector3(0.11,0.26,0.17),Vector3(0,-0.03,-0.23),gold)
			for i in 6:
				var winding := ring(root,"CopperCoil",0.105,Vector3(0,0.20,-0.29-i*0.052),gold if i%2==0 else glow)
				winding.rotation.x = PI/2
			for side in [-1,1]: box(root,"ConductorRail",Vector3(0.02,0.04,0.37),Vector3(side*0.12,0.20,-0.40),glow)
		else:
			box(root,"EjectionPort",Vector3(0.012,0.05,0.11),Vector3(0.094,0.29,-0.11),leather)
			for side in [-1,1]: gem(root,"GripRivet",0.017,0.025,Vector3(side*0.074,0.02,0.08),gold)
	else:
		var long_staff: bool = id == "fire"
		var shaft := 1.35 if long_staff else (0.73 if id == "frost" else 0.59)
		cylinder(root,"TaperedShaft",0.048,shaft,Vector3(0,shaft*0.25,0),wood,0.032)
		for i in 9: ring(root,"LeatherWrap",0.053,Vector3(0,-0.12+i*0.032,0),leather)
		for y in [-shaft*0.25,shaft*0.65]: cylinder(root,"Ferrule",0.058,0.10,Vector3(0,y,0),gold)
		var crown := shaft*0.78
		if id == "practice":
			gem(root,"SimpleQuartz",0.087,0.25,Vector3(0,crown,0),glow)
			ring(root,"CopperCollar",0.10,Vector3(0,crown-0.09,0),gold)
		elif id == "rune":
			var halo := ring(root,"RunicCrown",0.22,Vector3(0,crown+0.04,0),gold)
			halo.rotation.x = PI/2
			gem(root,"SuspendedRunestone",0.10,0.29,Vector3(0,crown+0.04,0),glow)
			for i in 8:
				var angle := i*TAU/8
				var rune := box(root,"EngravedRune",Vector3(0.028,0.055,0.015),Vector3(sin(angle)*0.19,crown+0.04+cos(angle)*0.19,0.035),glow)
				rune.rotation.z = -angle
		elif id == "frost":
			gem(root,"CentralIceCrystal",0.12,0.49,Vector3(0,crown+0.10,0),glow)
			for side in [-1,1]:
				var branch := Node3D.new()
				root.add_child(branch)
				branch.position = Vector3(side*0.12,crown-0.04,0)
				branch.rotation.z = -side*0.48
				gem(branch,"IceShard",0.065,0.34,Vector3.ZERO,glow)
			for i in 4: ring(root,"SilverFrostBand",0.065,Vector3(0,crown-0.15-i*0.10,0),steel)
		else:
			gem(root,"EmberHeart",0.13,0.36,Vector3(0,crown+0.10,0),glow)
			for i in 3:
				var angle := i*TAU/3
				var prong := cylinder(root,"BrazierClaw",0.047,0.40,Vector3(sin(angle)*0.15,crown,cos(angle)*0.15),gold,0.015)
				prong.rotation = Vector3(cos(angle)*0.35,0,-sin(angle)*0.35)
			flame(root,Vector3(0,crown+0.18,0),glow)
			for i in 5: ring(root,"CinderBand",0.059,Vector3(0,0.30+i*0.12,0),gold)
	return root
