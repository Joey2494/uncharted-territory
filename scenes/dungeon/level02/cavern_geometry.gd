@tool
extends RefCounted
const Cache = preload("res://scripts/rendering/static_art_cache.gd")
## Solid stratified limestone. The existing region remains the physics authority.

class Surface:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var ambient_uv := PackedVector2Array()
	func triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
		var normal := (b-a).cross(c-a).normalized()
		if normal.length_squared() < 0.5: return
		for p in [a,c,b]:
			points.append(p)
			normals.append(normal)
			colors.append(color)
			ambient_uv.append(Vector2(0.995,0.5))
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
		triangle(a,b,c,color)
		triangle(b,d,c,color)
	func mesh() -> ArrayMesh:
		# Smooth erosion, while preserving real fracture edges instead of melting all beds.
		var sums := {}
		for i in points.size():
			if not sums.has(points[i]): sums[points[i]] = []
			sums[points[i]].append(normals[i])
		var smoothed := PackedVector3Array()
		for i in points.size():
			var sum := Vector3.ZERO
			for other: Vector3 in sums[points[i]]:
				if normals[i].dot(other) > 0.40: sum += other
			smoothed.append(sum.normalized())
		normals = smoothed
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV2] = ambient_uv
		var result := ArrayMesh.new()
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		return result

static var _rock: StandardMaterial3D
static var _sediment: StandardMaterial3D
static var _ambient_ramp: ImageTexture
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()

func _begin(label: String) -> void:
	_rng.seed = absi(label.hash())+6173
	_noise.seed = 6173 # continuous world-space geology across region boundaries
	_noise.frequency = 0.42
	_noise.fractal_octaves = 3
	if _rock == null:
		var baked := Cache.material_set("cave")
		if not baked.is_empty():
			_rock = baked.rock
			_sediment = baked.sediment
			_ambient_ramp = baked.ambient
			return
		_rock = _material("Weathered grey limestone",false)
		_sediment = _material("Limestone dust and worn sediment",true)

func _material(label: String, floor_surface: bool) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.seed = 991
	noise.frequency = 0.005
	noise.fractal_octaves = 3
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0,0.25,0.45,0.68,1.0])
	ramp.colors = PackedColorArray([Color(0.24,0.26,0.25),Color(0.31,0.32,0.30),Color(0.36,0.37,0.35),Color(0.41,0.41,0.385),Color(0.46,0.45,0.42)])
	if floor_surface:
		ramp.colors = PackedColorArray([Color(0.27,0.28,0.26),Color(0.31,0.32,0.30),Color(0.35,0.35,0.33),Color(0.375,0.37,0.345),Color(0.40,0.39,0.36)])
	var texture := NoiseTexture2D.new()
	texture.width = 1024
	texture.height = 1024
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	texture.color_ramp = ramp
	var roughness_ramp := Gradient.new()
	roughness_ramp.offsets = ramp.offsets
	roughness_ramp.colors = PackedColorArray([Color(0.24,0.24,0.24),Color(0.40,0.40,0.40),Color(0.76,0.76,0.76),Color(0.98,0.98,0.98),Color.WHITE])
	var roughness_map := NoiseTexture2D.new()
	roughness_map.width = 1024
	roughness_map.height = 1024
	roughness_map.seamless = true
	roughness_map.generate_mipmaps = true
	roughness_map.noise = noise
	roughness_map.color_ramp = roughness_ramp
	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = 509
	detail_noise.frequency = 0.30
	detail_noise.fractal_octaves = 3
	var normal_texture := NoiseTexture2D.new()
	normal_texture.width = 512
	normal_texture.height = 512
	normal_texture.seamless = true
	normal_texture.generate_mipmaps = true
	normal_texture.noise = detail_noise
	normal_texture.as_normal_map = true
	normal_texture.bump_strength = 0.55
	var grain_noise := FastNoiseLite.new()
	grain_noise.seed = 1387
	grain_noise.frequency = 0.34
	grain_noise.fractal_octaves = 3
	var grain_ramp := Gradient.new()
	grain_ramp.colors = PackedColorArray([Color(0.77,0.77,0.76),Color(1.0,1.0,0.99)])
	var grain_texture := NoiseTexture2D.new()
	grain_texture.width = 1024
	grain_texture.height = 1024
	grain_texture.seamless = true
	grain_texture.generate_mipmaps = true
	grain_texture.noise = grain_noise
	grain_texture.color_ramp = grain_ramp
	var material := StandardMaterial3D.new()
	material.resource_name = label
	material.albedo_texture = texture
	material.albedo_color = Color(0.96,0.96,0.93) if floor_surface else Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE*0.045
	material.normal_enabled = true
	material.normal_texture = normal_texture
	material.normal_scale = 0.12 if floor_surface else 0.25
	material.detail_enabled = true
	material.detail_albedo = grain_texture
	material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	material.roughness = 0.96 if floor_surface else 0.92
	material.roughness_texture = roughness_map
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	if _ambient_ramp == null:
		var ramp_image := Image.create(256,1,false,Image.FORMAT_RGB8)
		for i in 256: ramp_image.set_pixel(i,0,Color(float(i)/255.0,float(i)/255.0,float(i)/255.0))
		_ambient_ramp = ImageTexture.create_from_image(ramp_image)
	material.ao_enabled = true
	material.ao_on_uv2 = true
	material.ao_texture = _ambient_ramp
	material.ao_light_affect = 0.12
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.metallic_specular = 0.40
	material.cull_mode = BaseMaterial3D.CULL_BACK
	return material

func _root(label: String, kind: String) -> Node3D:
	var result := Node3D.new()
	result.name = label
	result.set_meta("cavern_geometry",kind)
	return result

func _commit(parent: Node3D, surface: Surface, material: Material, label: String) -> void:
	if surface.points.is_empty(): return
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = surface.mesh()
	instance.mesh.surface_set_material(0,material)
	if material == _rock or material == _sediment:
		instance.layers = 1|(1<<18) # Static geology captured by the local puddle probes.
	parent.add_child(instance)

func floor_mesh(label: String, dimensions: Vector2, origin: Vector3, openings: Vector4 = Vector4.ZERO, detail: RefCounted = null) -> Node3D:
	_begin(label)
	var cache_key := Cache.key("floor",[label,dimensions,origin,openings,detail.cache_signature() if detail != null and detail.has_method("cache_signature") else null])
	var cacheable := detail == null or detail.has_method("cache_signature")
	var baked := Cache.lookup("cave",cache_key) if cacheable else {}
	if not baked.is_empty():
		_rng.state = baked.state
		return baked.node
	var root := _root("CavernFloor","floor")
	var surface := Surface.new()
	var columns := ceili(dimensions.x/0.7)
	var rows := ceili(dimensions.y/0.7)
	var grid: Array[Vector3] = []
	var shades: Array[Color] = []
	var occlusions: Array[float] = []
	var half := dimensions*0.5
	for z in range(rows+1):
		for x in range(columns+1):
			var at := Vector3(float(x)/columns*dimensions.x-dimensions.x*0.5,-0.008,float(z)/rows*dimensions.y-dimensions.y*0.5)
			if x > 0 and x < columns and z > 0 and z < rows:
				# Tiny depressions are entirely below the unchanged walk plane and route marks.
				at.y -= absf(_noise.get_noise_2d(at.x+origin.x,at.z+origin.z))*0.055
			if detail != null: at.y += detail.depression(Vector2(at.x,at.z))
			grid.append(at)
			# Ground contact shading fades out at open doorways instead of drawing a seam.
			var edge := minf(half.x-absf(at.x),half.y-absf(at.z))
			if (at.z < 0 and absf(at.x) < openings.x) or (at.z > 0 and absf(at.x) < openings.y): edge = half.x-absf(at.x)
			if (at.x < 0 and absf(at.z) < openings.z) or (at.x > 0 and absf(at.z) < openings.w): edge = half.y-absf(at.z)
			var world := at+origin
			var wash := _noise.get_noise_2d(world.x*0.65,world.z*0.65)
			var margin := 1.35+wash*0.9
			var contact := 1.0-smoothstep(0.10,margin,edge)
			var damp := smoothstep(-0.1,0.42,wash)*contact
			shades.append(Color(1.0,0.99,0.95).lerp(Color(0.62,0.67,0.65),damp*0.55))
			occlusions.append(clampf(1.0-contact*0.46,0.42,0.995))
	for z in rows:
		for x in columns:
			var a := z*(columns+1)+x
			var b := a+1
			var c := a+columns+1
			var d := c+1
			if detail != null and detail.has_basin(Vector2i(x,z)):
				detail.append_basin(surface,grid[a],grid[b],grid[c],grid[d],[shades[a],shades[b],shades[c],shades[d]],[occlusions[a],occlusions[b],occlusions[c],occlusions[d]])
				continue
			if detail != null and detail.has_crack(Vector2i(x,z)):
				detail.append_crack(surface,Vector2i(x,z),grid[a],grid[b],grid[c],grid[d],[shades[a],shades[b],shades[c],shades[d]],[occlusions[a],occlusions[b],occlusions[c],occlusions[d]])
				continue
			var start := surface.points.size()
			surface.quad(grid[a],grid[c],grid[b],grid[d],Color.WHITE)
			var corners := [a,b,c,c,b,d]
			for j in 6:
				surface.colors[start+j] = shades[corners[j]]
				surface.ambient_uv[start+j].x = occlusions[corners[j]]
	_commit(root,surface,_sediment,"UnevenSediment")
	if cacheable: Cache.record("cave",cache_key,root,_rng.state)
	return root

func wall_mesh(label: String, center: Vector3, size: Vector3, normal: Vector3, room: bool, origin: Vector3 = Vector3.ZERO, dimensions: Vector2 = Vector2.ZERO) -> Node3D:
	_begin(label)
	var cache_key := Cache.key("wall",[label,center,size,normal,room,origin,dimensions])
	var baked := Cache.lookup("cave",cache_key)
	if not baked.is_empty():
		_rng.state = baked.state
		return baked.node
	var root := _root("CavernRock","wall")
	var stone := Surface.new()
	var tangent := Vector3(-normal.z,0,normal.x)
	var length := maxf(size.x,size.z)
	var columns := maxi(4,ceili(length/0.34))
	var depth := 3.1 if room else 2.2
	var foreground := normal.z > 0.5
	var top := 2.72 if foreground else (4.9 if room else 4.1)
	var levels := PackedFloat32Array([-3.8,-1.6,-0.008,0.06,0.26,0.49,0.56,0.68,1.03,1.12,1.27,1.69,1.98,2.08,2.24,2.42])
	if not foreground: levels.append_array(PackedFloat32Array([2.71,2.84,3.01,3.43,3.71]))
	if room and not foreground: levels.append_array(PackedFloat32Array([4.07,4.39]))
	levels.append(top)
	var front: Array[Vector3] = []
	var back: Array[Vector3] = []
	var tints: Array[Color] = []
	var occlusions: Array[float] = []
	for row in levels.size():
		for i in range(columns+1):
			var u := -length*0.5+float(i)/columns*length
			var base := center+tangent*u
			var outward := normal
			if room:
				# Two half-arcs meet at each room corner, giving the hollow a cave contour.
				var horizontal := absf(normal.z) > 0.5
				var along := base.x if horizontal else base.z
				var half := dimensions.x*0.5 if horizontal else dimensions.y*0.5
				var across := dimensions.y*0.5 if horizontal else dimensions.x*0.5
				var radius := 1.65
				if absf(along) > half-radius:
					var angle := clampf((absf(along)-half+radius)/(radius+0.6),0.0,1.0)*PI*0.25
					var corner := Vector3(signf(along)*(half-radius),0,normal.z*(across-radius)) if horizontal else Vector3(normal.x*(across-radius),0,signf(along)*(half-radius))
					outward = Vector3(signf(along)*sin(angle),0,normal.z*cos(angle)) if horizontal else Vector3(normal.x*cos(angle),0,signf(along)*sin(angle))
					base = corner+outward*(radius+0.3)
			var world := base+origin
			var y := levels[row]
			var fold := _noise.get_noise_2d(world.x*0.19,world.z*0.19)*0.9
			var wave := fold+_noise.get_noise_3d(world.x*0.64,y*0.6,world.z*0.64)*0.32
			if foreground and y > 1.69: wave *= 0.23
			if row > 3: y += wave*smoothstep(0.06,0.65,y)
			if row == levels.size()-1:
				y = top-0.08-absf(_noise.get_noise_2d(world.x*0.65,world.z*0.65))*(0.14 if foreground else 1.1)
				y = maxf(y,front[(row-1)*(columns+1)+i].y+0.14)
			var offset := _face_offset(world,y,levels[row])
			front.append(Vector3(base.x,y,base.z)+outward*offset)
			back.append(Vector3(base.x,-3.8 if row == 0 else y-0.25,base.z)+outward*(depth+_noise.get_noise_2d(world.x,world.z)*0.85))
			var profile := _erosion(world,levels[row])
			var contact := 1.0-smoothstep(0.0,0.65,y)
			var damp := smoothstep(-0.12,0.45,_noise.get_noise_2d(world.x*0.6,world.z*0.6))*exp(-maxf(y,0.0)*0.55)
			var tint := Color(1.0,0.99,0.95).lerp(Color(0.57,0.64,0.63),damp*0.60)
			if row < 2: tint *= 0.58
			tints.append(tint)
			occlusions.append(clampf(0.99-profile.y*0.48-profile.z*0.55-contact*0.32,0.34,0.995))
	var stride := columns+1
	for row in range(levels.size()-1):
		for i in columns:
			var a := row*stride+i
			var b := a+1
			var c := a+stride
			var d := c+1
			var start := stone.points.size()
			stone.quad(front[a],front[b],front[c],front[d],Color.WHITE)
			var corners := [a,c,b,b,c,d]
			for j in 6:
				stone.colors[start+j] = tints[corners[j]]
				stone.ambient_uv[start+j].x = occlusions[corners[j]]
	# Ruled rear strips avoid a giant non-planar fan, while keeping all cap edges sealed.
	for i in columns:
		var upper := (levels.size()-1)*stride
		if i > 0 and i < columns-1:
			stone.quad(back[i+1],back[i],back[upper+i+1],back[upper+i],Color(0.49,0.55,0.51))
			continue
		var boundary: Array[Vector3] = [back[i],back[i+1]]
		if i == columns-1:
			for row in range(1,levels.size()): boundary.append(back[row*stride+i+1])
		else: boundary.append(back[upper+i+1])
		boundary.append(back[upper+i])
		if i == 0:
			for row in range(levels.size()-2,0,-1): boundary.append(back[row*stride+i])
		var rear_center := (back[i]+back[i+1]+back[upper+i]+back[upper+i+1])*0.25
		for j in boundary.size(): stone.triangle(boundary[j],rear_center,boundary[(j+1)%boundary.size()],Color(0.49,0.55,0.51))
	# Curved strips form a substantial roof shoulder, with the same boundary vertices.
	var roof: Array[Vector3] = []
	const ROOF_STEPS := 4
	for j in range(ROOF_STEPS+1):
		var t := float(j)/ROOF_STEPS
		for i in range(stride):
			var a := front[(levels.size()-1)*stride+i]
			var b := back[(levels.size()-1)*stride+i]
			var p := a.lerp(b,t)
			var erosion := _noise.get_noise_3d(p.x+origin.x,3.7,p.z+origin.z)
			p.y += sin(t*PI)*((0.10 if foreground else 0.45)+erosion*(0.10 if foreground else 0.44))
			roof.append(p)
	for j in ROOF_STEPS:
		for i in columns:
			var a := j*stride+i
			stone.quad(roof[a],roof[a+1],roof[a+stride],roof[a+stride+1],Color(0.90,0.90,0.85))
	# Doorway reveals and corner ends close the solid shell, rather than exposing a plane.
	for side in [0,columns]:
		var cap: Array[Vector3] = []
		for row in levels.size():
			var index: int = row*stride+side
			for j in range(ROOF_STEPS+1):
				var t := float(j)/ROOF_STEPS
				var p := front[index].lerp(back[index],t)
				if row > 0 and row < levels.size()-1:
					# Sculpt the exposed reveal too, so it does not read as a flat pillar.
					var erosion := 0.16+_noise.get_noise_3d(p.x+origin.x,p.y,p.z+origin.z)*0.20
					p += tangent*(1.0 if side == 0 else -1.0)*sin(t*PI)*erosion
				cap.append(p)
		for row in range(levels.size()-1):
			for j in ROOF_STEPS:
				var a := row*(ROOF_STEPS+1)+j
				var b := a+ROOF_STEPS+1
				if side == 0: stone.quad(cap[a],cap[b],cap[a+1],cap[b+1],Color(0.84,0.85,0.80))
				else: stone.quad(cap[b],cap[a],cap[b+1],cap[a+1],Color(0.84,0.85,0.80))
		for j in ROOF_STEPS:
			var a := roof[j*stride+side]
			var b := roof[(j+1)*stride+side]
			var c := cap[(levels.size()-1)*(ROOF_STEPS+1)+j]
			var d := cap[(levels.size()-1)*(ROOF_STEPS+1)+j+1]
			if side == 0: stone.quad(a,b,c,d,Color(0.84,0.85,0.80))
			else: stone.quad(b,a,d,c,Color(0.84,0.85,0.80))
	for j in ROOF_STEPS:
		var t := float(j)/ROOF_STEPS
		var next_t := float(j+1)/ROOF_STEPS
		for i in columns:
			stone.quad(front[i+1].lerp(back[i+1],t),front[i].lerp(back[i],t),front[i+1].lerp(back[i+1],next_t),front[i].lerp(back[i],next_t),Color(0.35,0.37,0.35))
	# Sparse mineral teeth are rooted in the shoulder, not placed in rows of decoration.
	root.set_meta("shell_vertex_count",stone.points.size())
	if not foreground:
		for i in maxi(1,int(length/5.0)):
			var u := _rng.randf_range(-length*0.5+0.55,length*0.5-0.55)
			var column := clampi(roundi((u/length+0.5)*columns),0,columns)
			var at := front[(levels.size()-1)*stride+column]+normal*0.15+Vector3.UP*0.08
			if _noise.get_noise_2d((at.x+origin.x)*0.43,(at.z+origin.z)*0.43) < -0.05: continue
			for tooth in _rng.randi_range(1,3):
				var height := minf(_rng.randf_range(0.28,1.40),at.y-2.3)
				var offset := tangent*(float(tooth)*0.19)+normal*float(tooth)*0.06
				_spire(stone,at+offset,Vector3.DOWN,height,height*_rng.randf_range(0.20,0.35),Color(0.88,0.90,0.80))
	root.set_meta("ceiling_height",top)
	root.set_meta("peripheral_depth",-3.8)
	root.set_meta("rock_thickness",depth)
	root.set_meta("closed_shell",true)
	_commit(root,stone,_rock,"RockFaceAndStalactites")
	Cache.record("cave",cache_key,root,_rng.state)
	return root

func _face_offset(world: Vector3, y: float, bed: float) -> float:
	if y < -0.01: return 0.18+_noise.get_noise_2d(world.x+y,world.z)*0.22
	# A continuous eroded toe blends the wall into sediment, instead of a straight seam.
	var toe := -0.53-_noise.get_noise_2d(world.x*1.1,world.z*1.1)*0.19
	if bed < 0.01: return toe
	var shape := _erosion(world,bed).x
	if y > 2.4: shape -= smoothstep(2.4,4.8,y)*0.34
	return lerpf(toe,clampf(shape,-0.72,1.05),smoothstep(0.0,0.54,y))

func _erosion(world: Vector3, bed: float) -> Vector3:
	# Warped, broken joints: layer widths and crack depths vary independently.
	var warp := _noise.get_noise_2d(world.x*0.29,world.z*0.29)
	var mass := _noise.get_noise_3d(world.x*0.57+warp,bed*0.64,world.z*0.57-warp)
	var grain := _noise.get_noise_3d(world.x*2.1,bed*1.6,world.z*2.1)
	var shape := -0.16+mass*1.18+grain*0.14
	var joint := 0.0
	if (bed > 0.54 and bed < 0.60) or (bed > 1.10 and bed < 1.16) or (bed > 2.06 and bed < 2.13) or (bed > 2.81 and bed < 2.90):
		joint = smoothstep(-0.48,0.34,_noise.get_noise_3d(world.x*0.7,bed*1.3,world.z*0.7))
		shape += joint*(0.23+maxf(mass,0.0)*0.36)
	var vein := world.x*0.66+world.z*0.53+bed*0.21+warp*2.3
	var fracture := pow(1.0-absf(sin(vein)),8.0)
	fracture *= smoothstep(-0.38,0.30,_noise.get_noise_3d(world.x*0.38,bed*0.8,world.z*0.38))
	var branch := pow(1.0-absf(sin(world.x*1.12-world.z*0.77-bed*0.32+warp*1.7)),10.0)
	fracture = maxf(fracture,branch*smoothstep(0.0,0.5,grain))
	shape += fracture*(0.38+joint*0.24)
	return Vector3(shape,joint,fracture)

func _spire(surface: Surface, at: Vector3, axis: Vector3, height: float, radius: float, color: Color) -> void:
	var rings: Array[Vector3] = []
	const SIDES := 9
	for ring in 5:
		var t := float(ring)/4.0
		var r := radius*pow(1.0-t,1.1)+0.012
		for i in SIDES:
			var angle := TAU*float(i)/SIDES
			var p := at+axis*(t*height)+Vector3(cos(angle)*r,0,sin(angle)*r)*_rng.randf_range(0.93,1.07)
			p += Vector3(t*t*height*0.10,0,t*t*height*0.045)
			rings.append(p)
	for ring in 4:
		for i in SIDES:
			var a := ring*SIDES+i
			var b := ring*SIDES+(i+1)%SIDES
			if axis.y < 0: surface.quad(rings[a],rings[b],rings[a+SIDES],rings[b+SIDES],color)
			else: surface.quad(rings[a],rings[a+SIDES],rings[b],rings[b+SIDES],color)
	var base_center := Vector3.ZERO
	var tip_center := Vector3.ZERO
	for i in SIDES:
		base_center += rings[i]/SIDES
		tip_center += rings[4*SIDES+i]/SIDES
	for i in SIDES:
		var next := (i+1)%SIDES
		if axis.y < 0:
			surface.triangle(rings[i],base_center,rings[next],color)
			surface.triangle(rings[4*SIDES+i],rings[4*SIDES+next],tip_center,color)
		else:
			surface.triangle(rings[i],rings[next],base_center,color)
			surface.triangle(rings[4*SIDES+i],tip_center,rings[4*SIDES+next],color)

func cover_mesh(label: String, size: Vector3) -> Node3D:
	_begin(label)
	var root := _root("StoneCover","cover")
	var surface := Surface.new()
	var half := size*0.5
	# A naturally fractured block still advertises the full existing cover footprint.
	var rings: Array[Vector3] = []
	var outline := [Vector2(-1,-_rng.randf_range(0.43,0.78)),Vector2(-_rng.randf_range(0.42,0.80),-1),Vector2(_rng.randf_range(0.35,0.76),-1),Vector2(1,-_rng.randf_range(0.40,0.85)),Vector2(1,_rng.randf_range(0.35,0.78)),Vector2(_rng.randf_range(0.38,0.82),1),Vector2(-_rng.randf_range(0.32,0.77),1),Vector2(-1,_rng.randf_range(0.38,0.76))]
	var lean := Vector2(_rng.randf_range(-0.17,0.17),_rng.randf_range(-0.14,0.14))
	var crown := _rng.randi_range(0,7)
	for ring in 5:
		for i in 8:
			var p: Vector2 = outline[i]
			var sizing: float = [0.91,1.0,0.93,0.81,0.57][ring]
			var y: float = [-1.0,-0.44,0.07,0.38,0.91][ring]*half.y
			if ring == 4: y = half.y if i == crown else half.y*_rng.randf_range(0.58,0.92)
			var shift := lean*pow(float(ring)/4.0,2.0)
			rings.append(Vector3((p.x*sizing+shift.x)*half.x,y,(p.y*sizing+shift.y)*half.z))
	for i in 8:
		var next := (i+1)%8
		for ring in 4:
			var shade := 0.80 if ring == 2 else 0.98
			surface.quad(rings[(ring+1)*8+i],rings[(ring+1)*8+next],rings[ring*8+i],rings[ring*8+next],Color(shade,shade,shade*0.95))
		surface.triangle(rings[32+i],Vector3(lean.x*half.x,half.y*0.84,lean.y*half.z),rings[32+next],Color(1.0,0.98,0.91))
		surface.triangle(rings[i],rings[next],Vector3(0,-half.y,0),Color(0.55,0.56,0.52))
	_commit(root,surface,_rock,"FracturedBoulder")
	return root
