@tool
extends RefCounted
## Static cutaway geology. The existing region remains the physics authority.

class Surface:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	func triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
		var normal := (b-a).cross(c-a).normalized()
		for p in [a,c,b]:
			points.append(p)
			normals.append(normal)
			colors.append(color)
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
		triangle(a,b,c,color)
		triangle(b,d,c,color)
	func mesh() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		var result := ArrayMesh.new()
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		return result

static var _rock: StandardMaterial3D
static var _sediment: StandardMaterial3D
static var _crack: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()

func _begin(label: String) -> void:
	_rng.seed = absi(label.hash())+6173
	_noise.seed = absi(label.hash()) % 65536
	_noise.frequency = 0.42
	_noise.fractal_octaves = 3
	if _rock == null:
		_rock = _material("Rough cavern limestone",false)
		_sediment = _material("Worn cave sediment",true)
		_crack = StandardMaterial3D.new()
		_crack.resource_name = "Deep irregular rock fissures"
		_crack.vertex_color_use_as_albedo = true
		_crack.roughness = 1.0
		_crack.cull_mode = BaseMaterial3D.CULL_DISABLED

func _material(label: String, floor_surface: bool) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.seed = 389 if floor_surface else 991
	noise.frequency = 0.009
	noise.fractal_octaves = 4
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0,0.30,0.53,0.74,1.0])
	if floor_surface:
		ramp.colors = PackedColorArray([Color(0.20,0.19,0.17),Color(0.27,0.25,0.21),Color(0.32,0.30,0.25),Color(0.37,0.34,0.28),Color(0.42,0.39,0.32)])
	else:
		ramp.colors = PackedColorArray([Color(0.19,0.22,0.22),Color(0.27,0.30,0.29),Color(0.35,0.37,0.34),Color(0.40,0.41,0.37),Color(0.48,0.47,0.42)])
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = ramp
	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = 509
	detail_noise.frequency = 0.16
	detail_noise.fractal_octaves = 3
	var normal_texture := NoiseTexture2D.new()
	normal_texture.width = 256
	normal_texture.height = 256
	normal_texture.seamless = true
	normal_texture.noise = detail_noise
	normal_texture.as_normal_map = true
	normal_texture.bump_strength = 1.2
	var material := StandardMaterial3D.new()
	material.resource_name = label
	material.albedo_texture = texture
	material.vertex_color_use_as_albedo = true
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE*(0.12 if floor_surface else 0.18)
	material.normal_enabled = true
	material.normal_texture = normal_texture
	material.normal_scale = 0.22
	material.roughness = 0.96 if floor_surface else 0.88
	material.metallic_specular = 0.22
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	parent.add_child(instance)

func floor_mesh(label: String, dimensions: Vector2, origin: Vector3) -> Node3D:
	_begin(label)
	var root := _root("CavernFloor","floor")
	var surface := Surface.new()
	var columns := ceili(dimensions.x/1.25)
	var rows := ceili(dimensions.y/1.25)
	var grid: Array[Vector3] = []
	for z in range(rows+1):
		for x in range(columns+1):
			var at := Vector3(float(x)/columns*dimensions.x-dimensions.x*0.5,-0.008,float(z)/rows*dimensions.y-dimensions.y*0.5)
			if x > 0 and x < columns and z > 0 and z < rows:
				at.x += _rng.randf_range(-0.27,0.27)
				at.z += _rng.randf_range(-0.27,0.27)
				# Tiny depressions are entirely below the unchanged walk plane and route marks.
				at.y -= absf(_noise.get_noise_2d(at.x+origin.x,at.z+origin.z))*0.025
			grid.append(at)
	for z in rows:
		for x in columns:
			var a := z*(columns+1)+x
			var b := a+1
			var c := a+columns+1
			var d := c+1
			var tint := Color(0.96,0.95,0.91).lerp(Color(1.02,1.01,0.97),_rng.randf())
			if (x+z)%2 == 0:
				surface.quad(grid[a],grid[c],grid[b],grid[d],tint)
			else:
				surface.triangle(grid[a],grid[c],grid[d],tint)
				surface.triangle(grid[a],grid[d],grid[b],tint)
	_commit(root,surface,_sediment,"UnevenSediment")
	return root

func wall_mesh(label: String, center: Vector3, size: Vector3, normal: Vector3, room: bool) -> Node3D:
	_begin(label)
	var root := _root("CavernRock","wall")
	var stone := Surface.new()
	var cracks := Surface.new()
	var tangent := Vector3(-normal.z,0,normal.x)
	var length := maxf(size.x,size.z)
	var columns := maxi(2,ceili(length/1.05))
	var depth := 1.8 if room else 1.2
	# The camera looks north: low southern cutaways cannot hide actors above the old collider.
	var top := 2.85 if normal.z > 0.5 else (5.0 if room else 4.0)
	var levels := PackedFloat32Array([-3.3,-1.25,-0.15,0.0,0.72,1.45,2.25,top])
	var grid: Array[Vector3] = []
	for row in levels.size():
		for i in range(columns+1):
			var u := -length*0.5+float(i)/columns*length
			var y := levels[row]
			var relief := _relief(u,y)
			if row < 3: relief = 0.12+absf(relief)*1.3
			if row == 3: relief = 0.0 # close the floor edge without a gap
			if row == levels.size()-1:
				y -= _rng.randf_range(0.0,0.85 if top > 3.0 else 0.42)
				relief += 0.30
			if row in [4,5,6]: y += _rng.randf_range(-0.17,0.17)
			var stagger := _rng.randf_range(-0.19,0.19) if i > 0 and i < columns and row > 3 else 0.0
			grid.append(center+tangent*(u+stagger)+Vector3.UP*(y-center.y)+normal*(relief-0.3))
	for row in range(levels.size()-1):
		for i in columns:
			var a := row*(columns+1)+i
			var b := a+1
			var c := a+columns+1
			var d := c+1
			var tint := Color(0.87,0.91,0.87).lerp(Color(1.02,1.02,0.94),_rng.randf())
			if row < 3: tint = Color(0.48,0.53,0.51)
			stone.quad(grid[a],grid[b],grid[c],grid[d],tint)
	# Jagged outward shelves close the cut section and descend into dark peripheral shafts.
	for i in columns:
		var a: Vector3 = grid[(levels.size()-1)*(columns+1)+i]
		var b: Vector3 = grid[(levels.size()-1)*(columns+1)+i+1]
		var rear_a := a+normal*(depth+_rng.randf_range(0.1,0.9))+Vector3.DOWN*_rng.randf_range(0.15,0.55)
		var rear_b := b+normal*(depth+_rng.randf_range(0.1,0.9))+Vector3.DOWN*_rng.randf_range(0.15,0.55)
		stone.quad(a,b,rear_a,rear_b,Color(0.72,0.77,0.72))
		stone.quad(rear_b,rear_a,Vector3(rear_b.x,-3.8,rear_b.z),Vector3(rear_a.x,-3.8,rear_a.z),Color(0.36,0.42,0.40))
	for edge in [0,columns]:
		for row in range(levels.size()-1):
			var a: Vector3 = grid[row*(columns+1)+edge]
			var b: Vector3 = grid[(row+1)*(columns+1)+edge]
			stone.quad(a,b,a+normal*depth,b+normal*depth,Color(0.64,0.69,0.64))
	# Mineral teeth hang only beside walls, above the character's head, never across a door.
	for i in maxi(1,int(length/2.1)):
		var u := _rng.randf_range(-length*0.5+0.7,length*0.5-0.7)
		var ceiling := top-_rng.randf_range(0.12,0.38)
		var height := minf(_rng.randf_range(1.1,2.1),ceiling-2.2)
		var at := center+tangent*u+Vector3.UP*(ceiling-center.y)-normal*0.45
		_spire(stone,at,Vector3.DOWN,height,_rng.randf_range(0.24,0.45),Color(1.08,1.06,0.95))
		_spire(stone,at+tangent*0.32+normal*0.16,Vector3.DOWN,minf(height*0.63,ceiling-2.2),0.16,Color(1.04,1.02,0.91))
	# Raised rim shelves and stalagmites stay on the inaccessible side of the wall.
	for i in maxi(1,int(length/4.3)):
		var u := _rng.randf_range(-length*0.5+0.8,length*0.5-0.8)
		var at := center+tangent*u+Vector3.UP*(-0.35-center.y)+normal*0.8
		_spire(stone,at,Vector3.UP,_rng.randf_range(1.2,2.5),_rng.randf_range(0.35,0.63),Color(0.77,0.81,0.73))
	# Long fissures follow the relief instead of forming masonry seams.
	for i in maxi(1,int(length/2.6)):
		var u := _rng.randf_range(-length*0.5+0.18,length*0.5-0.18)
		var y := _rng.randf_range(0.25,0.65)
		for j in 5:
			var next_u := clampf(u+_rng.randf_range(-0.19,0.19),-length*0.5+0.05,length*0.5-0.05)
			var next_y := y+_rng.randf_range(0.25,0.39)
			var a := _wall_sample(grid,columns,levels,length,u,y)-normal*0.012
			var b := _wall_sample(grid,columns,levels,length,next_u,next_y)-normal*0.012
			var width := tangent*_rng.randf_range(0.008,0.020)
			cracks.quad(a-width,b-width,a+width,b+width,Color(0.075,0.085,0.076))
			u = next_u
			y = next_y
	root.set_meta("ceiling_height",top)
	root.set_meta("peripheral_depth",-3.8)
	_commit(root,stone,_rock,"RockFaceAndStalactites")
	_commit(root,cracks,_crack,"RockFissures")
	return root

func _wall_sample(grid: Array[Vector3], columns: int, levels: PackedFloat32Array, length: float, u: float, y: float) -> Vector3:
	var x := clampf((u/length+0.5)*columns,0.0,columns-0.001)
	var column := floori(x)
	var row := 0
	while row < levels.size()-2 and y > levels[row+1]: row += 1
	var tx := x-column
	var ty := clampf(inverse_lerp(levels[row],levels[row+1],y),0.0,1.0)
	var a := grid[row*(columns+1)+column]
	var b := grid[row*(columns+1)+column+1]
	var c := grid[(row+1)*(columns+1)+column]
	var d := grid[(row+1)*(columns+1)+column+1]
	if tx+ty <= 1.0: return a+(b-a)*tx+(c-a)*ty
	return d+(c-d)*(1.0-tx)+(b-d)*(1.0-ty)

func _relief(u: float, y: float) -> float:
	return clampf(0.32+_noise.get_noise_2d(u+y*0.23,y*0.85)*1.35+sin(y*2.8+u*0.64)*0.22,-0.14,1.15)

func _spire(surface: Surface, at: Vector3, axis: Vector3, height: float, radius: float, color: Color) -> void:
	var rings: Array[Vector3] = []
	const SIDES := 12
	for ring in 5:
		var t := float(ring)/4.0
		var r := radius*pow(1.0-t,1.1)+0.012
		for i in SIDES:
			var angle := TAU*float(i)/SIDES
			var p := at+axis*(t*height)+Vector3(cos(angle)*r,0,sin(angle)*r)*_rng.randf_range(0.87,1.12)
			p += Vector3(t*t*height*0.10,0,t*t*height*0.045)
			rings.append(p)
	for ring in 4:
		for i in SIDES:
			var a := ring*SIDES+i
			var b := ring*SIDES+(i+1)%SIDES
			if axis.y < 0: surface.quad(rings[a],rings[b],rings[a+SIDES],rings[b+SIDES],color)
			else: surface.quad(rings[a],rings[a+SIDES],rings[b],rings[b+SIDES],color)

func cover_mesh(label: String, size: Vector3) -> Node3D:
	_begin(label)
	var root := _root("StoneCover","cover")
	var surface := Surface.new()
	var half := size*0.5
	# A naturally fractured block still advertises the full existing cover footprint.
	var rings: Array[Vector3] = []
	var outline := [Vector2(-1,-0.72),Vector2(-0.70,-1),Vector2(0.69,-1),Vector2(1,-0.71),Vector2(1,0.68),Vector2(0.68,1),Vector2(-0.69,1),Vector2(-1,0.70)]
	for ring in 3:
		for p: Vector2 in outline:
			var sizing := 1.0 if ring == 1 else 0.89
			var y := (-half.y if ring == 0 else (half.y*0.60 if ring == 1 else half.y))
			rings.append(Vector3(p.x*half.x*sizing,y,p.y*half.z*sizing))
	for i in 8:
		var next := (i+1)%8
		for ring in 2:
			surface.quad(rings[ring*8+i],rings[ring*8+next],rings[(ring+1)*8+i],rings[(ring+1)*8+next],Color(0.96,0.97,0.88))
		surface.triangle(rings[16+i],Vector3(0,half.y*0.96,0),rings[16+next],Color(1.02,1.01,0.91))
	_commit(root,surface,_rock,"FracturedBoulder")
	return root
