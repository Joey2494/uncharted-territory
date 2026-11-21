extends RefCounted
const Cache = preload("res://scripts/rendering/static_art_cache.gd")
## Third-level sandstone architecture. Mesh generation only; no physics or puzzle state.
const Surface = preload("res://scenes/dungeon/level02/cavern_geometry.gd").Surface
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
static var stone: StandardMaterial3D
static var sand: StandardMaterial3D
static var shadow: StandardMaterial3D
static var pigment: StandardMaterial3D
static var bronze: StandardMaterial3D
static var linen: StandardMaterial3D
static var flame: StandardMaterial3D

func begin(label: String) -> void:
	rng.seed = absi(label.hash())+19031
	noise.seed = 19031
	noise.frequency = 0.75
	if stone != null: return
	var baked := Cache.material_set("tomb")
	if not baked.is_empty():
		stone = baked.stone
		sand = baked.sand
		shadow = baked.shadow
		pigment = baked.pigment
		bronze = baked.bronze
		linen = baked.linen
		flame = baked.flame
		return
	stone = _material("Stratified ochre sandstone",Color(0.38,0.33,0.25),Color(0.55,0.49,0.38),0.94)
	sand = _material("Settled sand and limestone dust",Color(0.34,0.27,0.18),Color(0.50,0.41,0.28),0.98)
	shadow = _material("Recessed weathered sandstone",Color(0.16,0.12,0.085),Color(0.28,0.22,0.15),1.0)
	pigment = _material("Worn ochre and malachite inlay",Color(0.40,0.36,0.27),Color(0.71,0.63,0.44),0.95)
	bronze = _material("Tarnished funerary bronze",Color(0.29,0.19,0.095),Color(0.49,0.35,0.17),0.74)
	bronze.metallic = 0.50
	linen = _material("Dust-filled ancient linen",Color(0.32,0.28,0.20),Color(0.66,0.59,0.43),1.0)
	flame = StandardMaterial3D.new()
	flame.resource_name = "Torch ember core"
	flame.vertex_color_use_as_albedo = true
	flame.emission_enabled = true
	flame.emission = Color(1.0,0.25,0.035)
	flame.emission_energy_multiplier = 2.4

func _material(label: String, dark: Color, light: Color, roughness: float) -> StandardMaterial3D:
	var field := FastNoiseLite.new()
	field.seed = 381
	field.frequency = 0.028
	field.fractal_octaves = 4
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([dark,light])
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.noise = field
	texture.color_ramp = ramp
	texture.seamless = true
	texture.generate_mipmaps = true
	var grain := FastNoiseLite.new()
	grain.seed = 1907
	grain.frequency = 0.28
	var normal := NoiseTexture2D.new()
	normal.width = 512
	normal.height = 512
	normal.noise = grain
	normal.as_normal_map = true
	normal.bump_strength = 0.65
	normal.seamless = true
	normal.generate_mipmaps = true
	var material := StandardMaterial3D.new()
	material.resource_name = label
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE*0.13
	material.normal_enabled = true
	material.normal_texture = normal
	material.normal_scale = 0.34
	material.roughness = roughness
	material.metallic_specular = 0.20
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

func root(label: String, kind: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.set_meta("tomb_art",kind)
	return node

func commit(parent: Node3D, surface: Surface, material: Material, label: String) -> void:
	if surface.points.is_empty(): return
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.mesh()
	mesh.mesh.surface_set_material(0,material)
	parent.add_child(mesh)

func occluder(node: Node3D) -> void:
	var bounds := AABB()
	var first := true
	for mesh in node.get_children():
		if not mesh is MeshInstance3D: continue
		var box: AABB = mesh.transform*mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if not first:
		node.set_meta("tomb_bounds",bounds)
		node.add_to_group("tomb_visual_occluders")

func block(surface: Surface, at: Vector3, size: Vector3, color: Color = Color.WHITE, pose: Basis = Basis.IDENTITY, bevel: float = 0.07, weathered: bool = false) -> void:
	var half := size*0.5
	var cut := minf(bevel,minf(half.x,half.z)*0.4)
	var outline := [Vector2(-half.x,-half.z+cut),Vector2(-half.x+cut,-half.z),Vector2(half.x-cut,-half.z),Vector2(half.x,-half.z+cut),Vector2(half.x,half.z-cut),Vector2(half.x-cut,half.z),Vector2(-half.x+cut,half.z),Vector2(-half.x,half.z-cut)]
	var points: Array[Vector3] = []
	var edge := minf(cut,half.y*0.35)
	for ring in 4:
		var y: float = [-half.y,-half.y+edge,half.y-edge,half.y][ring]
		var inset := edge*0.55 if ring in [0,3] else 0.0
		for i in 8:
			var p: Vector2 = outline[i]
			p -= p.normalized()*inset
			points.append(at+pose*Vector3(p.x,y,p.y))
	for i in 8:
		var next := (i+1)%8
		for ring in 3:
			var a := points[(ring+1)*8+i]
			var b := points[(ring+1)*8+next]
			var c := points[ring*8+i]
			var d := points[ring*8+next]
			if weathered and ring == 1 and i == 5:
				weathered_face(surface,a,b,c,d,color)
			else: surface.quad(a,b,c,d,color)
		surface.triangle(points[24+i],at+pose*Vector3.UP*half.y,points[24+next],color)
		surface.triangle(points[i],points[next],at-pose*Vector3.UP*half.y,color.darkened(0.12))

func weathered_face(surface: Surface, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	var across := maxi(1,ceili(a.distance_to(b)/0.32))
	var down := maxi(1,ceili(a.distance_to(c)/0.32))
	var normal := (b-a).cross(c-a).normalized()
	for y in down:
		for x in across:
			var points: Array[Vector3] = []
			for corner in [Vector2i(x,y),Vector2i(x+1,y),Vector2i(x,y+1),Vector2i(x+1,y+1)]:
				var u: float = float(corner.x)/across
				var v: float = float(corner.y)/down
				var p := a.lerp(b,u).lerp(c.lerp(d,u),v)
				# Join the bevel exactly. Broad erosion and shallow bedding are real mesh relief.
				var edge := sin(PI*u)*sin(PI*v)
				var erosion := noise.get_noise_3dv(p*4.0)*0.055
				var bed := sin(p.y*37.0+noise.get_noise_3dv(p*1.3)*2.0)*0.006
				points.append(p+normal*edge*(erosion+bed))
			var tint := color*(0.95+0.06*noise.get_noise_3dv(points[0]*2.7))
			surface.quad(points[0],points[1],points[2],points[3],tint)

func tube(surface: Surface, a: Vector3, b: Vector3, radius: float, color: Color, sides: int = 8) -> void:
	var axis := (b-a).normalized()
	var ref := Vector3.RIGHT if absf(axis.y) > 0.9 else Vector3.UP
	var x := axis.cross(ref).normalized()
	var z := axis.cross(x).normalized()
	for i in sides:
		var d := (x*cos(TAU*i/sides)+z*sin(TAU*i/sides))*radius
		var e := (x*cos(TAU*(i+1)/sides)+z*sin(TAU*(i+1)/sides))*radius
		surface.quad(a+d,a+e,b+d,b+e,color)
		surface.triangle(a+d,a,a+e,color)
		surface.triangle(b+e,b,b+d,color)

func ellipsoid(surface: Surface, at: Vector3, size: Vector3, color: Color, pose: Basis = Basis.IDENTITY) -> void:
	for row in 8:
		for i in 12:
			var points: Array[Vector3] = []
			for pair: Vector2i in [Vector2i(row,i),Vector2i(row+1,i),Vector2i(row,i+1),Vector2i(row+1,i+1)]:
				var t := PI*pair.x/8.0
				var a := TAU*pair.y/12.0
				points.append(at+pose*(Vector3(sin(t)*cos(a),cos(t),sin(t)*sin(a))*size))
			surface.quad(points[0],points[2],points[1],points[3],color)

func wall(label: String, at: Vector3, size: Vector3, outward: Vector3, room: bool, burial: bool) -> Node3D:
	begin(label)
	var cache_key := Cache.key("wall",[label,at,size,outward,room,burial])
	var baked := Cache.lookup("tomb",cache_key)
	if not baked.is_empty():
		rng.state = baked.state
		return baked.node
	var node := root("SandstoneWall","wall")
	var masonry := Surface.new()
	var mortar := Surface.new()
	var carving := Surface.new()
	var tangent := Vector3(-outward.z,0,outward.x)
	var basis := Basis(tangent,Vector3.UP,-outward)
	var length := maxf(size.x,size.z)
	var foreground := outward.z > 0.5
	var height := 2.15 if foreground else (5.1 if room else 4.2)
	var depth := 1.75 if room else 1.3
	var center := Vector3(at.x,0,at.z)
	block(mortar,center+outward*(depth*0.5+(0.38 if burial else 0.0))+Vector3.UP*(height*0.5-0.05),Vector3(length,height+0.1,depth-(0.75 if burial else 0.0)),Color(0.80,0.78,0.72),basis,0.03)
	var rows := 2 if foreground else 4
	var row_y := 0.0
	for row in rows:
		var next_y := height*float(row+1)/rows
		if row < rows-1: next_y += rng.randf_range(-0.10,0.10)
		var along := -length*0.5
		while along < length*0.5-0.02:
			var width := minf(rng.randf_range(1.75,3.25),length*0.5-along)
			if length*0.5-along-width < 0.5: width = length*0.5-along
			var u := along+width*0.5
			var recessed := burial and absf(u) < 1.45 and row < 2
			var inset := 0.60 if recessed else -0.10+rng.randf_range(-0.035,0.04)
			var p := center+tangent*u+outward*(depth*0.5+inset)+Vector3.UP*((row_y+next_y)*0.5)
			var tint := Color(1.0,0.97,0.89)*rng.randf_range(0.88,1.08)
			block(masonry,p,Vector3(maxf(width-0.035,0.04),next_y-row_y-0.035,depth),tint,basis,rng.randf_range(0.07,0.13),true)
			if room and width > 1.0 and not recessed and row == 2:
				# A shallow inscribed panel meets this particular block, including its setback.
				var face_at := p-outward*(depth*0.5+0.012)
				glyph(carving,face_at,basis,rng.randi_range(0,4),rng.randf_range(0.34,0.46),Color(0.59,0.64,0.55))
			along += width
		row_y = next_y
	# Recessed base course, massive cornice and an exposed cut section give real depth.
	block(masonry,center+outward*(depth*0.5)+Vector3.UP*0.13,Vector3(length,0.30,depth+0.08),Color(0.86,0.82,0.71),basis,0.05)
	block(masonry,center+outward*(depth*0.5)+Vector3.UP*(height-0.10),Vector3(length+0.06,0.32,depth+0.22),Color(1.05,1.0,0.89),basis,0.09)
	if room and length > 7.0 and not foreground and not burial:
		# A recessed plaster register belongs to the masonry, away from burial cavities.
		var panel_at := center-outward*0.17+Vector3.UP*1.45
		block(masonry,panel_at+outward*0.045,Vector3(3.1,1.65,0.14),Color(0.94,0.90,0.79),basis,0.065)
		mural(carving,panel_at-outward*0.033,basis)
	if burial:
		var crypt := sarcophagus(label,center+outward*0.10+Vector3.UP*0.05,basis)
		node.add_child(crypt)
		node.set_meta("burial_recess",true)
	commit(node,mortar,shadow,"DeepStoneJoints")
	commit(node,masonry,stone,"ThickSandstoneCourses")
	commit(node,carving,pigment,"CarvedSignsAndFadedRelief")
	node.set_meta("wall_thickness",depth)
	node.set_meta("top_height",height)
	occluder(node)
	Cache.record("tomb",cache_key,node,rng.state)
	return node

func floor_art(label: String, rect: Rect2, room: bool) -> Node3D:
	begin(label)
	var cache_key := Cache.key("floor_art",[label,rect,room])
	var baked := Cache.lookup("tomb",cache_key)
	if not baked.is_empty():
		rng.state = baked.state
		return baked.node
	var node := root("BuriedPavement","floor")
	var slabs := Surface.new()
	var sediment := Surface.new()
	var cx := ceili(rect.size.x/1.75)
	var cz := ceili(rect.size.y/2.0)
	var zs: Array[float] = []
	for i in range(cz+1): zs.append(rect.position.y+rect.size.y*i/cz+(rng.randf_range(-0.20,0.20) if i > 0 and i < cz else 0.0))
	block(sediment,Vector3(rect.get_center().x,-0.11,rect.get_center().y),Vector3(rect.size.x,0.05,rect.size.y),Color(0.76,0.72,0.64),Basis.IDENTITY,0.01)
	for z in cz:
		var xs: Array[float] = []
		for i in range(cx+1): xs.append(rect.position.x+rect.size.x*i/cx+(rng.randf_range(-0.43,0.43) if i > 0 and i < cx else 0.0))
		for x in cx:
			var p := Vector3((xs[x]+xs[x+1])*0.5,-0.10-rng.randf_range(0,0.025),(zs[z]+zs[z+1])*0.5)
			var tint := Color(1.0,0.99,0.95)*rng.randf_range(0.86,1.06)
			paving_stone(slabs,p,Vector2(xs[x+1]-xs[x]-0.025,zs[z+1]-zs[z]-0.025),tint)
	# Windblown banks are tied to the perimeter; the whole central route stays flat.
	for i in maxi(4,int((rect.size.x+rect.size.y)*0.34)):
		var side := rng.randi_range(0,3)
		var p := rect.get_center()
		var radius := Vector2(rng.randf_range(0.55,1.4),rng.randf_range(0.5,1.1))
		if side < 2:
			p.x = rect.position.x+0.65 if side == 0 else rect.end.x-0.65
			p.y += rng.randf_range(-rect.size.y*0.34,rect.size.y*0.34)
		else:
			p.y = rect.position.y+0.65 if side == 2 else rect.end.y-0.65
			p.x += rng.randf_range(-rect.size.x*0.34,rect.size.x*0.34)
		if not room and minf(rect.size.x,rect.size.y) <= 5.1:
			if rect.size.x < rect.size.y and side >= 2: continue
			if rect.size.y < rect.size.x and side < 2: continue
		bank(sediment,rect,p,radius,rng.randf_range(0.035,0.13))
		for j in rng.randi_range(2,4):
			var offset := Vector2(rng.randf_range(-0.42,0.42),rng.randf_range(-0.42,0.42))
			var at := p+offset
			if not rect.grow(-0.12).has_point(at): continue
			block(slabs,Vector3(at.x,0.025,at.y),Vector3(rng.randf_range(0.08,0.25),rng.randf_range(0.06,0.14),rng.randf_range(0.10,0.25)),Color(0.94,0.89,0.76),Basis(Vector3.UP,rng.randf()*TAU),0.035)
	commit(node,slabs,stone,"WornCutStonePavement")
	commit(node,sediment,sand,"DriftsAndSettledDust")
	Cache.record("tomb",cache_key,node,rng.state)
	return node

func paving_stone(surface: Surface, at: Vector3, size: Vector2, color: Color) -> void:
	var half := size*0.5
	if rng.randf() < 0.22:
		var split := rng.randf_range(-0.28,0.28)*size.x
		var kink := rng.randf_range(-0.16,0.16)
		paving_piece(surface,at,[Vector2(-half.x,-half.y),Vector2(split-0.018,-half.y),Vector2(split+kink-0.018,0.15),Vector2(split-kink-0.018,half.y),Vector2(-half.x,half.y)],color)
		paving_piece(surface,at,[Vector2(split+0.018,-half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y),Vector2(split-kink+0.018,half.y),Vector2(split+kink+0.018,0.15)],color.darkened(0.03))
	else:
		var cut := rng.randf_range(0.035,0.15)
		paving_piece(surface,at,[Vector2(-half.x,-half.y+cut),Vector2(-half.x+cut,-half.y),Vector2(half.x-cut*0.6,-half.y),Vector2(half.x,-half.y+cut*0.6),Vector2(half.x,half.y-cut),Vector2(half.x-cut,half.y),Vector2(-half.x+cut,half.y),Vector2(-half.x,half.y-cut)],color)

func paving_piece(surface: Surface, at: Vector3, outline: Array, color: Color) -> void:
	var center := Vector2.ZERO
	for p: Vector2 in outline: center += p
	center /= outline.size()
	var top_center := at+Vector3(center.x,0.079,center.y)
	for i in outline.size():
		var next := (i+1)%outline.size()
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[next]
		var ai := a.lerp(center,0.022)
		var bi := b.lerp(center,0.022)
		var p := at+Vector3(ai.x,0.077+noise.get_noise_2dv(Vector2(at.x,at.z)+a)*0.008,ai.y)
		var q := at+Vector3(bi.x,0.077+noise.get_noise_2dv(Vector2(at.x,at.z)+b)*0.008,bi.y)
		var low_a := at+Vector3(a.x,0.055,a.y)
		var low_b := at+Vector3(b.x,0.055,b.y)
		surface.triangle(p,top_center,q,color)
		surface.quad(p,q,low_a,low_b,color.darkened(0.12))
		surface.quad(low_a,low_b,at+Vector3(a.x,-0.08,a.y),at+Vector3(b.x,-0.08,b.y),color.darkened(0.24))
		surface.triangle(at+Vector3(a.x,-0.08,a.y),at+Vector3(b.x,-0.08,b.y),at+Vector3(center.x,-0.08,center.y),color)

func bank(surface: Surface, bounds: Rect2, at: Vector2, radius: Vector2, height: float) -> void:
	var rings: Array[Vector3] = []
	const SIDES := 15
	for ring in 3:
		var t := float(ring+1)/3.0
		for i in SIDES:
			var angle := TAU*i/SIDES
			var p := at+Vector2(cos(angle),sin(angle))*radius*t*(1.0+noise.get_noise_2d(at.x+i,at.y)*0.12)
			p = p.clamp(bounds.position+Vector2.ONE*0.04,bounds.end-Vector2.ONE*0.04)
			rings.append(Vector3(p.x,-0.030+height*pow(1.0-t*t,1.8),p.y))
	for i in SIDES:
		var next := (i+1)%SIDES
		surface.triangle(rings[i],Vector3(at.x,height-0.030,at.y),rings[next],Color(1.04,1.0,0.89))
		for ring in 2: surface.quad(rings[ring*SIDES+i],rings[ring*SIDES+next],rings[(ring+1)*SIDES+i],rings[(ring+1)*SIDES+next],Color(1.0,0.97,0.87))

func column(label: String, at: Vector3, height: float, broken: bool = false) -> Node3D:
	begin(label)
	var cache_key := Cache.key("column",[label,at,height,broken])
	var baked := Cache.lookup("tomb",cache_key)
	if not baked.is_empty():
		rng.state = baked.state
		return baked.node
	var node := root("LotusColumn","column")
	var surface := Surface.new()
	var rings: Array[Vector3] = []
	var radii := [0.70,0.70,0.48,0.43,0.41,0.42,0.54,0.71,0.71]
	var levels := [0.0,0.18,0.30,0.42,0.56,0.83,0.89,0.96,1.0]
	for ring in radii.size():
		for i in 16:
			var a := TAU*i/16.0
			var y: float = levels[ring]*height
			if broken and ring == radii.size()-1: y -= rng.randf_range(0.0,0.42)
			var r: float = radii[ring]+(0.035*cos(a*8.0) if ring in [3,4,5] else 0.0)
			rings.append(at+Vector3(cos(a)*r,y,sin(a)*r))
	for ring in range(radii.size()-1):
		for i in 16:
			var a := ring*16+i
			var b := ring*16+(i+1)%16
			surface.quad(rings[a+16],rings[b+16],rings[a],rings[b],Color(0.95,0.92,0.83))
	for i in 16: surface.triangle(rings[128+i],at+Vector3.UP*height,rings[128+(i+1)%16],Color(0.92,0.88,0.78))
	commit(node,surface,stone,"FlutedShaftAndLotusCapital")
	occluder(node)
	Cache.record("tomb",cache_key,node,rng.state)
	return node

func arch(label: String, at: Vector3, across_x: bool) -> Node3D:
	begin(label)
	var cache_key := Cache.key("arch",[label,at,across_x])
	var baked := Cache.lookup("tomb",cache_key)
	if not baked.is_empty():
		rng.state = baked.state
		return baked.node
	var node := root("TombPortal","arch")
	var surface := Surface.new()
	var relief := Surface.new()
	var pose := Basis(Vector3.UP,PI*0.5 if across_x else 0.0)
	for side in [-1.0,1.0]:
		block(surface,at+pose*Vector3(side*3.02,1.85,0),Vector3(0.92,3.7,1.35),Color(1.03,0.96,0.81),pose,0.10)
		glyph(relief,at+pose*Vector3(side*3.02,2.0,0.70),pose,1,0.60,Color(0.26,0.37,0.33))
	# Segmental vault, with solid voussoirs and visible intrados/extrados.
	for i in 11:
		var a := PI*float(i)/11.0
		var b := PI*float(i+1)/11.0
		var ring: Array[Vector3] = []
		for z in [-0.65,0.65]:
			for spec in [[a,2.55],[b,2.55],[a,3.38],[b,3.38]]:
				ring.append(at+pose*Vector3(cos(spec[0])*spec[1],3.25+sin(spec[0])*spec[1]*0.48,z))
		for face in [[0,1,4,5],[2,6,3,7],[0,2,1,3],[4,5,6,7],[0,4,2,6],[1,3,5,7]]:
			surface.quad(ring[face[0]],ring[face[2]],ring[face[1]],ring[face[3]],Color(1.04,0.98,0.86))
	commit(node,surface,stone,"SolidVaultAndPylons")
	commit(node,relief,pigment,"PortalReliefs")
	occluder(node)
	Cache.record("tomb",cache_key,node,rng.state)
	return node

func glyph(surface: Surface, at: Vector3, pose: Basis, kind: int, scale: float, color: Color) -> void:
	var paths: Array = []
	match kind:
		0: paths = [[Vector2(-0.42,0),Vector2(0,0.20),Vector2(0.42,0),Vector2(0,-0.12),Vector2(-0.42,0)],[Vector2(0,0.15),Vector2(0,-0.18)],[Vector2(0,-0.12),Vector2(0.22,-0.38)]]
		1:
			var loop: Array[Vector2] = []
			for i in 13: loop.append(Vector2(cos(TAU*i/12.0)*0.23,0.25+sin(TAU*i/12.0)*0.23))
			paths = [loop,[Vector2(0,0.02),Vector2(0,-0.45)],[Vector2(-0.28,-0.08),Vector2(0.28,-0.08)]]
		2: paths = [[Vector2(-0.32,-0.40),Vector2(-0.24,0.27),Vector2(0,0.43),Vector2(0.26,0.27),Vector2(0.32,-0.4)],[Vector2(-0.30,-0.18),Vector2(0.30,-0.18)],[Vector2(-0.24,0.27),Vector2(0.26,0.27)]]
		3: paths = [[Vector2(-0.4,-0.1),Vector2(-0.12,0.17),Vector2(0.17,0.13),Vector2(0.32,0.35),Vector2(0.47,0.28)],[Vector2(-0.12,0.17),Vector2(0.08,-0.20),Vector2(0.3,-0.12)],[Vector2(0.08,-0.20),Vector2(0.08,-0.44)]]
		_: paths = [[Vector2(-0.40,0.30),Vector2(-0.14,0.12),Vector2(0.10,0.30),Vector2(0.40,0.12)],[Vector2(-0.40,-0.10),Vector2(-0.14,-0.28),Vector2(0.10,-0.10),Vector2(0.40,-0.28)]]
	for path in paths:
		for i in range(1,path.size()):
			var a: Vector2 = path[i-1]*scale
			var b: Vector2 = path[i]*scale
			tube(surface,at+pose*Vector3(a.x,a.y,0),at+pose*Vector3(b.x,b.y,0),scale*0.028,color,6)

func mural(surface: Surface, at: Vector3, pose: Basis) -> void:
	var paint := Color(0.68,0.40,0.27)
	var motif := rng.randi_range(0,2)
	if motif == 1:
		# Winged solar disk. Missing feathers expose the worn register underneath.
		ellipsoid(surface,at+Vector3.UP*0.18,Vector3(0.24,0.24,0.011),Color(0.73,0.51,0.27),pose)
		for side in [-1.0,1.0]:
			for i in 8:
				if rng.randf() < 0.12: continue
				var a := Vector3(side*(0.28+i*0.10),0.22+i*0.045,0)
				var b := Vector3(side*(0.43+i*0.11),-0.12+i*0.055,0)
				tube(surface,at+pose*a,at+pose*b,0.014,Color(0.45,0.53,0.48),6)
			glyph(surface,at+pose*Vector3(side*1.21,0.12,0),pose,1,0.36,paint)
		return
	if motif == 2:
		# River reeds and lotus blossoms vary the narrative instead of repeating figures.
		for i in 5:
			var x := -1.1+i*0.54
			var height := rng.randf_range(0.55,1.05)
			tube(surface,at+pose*Vector3(x,-0.57,0),at+pose*Vector3(x+0.06,height-0.57,0),0.012,Color(0.42,0.51,0.43),6)
			for petal in 3:
				var turn := pose*Basis(Vector3.FORWARD,(petal-1)*0.40)
				ellipsoid(surface,at+pose*Vector3(x+0.06,height-0.52,0),Vector3(0.045,0.15,0.009),Color(0.66,0.60,0.43),turn)
		return
	for side in [-1.0,1.0]:
		var center := at+pose*Vector3(side*0.67,-0.15,0)
		# Profile, headdress, broad chest and linen kilt form a shallow eroded relief.
		ellipsoid(surface,center+Vector3.UP*0.58,Vector3(0.10,0.13,0.009),paint,pose)
		block(surface,center+pose*Vector3(side*0.10,0.58,0.002),Vector3(0.08,0.045,0.014),paint,pose,0.01)
		block(surface,center+pose*Vector3(-side*0.04,0.65,0),Vector3(0.20,0.15,0.016),Color(0.32,0.39,0.37),pose,0.02)
		block(surface,center+Vector3.UP*0.28,Vector3(0.23,0.37,0.016),paint,pose,0.025)
		block(surface,center+Vector3.UP*0.015,Vector3(0.33,0.22,0.015),Color(0.88,0.82,0.67),pose,0.03)
		for path in [[Vector2(-0.07,-0.09),Vector2(-0.16,-0.43),Vector2(-0.03,-0.44)],[Vector2(0.08,-0.09),Vector2(0.19,-0.42),Vector2(0.30,-0.42)],[Vector2(0.07,0.39),Vector2(side*0.32,0.24),Vector2(side*0.39,0.55)]]:
			for i in range(1,path.size()):
				var a: Vector2 = path[i-1]
				var b: Vector2 = path[i]
				var vector := b-a
				block(surface,center+pose*Vector3((a.x+b.x)*0.5,(a.y+b.y)*0.5,0),Vector3(0.045,vector.length(),0.012),paint,pose*Basis(Vector3.FORWARD,atan2(vector.x,vector.y)),0.008)
		glyph(surface,center+pose*Vector3(side*0.46,0.55,0),pose,1,0.24,Color(0.43,0.51,0.46))

func sarcophagus(label: String, at: Vector3, pose: Basis = Basis.IDENTITY) -> Node3D:
	var node := root("BurialSarcophagus","sarcophagus")
	var body := Surface.new()
	var lid := Surface.new()
	var remains := Surface.new()
	# The long axis follows the wall. A hollow rim, offset lid and wrapped remains read in 3D.
	var turn := pose*Basis(Vector3.UP,PI*0.5)
	block(body,at+Vector3.UP*0.30,Vector3(1.0,0.60,2.6),Color(0.75,0.75,0.69),turn,0.13)
	for side in [-1.0,1.0]: block(body,at+turn*Vector3(side*0.47,0.68,0),Vector3(0.15,0.28,2.6),Color(0.88,0.85,0.75),turn,0.05)
	for end in [-1.0,1.0]: block(body,at+turn*Vector3(0,0.68,end*1.24),Vector3(0.90,0.28,0.15),Color(0.88,0.85,0.75),turn,0.04)
	var open := absi(label.hash())%3 != 0
	var lid_at := at+turn*Vector3(0.34 if open else 0.0,0.84,0.08)
	var lid_pose := turn*Basis(Vector3.FORWARD,0.14 if open else 0.0)
	block(lid,lid_at,Vector3(0.87,0.19,2.47),Color(0.80,0.87,0.79),lid_pose,0.12)
	ellipsoid(lid,lid_at+lid_pose*Vector3(0,0.13,-0.76),Vector3(0.24,0.10,0.29),Color(1.16,0.94,0.50),lid_pose)
	for i in 5: block(lid,lid_at+lid_pose*Vector3(0,0.115,-0.22+i*0.28),Vector3(0.60,0.03,0.035),Color(0.24,0.37,0.34),lid_pose,0.008)
	if open:
		ellipsoid(remains,at+turn*Vector3(-0.12,0.63,0.08),Vector3(0.24,0.12,0.73),Color(0.91,0.84,0.65),turn)
		ellipsoid(remains,at+turn*Vector3(-0.12,0.67,-0.78),Vector3(0.17,0.12,0.20),Color(0.82,0.76,0.60),turn)
		for i in 9: tube(remains,at+turn*Vector3(-0.33,0.73,-0.55+i*0.13),at+turn*Vector3(0.09,0.73,-0.51+i*0.13),0.018,Color(0.61,0.56,0.43),6)
	commit(node,body,shadow,"HollowWeatheredStoneCoffin")
	commit(node,lid,pigment,"CarvedAnthropoidLid")
	commit(node,remains,linen,"WrappedMummyRemains")
	return node
