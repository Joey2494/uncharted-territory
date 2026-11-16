@tool
extends RefCounted
## Static, collision-free silk dressing. Positions are local to one wall anchor.
## Single-surface batches remain compatible with the existing wall fade.

class Surface:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	func vertex(at: Vector3, normal: Vector3, color: Color, uv: Vector2 = Vector2.ZERO) -> void:
		points.append(at)
		normals.append(normal)
		colors.append(color)
		uvs.append(uv)
	func triangle(a: int, b: int, c: int) -> void:
		# Godot uses clockwise front faces, as do its native primitive meshes.
		indices.append(a)
		indices.append(c)
		indices.append(b)
	func mesh() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		var result := ArrayMesh.new()
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		return result

var _rng := RandomNumberGenerator.new()
var _threads: Surface
var _bodies: Surface
var _veils: Surface
var _root: Node3D
var _thread_material: StandardMaterial3D
var _body_material: StandardMaterial3D
var _veil_material: StandardMaterial3D
static var _silk_texture: NoiseTexture2D
const SILK := Color(0.61,0.63,0.61)
const OLD_SILK := Color(0.42,0.45,0.43)

func corner(label: String, signs: Vector2, density: float, index: int, maximum_reach: float) -> Node3D:
	_begin(label, index)
	_root.set_meta("habitat_kind","corner")
	var sx := signs.x
	var sz := signs.y
	var reach := minf(maximum_reach,lerpf(1.4,3.5,density)*_rng.randf_range(0.88,1.08))
	# A ragged wall web and a separate open ceiling canopy, never a solid roof.
	_web(Vector3(0,2.92,0),Vector3(-sx*reach,0,0),Vector3(0,-reach*0.72,0),0.72+density*0.22)
	if density > 0.35 or index < 2:
		_web(Vector3(0,3.04,0),Vector3(-sx*reach,-0.35,0),Vector3(0,-0.55,-sz*reach),0.62)
		_root.set_meta("ceiling_web",true)
		for i in 3:
			var t := _rng.randf_range(0.2,0.8)
			var at := Vector3(-sx*reach*(1.0-t),2.60,-sz*reach*t)
			_strand([at,at+Vector3(sx*0.07,-0.25,sz*0.06),at+Vector3(sx*0.12,-_rng.randf_range(0.45,0.9),sz*0.10)],0.008,OLD_SILK)
	if density > 0.48 and index % 2 == 0:
		_web(Vector3(0,2.70,0),Vector3(0,0,-sz*reach*0.72),Vector3(0,-1.4,0),0.64)
	if (density > 0.55 and index < 2) or (label == "Arrival" and index == 1):
		var center := Vector3(-sx*0.65,1.75,-sz*0.65)
		var size := Vector3(0.27+density*0.12,0.64+density*0.30,0.25+density*0.10)
		_cocoon(center,size,Basis(Vector3.FORWARD,_rng.randf_range(-0.14,0.14)),true)
		_strand([Vector3(-sx*0.10,3.03,-sz*0.10),center+Vector3(0,size.y,0)],0.016,SILK)
		_root.set_meta("hanging_cocoon",true)
	var nest_here := (index in [1,2] if label == "Boss" else index == (2 if label == "Antechamber" else 1))
	if density > 0.72 and nest_here:
		# Keep existing statues/crystals clear rather than placing them in a nest throat.
		var inset := Vector2(3.1,1.9) if label == "Archive" else (Vector2(2.4,1.5) if label == "Vault" else Vector2.ONE)
		var nest_at := Vector3(-sx*inset.x,0.04,-sz*inset.y)
		_nest(nest_at,0.67+density*0.16)
		var pose := Basis(Vector3(0,0,1),1.30*sx)*Basis(Vector3.UP,0.35*sz)
		_cocoon(nest_at+Vector3(-sx*0.65,0.30,sz*0.35),Vector3(0.24,0.71,0.23),pose,false)
		_root.set_meta("nest",true)
		_strand([Vector3(0,1.2,0),nest_at+Vector3.UP*0.2],0.012,OLD_SILK)
		for i in 5:
			var floor_at := Vector3(-sx*_rng.randf_range(0.3,2.15),0.035,-sz*_rng.randf_range(0.35,1.9))
			_strand([Vector3(-sx*0.03,_rng.randf_range(0.35,1.4),-sz*0.03),floor_at],0.012,OLD_SILK)
	return _finish()

func corridor(label: String, half: Vector2, vertical: bool, side: float, cross_supported: bool) -> Node3D:
	_begin(label,int(side)+3)
	_root.set_meta("habitat_kind","corridor")
	var along := Vector3(0,0,1) if vertical else Vector3(1,0,0)
	var across := Vector3(-side,0,0) if vertical else Vector3(0,0,-side)
	var width := half.x*2.0 if vertical else half.y*2.0
	_web(Vector3(0,2.94,0),along*_rng.randf_range(0.95,1.55),Vector3(0,-1.2,0),0.60)
	_web(Vector3(0,3.02,0),along*1.3+Vector3(0,-0.10,0),across*1.25+Vector3(0,-0.2,0),0.48)
	_root.set_meta("ceiling_web",true)
	if side < 0 and cross_supported:
		for i in 3:
			var start := Vector3(0,3.04,0)+along*(float(i)*0.26)
			var end := start+across*(width-0.20)+along*0.45
			_strand([start,start.lerp(end,0.35)+Vector3.DOWN*0.14,start.lerp(end,0.7)+Vector3.DOWN*0.19,end],0.012,SILK)
	if label in ["VaultPass","BossPass","ShortcutElbow"] and side > 0:
		var center := Vector3(0,1.85,0)+across*0.24
		_cocoon(center,Vector3(0.19,0.60,0.18),Basis(Vector3.FORWARD,0.10),true)
		_strand([Vector3(0,3.05,0),center+Vector3.UP*0.60],0.014,SILK)
		_root.set_meta("hanging_cocoon",true)
	return _finish()

func _begin(label: String, salt: int) -> void:
	_rng.seed = absi(label.hash())+salt*7919+9157
	_root = Node3D.new()
	_root.name = "SpiderHabitat_%d" % salt
	_root.set_meta("spider_habitat",true)
	_threads = Surface.new()
	_bodies = Surface.new()
	_veils = Surface.new()
	if _thread_material == null:
		_thread_material = _material("Weathered silk filaments")
		_thread_material.emission_enabled = true
		_thread_material.emission = Color(0.20,0.23,0.19)
		_thread_material.emission_energy_multiplier = 0.10
		_body_material = _material("Dusty cocoon silk")
		_body_material.albedo_texture = _cocoon_texture()
		_body_material.uv1_scale = Vector3(1.0,2.0,1.0)
		_veil_material = _material("Sparse translucent web membrane")
		_veil_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_veil_material.albedo_color.a = 0.075
		_veil_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_veil_material.render_priority = -1

func _cocoon_texture() -> NoiseTexture2D:
	if _silk_texture == null:
		var noise := FastNoiseLite.new()
		noise.seed = 1049
		noise.frequency = 0.12
		noise.fractal_octaves = 3
		var colors := Gradient.new()
		colors.colors = PackedColorArray([Color(0.59,0.60,0.56),Color(0.97,0.98,0.95)])
		_silk_texture = NoiseTexture2D.new()
		_silk_texture.width = 256
		_silk_texture.height = 256
		_silk_texture.seamless = true
		_silk_texture.noise = noise
		_silk_texture.color_ramp = colors
	return _silk_texture

func _material(label: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = label
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.97
	return material

func _finish() -> Node3D:
	_commit(_threads,_thread_material,"SilkFilaments",false)
	_commit(_bodies,_body_material,"CocoonsAndNest",true)
	_commit(_veils,_veil_material,"RaggedWebVeil",false)
	return _root

func _commit(surface: Surface, material: Material, label: String, shadows: bool) -> void:
	if surface.indices.is_empty(): return
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = surface.mesh()
	instance.mesh.surface_set_material(0,material)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(instance)

func _strand(path: Array, radius: float, color: Color) -> void:
	var start := _threads.points.size()
	for i in path.size():
		var before: Vector3 = path[maxi(i-1,0)]
		var after: Vector3 = path[mini(i+1,path.size()-1)]
		var tangent := (after-before).normalized()
		var reference := Vector3.RIGHT if absf(tangent.dot(Vector3.UP)) > 0.94 else Vector3.UP
		var normal := tangent.cross(reference).normalized()
		var other := tangent.cross(normal).normalized()
		for j in 3:
			var angle := TAU*float(j)/3.0
			var direction := normal*cos(angle)+other*sin(angle)
			_threads.vertex(path[i]+direction*radius,direction,color)
		if i == 0: continue
		for j in 3:
			var a := start+(i-1)*3+j
			var b := start+(i-1)*3+(j+1)%3
			var c := start+i*3+j
			var d := start+i*3+(j+1)%3
			_threads.triangle(a,b,c)
			_threads.triangle(b,d,c)

func _web(hub: Vector3, a: Vector3, b: Vector3, fullness: float) -> void:
	var spokes := _rng.randi_range(12,16)
	var rings := _rng.randi_range(6,8)
	var grid: Array = []
	for ring in range(rings+1):
		var row: Array[Vector3] = []
		var radius := float(ring)/float(rings)
		for spoke in range(spokes+1):
			var angle := float(spoke)/float(spokes)*PI*0.5
			var jitter := _rng.randf_range(-0.024,0.024)*radius
			var point := hub+(a*cos(angle)+b*sin(angle))*(radius+jitter)
			point.y -= sin(angle*2.0)*radius*0.13
			row.append(point)
		grid.append(row)
	for spoke in range(spokes+1):
		var line: Array = []
		for ring in range(rings+1): line.append(grid[ring][spoke])
		_strand(line,0.014 if spoke%4 == 0 else 0.009,SILK.darkened(_rng.randf_range(0.0,0.22)))
	for ring in range(1,rings+1):
		for spoke in spokes:
			if _rng.randf() > fullness+0.12: continue
			var p: Vector3 = grid[ring][spoke]
			var q: Vector3 = grid[ring][spoke+1]
			_strand([p,p.lerp(q,0.5)+Vector3.DOWN*0.018,q],0.0075,OLD_SILK.lightened(_rng.randf_range(0.05,0.25)))
			if ring < rings-1 and _rng.randf() < 0.18:
				var r: Vector3 = grid[ring+1][spoke]
				var first := _veils.points.size()
				var normal := (q-p).cross(r-p).normalized()
				for point in [p,q,r]: _veils.vertex(point,normal,SILK)
				_veils.triangle(first,first+1,first+2)

func _ellipsoid(center: Vector3, radii: Vector3, pose: Basis, color: Color, tapered: bool = false) -> void:
	var start := _bodies.points.size()
	const RINGS := 10
	const SIDES := 14
	for ring in range(RINGS+1):
		var polar := PI*float(ring)/float(RINGS)
		for side in range(SIDES+1):
			var angle := TAU*float(side)/float(SIDES)
			var normal := Vector3(sin(polar)*cos(angle),cos(polar),sin(polar)*sin(angle))
			var irregular := 1.0+0.035*sin(angle*3.0+polar*7.0)
			if tapered: irregular *= 1.0-0.14*cos(polar)
			var point := normal*radii*Vector3(irregular,1,irregular)
			var tint := color.darkened((1.0-normal.y)*0.12)
			_bodies.vertex(center+pose*point,(pose*(normal/radii)).normalized(),tint,Vector2(float(side)/SIDES,float(ring)/RINGS))
			if ring == 0 or side == 0: continue
			var d := start+ring*(SIDES+1)+side
			_bodies.triangle(d-SIDES-2,d-SIDES-1,d-1)
			_bodies.triangle(d-SIDES-1,d,d-1)

func _cocoon(center: Vector3, radii: Vector3, pose: Basis, hanging: bool) -> void:
	_ellipsoid(center,radii,pose,Color(0.76,0.77,0.73),true)
	for layer in 3:
		var line: Array = []
		var turns := (13.7 if hanging else 11.3)+float(layer)*0.65
		for i in 221:
			var t := float(i)/220.0
			var polar := lerpf(0.12,PI-0.12,t)
			var angle := t*TAU*turns*(1.0 if layer%2 == 0 else -1.0)+float(layer)*2.1
			var envelope := sin(polar)*(1.0-0.14*cos(polar))*(1.0+0.035*sin(angle*3.0+polar*7.0))*1.018
			var point := Vector3(cos(angle)*radii.x*envelope,cos(polar)*radii.y,sin(angle)*radii.z*envelope)
			line.append(center+pose*point)
		_strand(line,0.006,Color(0.64,0.65,0.62))
	for i in 3:
		var angle := TAU*float(i)/3.0
		var path: Array = []
		for j in 12:
			var polar := PI*float(j)/11.0
			var envelope := sin(polar)*(1.0-0.14*cos(polar))*(1.0+0.035*sin(angle*3.0+polar*7.0))*1.02
			path.append(center+pose*Vector3(cos(angle)*radii.x*envelope,cos(polar)*radii.y,sin(angle)*radii.z*envelope))
		_strand(path,0.005,OLD_SILK.lightened(0.25))

func _nest(center: Vector3, radius: float) -> void:
	# A shallow funnel with a dark throat, egg clutches and matted outer silk.
	_funnel(center,radius)
	_ellipsoid(center+Vector3(-radius*0.10,0.032,radius*0.06),Vector3(radius*0.24,0.018,radius*0.20),Basis.IDENTITY,Color(0.045,0.055,0.040))
	var rim: Array = []
	for i in 193:
		var t := float(i)/192.0
		var angle := t*TAU*7.0
		var r := lerpf(radius*0.32,radius,t)*(1.0+0.085*sin(angle*3.0)+0.028*sin(angle*13.0))
		rim.append(center+Vector3(cos(angle)*r,0.18+0.06*sin(t*PI)+0.012*sin(angle*3.0),sin(angle)*r))
	_strand(rim,0.012,OLD_SILK.lightened(0.15))
	# A sheltered, uneven clutch rather than a decorative ring of identical eggs.
	for i in 5:
		var egg_at := center+Vector3(-radius*0.57+_rng.randf_range(-0.18,0.16),0.25+float(i%2)*0.10,radius*0.38+_rng.randf_range(-0.18,0.14))
		var size := _rng.randf_range(0.85,1.18)
		_ellipsoid(egg_at,Vector3(0.12,0.17,0.11)*size,Basis(Vector3.FORWARD,_rng.randf_range(-0.2,0.2)),Color(0.74,0.75,0.71))
	for i in 12:
		var angle := float(i)/12.0*TAU
		var start := center+Vector3(cos(angle)*radius*0.4,0.23,sin(angle)*radius*0.4)
		var end := center+Vector3(cos(angle)*radius*1.6,0.01,sin(angle)*radius*1.6)
		_strand([start,start.lerp(end,0.45)+Vector3.UP*0.03,end],0.011,OLD_SILK)

func _funnel(center: Vector3, radius: float) -> void:
	var first := _bodies.points.size()
	const STEPS := 24
	for ring in 6:
		var t := float(ring)/5.0
		for side in range(STEPS+1):
			var angle := TAU*float(side)/STEPS
			var r := lerpf(radius*0.23,radius*1.08,t)*(1.0+0.09*sin(angle*3.0)+0.035*sin(angle*7.0))
			var point := center+Vector3(cos(angle)*r,0.07+0.13*sqrt(t)+0.018*t*sin(angle*3.0),sin(angle)*r)
			point += Vector3(-radius*0.10,0,radius*0.06)*(1.0-t)
			var normal := Vector3(-cos(angle)*0.15,1,-sin(angle)*0.15).normalized()
			_bodies.vertex(point,normal,Color(0.35,0.37,0.33),Vector2(cos(angle)*t*0.5+0.5,sin(angle)*t*0.5+0.5))
			if ring == 0 or side == 0: continue
			var d := first+ring*(STEPS+1)+side
			_bodies.triangle(d-STEPS-2,d-STEPS-1,d-1)
			_bodies.triangle(d-STEPS-1,d,d-1)
