extends SceneTree
## Same offline mesh -> owned nodes -> PackedScene pipeline as level-two build_creature_models.gd.
var _asset: Node3D
var mats: Dictionary={}
var serial:=0
var bone := "Bone"
var model_kind := "bone_axe"
func _initialize() -> void: build_all.call_deferred()
func material(key: String, color: Color, metallic:=0.0, rough:=0.7, texture:=false, glow:=0.0) -> void:
	var m:=StandardMaterial3D.new()
	m.resource_name=key
	m.albedo_color=color
	m.metallic=metallic
	m.roughness=rough
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	if texture:
		var noise:=FastNoiseLite.new()
		noise.seed=379+key.length()*17
		noise.frequency=0.07
		var tex:=NoiseTexture2D.new()
		tex.width=128
		tex.height=128
		tex.seamless=true
		tex.noise=noise
		var gradient:=Gradient.new()
		gradient.colors=PackedColorArray([Color(0.77,0.74,0.67),Color(1,0.98,0.91)])
		tex.color_ramp=gradient
		m.albedo_texture=tex
		var normal:=NoiseTexture2D.new()
		normal.width=128
		normal.height=128
		normal.noise=noise
		normal.as_normal_map=true
		normal.bump_strength=1.2
		m.normal_enabled=true
		m.normal_texture=normal
		m.normal_scale=0.12
	if key in ["Linen","DirtyLinen","Rag","Crimson"]:
		m.normal_enabled=false
		m.vertex_color_use_as_albedo=true
	if glow>0:
		m.emission_enabled=true
		m.emission=color
		m.emission_energy_multiplier=glow
	mats[key]=m
func node(name: String, parent: Node3D, at:=Vector3.ZERO) -> Node3D:
	var n:=Node3D.new()
	n.name=name
	parent.add_child(n)
	n.position=at
	n.owner=_asset
	return n
func mesh(name: String, geometry: Mesh, parent: Node3D, mat: String) -> MeshInstance3D:
	serial+=1
	var n:=MeshInstance3D.new()
	n.name=name+"_%03d"%serial
	n.mesh=geometry
	n.material_override=mats[mat]
	parent.add_child(n)
	n.owner=_asset
	return n
func ell(name: String, parent: Node3D, at: Vector3, radius: Vector3, mat: String) -> MeshInstance3D:
	var shape:=SphereMesh.new()
	shape.radius=1
	shape.height=2
	shape.radial_segments=12
	shape.rings=7
	var n:=mesh(name,shape,parent,mat)
	n.position=at
	n.scale=radius
	return n
func tube(name: String, parent: Node3D, pts: Array, radii: Array, mat: String, sides:=8) -> MeshInstance3D:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array=[]
	for i in pts.size():
		var tangent: Vector3=(pts[mini(i+1,pts.size()-1)]-pts[maxi(0,i-1)]).normalized()
		var axis:=Vector3.UP if absf(tangent.dot(Vector3.UP))<0.9 else Vector3.RIGHT
		var right:=tangent.cross(axis).normalized()
		var up:=tangent.cross(right).normalized()
		var ring: Array=[]
		for j in sides:
			var a:=TAU*j/sides
			ring.append(pts[i]+(right*cos(a)+up*sin(a))*maxf(0.002,radii[i]))
			rings.append(ring)
	for i in range(rings.size()-1):
		for j in sides:
			var k: int=(j+1)%sides
			var ids: Array=[[i,j],[i+1,j],[i+1,k],[i,j],[i+1,k],[i,k]]
			for pair in ids:
				st.set_uv(Vector2(float(pair[1])/sides,float(pair[0])/(rings.size()-1)))
				st.add_vertex(rings[pair[0]][pair[1]])
	st.generate_normals()
	return mesh(name,st.commit(),parent,mat)
func spike(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat:= "Bone") -> void:
	tube("Point",parent,[a,a.lerp(b,0.52)+Vector3(0,radius*0.4,0.02),b],[radius,radius*0.6,0.002],mat)
func plate(name: String, parent: Node3D, outline: Array, depth: float, mat: String) -> MeshInstance3D:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center:=Vector3.ZERO
	for p: Vector3 in outline: center+=p
	center/=outline.size()
	for i in outline.size():
		var j: int=(i+1)%outline.size()
		for offset in [-depth*0.5,depth*0.5]:
			for p: Vector3 in [center,outline[i],outline[j]]:
				var v:=p+Vector3(0,0,offset)
				st.set_uv(Vector2(v.x*2,v.y*2))
				st.add_vertex(v)
		for p: Vector3 in [outline[i]+Vector3.BACK*depth*0.5,outline[j]+Vector3.BACK*depth*0.5,outline[j]-Vector3.BACK*depth*0.5,outline[i]+Vector3.BACK*depth*0.5,outline[j]-Vector3.BACK*depth*0.5,outline[i]-Vector3.BACK*depth*0.5]:
			st.set_uv(Vector2(p.x,p.y));st.add_vertex(p)
	st.generate_normals()
	return mesh(name,st.commit(),parent,mat)
func bone_segment(parent: Node3D, a: Vector3, b: Vector3, width: float) -> void:
	var d:=b-a
	tube("LongBone",parent,[a,a+d*0.12,a+d*0.4,a+d*0.74,b],[width*1.15,width,width*0.65,width*0.75,width*1.06],bone)
	for p: Vector3 in [a,b]: ell("Epiphysis",parent,p,Vector3(width*1.14,width*0.85,width),bone)
func loop(name: String, parent: Node3D, center: Vector3, rx: float, ry: float, mat: String, thickness: float, n:=24) -> void:
	var pts: Array=[]
	var radii: Array=[]
	for j in n+1:
		var a:=j*TAU/n
		pts.append(center+Vector3(cos(a)*rx,sin(a)*ry,0))
		radii.append(thickness*(1+0.14*sin(j*1.6)))
	tube(name,parent,pts,radii,mat,10)
func ribbon(name: String, parent: Node3D, centers: Array, width: float, mat: String) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges: Array=[]
	for i in centers.size():
		var a: Vector3=centers[i]
		var tangent: Vector3=(centers[mini(i+1,centers.size()-1)]-centers[maxi(0,i-1)]).normalized()
		var normal:=Vector3(a.x,0,a.z).normalized()
		if normal.length()<0.1:normal=Vector3.FORWARD
		var side:=tangent.cross(normal).normalized()*width*0.5
		edges.append([a-side,a+side])
	for i in range(centers.size()-1):
		for ij in [[i,0],[i+1,1],[i+1,0],[i,0],[i,1],[i+1,1]]:
			st.set_uv(Vector2(float(ij[1]),float(ij[0])/(centers.size()-1)))
			st.add_vertex(edges[ij[0]][ij[1]])
	st.index();st.generate_normals();mesh(name,st.commit(),parent,mat)
func wraps(parent: Node3D, at: Vector3, height: float, rx: float, rz: float, turns: float, mat:= "Linen", cap:=false) -> void:
	# One continuous conforming cloth surface: helical fold ridges without coplanar strip overlap.
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows:=maxi(12,int(turns*6))
	var sides:=48
	var points: Array=[]
	for i in rows+1:
		var t:=float(i)/rows
		var ring: Array=[]
		for j in sides+1:
			var u:=float(j)/sides
			var a:=u*TAU
			var phase:=t*turns-u
			var fold:=0.006+0.005*cos(phase*TAU)
			var profile:=sqrt(maxf(0.002,1.0-pow((0.09+t*0.27-0.11)/0.25,2))) if cap else (0.95+0.05*sin(t*PI))
			ring.append(at+Vector3(cos(a)*(rx*profile+fold),t*height,sin(a)*(rz*profile+fold)))
		points.append(ring)
	for i in rows:
		for j in sides:
			for ij in [[i,j],[i+1,j],[i+1,j+1],[i,j],[i+1,j+1],[i,j+1]]:
				var t:=float(ij[0])/rows
				var u:=float(ij[1])/sides
				var shade:=0.89+0.07*float(int(floor(t*turns-u+100))%3)/2
				st.set_color(Color(shade,shade,shade))
				st.set_uv(Vector2(u,t*turns))
				st.add_vertex(points[ij[0]][ij[1]])
	st.index()
	st.generate_normals()
	mesh("ConformingBandages",st.commit(),parent,mat)
func wrap_along(parent: Node3D, a: Vector3, b: Vector3, radius: float, turns: float) -> void:
	var n:=node("ConformingLinen",parent,a)
	var up: Vector3=(b-a).normalized()
	var right:=up.cross(Vector3.FORWARD).normalized()
	if right.length()<0.01: right=Vector3.RIGHT
	n.basis=Basis(right,up,right.cross(up)).orthonormalized()
	wraps(n,Vector3.ZERO,a.distance_to(b),radius,radius*0.95,turns)
func skull(parent: Node3D, mummy: bool, opened: bool) -> void:
	var head:=node("Head",parent,Vector3(0,2.23,-0.025))
	# Separated cranial vault, orbital rims, cheek arches and open mandibular arch.
	ell("CranialVault",head,Vector3(0,0.11,0.035),Vector3(0.255,0.25,0.21),bone)
	ell("Occipital",head,Vector3(0,0.02,0.1),Vector3(0.22,0.2,0.17),bone)
	for side in [-1,1]:
		ell("Temple",head,Vector3(side*0.212,-0.015,0.015),Vector3(0.075,0.17,0.155),bone)
		var socket:=ell("HollowOrbit",head,Vector3(side*0.118,-0.042,-0.154),Vector3(0.096,0.067,0.04),"Cavity")
		socket.rotation.z=side*0.16
		tube("OrbitalRim",head,[Vector3(side*0.027,0.005,-0.236),Vector3(side*0.12,0.032,-0.232),Vector3(side*0.218,-0.01,-0.19),Vector3(side*0.186,-0.1,-0.21),Vector3(side*0.06,-0.103,-0.242),Vector3(side*0.027,-0.044,-0.24)],[0.022,0.027,0.021,0.019,0.018,0.017],bone)
		tube("HeavyBrow",head,[Vector3(side*0.023,0.019,-0.235),Vector3(side*0.12,0.064,-0.226),Vector3(side*0.222,0.027,-0.185)],[0.034,0.043,0.025],bone)
		ell("EyeEmber",head,Vector3(side*0.118,-0.042,-0.208),Vector3(0.024,0.012,0.01),"GreenEye" if mummy else "RedEye")
		tube("ZygomaticArch",head,[Vector3(side*0.22,-0.067,-0.12),Vector3(side*0.228,-0.144,-0.15),Vector3(side*0.136,-0.165,-0.22)],[0.035,0.03,0.022],bone)
		tube("UpperMaxilla",head,[Vector3(side*0.12,-0.12,-0.21),Vector3(side*0.14,-0.183,-0.22),Vector3(side*0.025,-0.19,-0.245)],[0.05,0.042,0.032],bone)
	plate("NasalOpening",head,[Vector3(0,-0.065,-0.24),Vector3(-0.037,-0.15,-0.24),Vector3(0.035,-0.15,-0.24)],0.009,"Cavity")
	tube("NasalBridge",head,[Vector3(0,0.025,-0.219),Vector3(0,-0.06,-0.246)],[0.025,0.017],bone)
	var drop:=0.14 if opened else 0.06
	var jaw:=node("Jaw",head,Vector3(0,-drop,0))
	tube("Mandible",jaw,[Vector3(-0.2,-0.12,0),Vector3(-0.19,-0.26,-0.09),Vector3(-0.11,-0.3,-0.21),Vector3(0,-0.315,-0.235),Vector3(0.11,-0.3,-0.21),Vector3(0.19,-0.26,-0.09),Vector3(0.2,-0.12,0)],[0.028,0.041,0.04,0.043,0.04,0.041,0.028],bone)
	for i in 10:
		var x: float=(i-4.5)*0.027
		var z: float=-0.244+absf(x)*0.22
		tube("UpperTooth",head,[Vector3(x,-0.184,z),Vector3(x,-0.237+(i%2)*0.007,z-0.003)],[0.015,0.012],"Tooth",8)
		tube("LowerTooth",jaw,[Vector3(x,-0.286,z+0.006),Vector3(x,-0.244,z-0.003)],[0.014,0.01],"Tooth",8)
	for i in 4:
		var x: float=(i-1.5)*0.075
		tube("CranialSuture",head,[Vector3(x,0.2,-0.12),Vector3(x+0.02,0.22,-0.08),Vector3(x-0.01,0.25,0.005)],[0.004,0.003,0.002],"Crack",6)
func torso(mummy: bool) -> void:
	var body:=node("Body",_asset)
	if mummy:
		ell("DesiccatedTorso",body,Vector3(0,1.63,0),Vector3(0.46,0.49,0.25),"Flesh")
		ell("Waist",body,Vector3(0,1.17,0),Vector3(0.32,0.22,0.2),"Flesh")
	for i in 10:
		var y:=1.08+i*0.092
		ell("Vertebra",body,Vector3(0,y,0.16),Vector3(0.07,0.047,0.065),bone)
		spike(body,Vector3(0,y,0.18),Vector3(0,y+0.025,0.265),0.029,bone)
	for side in [-1,1]:
		for i in 7:
			var y:=1.39+i*0.078
			var w: float=0.26+sin(float(i)/6*PI)*0.105
			var pts: Array=[];var radii: Array=[]
			for j in 9:
				var a: float=-0.25+float(j)/8*PI*0.95
				pts.append(Vector3(side*sin(a)*w,y-0.035*sin(a),cos(a)*0.22-0.015))
				radii.append(0.019+0.012*sin(float(j)/8*PI))
			tube("CurvedRib",body,pts,radii,bone)
		tube("Clavicle",body,[Vector3(0,1.98,-0.08),Vector3(side*0.21,1.98,-0.05),Vector3(side*0.42,1.9,0)],[0.035,0.04,0.037],bone)
		plate("Scapula",body,[Vector3(side*0.07,1.92,0.19),Vector3(side*0.34,1.91,0.2),Vector3(side*0.27,1.6,0.19)],0.025,bone)
		plate("IliacWing",body,[Vector3(side*0.04,1.19,0.06),Vector3(side*0.28,1.26,-0.005),Vector3(side*0.33,1.15,-0.07),Vector3(side*0.2,0.99,-0.04),Vector3(side*0.05,1.03,-0.02)],0.105,bone)
		loop("ObturatorRim",body,Vector3(side*0.1,1.01,-0.05),0.085,0.065,bone,0.023)
	tube("Sternum",body,[Vector3(0,1.96,-0.19),Vector3(0,1.77,-0.235),Vector3(0,1.48,-0.21)],[0.036,0.043,0.022],bone)
	bone_segment(body,Vector3(0,1.98,0.035),Vector3(0,2.1,0.025),0.052)
	skull(body,mummy,model_kind=="bone_spike")
	var head:=body.get_node("Head") as Node3D
	head.scale=Vector3.ONE*(0.82 if model_kind=="bone_axe" else (0.72 if model_kind=="tomb_sword" else (0.85 if mummy else 0.78)))
func leg(side: int, mummy: bool) -> void:
	var n:=node("LegR" if side>0 else "LegL",_asset,Vector3(side*0.19,1.09,0))
	var knee:=Vector3(side*0.055,-0.48,-0.025)
	var ankle:=Vector3(side*0.07,-0.94,0.05)
	bone_segment(n,Vector3.ZERO,knee,0.073)
	ell("Patella",n,knee+Vector3(0,0,-0.045),Vector3(0.067,0.065,0.034),bone)
	bone_segment(n,knee,ankle,0.055)
	bone_segment(n,knee+Vector3(side*0.054,-0.03,0.01),ankle+Vector3(side*0.045,0,0),0.029)
	ell("Heel",n,ankle+Vector3(0,-0.03,0.035),Vector3(0.085,0.08,0.09),bone)
	for i in 4:
		var a:=ankle+Vector3((i-1.5)*0.038,-0.025,-0.025)
		var b:=a+Vector3((i-1.5)*0.012,-0.045,-0.22+absf(i-1.5)*0.025)
		bone_segment(n,a,b,0.024)
		spike(n,b,b+Vector3(0,-0.005,-0.055),0.019,"Tooth")
	if mummy:
		ell("MummifiedThigh",n,Vector3(0,-0.25,0),Vector3(0.13,0.28,0.12),"Flesh")
		wraps(n,Vector3(0,-0.43,0),0.42,0.14,0.13,5)
		wraps(n,Vector3(side*0.05,-0.88,0.03),0.36,0.105,0.1,5)
func arm(side: int, mummy: bool) -> Node3D:
	var n:=node("ArmR" if side>0 else "ArmL",_asset,Vector3(side*0.43,1.91,0))
	var elbow:=Vector3(side*0.1,-0.36,-0.02)
	var wrist:=Vector3(side*0.07,-0.7,-0.2)
	bone_segment(n,Vector3.ZERO,elbow,0.068)
	bone_segment(n,elbow+Vector3(0,0,0.02),wrist+Vector3(0,0,0.01),0.039)
	bone_segment(n,elbow+Vector3(side*0.055,0,0.025),wrist+Vector3(side*0.045,0,0.02),0.03)
	var hand:=node("Hand",n,wrist)
	ell("Carpals",hand,Vector3(0,-0.025,-0.015),Vector3(0.07,0.065,0.05),bone)
	for i in 4:
		var a:=Vector3((i-1.5)*0.036,-0.045,-0.025)
		var b:=a+Vector3((i-1.5)*0.008,-0.09,-0.02)
		var c:=b+Vector3(0,-0.06,-0.04)
		bone_segment(hand,a,b,0.018)
		bone_segment(hand,b,c,0.014)
		spike(hand,c,c+Vector3(0,-0.035,-0.035),0.013,bone)
	bone_segment(hand,Vector3(side*0.05,0,0),Vector3(side*0.105,-0.08,-0.06),0.022)
	if mummy:
		ell("MummifiedArm",n,Vector3(0,-0.17,0),Vector3(0.14,0.22,0.13),"Flesh")
		wrap_along(n,elbow+Vector3.UP*0.025,Vector3(0,-0.025,0),0.145,4)
		wrap_along(n,wrist+Vector3.UP*0.025,elbow-Vector3.UP*0.025,0.098,4)
	return n

func cloth_panel(parent: Node3D, width: float, top: float, bottom: float, z: float, mat: String) -> void:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows:=8;var cols:=12
	var points: Array=[]
	for j in rows+1:
		var row: Array=[]
		for i in cols+1:
			var t:=float(j)/rows
			var edge:=0.07*sin(i*2.3)+0.05*cos(i*4.1)
			row.append(Vector3((float(i)/cols-0.5)*width*(1+0.25*t),lerpf(top,bottom+edge,t),z+0.07*sin(i*1.8)*t+0.15*t*t))
		points.append(row)
	for j in rows:
		for i in cols:
			for ij in [[i,j],[i+1,j],[i+1,j+1],[i,j],[i+1,j+1],[i,j+1]]:
				st.set_uv(Vector2(float(ij[0])/cols,float(ij[1])/rows))
				st.add_vertex(points[ij[1]][ij[0]])
	st.generate_normals()
	mesh("TornCloth",st.commit(),parent,mat)
func torus(name: String, parent: Node3D, at: Vector3, radius: float, thick: float, mat: String) -> MeshInstance3D:
	var shape:=TorusMesh.new()
	shape.inner_radius=radius-thick
	shape.outer_radius=radius+thick
	shape.rings=20
	shape.ring_segments=8
	var n:=mesh(name,shape,parent,mat)
	n.position=at
	return n
func rivets(parent: Node3D, points: Array, mat:= "Edge") -> void:
	for point: Vector3 in points: ell("Rivet",parent,point,Vector3.ONE*0.018,mat)
func axe_details() -> void:
	var head:=_asset.get_node("Body/Head") as Node3D
	var band: Array=[];var radii: Array=[]
	for i in 20:
		var a:=TAU*i/19
		band.append(Vector3(cos(a)*0.258,0.13,sin(a)*0.215));radii.append(0.035)
	tube("CrownBand",head,band,radii,"Bronze")
	for side in [-1,0,1]:
		tube("CrownProng",head,[Vector3(side*0.17,0.2,0.02),Vector3(side*0.22,0.42,0.04),Vector3(side*0.2,0.6,-0.03)],[0.043,0.029,0.003],"Iron")
	var arm:=_asset.get_node("ArmR") as Node3D
	var weapon:=node("Weapon",arm,Vector3(0.07,-0.7,-0.2))
	var a:=Vector3(0,-0.42,0.46);var b:=Vector3(0.4,0.82,-0.91)
	tube("AxeHaft",weapon,[a,a.lerp(b,0.5),b],[0.039,0.043,0.038],"Wood")
	for i in 8:
		var t:=0.35+i*0.027
		var spot:=a.lerp(b,t)
		tube("GripBinding",weapon,[spot,spot+(b-a).normalized()*0.025],[0.049,0.049],"Leather",12)
	var blade:=node("BeardedAxe",weapon,b)
	blade.scale.x=-1
	plate("AxeCore",blade,[Vector3(-0.06,0.16,0),Vector3(-0.4,0.4,0),Vector3(-0.58,0.31,0),Vector3(-0.69,0.08,0),Vector3(-0.65,-0.17,0),Vector3(-0.5,-0.36,0),Vector3(-0.3,-0.38,0),Vector3(-0.27,-0.1,0),Vector3(0.06,-0.1,0)],0.075,"Iron")
	tube("CurvedHonedEdge",blade,[Vector3(-0.4,0.4,-0.025),Vector3(-0.58,0.31,-0.025),Vector3(-0.69,0.08,-0.025),Vector3(-0.65,-0.17,-0.025),Vector3(-0.5,-0.36,-0.025),Vector3(-0.3,-0.38,-0.025)],[0.026,0.03,0.027,0.03,0.027,0.012],"Edge",8)
	ell("AxeSocket",blade,Vector3.ZERO,Vector3(0.09,0.17,0.09),"Bronze")
	for i in 3: spike(_asset.get_node("ArmL"),Vector3(-0.03,-0.25-i*0.12,0),Vector3(-0.15,-0.24-i*0.12,0.09),0.035,"Iron")
	_asset.get_node("LegR").rotation.x=-0.15
	_asset.get_node("LegL").rotation.x=0.16
	_asset.get_node("ArmL").rotation.x=-0.65
	_asset.get_node("ArmL").rotation.z=-0.2
func sword_details() -> void:
	var body:=_asset.get_node("Body") as Node3D
	var head:=_asset.get_node("Body/Head") as Node3D
	cloth_panel(body,0.64,1.96,0.81,0.26,"Rag")
	tube("HoodArch",head,[Vector3(-0.25,-0.21,0),Vector3(-0.29,0.12,0.035),Vector3(-0.23,0.32,0.05),Vector3(0,0.37,0.06),Vector3(0.23,0.32,0.05),Vector3(0.29,0.11,0.04),Vector3(0.25,-0.21,0)],[0.07,0.074,0.07,0.065,0.07,0.074,0.07],"Rag",12)
	for side in [-1,1]:
		var shoulder:=_asset.get_node("ArmR" if side>0 else "ArmL") as Node3D
		ell("RustedPauldron",shoulder,Vector3(0,0.015,0),Vector3(0.2,0.13,0.19),"Iron")
		loop("ShoulderEdge",shoulder,Vector3(0,-0.02,-0.16),0.17,0.105,"Edge",0.018)
		rivets(shoulder,[Vector3(-0.12,0.04,-0.14),Vector3(0.12,0.04,-0.14),Vector3(0,-0.09,-0.16)])
	var arm:=_asset.get_node("ArmR") as Node3D
	var sword:=node("Weapon",arm,Vector3(0.07,-0.69,-0.2))
	# Long tapered diamond-section blade instead of a box.
	tube("SwordGrip",sword,[Vector3(0,0.15,0.05),Vector3(0,-0.1,-0.08)],[0.042,0.039],"Leather")
	ell("Pommel",sword,Vector3(0,0.19,0.07),Vector3(0.06,0.065,0.055),"Bronze")
	tube("CrossGuard",sword,[Vector3(-0.24,-0.08,-0.08),Vector3(0,-0.1,-0.09),Vector3(0.24,-0.08,-0.08)],[0.026,0.035,0.026],"Iron")
	var spine: Array=[Vector3(0,-0.14,-0.1),Vector3(-0.075,-0.24,-0.11),Vector3(-0.055,-1.24,-0.17),Vector3(0,-1.57,-0.19),Vector3(0.055,-1.24,-0.17),Vector3(0.075,-0.24,-0.11)]
	plate("LongSwordBlade",sword,spine,0.045,"Iron")
	tube("SwordFuller",sword,[Vector3(0,-0.24,-0.14),Vector3(0,-1.26,-0.202),Vector3(0,-1.54,-0.212)],[0.017,0.013,0.002],"Edge",6)
	# Lift the weapon hand so the long tip clears the floor.
	arm.rotation.x=0.8
	var guard:=_asset.get_node("ArmL") as Node3D
	plate("HeavyBracer",guard,[Vector3(-0.15,-0.3,-0.12),Vector3(0.14,-0.3,-0.12),Vector3(0.12,-0.72,-0.23),Vector3(-0.12,-0.78,-0.23)],0.13,"Iron")
	for i in 4: tube("BracerBand",guard,[Vector3(-0.13,-0.33-i*0.1,-0.19),Vector3(0.13,-0.33-i*0.1,-0.19)],[0.024,0.024],"Bronze")
	for side in [-1,1]:
		var shin:=_asset.get_node("LegR" if side>0 else "LegL") as Node3D
		wraps(shin,Vector3(side*0.05,-0.85,0.025),0.28,0.075,0.075,4,"Rag")
func mace(parent: Node3D, at: Vector3) -> void:
	var n:=node("Mace",parent,at)
	tube("FlangedWeight",n,[Vector3(0,0.23,0),Vector3(0,0.11,0),Vector3(0,-0.14,0),Vector3(0,-0.26,0)],[0.07,0.11,0.105,0.025],"Iron")
	for j in 3:
		for i in 5:
			var a: float=i*TAU/5+j*0.2
			spike(n,Vector3(cos(a)*0.08,-0.14+j*0.12,sin(a)*0.08),Vector3(cos(a)*0.23,-0.12+j*0.12,sin(a)*0.23),0.043,"Bronze")
func chain_details() -> void:
	var body:=_asset.get_node("Body") as Node3D
	var head:=_asset.get_node("Body/Head") as Node3D
	for side in [-1,1]: ribbon("LeatherHarness",body,[Vector3(side*0.34,1.95,-0.09),Vector3(side*0.18,1.77,-0.24),Vector3(0,1.63,-0.27)],0.095,"Leather")
	cloth_panel(body,0.58,1.16,0.34,0.16,"Crimson")
	for side in [-1,1]:
		var arm:=_asset.get_node("ArmR" if side>0 else "ArmL") as Node3D
		ell("BronzePauldron",arm,Vector3(0,0.02,0),Vector3(0.2,0.11,0.18),"Bronze")
		plate("LayeredShoulder",arm,[Vector3(-0.22,0.07,-0.15),Vector3(-0.1,0.17,-0.15),Vector3(0.13,0.15,-0.15),Vector3(0.25,0.01,-0.15),Vector3(0.16,-0.13,-0.15),Vector3(-0.2,-0.1,-0.15)],0.055,"Bronze")
		for i in 3: spike(arm,Vector3(side*0.08,0.13,0.08-i*0.1),Vector3(side*0.19,0.37,0.13-i*0.12),0.05,"Iron")
		wraps(arm,Vector3(side*0.08,-0.61,-0.13),0.25,0.09,0.085,3,"Leather")
		var leg:=_asset.get_node("LegR" if side>0 else "LegL") as Node3D
		ell("BronzeGreave",leg,Vector3(side*0.05,-0.7,-0.005),Vector3(0.095,0.26,0.1),"Bronze")
		var chain:=node("ChainR" if side>0 else "ChainL",_asset,Vector3(side*0.5,1.21,-0.2))
		for j in 18:
			var t: float=float(j)/17
			var at:=Vector3(side*0.08*sin(t*PI),-0.86*t,-0.12*t*t)
			var link:=torus("ChainLink",chain,at,0.056,0.013,"Iron")
			link.scale=Vector3(1,1,1.4)
			link.rotation=Vector3(PI/2,(j%2)*PI/2,0)
		mace(chain,Vector3(0,-0.99,-0.14))
	for y in [1.72,1.15]:
		var ring:=torus("RitualMedallion",body,Vector3(0,y,-0.25),0.115,0.025,"Bronze")
		ring.rotation.x=PI/2
		ell("MedallionCore",body,Vector3(0,y,-0.25),Vector3(0.085,0.085,0.026),"Crimson")
		spike(body,Vector3(0,y-0.05,-0.283),Vector3(0,y+0.065,-0.283),0.023,"Edge")
	var rim: Array=[];var radii: Array=[]
	for i in 25:
		var a: float=i*TAU/24
		rim.append(Vector3(cos(a)*0.282,0.19,sin(a)*0.23));radii.append(0.04)
	tube("CorrodedHelmRim",head,rim,radii,"Bronze")
	for side in [-1,1]:
		plate("HelmCheek",head,[Vector3(side*0.18,0.19,-0.16),Vector3(side*0.28,0.12,-0.12),Vector3(side*0.26,-0.15,-0.12),Vector3(side*0.18,-0.11,-0.16)],0.03,"Bronze")
		spike(head,Vector3(side*0.23,0.25,0),Vector3(side*0.39,0.46,0.07),0.075,"Iron")

# Reference revision 3: sculpted wrapping colossus and fibrous desiccated revenant.
# These create saved surfaces, not billboard references or runtime-only meshes.
func organic(name: String, parent: Node3D, points: Array, sizes: Array, mat: String, seed_value:=0.0) -> void:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array=[]
	var sides:=32
	for i in points.size():
		var direction: Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
		var right:=direction.cross(Vector3.FORWARD).normalized()
		if right.length()<0.1: right=Vector3.RIGHT
		var forward:=direction.cross(right).normalized()
		var ring: Array=[]
		for j in sides+1:
			var a: float=TAU*j/sides
			var ripple: float=1.0+0.033*sin(a*7+seed_value+i*0.7)+0.018*sin(a*13-i*1.3)
			var at: Vector3=points[i]+right*cos(a)*sizes[i].x*ripple+forward*sin(a)*sizes[i].y*ripple
			ring.append(at)
		rings.append(ring)
	for i in range(points.size()-1):
		for j in sides:
			for ij in [[i,j],[i+1,j],[i+1,j+1],[i,j],[i+1,j+1],[i,j+1]]:
				var shade: float=0.84+0.14*sin(float(ij[1])*0.7+float(ij[0])*1.1+seed_value)
				st.set_color(Color(shade,shade,shade))
				st.set_uv(Vector2(float(ij[1])/sides,float(ij[0])*0.25))
				st.add_vertex(rings[ij[0]][ij[1]])
	st.index();st.generate_normals()
	mesh(name,st.commit(),parent,mat)

func band(parent: Node3D, center: Vector3, rx: float, rz: float, width: float, tilt: float, mat: String, phase:=0.0, pitch:=0.0, arc:=TAU) -> void:
	# Broad irregular strips, raised folded edge and visible dark seam between layers.
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows:=48
	var columns:=5
	var grid: Array=[]
	var edge_points: Array=[];var radii: Array=[]
	for i in rows+1:
		var a: float=phase+float(i)/rows*arc
		var row: Array=[]
		var rough: float=0.006*sin(a*17+center.y*13)+0.004*cos(a*23)
		for j in columns+1:
			var v: float=float(j)/columns-0.5
			var fold: float=0.007*cos(v*TAU)+0.009*pow(absf(v)*2,4)
			row.append(center+Vector3(cos(a)*(rx+fold+rough),tilt*cos(a)+pitch*sin(a)+v*width*(1+0.07*sin(a*13)),sin(a)*(rz+fold+rough)))
		grid.append(row)
		edge_points.append(row[0]+Vector3(cos(a)*0.002,0,sin(a)*0.002));radii.append(0.004)
	for i in rows:
		for j in columns:
			for ij in [[i,j],[i+1,j],[i+1,j+1],[i,j],[i+1,j+1],[i,j+1]]:
				var shade: float=0.87+0.1*float(ij[1])/columns+0.025*sin(float(ij[0])*2)
				st.set_color(Color(shade,shade*0.99,shade*0.95))
				st.set_uv(Vector2(float(ij[0])/8,float(ij[1])/columns))
				st.add_vertex(grid[ij[0]][ij[1]])
	st.index();st.generate_normals()
	mesh("LayeredLinenStrip",st.commit(),parent,mat)
	tube("WornStripEdge",parent,edge_points,radii,"LinenEdge",5)

func tendon_limb(parent: Node3D, a: Vector3, b: Vector3, middle: Vector3, radius: float, count: int, seed_value: float) -> void:
	organic("DesiccatedMuscle",parent,[a,a.lerp(middle,0.5),middle,middle.lerp(b,0.65),b],[Vector2(radius*0.55,radius*0.6),Vector2(radius,radius*0.82),Vector2(radius*0.9,radius*0.7),Vector2(radius*0.5,radius*0.48),Vector2(radius*0.38,radius*0.42)],"DeadSkin",seed_value)
	var axis: Vector3=(b-a).normalized()
	var right:=axis.cross(Vector3.FORWARD).normalized()
	var front:=axis.cross(right).normalized()
	for i in count:
		var angle: float=TAU*i/count
		var points: Array=[];var widths: Array=[]
		for j in 8:
			var t: float=float(j)/7
			var centre: Vector3=a.lerp(middle,t*2) if t<0.5 else middle.lerp(b,(t-0.5)*2)
			var bulge: float=(0.48+0.47*sin(t*PI))*(1+0.11*sin(t*11+i))
			var theta: float=angle+sin(t*5+seed_value+i*1.7)*0.48+sin(t*11+i)*0.12
			points.append(centre+(right*cos(theta)+front*sin(theta)*0.78)*radius*bulge)
			widths.append((0.004+0.009*sin(t*PI))*(0.7+0.3*sin(i*3.1+t*6)))
		tube("ExposedSinew",parent,points,widths,"RustFibre" if i%4==0 else ("GreyFibre" if i%5==0 else "DarkFibre"),7)

func corpse_hand(parent: Node3D, at: Vector3, side: int) -> void:
	var hand:=node("Hand",parent,at)
	organic("CollapsedPalm",hand,[Vector3(0,0.035,0),Vector3(0,-0.065,-0.01),Vector3(0,-0.13,-0.02)],[Vector2(0.045,0.035),Vector2(0.073,0.034),Vector2(0.058,0.022)],"DeadSkin")
	for i in 4:
		var a:=Vector3((i-1.5)*0.038,-0.105,-0.01)
		var b:=a+Vector3((i-1.5)*0.025,-0.105,-0.02)
		var c:=b+Vector3(side*0.015,-0.075,-0.055)
		var d:=c+Vector3(-side*0.015,-0.015,-0.046)
		tube("CrookedFinger",hand,[a,b,c,d],[0.02,0.018,0.014,0.008],"DeadSkin",10)
		for off in [-1,1]: tube("FingerTendon",hand,[a+Vector3(off*0.009,0,-0.016),b+Vector3(off*0.008,0,-0.014),c+Vector3(0,0,-0.01)],[0.004,0.004,0.002],"GreyFibre",5)
		ell("Knuckle",hand,b,Vector3(0.021,0.019,0.019),"DarkFibre")
	tube("Thumb",hand,[Vector3(side*0.055,-0.025,0),Vector3(side*0.12,-0.1,-0.01),Vector3(side*0.11,-0.17,-0.06)],[0.026,0.021,0.01],"DeadSkin")

func revenant_model() -> void:
	var body:=node("Body",_asset)
	organic("HollowDesiccatedTorso",body,[Vector3(0,0.99,0.04),Vector3(0,1.12,0.035),Vector3(0,1.31,0.02),Vector3(0,1.51,0.02),Vector3(0,1.72,0.0),Vector3(0,1.9,0.02),Vector3(0,2.0,0.025)],[Vector2(0.18,0.13),Vector2(0.23,0.13),Vector2(0.16,0.105),Vector2(0.22,0.13),Vector2(0.33,0.17),Vector2(0.36,0.14),Vector2(0.16,0.10)],"DeadSkin",3.0)
	# The rib silhouette stays beneath stretched skin; no external lances or horns.
	for side in [-1,1]:
		for i in 8:
			var y: float=1.45+i*0.055
			var width: float=0.2+sin(i*0.32)*0.13
			var pts: Array=[Vector3(0.018*side,y+0.012,-0.135),Vector3(side*0.14,y-0.025,-0.185),Vector3(side*width,y+0.005,-0.125),Vector3(side*(width+0.015),y+0.065,0.01),Vector3(side*width*0.75,y+0.09,0.13)]
			tube("SkinCoveredRibFold",body,pts,[0.013,0.018,0.02,0.016,0.008],"RustFibre" if i%3==0 else "DarkFibre",10)
		for i in 14:
			var t: float=float(i)/13
			var a:=Vector3(side*(0.08+t*0.25),1.94-t*0.09,-0.105)
			var b:=Vector3(side*(0.07+t*0.21),1.7-t*0.17,-0.18)
			var c:=Vector3(side*(0.025+t*0.15),1.24+t*0.2,-0.12)
			tube("ChestSinew",body,[a,a.lerp(b,0.5)+Vector3(0,0,-0.02),b,c],[0.009,0.013,0.01,0.004],"RustFibre" if i%3==0 else "GreyFibre" if i%4==0 else "DarkFibre",7)
		for i in 9:
			var x: float=side*(0.04+i*0.018)
			tube("AbdominalFibres",body,[Vector3(x*1.6,1.56,-0.14),Vector3(x+side*0.04*sin(i*1.8),1.29,-0.15),Vector3(x*1.5,1.04,-0.13)],[0.01,0.008,0.004],"DarkFibre" if i%2 else "RustFibre",7)
		for i in 6:
			tube("BackTendons",body,[Vector3(side*(0.08+i*0.04),1.93,0.11),Vector3(side*(0.15+i*0.025),1.63,0.17),Vector3(side*0.07,1.12,0.14)],[0.012,0.015,0.005],"GreyFibre" if i%4==0 else "DarkFibre",7)

	for side in [-1,1]:
		for i in 7:
			var y: float=1.56+i*0.055
			var x: float=side*(0.05+(i%3)*0.035)
			plate("TornFascialMembrane",body,[Vector3(x,y,-0.198),Vector3(side*(0.24+(i%2)*0.04),y+0.08,-0.18),Vector3(side*0.3,y+0.025,-0.15),Vector3(x+side*0.08,y-0.035,-0.20)],0.004,"DeadSkin" if i%2 else "RustFibre")
		for i in 8:
			var start:=Vector3(side*(0.1+i*0.024),1.95-i*0.015,-0.12)
			var end:=Vector3(-side*0.04,1.61-i*0.03,-0.22)
			tube("TwistedPectoralTendon",body,[start,start.lerp(end,0.4)+Vector3(0,0.025,-0.04),end],[0.009,0.016,0.003],"GreyFibre" if i%3==0 else "RustFibre",9)
	for i in 13:
		ell("SubcutaneousSpinalJoint",body,Vector3(0,1.08+i*0.066,0.15),Vector3(0.036,0.029,0.028),"GreyFibre")
	# Long dry neck and small shrivelled head with actual recessed jaw/eye structure.
	tendon_limb(body,Vector3(0,1.94,0.01),Vector3(0,2.22,-0.08),Vector3(0,2.09,-0.035),0.095,18,2)
	bone="DeadSkin"
	skull(body,false,true)
	var head:=body.get_node("Head") as Node3D
	head.position=Vector3(0,2.29,-0.075)
	head.scale=Vector3(0.69,0.88,0.76)
	head.rotation=Vector3(0.06,-0.1,-0.05)
	for e in head.find_children("EyeEmber*","MeshInstance3D",true,false): e.material_override=mats["DeadEye"]
	for e in head.find_children("*Tooth*","MeshInstance3D",true,false): e.material_override=mats["GreyFibre"]
	for i in 26:
		var a: float=i*2.399
		var x: float=cos(a)*0.23
		var z: float=sin(a)*0.185
		tube("ScalpFascia",head,[Vector3(x*0.7,0.285,z*0.65),Vector3(x,0.12,z),Vector3(x*0.92,-0.04,z*1.01),Vector3(x*0.65,-0.18,z*0.9)],[0.012,0.014,0.01,0.004],"RustFibre" if i%3==0 else "DarkFibre",7)
	for side in [-1,1]:
		var legnode:=node("LegR" if side>0 else "LegL",_asset,Vector3(side*0.18,1.12,0.015))
		var knee:=Vector3(side*0.1,-0.5,-0.04)
		var ankle:=Vector3(side*0.12,-1.04,0.02)
		tendon_limb(legnode,Vector3.ZERO,knee,Vector3(side*0.05,-0.23,-0.035),0.10,20,side*3)
		tendon_limb(legnode,knee,ankle,Vector3(side*0.12,-0.72,0.005),0.075,18,side*5)
		ell("GauntKnee",legnode,knee+Vector3(0,0,-0.02),Vector3(0.062,0.067,0.044),"GreyFibre")
		organic("ShrivelledFoot",legnode,[ankle+Vector3(0,-0.015,0.08),ankle+Vector3(0,-0.045,-0.07),ankle+Vector3(0,-0.045,-0.22)],[Vector2(0.065,0.044),Vector2(0.092,0.04),Vector2(0.073,0.025)],"DeadSkin")
		for i in 5:
			var start:=ankle+Vector3((i-2)*0.033,-0.065,-0.18)
			tube("WitheredToe",legnode,[start,start+Vector3(0,0,-0.06),start+Vector3(0,0.015,-0.08)],[0.019,0.017,0.008],"GreyFibre",8)
		var armnode:=node("ArmR" if side>0 else "ArmL",_asset,Vector3(side*0.36,1.95,0))
		var elbow:=Vector3(side*0.15,-0.45,-0.005)
		var wrist:=Vector3(side*0.24,-0.92,-0.10)
		tendon_limb(armnode,Vector3.ZERO,elbow,Vector3(side*0.09,-0.21,0.01),0.085,18,side)
		tendon_limb(armnode,elbow,wrist,Vector3(side*0.21,-0.64,-0.07),0.075,20,side*2)
		corpse_hand(armnode,wrist,side)
		# Loose ends are soft tapered fascia strands, never rigid spikes.
		for i in 7:
			var a:=Vector3(side*(0.14+i*0.012),-0.4-i*0.06,0.03)
			tube("HangingFascia",armnode,[a,a+Vector3(side*0.035,-0.07,0.015),a+Vector3(side*0.01,-0.14,0.025)],[0.005,0.003,0.001],"RustFibre",5)
	_asset.get_node("Body").rotation.z=-0.035
	_asset.get_node("ArmR").rotation.x=-0.08
	_asset.get_node("ArmL").rotation.z=-0.12
	_asset.get_node("LegR").rotation.x=0.07
	_asset.get_node("LegL").rotation.x=-0.09
	_asset.scale=Vector3(0.95,1.11,0.95)


func cloth_shell(parent: Node3D, centers: Array, sizes: Array, turns: float, eye_cut:=false) -> void:
	# Continuous cloth envelope avoids strip/skin intersections while retaining raised helical folds.
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows:=int(turns*16);var sides:=80
	var grid: Array=[];var shades: Array=[]
	for i in rows+1:
		var t: float=float(i)/rows
		var segment: int=mini(int(t*(centers.size()-1)),centers.size()-2)
		var weight: float=t*(centers.size()-1)-segment
		var center: Vector3=centers[segment].lerp(centers[segment+1],weight)
		var size: Vector2=sizes[segment].lerp(sizes[segment+1],weight)
		var direction: Vector3=(centers[segment+1]-centers[segment]).normalized()
		var right:=direction.cross(Vector3.FORWARD).normalized()
		var front:=direction.cross(right).normalized()
		var row: Array=[];var colorrow: Array=[]
		for j in sides+1:
			var a: float=TAU*j/sides
			var phase: float=t*turns+float(j)/sides*0.6+0.12*sin(a*2+t*9)
			var f: float=fposmod(phase,1.0)
			var ridge: float=0.018*sin(f*PI)+0.005*sin(a*8+t*21)
			row.append(center+right*cos(a)*(size.x+ridge)+front*sin(a)*(size.y+ridge))
			var shade: float=0.82+0.15*minf(1,f*9)+0.025*sin(t*45+a*3)
			colorrow.append(Color(shade,shade*0.98,shade*0.94))
		grid.append(row);shades.append(colorrow)
	for i in rows:
		for j in sides:
			var at: Vector3=grid[i][j]
			if eye_cut and at.z< -0.19 and at.y>0.018 and at.y<0.115 and absf(at.x)>0.025 and absf(at.x)<0.218: continue
			for ij in [[i,j],[i+1,j],[i+1,j+1],[i,j],[i+1,j+1],[i,j+1]]:
				st.set_color(shades[ij[0]][ij[1]])
				st.set_uv(Vector2(float(ij[1])/sides*4,float(ij[0])/rows*turns))
				st.add_vertex(grid[ij[0]][ij[1]])
	st.index();st.generate_normals()
	mesh("SculptedLayeredWrapping",st.commit(),parent,"IvoryLinen")

func flowing_cloth(parent: Node3D, controls: Array, width: float) -> void:
	var centers: Array=[]
	for i in range(controls.size()-1):
		for j in 10:
			centers.append(controls[i].cubic_interpolate(controls[i+1],controls[maxi(0,i-1)],controls[mini(controls.size()-1,i+2)],j/10.0))
	centers.append(controls[-1])
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges: Array=[]
	for i in centers.size():
		var tangent: Vector3=(centers[mini(i+1,centers.size()-1)]-centers[maxi(0,i-1)]).normalized()
		var side: Vector3=tangent.cross(Vector3.FORWARD).normalized()*width*0.5
		var taper: float=1.0-0.3*float(i)/centers.size()
		edges.append([centers[i]-side*taper,centers[i]+side*taper])
	for i in range(centers.size()-1):
		for ij in [[i,0],[i+1,1],[i+1,0],[i,0],[i,1],[i+1,1]]:
			st.set_uv(Vector2(float(ij[1]),float(ij[0])/centers.size()))
			st.add_vertex(edges[ij[0]][ij[1]])
	st.index();st.generate_normals();mesh("AirborneTornLinen",st.commit(),parent,"OldIvory")

func titan_hand(parent: Node3D, at: Vector3, side: int) -> void:
	var hand:=node("Hand",parent,at)
	organic("MassivePurplePalm",hand,[Vector3(0,0.06,0),Vector3(0,-0.095,-0.025),Vector3(0,-0.22,-0.035)],[Vector2(0.15,0.13),Vector2(0.205,0.13),Vector2(0.17,0.105)],"TitanSkin",1.0)
	for i in 4:
		var a:=Vector3((i-1.5)*0.09,-0.17,-0.035)
		var b:=a+Vector3((i-1.5)*0.024,-0.12,-0.035)
		var c:=b+Vector3(0,-0.04,-0.095)
		tube("HeavyPurpleFinger",hand,[a,b,c],[0.055,0.051,0.037],"TitanSkin",14)
		ell("AngularKnuckle",hand,b,Vector3(0.06,0.06,0.058),"PurpleHighlight")
		ell("DarkNail",hand,c+Vector3(0,0.02,-0.02),Vector3(0.036,0.025,0.045),"ObsidianNail")
		for j in 2:
			tube("FingerCrease",hand,[b+Vector3(-0.035,-0.015+j*0.025,-0.047),b+Vector3(0.035,-0.015+j*0.025,-0.047)],[0.005,0.005],"PurpleShadow",5)
	tube("OpposingThumb",hand,[Vector3(side*0.145,-0.045,0),Vector3(side*0.255,-0.105,-0.01),Vector3(side*0.24,-0.19,-0.09)],[0.073,0.068,0.044],"TitanSkin",14)
	band(hand,Vector3(0,-0.02,0),0.195,0.145,0.12,-side*0.04,"IvoryLinen",0,-0.025)

func rune_ring(parent: Node3D, y: float, rx: float, rz: float, width: float) -> void:
	band(parent,Vector3(0,y,0),rx,rz,width,0,"IvoryLinen")
	for k in 20:
		var a: float=TAU*k/20
		var radial:=Vector3(cos(a),0,sin(a))
		var tangent:=Vector3(-sin(a),0,cos(a))
		var at:=Vector3(cos(a)*(rx+0.022),y,sin(a)*(rz+0.022))
		var p: Array=[at+tangent*(-0.028)+Vector3.UP*width*0.27,at+tangent*0.028+Vector3.UP*width*0.27,at+tangent*0.028-Vector3.UP*width*0.27,at-tangent*0.015-Vector3.UP*width*0.27,at-tangent*0.015,at+tangent*0.009]
		tube("WovenGeometricMark",parent,p,[0.004,0.004,0.004,0.004,0.004,0.004],"WovenInk",5)

func titan_model() -> void:
	var body:=node("Body",_asset)
	organic("HulkingPurpleTrunk",body,[Vector3(0,1.04,0.03),Vector3(0,1.17,0.03),Vector3(0,1.4,0),Vector3(0,1.65,0),Vector3(0,1.9,0.01),Vector3(0,2.05,0.04),Vector3(0,2.13,0.03)],[Vector2(0.33,0.23),Vector2(0.38,0.26),Vector2(0.39,0.28),Vector2(0.52,0.32),Vector2(0.65,0.32),Vector2(0.60,0.28),Vector2(0.31,0.19)],"TitanSkin",4.0)
	for side in [-1,1]:
		ell("Trapezius",body,Vector3(side*0.31,2.06,0.08),Vector3(0.34,0.2,0.25),"TitanSkin")
	cloth_shell(body,[Vector3(0,1.04,0.03),Vector3(0,1.2,0.03),Vector3(0,1.45,0),Vector3(0,1.7,0),Vector3(0,1.95,0.02),Vector3(0,2.12,0.03)],[Vector2(0.37,0.27),Vector2(0.42,0.3),Vector2(0.47,0.34),Vector2(0.6,0.37),Vector2(0.7,0.37),Vector2(0.36,0.25)],8)
	for side in [-1,1]:
		for i in 3:
			ribbon("BroadCrossedChestLinen",body,[Vector3(side*(0.44+i*0.07),2.13,0.10),Vector3(side*(0.48+i*0.035),2.0,-0.35),Vector3(side*0.24,1.76-i*0.085,-0.435-i*0.007),Vector3(-side*0.22,1.45-i*0.07,-0.365-i*0.009)],0.19,"IvoryLinen" if i%2 else "OldIvory")
	# Closed wrapped face. Deliberately no teeth, skull, or green eye.
	var head:=node("Head",body,Vector3(0,2.14,-0.30))
	head.rotation=Vector3(0.25,-0.1,0.09)
	ell("PurpleHead",head,Vector3(0,0.035,0.01),Vector3(0.275,0.31,0.245),"TitanSkin")
	var jaw:=node("Jaw",head)
	cloth_shell(jaw,[Vector3(0,-0.29,0.01),Vector3(0,-0.18,0.01),Vector3(0,0.0,0.01),Vector3(0,0.17,0.01),Vector3(0,0.31,0.01),Vector3(0,0.36,0.01)],[Vector2(0.14,0.15),Vector2(0.245,0.25),Vector2(0.285,0.27),Vector2(0.28,0.255),Vector2(0.18,0.16),Vector2(0.01,0.01)],6,true)
	for side in [-1,1]:
		var socket:=ell("ShadowedEyeSlit",head,Vector3(side*0.118,0.064,-0.255),Vector3(0.105,0.043,0.025),"Cavity")
		socket.rotation.z=side*0.20
		var eye:=ell("AzureEye",head,Vector3(side*0.12,0.064,-0.281),Vector3(0.06,0.018,0.012),"AzureEye")
		eye.rotation.z=side*0.20
		tube("EyeClothBrow",head,[Vector3(side*0.035,0.12,-0.263),Vector3(side*0.15,0.14,-0.245),Vector3(side*0.26,0.09,-0.15)],[0.023,0.03,0.034],"IvoryLinen")
		ribbon("DiagonalHeadBinding",head,[Vector3(side*0.05,0.34,-0.10),Vector3(side*0.23,0.23,-0.16),Vector3(side*0.25,-0.01,-0.18),Vector3(side*0.16,-0.23,-0.23)],0.14,"IvoryLinen")
	flowing_cloth(body,[Vector3(0.28,2.1,0.22),Vector3(0.16,2.6,0.23),Vector3(-0.3,2.8,0.25),Vector3(-0.65,2.93,0.22),Vector3(-1.08,2.75,0.19),Vector3(-1.26,2.54,0.18)],0.22)
	flowing_cloth(body,[Vector3(0.43,2.12,0.27),Vector3(0.6,2.5,0.34),Vector3(0.94,2.48,0.32),Vector3(1.15,2.26,0.26)],0.13)
	for side in [-1,1]:
		var limb:=node("ArmR" if side>0 else "ArmL",_asset,Vector3(side*0.65,1.97,0))
		var elbow:=Vector3(side*0.18,-0.38,-0.04)
		var wrist:=Vector3(side*0.24,-0.81,-0.33)
		organic("GiantUpperArm",limb,[Vector3(0,0.08,0),Vector3(side*0.10,-0.12,0),elbow],[Vector2(0.24,0.24),Vector2(0.26,0.24),Vector2(0.20,0.19)],"TitanSkin",side)
		organic("GiantForearm",limb,[elbow,elbow.lerp(wrist,0.38),wrist],[Vector2(0.21,0.20),Vector2(0.29,0.26),Vector2(0.18,0.16)],"TitanSkin",side*2)
		cloth_shell(limb,[elbow+Vector3(0,0.025,0),elbow.lerp(wrist,0.38),wrist],[Vector2(0.25,0.24),Vector2(0.33,0.30),Vector2(0.22,0.20)],6)
		for i in 2:
			band(limb,Vector3(side*0.04,-0.03-i*0.10,0),0.29,0.285,0.18,side*0.06,"IvoryLinen",0,0.025)
		var cuff:=node("EngravedCuff",limb,elbow+Vector3(0,-0.06,-0.035))
		rune_ring(cuff,0,0.30,0.265,0.145)
		titan_hand(limb,wrist,side)
		for i in 6:
			var y: float=-0.12-i*0.10
			tube("PurpleMuscleCrease",limb,[Vector3(side*0.05,y,-0.22),Vector3(side*0.16,y-0.03,-0.235)],[0.008,0.003],"PurpleHighlight",6)
		var legnode:=node("LegR" if side>0 else "LegL",_asset,Vector3(side*0.29,1.09,0.025))
		var knee:=Vector3(side*0.1,-0.45,-0.10)
		var ankle:=Vector3(side*0.13,-0.94,0.005)
		organic("PowerfulThigh",legnode,[Vector3.ZERO,Vector3(side*0.06,-0.2,-0.04),knee],[Vector2(0.22,0.20),Vector2(0.235,0.21),Vector2(0.17,0.18)],"TitanSkin",side*4)
		organic("PowerfulShin",legnode,[knee,Vector3(side*0.12,-0.68,0.01),ankle],[Vector2(0.18,0.18),Vector2(0.20,0.20),Vector2(0.14,0.14)],"TitanSkin",side*5)
		cloth_shell(legnode,[Vector3(0,0.005,0),Vector3(side*0.06,-0.2,-0.04),knee+Vector3(0,0.08,0)],[Vector2(0.26,0.24),Vector2(0.275,0.25),Vector2(0.21,0.22)],3)
		cloth_shell(legnode,[knee+Vector3(0,-0.06,0),Vector3(side*0.12,-0.68,0.01),ankle],[Vector2(0.22,0.22),Vector2(0.24,0.24),Vector2(0.18,0.18)],5)
		organic("HeavyBareFoot",legnode,[ankle+Vector3(0,-0.025,0.10),ankle+Vector3(0,-0.06,-0.1),ankle+Vector3(0,-0.06,-0.30)],[Vector2(0.15,0.105),Vector2(0.21,0.11),Vector2(0.18,0.075)],"TitanSkin",side)
		for i in 4:
			var at:=ankle+Vector3((i-1.5)*0.09,-0.065,-0.29)
			ell("GiantToe",legnode,at,Vector3(0.052,0.062,0.09),"PurpleHighlight")
			ell("ToeNail",legnode,at+Vector3(0,0.025,-0.048),Vector3(0.033,0.018,0.042),"ObsidianNail")
		band(legnode,ankle+Vector3(0,0,-0.08),0.205,0.245,0.14,side*0.055,"OldIvory",0,0.10)
		for i in 5:
			var a:=Vector3(side*0.12,-0.09-i*0.16,-0.14)
			ribbon("RippedWrapEnd",legnode,[a,a+Vector3(side*0.12,-0.03,-0.04),a+Vector3(side*0.16,-0.13,-0.035)],0.065,"OldIvory")
	# The broad engraved shoulder bands are the reference's clear visual signature.
	for side in [-1,1]:
		for i in 2:
			var x: float=side*(0.38+i*0.105)
			var pts: Array=[Vector3(x,2.16,0.19),Vector3(x,2.19,-0.02),Vector3(x,2.08,-0.26),Vector3(x*0.9,1.87,-0.41),Vector3(x*0.8,1.6,-0.33)]
			ribbon("CeremonialShoulderSash",body,pts,0.14,"IvoryLinen")
			for j in 8:
				var at: Vector3=pts[2].lerp(pts[4],float(j)/8)+Vector3(0,0,-0.012)
				tube("SashWovenMark",body,[at+Vector3(-0.025,0.015,0),at+Vector3(0.025,0.015,0),at+Vector3(0.025,-0.015,0),at+Vector3(-0.01,-0.015,0)],[0.004,0.004,0.004,0.004],"WovenInk",5)
	_asset.get_node("ArmL").rotation.x=0.10
	_asset.get_node("ArmL").rotation.z=-0.16
	_asset.get_node("ArmR").rotation.z=0.10
	_asset.get_node("LegL").rotation.x=-0.08
	_asset.scale=Vector3.ONE*1.43

func reference_polish(id: String) -> void:
	var body := _asset.get_node("Body") as Node3D
	var head := body.get_node("Head") as Node3D
	if id == "bone_axe":
		# Rusted three-prong crown and a broad blade remain legible from gameplay height.
		for side in [-1, 1]:
			plate("BrokenCrownFlare",head,[Vector3(side*0.1,0.14,0.1),Vector3(side*0.29,0.22,0.08),Vector3(side*0.24,0.4,0.06)],0.035,"Bronze")
			wraps(_asset.get_node("LegR" if side>0 else "LegL"),Vector3(side*0.05,-0.78,0.02),0.23,0.082,0.08,3,"Leather")
		cloth_panel(body,0.32,1.15,0.65,0.15,"Rag")
		ell("CrownBloodstone",head,Vector3(0,0.16,-0.224),Vector3(0.045,0.055,0.022),"Crimson")
	elif id == "bone_spike":
		# Lean forward, with uneven hanging fascia instead of a symmetrical skeleton.
		body.rotation.x = -0.09
		_asset.get_node("ArmL").scale.y = 1.10
		for side in [-1,1]:
			for i in 4:
				var at := Vector3(side*(0.24+i*0.024),1.8-i*0.08,0.10)
				ribbon("LooseShoulderFascia",body,[at,at+Vector3(side*0.06,-0.16,0.04),at+Vector3(side*0.035,-0.34-i*0.025,0.02)],0.035,"DeadSkin")
	elif id == "tomb_sword":
		# Enclose the hood at the back and sides; leave the skull and ribcage exposed.
		for side in [-1,1]:
			plate("TatteredHoodSide",head,[Vector3(side*0.22,0.28,0.08),Vector3(side*0.29,0.1,0.04),Vector3(side*0.25,-0.30,0.09),Vector3(side*0.11,-0.39,0.20),Vector3(side*0.10,0.24,0.23)],0.018,"Rag")
		plate("HoodCowlBack",head,[Vector3(-0.22,0.26,0.20),Vector3(0,0.37,0.18),Vector3(0.22,0.26,0.20),Vector3(0.20,-0.28,0.22),Vector3(-0.20,-0.28,0.22)],0.018,"Rag")
		var guard := _asset.get_node("ArmL") as Node3D
		guard.scale = Vector3(1.18,1.0,1.12)
		for i in 4:
			tube("BracerScars",guard,[Vector3(-0.06,-0.36-i*0.09,-0.215),Vector3(0.04,-0.40-i*0.09,-0.219)],[0.006,0.003],"Edge",5)
	elif id == "chain_jailer":
		# Splayed weapon arms, verdigris armour, red cloth and paired ritual seals.
		_asset.get_node("ArmR").rotation.z = 0.24
		_asset.get_node("ArmL").rotation.z = -0.24
		for side in [-1,1]:
			var arm := _asset.get_node("ArmR" if side>0 else "ArmL") as Node3D
			for i in 3:
				plate("OverlappingShoulderLamella",arm,[Vector3(-0.19,-0.015-i*0.065,-0.17),Vector3(0.18,-0.015-i*0.065,-0.17),Vector3(0.14,-0.10-i*0.065,-0.18),Vector3(-0.14,-0.10-i*0.065,-0.18)],0.025,"Bronze")
			for y in [1.15,1.72]:
				rivets(body,[Vector3(side*0.09,y,-0.287)],"Copper")
		cloth_panel(body,0.46,1.13,0.24,-0.10,"Crimson")
	else:
		# A heavy wrapped silhouette, narrow blue eyes, aged hems and engraved cuffs.
		for side in [-1,1]:
			var arm := _asset.get_node("ArmR" if side>0 else "ArmL") as Node3D
			for i in 4:
				var at := Vector3(side*0.16,-0.35-i*0.08,-0.27)
				ribbon("FrayedCuffTail",arm,[at,at+Vector3(side*0.09,-0.06,-0.02),at+Vector3(side*0.13,-0.18,-0.01)],0.045,"OldIvory")
			band(body,Vector3(0,1.20,0.025),0.43,0.31,0.08,side*0.12,"OldIvory",0,0.025,PI)

func save_model(id: String, filename: String) -> void:
	_asset=Node3D.new()
	_asset.name=filename
	_asset.set_script(load("res://addons/ziyuan_level03/models/model_motion.gd"))
	_asset.set("kind",id)
	serial=0
	model_kind=id
	bone="DarkBone" if id=="tomb_sword" else "Bone"
	if id=="bone_spike": revenant_model()
	elif id=="sand_king": titan_model()
	else:
		torso(false)
		leg(-1,false);leg(1,false)
		arm(-1,false);arm(1,false)
		match id:
			"bone_axe": axe_details()
			"tomb_sword": sword_details()
			"chain_jailer": chain_details()
	reference_polish(id)
	var packed:=PackedScene.new()
	var code:=packed.pack(_asset)
	if code==OK: code=ResourceSaver.save(packed,"res://addons/ziyuan_level03/models/"+filename+".tscn")
	print("L3_MODEL ",filename," meshes=",serial," status=",code)
	_asset.free()
	if code!=OK: quit(1)
func build_all() -> void:
	material("Bone",Color("afa58a"),0.0,0.9,true)
	material("DarkBone",Color("8d897b"),0.03,0.8,true)
	material("Tooth",Color("d7ccb5"),0.02,0.55,true)
	material("Cavity",Color("111012"),0,1)
	material("Crack",Color("454037"),0,1)
	material("Iron",Color("434b49"),0.5,0.76,true)
	material("Edge",Color("89938c"),0.6,0.54,true)
	material("Bronze",Color("3f6257"),0.42,0.85,true)
	material("Copper",Color("a67d4f"),0.4,0.74,true)
	material("Leather",Color("3e3029"),0.05,0.88,true)
	material("Wood",Color("65513e"),0,0.86,true)
	material("Rag",Color("292e30"),0,0.98,true)
	material("Crimson",Color("602f2e"),0,0.95,true)
	material("Linen",Color("b8a584"),0,0.95,true)
	material("DirtyLinen",Color("918166"),0,1,true)
	material("Flesh",Color("383a31"),0,0.94,true)
	material("RedEye",Color("eb2920"),0,0.4,false,1.0)
	material("GreenEye",Color("44ef49"),0,0.4,false,1.3)
	material("DeadSkin",Color("555246"),0.02,0.87,true)
	material("DarkFibre",Color("626457"),0.02,0.74,true)
	material("GreyFibre",Color("827e69"),0.03,0.8,true)
	material("RustFibre",Color("8a633c"),0,0.93,true)
	material("DeadEye",Color("241d10"),0,0.7)
	material("TitanSkin",Color("574052"),0.02,0.81,true)
	material("PurpleHighlight",Color("75536b"),0.02,0.82,true)
	material("PurpleShadow",Color("291e2b"),0,0.95)
	material("ObsidianNail",Color("25222b"),0.1,0.5,true)
	material("IvoryLinen",Color("c4bba2"),0,0.93,true)
	material("OldIvory",Color("a69a7c"),0,0.97,true)
	material("LinenEdge",Color("6b6251"),0,0.97)
	material("WovenInk",Color("85715b"),0,0.96)
	material("AzureEye",Color("22bafc"),0,0.3,false,2.3)
	for key in ["DeadSkin","DarkFibre","GreyFibre","RustFibre","TitanSkin","PurpleHighlight","IvoryLinen","OldIvory"]:
		mats[key].vertex_color_use_as_albedo=true
	for key in ["IvoryLinen","OldIvory"]: mats[key].normal_enabled=false

	var tissue_noise:=FastNoiseLite.new()
	tissue_noise.seed=8311
	tissue_noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	tissue_noise.frequency=0.09
	tissue_noise.fractal_type=FastNoiseLite.FRACTAL_RIDGED
	tissue_noise.fractal_octaves=5
	var tissue:=NoiseTexture2D.new()
	tissue.width=256;tissue.height=512;tissue.noise=tissue_noise;tissue.seamless=true
	var tissue_ramp:=Gradient.new()
	tissue_ramp.colors=PackedColorArray([Color("252b28"),Color("625846"),Color("918778")])
	tissue_ramp.offsets=PackedFloat32Array([0,0.6,1])
	tissue.color_ramp=tissue_ramp
	for key in ["DeadSkin","DarkFibre","GreyFibre","RustFibre"]:
		mats[key].albedo_texture=tissue
		mats[key].normal_scale=0.20
	mats["DeadSkin"].albedo_color=Color("a5a08e")
	for entry in [["bone_axe","BoneAxeModel"],["bone_spike","BoneSpikeModel"],["tomb_sword","TombSwordModel"],["chain_jailer","ChainJailerModel"],["sand_king","SandKingModel"]]: save_model(entry[0],entry[1])
	quit()
