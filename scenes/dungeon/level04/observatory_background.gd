extends RefCounted
## Background-only finishing pass. Creates resources, never scene geometry.
const PLAN := preload("res://scenes/dungeon/level04/observatory_plan.gd")
const FLOOR := preload("res://scenes/dungeon/level04/observatory_background_floor.gdshader")
const DISTANCE := preload("res://scenes/dungeon/level04/observatory_distance.gdshader")
const BRIDGE := preload("res://scenes/dungeon/level04/observatory_background_bridge.gdshader")
const ABYSS := preload("res://scenes/dungeon/level04/observatory_abyss.gdshader")
const IDS := ["A","B","C","D","E","F","G","H","I","J","K","L"]
# Stone, aged brass, ambient colour, energy, paving size.
const THEMES := [
	["697579","8c7853","a3b7c6",0.68,Vector2(1.7,1.2)],
	["616b70","8c704d","b0b6bd",0.65,Vector2(2.4,1.65)],
	["626e75","9a8050","9eafc2",0.67,Vector2(1.45,1.15)],
	["53656d","7b6c50","88a7bd",0.67,Vector2(2.0,0.95)],
	["697273","918365","b1bfc8",0.72,Vector2(1.20,2.20)],
	["536b77","8b7a54","8db4cd",0.70,Vector2(1.65,1.25)],
	["606d71","89734e","9dabbc",0.65,Vector2(1.2,2.6)],
	["646b74","8e7952","9aaec3",0.70,Vector2(2.3,1.0)],
	["646c77","a58b5c","a4b8d1",0.73,Vector2(1.75,1.3)],
	["5d6a70","9b8053","a6b8c5",0.68,Vector2(1.8,1.1)],
	["5f707f","88795e","8facca",0.70,Vector2(1.45,1.45)],
	["595b70","7b685c","9a9bb8",0.65,Vector2(1.15,1.7)],
]

var _walls: Array[StandardMaterial3D] = []
var _brass: StandardMaterial3D
var _environment: Environment
var _ambient := Color("a3b7c6")
var _energy := 0.68
var _applied := false

func apply(level: Node3D) -> void:
	if _applied: return
	_applied = true
	for theme in IDS.size(): _walls.append(_wall_material(theme))
	_brass = _brass_material()
	for index in IDS.size():
		var room: Node3D = level.layout.get_node(IDS[index])
		var floor_view := _deck_surface(room.get_node("Deck"))
		if floor_view != null:
			var material := ShaderMaterial.new()
			material.shader = FLOOR
			material.set_shader_parameter("room_theme",index)
			material.set_shader_parameter("room_center",PLAN.CENTERS[IDS[index]])
			material.set_shader_parameter("room_extent",PLAN.bounds(IDS[index]).size*0.5)
			material.set_shader_parameter("stone_tint",Color(THEMES[index][0]))
			material.set_shader_parameter("accent_tint",Color(THEMES[index][1]))
			material.set_shader_parameter("slab_size",THEMES[index][4])
			floor_view.material_override = material
		_boundaries(room,index)
		# Retain the target's existing well cover. Shade its surface without a
		# hole, transparency, displacement, shaft model or altered collision.
		if IDS[index] == "D": _existing_depth_surfaces(room,2.0)
	for link: String in PLAN.LINKS:
		var bridge: Node3D = level.layout.get_node(link)
		_boundaries(bridge,IDS.find(link[0]))
		var floor_view := _deck_surface(bridge.get_node("Deck"))
		if floor_view == null: continue
		var path := PLAN.bridge_path(link[0],link[1])
		var segments := PackedVector4Array()
		var starts := PackedFloat32Array()
		var length := 0.0
		for index in range(path.size()-1):
			segments.append(Vector4(path[index].x,path[index].y,path[index+1].x,path[index+1].y))
			starts.append(length)
			length += path[index].distance_to(path[index+1])
		while segments.size() < 8:
			segments.append(Vector4.ZERO)
			starts.append(0.0)
		var material := ShaderMaterial.new()
		material.shader = BRIDGE
		material.set_shader_parameter("segment_count",path.size()-1)
		material.set_shader_parameter("segments",segments)
		material.set_shader_parameter("segment_starts",starts)
		floor_view.material_override = material
	# The existing courtyard floor beneath the cross bridge gains depth tint;
	# the original dial, route signals, labels and all other props are untouched.
	_existing_depth_surfaces(level.layout,8.0)
	var environment_node: WorldEnvironment = level.get_node("WorldEnvironment")
	_environment = environment_node.environment.duplicate() as Environment
	environment_node.environment = _environment
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = DISTANCE
	sky.sky_material = sky_material
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = _ambient
	_environment.ambient_light_energy = _energy
	var sun: DirectionalLight3D = level.get_node("Sun")
	sun.light_color = Color("e4d2b3")
	sun.light_energy = 0.94

func update(position: Vector3, delta: float) -> void:
	if _environment == null: return
	var tint := Color(0,0,0,1)
	var energy := 0.0
	var weights := 0.0
	for index in IDS.size():
		var distance := Vector2(position.x,position.z).distance_to(PLAN.CENTERS[IDS[index]])
		var weight := exp(-distance*distance/155.0)
		tint += Color(THEMES[index][2])*weight
		energy += float(THEMES[index][3])*weight
		weights += weight
	if weights < 0.0001: return
	tint /= weights
	tint.a = 1
	var blend := 1.0-exp(-2.4*delta)
	_ambient = _ambient.lerp(tint,blend)
	_energy = lerpf(_energy,energy/weights,blend)
	_environment.ambient_light_color = _ambient
	_environment.ambient_light_energy = _energy

func _deck_surface(deck: Node3D) -> MeshInstance3D:
	# A bent corridor has several CollisionShape3D children preceding its mesh.
	for child in deck.get_children():
		if child is MeshInstance3D: return child
	return null

func _boundaries(parent: Node3D, theme: int) -> void:
	for body in parent.get_children():
		if not body is StaticBody3D or not body.has_node("Surface"): continue
		var collision := body.get_child(0) as CollisionShape3D
		if collision == null or not collision.shape is BoxShape3D: continue
		var size: Vector3 = collision.shape.size
		if not is_equal_approx(size.x,0.30) or not is_equal_approx(size.y,1.5): continue
		for mesh in body.get_children():
			if mesh is MeshInstance3D:
				mesh.material_override = _walls[theme] if mesh.name == "Surface" else _brass

func _existing_depth_surfaces(parent: Node3D, minimum_radius: float) -> void:
	for body in parent.get_children():
		if not body is Node3D or body is StaticBody3D: continue
		for view in body.get_children():
			if not view is MeshInstance3D or not view.mesh is CylinderMesh: continue
			if view.mesh.top_radius < minimum_radius: continue
			var material := ShaderMaterial.new()
			material.shader = ABYSS
			view.material_override = material

func _brass_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("87704a")
	material.metallic = 0.66
	material.roughness = 0.68
	var noise := FastNoiseLite.new()
	noise.seed = 408
	noise.frequency = 0.11
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0,Color("474f48"))
	ramp.set_color(1,Color("b6a382"))
	texture.color_ramp = ramp
	material.albedo_texture = texture
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3(0.7,0.7,0.7)
	return material

func _wall_material(theme: int) -> StandardMaterial3D:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="256"><defs><linearGradient id="s" x2="0" y2="1"><stop stop-color="#647079"/><stop offset=".46" stop-color="#4d5961"/><stop offset="1" stop-color="#303e47"/></linearGradient><linearGradient id="b"><stop stop-color="#4c5348"/><stop offset=".5" stop-color="#ac9260"/><stop offset="1" stop-color="#68624b"/></linearGradient></defs><rect width="512" height="256" fill="url(#s)"/>'
	# Mortar, chipped joints and mineral runs are rasterised once into a tiled
	# surface map. StandardMaterial keeps the existing camera fade compatible.
	for row in 5:
		var offset := -64 if row%2 else 0
		for col in 5:
			var x := offset+col*128
			var y := row*51
			var gray := 70+(row*13+col*19+theme*7)%24
			svg += '<rect x="%d" y="%d" width="125" height="48" fill="#%02x%02x%02x" fill-opacity=".36" stroke="#1c2a33" stroke-width="2"/><path d="M%d %d h121" stroke="#9aa7a8" stroke-opacity=".16"/>' % [x,y,gray,gray+10,gray+15,x+2,y+3]
	for n in 160:
		var x := (n*137+theme*29)%512
		var y := (n*73+theme*17)%256
		svg += '<rect x="%d" y="%d" width="%d" height="%d" fill="%s" opacity=".10"/>' % [x,y,1+n%8,1+n%3,"#d4d3bd" if n%3 else "#10222c"]
	for n in 5:
		var x := 27+n*103+(theme*11)%31
		svg += '<path d="M%d 0 l-8 25 13 12 -9 30 3 19" fill="none" stroke="#192830" stroke-opacity=".6" stroke-width="1.4"/>' % x
	var motif := ''
	match theme:
		0: motif = '<path d="M36 207 V114 Q64 48 92 114 V207 M164 207 V114 Q192 48 220 114 V207 M292 207 V114 Q320 48 348 114 V207 M420 207 V114 Q448 48 476 114 V207"/>'
		1: motif = '<path d="M20 60 H492 V214 H20 Z M26 68 H486 M26 205 H486 M88 64 V211 M424 64 V211"/>'
		2: motif = '<path d="M32 210 Q128 38 224 210 M288 210 Q384 38 480 210 M128 119 V210 M60 165 L128 210 196 165 M384 119 V210 M316 165 L384 210 452 165"/>'
		3: motif = '<path d="M28 24 V232 M53 24 V232 M230 24 V232 M282 24 V232 M459 24 V232 M484 24 V232"/>'
		4: motif = '<path d="M32 65 H480 M32 211 H480 M64 65 V211 M128 65 V211 M192 65 V211 M256 65 V211 M320 65 V211 M384 65 V211 M448 65 V211"/>'
		5: motif = '<path d="M0 210 L128 65 256 210 384 65 512 210 M0 65 L128 210 256 65 384 210 512 65"/>'
		6: motif = '<path d="M0 92 H512 M0 112 H512 M0 180 H512 M0 199 H512 M48 92 V199 M176 92 V199 M304 92 V199 M432 92 V199"/>'
		7: motif = '<path d="M20 70 H492 M20 95 H492 M20 120 H492 M20 145 H492 M20 170 H492 M20 195 H492 M20 220 H492"/>'
		8: motif = '<path d="M32 210 Q128 34 224 210 M288 210 Q384 34 480 210 M128 111 L64 210 M128 111 L192 210 M384 111 L320 210 M384 111 L448 210"/>'
		9: motif = '<path d="M32 68 H224 V215 H32 Z M288 68 H480 V215 H288 Z M48 84 H208 V199 H48 Z M304 84 H464 V199 H304 Z"/>'
		10: motif = '<path d="M0 142 L64 72 128 142 192 72 256 142 320 72 384 142 448 72 512 142 M0 142 L64 212 128 142 192 212 256 142 320 212 384 142 448 212 512 142"/>'
		11: motif = '<path d="M32 64 H480 M32 211 H480 M64 64 V211 M192 64 V211 M320 64 V211 M448 64 V211"/>'
	svg += '<g fill="none" stroke="#1c2a31" stroke-width="7" opacity=".50">'+motif+'</g><g fill="none" stroke="#918365" stroke-width="1.7" opacity=".44">'+motif+'</g>'
	svg += '<rect y="23" width="512" height="9" fill="url(#b)" opacity=".65"/><rect y="230" width="512" height="6" fill="url(#b)" opacity=".5"/>'
	# A few blue mineral seams and a dim gold soffit are baked into the wall;
	# there are no added lamps, signs, props, meshes or collision shapes.
	svg += '<path d="M0 34 H512" stroke="#78a9bc" stroke-opacity=".23" stroke-width="1"/><path d="M0 0 H512" stroke="#b6a37f" stroke-opacity=".30" stroke-width="8"/></svg>'
	var image := Image.new()
	image.load_svg_from_string(svg)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	var normal := image.duplicate() as Image
	normal.clear_mipmaps()
	normal.bump_map_to_normal_map(0.65)
	normal.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(THEMES[theme][0]).lightened(0.33)
	material.albedo_texture = texture
	material.normal_enabled = true
	material.normal_scale = 0.40
	material.normal_texture = ImageTexture.create_from_image(normal)
	material.roughness = 0.90
	material.metallic = 0.09
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3(0.27,0.68,0.27)
	return material
