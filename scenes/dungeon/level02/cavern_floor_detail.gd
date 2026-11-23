@tool
extends "res://scenes/dungeon/level02/cavern_geometry.gd"
## Sparse static ground ecology. The shared floor still owns all physics.
var _dimensions := Vector2.ZERO
var _origin := Vector3.ZERO
var _openings := Vector4.ZERO
var _room := false
var _protected := PackedVector3Array()
var _columns := 0
var _rows := 0
var _crack_cells := {}
var _pools: Array[Dictionary] = []
var _label := ""
static var _wash_material: StandardMaterial3D
static var _water_material: StandardMaterial3D
static var _ground_silk_material: StandardMaterial3D

func configure(label: String, dimensions: Vector2, origin: Vector3, openings: Vector4, room: bool, protected: PackedVector3Array) -> void:
	_begin(label+"GroundEcology")
	_label = label
	_dimensions = dimensions
	_origin = origin
	_openings = openings
	_room = room
	_protected = protected
	_columns = ceili(dimensions.x/0.7)
	_rows = ceili(dimensions.y/0.7)
	# A few shallow basins, never a wet carpet over the combat floor.
	var count := 2 if label in ["Boss","Archive","Vault"] else (1 if room or dimensions.length() > 13.0 else 0)
	for i in count:
		var radius := Vector2(_rng.randf_range(0.42,0.75),_rng.randf_range(0.50,0.95)) if room else Vector2(0.18,0.46)
		if not room and dimensions.x > dimensions.y: radius = Vector2(radius.y,radius.x)
		var at := _pick(maxf(radius.x,radius.y)+0.12,3.0) if room else _pick_ellipse(radius,3.0)
		if not at.is_finite(): continue
		var level := _base_height(at)
		for side in 12:
			var angle := TAU*side/12.0
			level = minf(level,_base_height(at+Vector2(cos(angle),sin(angle))*radius))
		_pools.append({"at":at,"radius":radius,"level":level-0.005,"phase":_rng.randf()*TAU})
	# Fractures replace complete floor cells with an incised strip, not a black decal.
	var attempts := 2 if room else 1
	for i in attempts:
		var at := _pick(0.48,2.6)
		if not at.is_finite(): continue
		var cell := Vector2i(clampi(floori((at.x/dimensions.x+0.5)*_columns),0,_columns-1),clampi(floori((at.y/dimensions.y+0.5)*_rows),0,_rows-1))
		var horizontal := dimensions.x > dimensions.y if not room else _rng.randf() < 0.5
		var span := _rng.randi_range(2,3)
		var cells: Array[Vector2i] = []
		for part in span:
			var next := cell+(Vector2i(part,0) if horizontal else Vector2i(0,part))
			if next.x >= _columns or next.y >= _rows or _crack_cells.has(next): break
			var center := Vector2((next.x+0.5)/_columns*dimensions.x-dimensions.x*0.5,(next.y+0.5)/_rows*dimensions.y-dimensions.y*0.5)
			if not _allowed(center,0.48) or _in_water(center,0.6): break
			cells.append(next)
		if cells.is_empty(): continue
		var phase := _rng.randf()*TAU
		var width := 0.0
		for part in cells.size():
			var width_sample := _rng.randf_range(0.014,0.030)
			if part == 0: width = width_sample
			_crack_cells[cells[part]] = {"horizontal":horizontal,"part":part,"span":cells.size(),"phase":phase,"width":width}

func cache_signature() -> Array:
	return [_label,_dimensions,_origin,_openings,_room,_protected,_pools,_crack_cells]

func _allowed(at: Vector2, margin: float) -> bool:
	var half := _dimensions*0.5
	if absf(at.x)+margin > half.x-0.10 or absf(at.y)+margin > half.y-0.10: return false
	if _room:
		if absf(at.x)-margin < half.x*0.63 and absf(at.y)-margin < half.y*0.63: return false
	else:
		if maxf(_dimensions.x,_dimensions.y) <= 5.1:
			if absf(at.x)-margin < 1.82 and absf(at.y)-margin < 1.82: return false
		elif absf(at.x if _dimensions.y >= _dimensions.x else at.y)-margin < 1.82: return false
	# Reserve full door approaches and the painted routes, including junctions.
	if at.y < (0.0 if _room else -half.y+1.3+margin) and _openings.x > 0 and absf(at.x) < _openings.x+margin+0.25: return false
	if at.y > (0.0 if _room else half.y-1.3-margin) and _openings.y > 0 and absf(at.x) < _openings.y+margin+0.25: return false
	if at.x < (0.0 if _room else -half.x+1.3+margin) and _openings.z > 0 and absf(at.y) < _openings.z+margin+0.25: return false
	if at.x > (0.0 if _room else half.x-1.3-margin) and _openings.w > 0 and absf(at.y) < _openings.w+margin+0.25: return false
	for zone in _protected:
		if at.distance_to(Vector2(zone.x,zone.y)) < zone.z+margin: return false
	return true

func _in_water(at: Vector2, margin: float) -> bool:
	for pool in _pools:
		var delta: Vector2 = (at-pool.at)/(pool.radius+Vector2.ONE*margin)
		if delta.length_squared() < 1.0: return true
	return false

func _edge(at: Vector2) -> float:
	var half := _dimensions*0.5
	return minf(half.x-absf(at.x),half.y-absf(at.y))

func _pick(margin: float, edge_limit: float, edge_minimum: float = 0.0) -> Vector2:
	var half := _dimensions*0.5
	for i in 80:
		var at := Vector2(_rng.randf_range(-half.x,half.x),_rng.randf_range(-half.y,half.y))
		if _edge(at) >= edge_minimum and _edge(at) <= edge_limit and _allowed(at,margin): return at
	return Vector2.INF

func _pick_ellipse(radius: Vector2, edge_limit: float) -> Vector2:
	# Use separate across/along clearances for the narrow corridor strip.
	var half := _dimensions*0.5
	for i in 100:
		var at := Vector2(_rng.randf_range(-half.x,half.x),_rng.randf_range(-half.y,half.y))
		if _edge(at) > edge_limit: continue
		var valid := true
		for j in 12:
			var p := at+Vector2(cos(TAU*j/12.0),sin(TAU*j/12.0))*radius
			valid = valid and _allowed(p,0.04)
		if valid: return at
	return Vector2.INF

func _base_height(at: Vector2) -> float:
	var half := _dimensions*0.5
	if absf(at.x) >= half.x-0.001 or absf(at.y) >= half.y-0.001: return -0.008
	return -0.008-absf(_noise.get_noise_2d(at.x+_origin.x,at.y+_origin.z))*0.055

func depression(at: Vector2) -> float:
	var depth := 0.0
	for pool in _pools:
		var delta: Vector2 = (at-pool.at)/pool.radius
		if delta.length_squared() < 1.0: depth = minf(depth,-0.075*pow(1.0-delta.length_squared(),2.0))
	return depth

func _height(at: Vector2) -> float:
	var normalized := (at/_dimensions+Vector2.ONE*0.5)*Vector2(_columns,_rows)
	var cell := Vector2i(clampi(floori(normalized.x),0,_columns-1),clampi(floori(normalized.y),0,_rows-1))
	var tx := clampf(normalized.x-cell.x,0.0,1.0)
	var tz := clampf(normalized.y-cell.y,0.0,1.0)
	var heights: Array[float] = []
	for offset: Vector2i in [Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1),Vector2i.ONE]:
		var p := Vector2(float(cell.x+offset.x)/_columns*_dimensions.x,float(cell.y+offset.y)/_rows*_dimensions.y)-_dimensions*0.5
		heights.append(_base_height(p))
	if tx+tz <= 1.0: return heights[0]+(heights[1]-heights[0])*tx+(heights[2]-heights[0])*tz+depression(at)
	return heights[3]+(heights[2]-heights[3])*(1.0-tx)+(heights[1]-heights[3])*(1.0-tz)+depression(at)

func has_basin(cell: Vector2i) -> bool:
	var size := _dimensions/Vector2(_columns,_rows)
	var center := (Vector2(cell)+Vector2.ONE*0.5)*size-_dimensions*0.5
	for pool in _pools:
		var delta: Vector2 = (center-pool.at).abs()
		if delta.x < pool.radius.x+size.x*0.5 and delta.y < pool.radius.y+size.y*0.5: return true
	return false

func _weights(x: float, z: float) -> Vector4:
	if x+z <= 1.0: return Vector4(1.0-x-z,x,z,0.0)
	return Vector4(0.0,1.0-z,1.0-x,x+z-1.0)

func _interpolate_shade(colors: Array, weights: Vector4) -> Color:
	return colors[0]*weights.x+colors[1]*weights.y+colors[2]*weights.z+colors[3]*weights.w

func _interpolate_ambient(values: Array, weights: Vector4) -> float:
	return values[0]*weights.x+values[1]*weights.y+values[2]*weights.z+values[3]*weights.w

func append_basin(surface: Surface, a: Vector3, b: Vector3, c: Vector3, d: Vector3, colors: Array, ambient: Array) -> void:
	var grid: Array[Vector3] = []
	var tints: Array[Color] = []
	var occlusion: Array[float] = []
	const STEPS := 3
	for z in range(STEPS+1):
		for x in range(STEPS+1):
			var p := a.lerp(b,float(x)/STEPS).lerp(c.lerp(d,float(x)/STEPS),float(z)/STEPS)
			p.y = _height(Vector2(p.x,p.z))
			grid.append(p)
			var weights := _weights(float(x)/STEPS,float(z)/STEPS)
			tints.append(_interpolate_shade(colors,weights))
			occlusion.append(_interpolate_ambient(ambient,weights))
	for z in STEPS:
		for x in STEPS:
			var index := z*(STEPS+1)+x
			var start := surface.points.size()
			surface.quad(grid[index],grid[index+STEPS+1],grid[index+1],grid[index+STEPS+2],Color.WHITE)
			var order := [index,index+1,index+STEPS+1,index+STEPS+1,index+1,index+STEPS+2]
			for j in 6:
				surface.colors[start+j] = tints[order[j]]
				surface.ambient_uv[start+j].x = occlusion[order[j]]

func has_crack(cell: Vector2i) -> bool:
	return _crack_cells.has(cell)

func append_crack(surface: Surface, cell: Vector2i, a: Vector3, b: Vector3, c: Vector3, d: Vector3, colors: Array, ambient: Array) -> void:
	var plan: Dictionary = _crack_cells[cell]
	var vertices: Array[Vector3] = []
	var shades: Array[Color] = []
	var occlusion: Array[float] = []
	const STEPS := 4
	for step in range(STEPS+1):
		var t := float(step)/STEPS
		var progress: float = (plan.part+t)/plan.span
		var across := 0.5+sin(progress*4.8+plan.phase)*0.14+sin(progress*11.0+plan.phase)*0.05
		var width: float = plan.width/(c.z-a.z if plan.horizontal else b.x-a.x)
		var depth := 0.038*smoothstep(0.0,0.14,progress)*(1.0-smoothstep(0.82,1.0,progress))
		for fraction: float in [0.0,across-width,across,across+width,1.0]:
			var p := a.lerp(b,t).lerp(c.lerp(d,t),fraction) if plan.horizontal else a.lerp(c,t).lerp(b.lerp(d,t),fraction)
			# Exact barycentric height matches adjacent untouched floor cells.
			p.y = _height(Vector2(p.x,p.z))
			var core := absf(fraction-across) < width*0.5
			if core: p.y -= depth
			vertices.append(p)
			var weights := _weights(t if plan.horizontal else fraction,fraction if plan.horizontal else t)
			var tint := _interpolate_shade(colors,weights)
			shades.append(tint.darkened(depth/0.038*0.65) if core else tint)
			occlusion.append(_interpolate_ambient(ambient,weights)*(1.0-depth/0.038*0.28 if core else 1.0))
	for step in STEPS:
		for i in 4:
			var start := surface.points.size()
			var first := step*5+i
			var order: Array[int]
			if plan.horizontal:
				surface.quad(vertices[first],vertices[first+1],vertices[first+5],vertices[first+6],Color.WHITE)
				order = [first,first+5,first+1,first+1,first+5,first+6]
			else:
				surface.quad(vertices[first],vertices[first+5],vertices[first+1],vertices[first+6],Color.WHITE)
				order = [first,first+1,first+5,first+5,first+1,first+6]
			for j in 6:
				surface.colors[start+j] = shades[order[j]]
				surface.ambient_uv[start+j].x = occlusion[order[j]]

func build() -> Node3D:
	var root := _root("CavernGroundDetail","ground_detail")
	var rubble := Surface.new()
	var washes := Surface.new()
	var water := Surface.new()
	var silk := Surface.new()
	var pieces := 0
	var larger := 0
	var previews := {}
	var cluster := Vector2.INF
	var perimeter := (_dimensions.x+_dimensions.y)*2.0
	var count := clampi(roundi(perimeter*(0.27 if _room else 0.18)),5,28)
	for i in count:
		var radius := _rng.randf_range(0.065,0.19)
		if _room and (i%4 == 0 or not cluster.is_finite()): cluster = _pick(0.68,2.1,0.85)
		var at := cluster+Vector2(_rng.randf_range(-0.42,0.42),_rng.randf_range(-0.42,0.42)) if _room else Vector2.INF
		if not at.is_finite() or not _allowed(at,radius*1.45+0.08): at = _pick(radius*1.45+0.08,2.1 if _room else 0.64,0.55 if _room else 0.0)
		if not at.is_finite() or _in_water(at,radius+0.07): continue
		var size := Vector3(radius*_rng.randf_range(0.8,1.35),radius*_rng.randf_range(0.40,1.15),radius*_rng.randf_range(0.65,1.2))
		_pebble(rubble,at,size,6)
		_patch(washes,at,Vector2(size.x,size.z)*1.2,Color(0.075,0.085,0.080,0.30),0.002,5)
		pieces += 1
	if _room:
		for i in clampi(int(perimeter/21.0),2,4):
			var radius := _rng.randf_range(0.30,0.52)
			var at := _pick(radius*1.4+0.12,1.95,0.95)
			if not at.is_finite() or _in_water(at,radius+0.15): continue
			_pebble(rubble,at,Vector3(radius,_rng.randf_range(0.22,0.48),radius*_rng.randf_range(0.65,1.1)),8)
			if not previews.has("rubble"): previews["rubble"] = Vector3(at.x,_height(at),at.y)
			_patch(washes,at,Vector2.ONE*radius*1.25,Color(0.075,0.085,0.080,0.35),0.002,7)
			pieces += 1
			larger += 1
	# Broad dusty fans and short damp soil smears settle between the stones.
	for i in (6 if _room else 2):
		var radius := Vector2(_rng.randf_range(0.28,0.60),_rng.randf_range(0.35,0.75))
		var at := _pick(maxf(radius.x,radius.y)*1.05+0.1,3.0)
		if not at.is_finite() or _in_water(at,0.3): continue
		var dust := i%3 != 0
		_patch(washes,at,radius,Color(0.49,0.465,0.405,0.26) if dust else Color(0.20,0.175,0.14,0.40),0.003)
	for pool in _pools:
		_patch(washes,pool.at,pool.radius*1.08,Color(0.18,0.19,0.165,0.28),0.004)
		_water_patch(water,pool)
		if not previews.has("water") or pool.at.x > previews.water.x: previews["water"] = Vector3(pool.at.x,pool.level,pool.at.y)
	if _room and _label not in ["Arrival","Exit"]:
		for i in (2 if _label in ["Boss","Archive","Vault"] else 1):
			var at := _pick(0.65,2.3)
			if at.is_finite() and not _in_water(at,0.7): _silk_patch(silk,at)
	_materials()
	_commit(root,rubble,_rock,"SettledStoneFragments")
	_commit(root,washes,_wash_material,"DustSoilAndContactShade")
	_commit(root,water,_water_material,"ShallowWater")
	_commit(root,silk,_ground_silk_material,"GroundSilk")
	for mesh: MeshInstance3D in root.get_children():
		if mesh.name != "SettledStoneFragments": mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh.name == "ShallowWater": mesh.layers = 1<<19
	if _room and not _pools.is_empty():
		# Capture static rock once; only the puddle layer receives this subtle reflection.
		var probe := ReflectionProbe.new()
		probe.name = "StillWaterReflection"
		probe.position = Vector3(0,2.0,0)
		probe.origin_offset = Vector3(0,-1.2,0)
		probe.size = Vector3(_dimensions.x,7.0,_dimensions.y)
		probe.max_distance = maxf(_dimensions.x,_dimensions.y)*1.5
		probe.box_projection = true
		probe.interior = true
		probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		probe.intensity = 0.70
		probe.cull_mask = 1<<18
		probe.reflection_mask = 1<<19
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		root.add_child(probe)
	root.set_meta("fragment_count",pieces)
	root.set_meta("large_fragment_count",larger)
	root.set_meta("puddle_count",_pools.size())
	root.set_meta("crack_cells",_crack_cells.size())
	root.set_meta("ground_preview_points",previews)
	return root

func _materials() -> void:
	if _wash_material != null: return
	_wash_material = StandardMaterial3D.new()
	_wash_material.resource_name = "Settled dust, damp soil and contact shade"
	_wash_material.vertex_color_use_as_albedo = true
	_wash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wash_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_wash_material.roughness = 1.0
	_wash_material.metallic_specular = 0.08
	_water_material = StandardMaterial3D.new()
	_water_material.resource_name = "Still shallow cave water"
	_water_material.vertex_color_use_as_albedo = true
	_water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_water_material.roughness = 0.22
	_water_material.metallic_specular = 0.46
	var ripple_noise := FastNoiseLite.new()
	ripple_noise.seed = 1863
	ripple_noise.frequency = 0.035
	var ripple: Texture2D = Cache.texture("cave","ground_ripple")
	if ripple == null: ripple = _make_ripple(ripple_noise)
	_water_material.normal_enabled = true
	_water_material.normal_texture = ripple
	_water_material.normal_scale = 0.08
	_water_material.uv1_triplanar = true
	_water_material.uv1_world_triplanar = true
	_water_material.uv1_scale = Vector3.ONE*0.8
	_ground_silk_material = _wash_material.duplicate()
	_ground_silk_material.resource_name = "Dusty low ground silk"
	_ground_silk_material.roughness = 0.97

func _pebble(surface: Surface, at: Vector2, size: Vector3, sides: int) -> void:
	var center := Vector3(at.x,_height(at)-0.012,at.y)
	var angle := _rng.randf()*TAU
	var pose := Basis(Vector3.UP,angle)
	var rings: Array[Vector3] = []
	var tint := Color(1.26,1.20,1.09).lerp(Color(0.76,0.84,0.80),_rng.randf()*0.55)
	for ring in 3:
		for side in sides:
			var theta := TAU*side/sides
			var radius := _rng.randf_range(0.72,1.08)*(0.65 if ring == 2 else 1.0)
			var y: float = [-0.025,0.38,0.84][ring]*size.y
			if ring == 2: y *= _rng.randf_range(0.65,1.15)
			rings.append(center+pose*Vector3(cos(theta)*size.x*radius,y,sin(theta)*size.z*radius))
	var start := surface.points.size()
	for side in sides:
		var next := (side+1)%sides
		for ring in 2: surface.quad(rings[(ring+1)*sides+side],rings[(ring+1)*sides+next],rings[ring*sides+side],rings[ring*sides+next],tint)
		surface.triangle(rings[sides*2+side],center+Vector3.UP*size.y*0.90,rings[sides*2+next],tint.lightened(0.04))
		surface.triangle(rings[side],rings[next],center-Vector3.UP*0.025*size.y,tint.darkened(0.18))
	for i in range(start,surface.points.size()): surface.ambient_uv[i].x = lerpf(0.54,0.995,sqrt(clampf((surface.points[i].y-center.y)/size.y,0.0,1.0)))

func _patch(surface: Surface, at: Vector2, radius: Vector2, color: Color, lift: float, sides: int = 10) -> void:
	var inner: Array[Vector3] = []
	var outer: Array[Vector3] = []
	for i in sides:
		var angle := TAU*i/sides
		var direction := Vector2(cos(angle),sin(angle))*radius*_rng.randf_range(0.85,1.0)
		var p := at+direction
		outer.append(Vector3(p.x,_height(p)+lift,p.y))
		p = at+direction*0.55
		inner.append(Vector3(p.x,_height(p)+lift,p.y))
	var center := Vector3(at.x,_height(at)+lift,at.y)
	var fade := color
	fade.a = 0.0
	for i in sides:
		var next := (i+1)%sides
		surface.triangle(inner[i],center,inner[next],color)
		var start := surface.points.size()
		surface.quad(inner[i],inner[next],outer[i],outer[next],color)
		for j in [1,4,5]: surface.colors[start+j] = fade

func _water_patch(surface: Surface, pool: Dictionary) -> void:
	var ring: Array[Vector3] = []
	var inner: Array[Vector3] = []
	for i in 19:
		var angle := TAU*i/19.0
		var ragged := 0.88+sin(angle*3.0+pool.phase)*0.045+sin(angle*7.0)*0.025
		var p: Vector2 = pool.at+Vector2(cos(angle),sin(angle))*pool.radius*ragged
		ring.append(Vector3(p.x,pool.level,p.y))
		p = pool.at+(p-pool.at)*0.72
		inner.append(Vector3(p.x,pool.level,p.y))
	var center := Vector3(pool.at.x,pool.level,pool.at.y)
	for i in ring.size():
		var next := (i+1)%ring.size()
		var tint := Color(0.19,0.22,0.205,0.46)
		surface.triangle(inner[i],center,inner[next],tint)
		var start := surface.points.size()
		surface.quad(inner[i],inner[next],ring[i],ring[next],tint)
		for j in [1,4,5]: surface.colors[start+j].a = 0.0

func _silk_patch(surface: Surface, at: Vector2) -> void:
	var reach := _rng.randf_range(0.30,0.56)
	for strand in 5:
		var angle := _rng.randf()*TAU
		var direction := Vector2(cos(angle),sin(angle))
		var side := Vector2(-direction.y,direction.x)*0.0040
		for segment in 4:
			var p := at+direction*(float(segment)/4.0*reach)
			var q := at+direction*(float(segment+1)/4.0*reach)+side*_rng.randf_range(-7.0,7.0)
			var height := _height(p)+0.015
			var next_height := _height(q)+0.015
			surface.quad(Vector3(p.x-side.x,height,p.y-side.y),Vector3(p.x+side.x,height,p.y+side.y),Vector3(q.x-side.x,next_height,q.y-side.y),Vector3(q.x+side.x,next_height,q.y+side.y),Color(0.38,0.38,0.33,0.40))

func _make_ripple(ripple_noise: FastNoiseLite) -> NoiseTexture2D:
	var ripple := NoiseTexture2D.new()
	ripple.width = 256
	ripple.height = 256
	ripple.noise = ripple_noise
	ripple.seamless = true
	ripple.as_normal_map = true
	ripple.bump_strength = 0.15
	ripple.generate_mipmaps = true
	return ripple
