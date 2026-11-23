extends "res://scenes/dungeon/level03/tide_layout.gd"
## Egyptian funerary skin over the unchanged hydraulic map and collider builder.
const Cache = preload("res://scripts/rendering/static_art_cache.gd")
const Art = preload("res://scenes/dungeon/level03/tomb_geometry.gd")
const MummySkin = preload("res://scenes/dungeon/level03/tomb_mummy_skin.gd")
var _art := Art.new()
var _building := false
var _burials := {}
var _wall_count := 0
var _torch_count := 0

func build(rooms: Node3D) -> void:
	_art.begin("EgyptianHypogeum")
	_wire_off = Color(0.24,0.20,0.12)
	_building = true
	super.build(rooms)
	_building = false
	for id in ROOMS:
		var rect: Rect2 = ROOMS[id]
		_dust(rect,String(id))
		if id in [&"H",&"I"]: _sand_sink(rect,String(id))
	set_meta("tomb_environment",true)

func box(parent: Node3D, location: Vector3, size: Vector3, color: Color, solid := false) -> Node3D:
	var body := super.box(parent,location,size,color,solid)
	if not _building or parent != self: return body
	if solid and is_equal_approx(size.y,0.5) and location.y < 0.0:
		_hide_meshes(body)
		var rect := Rect2(Vector2(location.x-size.x*0.5,location.z-size.z*0.5),Vector2(size.x,size.z))
		var room := minf(size.x,size.z) > 6.0
		_mount(body,_art.floor_art("Pavement"+str(location),rect,room))
	elif solid and size.y < 1.1 and location.y > 0.0 and minf(size.x,size.z) > 0.5:
		_hide_meshes(body)
		var root := _art.root("BurialCover","cover")
		var surface := Art.Surface.new()
		_art.block(surface,location,size,Color(0.84,0.80,0.70),Basis.IDENTITY,0.12)
		_art.commit(root,surface,_art.stone,"BrokenSandstoneCover")
		_mount(body,root)
	elif not solid and size.x > 100.0: _hide_meshes(body)
	return body

func _build_edges(rect: Rect2, tiles: Array[Rect2]) -> void:
	var first := get_child_count()
	super._build_edges(rect,tiles)
	var room := minf(rect.size.x,rect.size.y) > 6.0
	var id := ""
	for key in ROOMS:
		if ROOMS[key] == rect: id = String(key)
	for i in range(first,get_child_count()):
		var body := get_child(i) as StaticBody3D
		if body == null: continue
		var size: Vector3 = body.get_child(0).shape.size
		var normal := Vector3(signf(body.position.x-rect.get_center().x),0,0) if size.x < size.z else Vector3(0,0,signf(body.position.z-rect.get_center().y))
		var length := maxf(size.x,size.z)
		var burial := id in ["C","G","H","J"] and normal.z < -0.5 and length > 4.1 and not _burials.has(id)
		if burial: _burials[id] = true
		_hide_meshes(body)
		body.add_to_group("camera_occluders")
		var wall := _art.wall(id+str(body.position),body.position,size,normal,room,burial)
		_mount(body,wall)
		_wall_count += 1
		if room and length > 4.0:
			var at := Vector3(body.position.x,0,body.position.z)
			var tangent := Vector3(-normal.z,0,normal.x)
			var foreground := normal.z > 0.5
			var height := 2.0 if foreground else (3.0 if id in ["C","D","I"] else 4.6)
			var column := _art.column(id+str(i),at+normal*0.60+tangent*(length*0.5-0.8),height,id in ["C","D","I"])
			wall.add_child(column)
			if not foreground and length > 5.1:
				_torch(wall,at-normal*0.42-tangent*minf(1.8,length*0.20)+Vector3.UP*2.25,_torch_count%2 == 0)

func _mount(parent: Node3D, art: Node3D) -> void:
	parent.add_child(art)
	art.transform = parent.transform.affine_inverse()

func _hide_meshes(node: Node) -> void:
	for mesh in node.find_children("*","MeshInstance3D",true,false): mesh.hide()

func label(parent: Node3D, content: String, point: Vector3, color: Color, flat := false) -> Label3D:
	var captions := {"A":"砂封前室","B":"祭仪潮井","C":"陪葬墓库","D":"折流铭文廊","E":"列柱守卫厅","F":"日轮蓄能殿","G":"王陵闸庭","H":"陪葬秘室","I":"沉沙泄压井","J":"陵墓出口"}
	if flat and captions.has(String(parent.name)) and content.begins_with(String(parent.name)+"  "):
		content = String(parent.name)+" · "+captions[String(parent.name)]
	content = content.replace("最终守卫 · 白盒占位","王陵墓门守卫")
	var marker := super.label(parent,content,point,Color(0.85,0.74,0.53),flat)
	marker.font_size = 38
	marker.pixel_size = 0.0065 if flat else 0.0055
	return marker

func _wire(parent: Node3D, points: Array, color: Color, _y: float, _width: float) -> void:
	super._wire(parent,points,color.darkened(0.16),0.027,0.075)

func _add_tidal_surface(id: StringName, rect: Rect2) -> void:
	super._add_tidal_surface(id,rect)
	for mesh in _water[id].find_children("*","MeshInstance3D",true,false):
		var material := StandardMaterial3D.new()
		material.resource_name = "Ancient dark hydraulic channel"
		material.albedo_color = Color(0.09,0.20,0.19,0.86)
		material.roughness = 0.24
		material.metallic_specular = 0.42
		if id == &"BC":
			# The sedimentation reservoir is flooded water, distinct from tomb sand.
			material.resource_name = "Sedimentation reservoir blue water"
			material.albedo_color = Color(0.10,0.53,0.76,1.0)
			material.roughness = 0.14
			material.metallic_specular = 0.65
			var ripples := FastNoiseLite.new()
			ripples.frequency = 0.055
			ripples.fractal_octaves = 2
			var normal: Texture2D = Cache.texture("tomb","reservoir_ripple")
			if normal == null: normal = _reservoir_normal(ripples)
			material.normal_enabled = true
			material.normal_texture = normal
			material.normal_scale = 0.25
			material.uv1_scale = Vector3(3.0,2.0,1.0)
		mesh.material_override = material
	if _float_decks.has(id):
		for mesh in _float_decks[id].find_children("*","MeshInstance3D",true,false): mesh.material_override = _art.stone

func finish_tomb(level: Node3D) -> void:
	for station: Node3D in level.get_node("Stations").get_children():
		var body: Node3D = station.get_node("Body")
		_hide_meshes(body)
		var altar := _art.root("SandstoneAltar","altar")
		var stonework := Art.Surface.new()
		var relief := Art.Surface.new()
		_art.block(stonework,Vector3(0,0.30,0),Vector3(1.25,0.60,0.9),Color(0.92,0.89,0.79),Basis.IDENTITY,0.10)
		_art.block(stonework,Vector3(0,0.70,0),Vector3(1.25,0.12,0.90),Color(1.0,0.97,0.85),Basis.IDENTITY,0.05)
		_art.glyph(relief,Vector3(0,0.40,0.46),Basis.IDENTITY,1 if station.name in ["tide","release"] else 0,0.43,Color(0.24,0.36,0.32))
		_art.commit(altar,stonework,_art.stone,"CarvedAltarBody")
		_art.commit(altar,relief,_art.pigment,"AltarInlay")
		station.add_child(altar)
	for barrier in level.get_node("Barriers").get_children():
		var view := barrier.get_node_or_null("View")
		if view == null: continue
		if barrier.name == &"BC":
			# Preserve the blue hydraulic grate instead of turning this waterway into a stone seal.
			var water_gate := StandardMaterial3D.new()
			water_gate.resource_name = "Blue sedimentation water gate"
			water_gate.albedo_color = Color(0.12,0.48,0.67,1.0)
			water_gate.roughness = 0.28
			for mesh in view.find_children("*","MeshInstance3D",true,false): mesh.material_override = water_gate
			barrier.add_to_group("camera_occluders")
			continue
		_hide_meshes(view)
		var slab := _art.root("SealedTombGate","seal")
		var surface := Art.Surface.new()
		var signs := Art.Surface.new()
		_art.block(surface,Vector3(0,1.4,0),Vector3(4.96,2.70,0.36),Color(0.76,0.80,0.72),Basis.IDENTITY,0.09)
		for i in 5: _art.glyph(signs,Vector3(-1.55+i*0.77,1.45,0.195),Basis.IDENTITY,i,0.55,Color(0.38,0.46,0.38))
		_art.commit(slab,surface,_art.stone,"MassiveSeal")
		_art.commit(slab,signs,_art.pigment,"SealReliefs")
		view.add_child(slab)
		barrier.add_to_group("camera_occluders")
	for group in [level.get_node("CombatGates"),level.get_node("Barriers")]:
		for gate in group.get_children():
			var visuals: Node3D = gate.get_node_or_null("Visuals")
			if visuals == null: continue
			for mesh in visuals.find_children("*","MeshInstance3D",true,false):
				mesh.material_override = _art.stone if mesh.name == "Slab" else _art.bronze
	# Keep 5m door throats intact. Frames form real room-to-corridor transitions.
	var frames := [[Vector3(0,0,19),false],[Vector3(-25,0,-7),false],[Vector3(25,0,-7),false],[Vector3(25,0,-17),false],[Vector3(18,0,-24),true],[Vector3(40,0,-24),true],[Vector3(0,0,-17),false],[Vector3(0,0,-41),false]]
	for i in frames.size(): add_child(_art.arch("Portal%d" % i,frames[i][0],frames[i][1]))
	for enemy: CharacterBody3D in level.get_node("Enemies").get_children():
		_attach_mummy(enemy)
	level.get_node("Enemies").child_entered_tree.connect(_on_enemy_entered)
	set_meta("tomb_wall_count",_wall_count)
	set_meta("tomb_torch_count",_torch_count)

func _on_enemy_entered(enemy: Node) -> void:
	if enemy.is_node_ready(): _attach_mummy(enemy)
	else: enemy.ready.connect(_attach_mummy.bind(enemy),CONNECT_ONE_SHOT)

func _attach_mummy(enemy: Node) -> void:
	if not enemy is CharacterBody3D or not enemy.has_method("is_encounter_active") or enemy.get_node_or_null("Visuals/Model") == null or enemy.has_node("TombMummyPresentation"): return
	var skin := MummySkin.new()
	skin.name = "TombMummyPresentation"
	enemy.add_child(skin)

func _torch(parent: Node3D, at: Vector3, shadows: bool) -> void:
	var root := _art.root("WallTorch","torch")
	var metal := Art.Surface.new()
	var fire := Art.Surface.new()
	_art.tube(metal,at-Vector3.UP*0.38,at+Vector3.UP*0.05,0.075,Color(0.73,0.61,0.42))
	_art.ellipsoid(metal,at,Vector3(0.17,0.08,0.17),Color(0.84,0.70,0.45))
	_art.ellipsoid(fire,at+Vector3.UP*0.18,Vector3(0.10,0.25,0.095),Color(1.0,0.54,0.13))
	_art.ellipsoid(fire,at+Vector3.UP*0.14+Vector3(0.04,0,0),Vector3(0.055,0.16,0.055),Color(1.0,0.87,0.34))
	_art.commit(root,metal,_art.bronze,"BronzeBowlAndBracket")
	_art.commit(root,fire,_art.flame,"LuminousFlameVolume")
	var light := OmniLight3D.new()
	light.name = "WarmTorchLight"
	light.position = at+Vector3.UP*0.30
	light.light_color = Color(1.0,0.70,0.43)
	light.light_energy = 1.9
	light.omni_range = 8.0
	light.omni_attenuation = 1.3
	light.shadow_enabled = shadows
	light.shadow_bias = 0.10
	root.add_child(light)
	parent.add_child(root)
	_torch_count += 1

func _dust(rect: Rect2, label: String) -> void:
	var dust := GPUParticles3D.new()
	dust.name = "TombDust"+label
	dust.amount = 28
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.visibility_aabb = AABB(Vector3(-rect.size.x*0.5,-0.3,-rect.size.y*0.5),Vector3(rect.size.x,5.0,rect.size.y))
	dust.position = Vector3(rect.get_center().x,2.0,rect.get_center().y)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(rect.size.x*0.42,1.7,rect.size.y*0.42)
	process.direction = Vector3(0.7,0.1,0.3)
	process.spread = 30.0
	process.initial_velocity_min = 0.025
	process.initial_velocity_max = 0.065
	process.gravity = Vector3(0,-0.006,0)
	process.scale_min = 0.35
	process.scale_max = 1.0
	dust.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035,0.035)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.75,0.62,0.43,0.12)
	quad.material = material
	dust.draw_pass_1 = quad
	add_child(dust)

func _sand_sink(rect: Rect2, label: String) -> void:
	var root := _art.root("SettledSandBasin"+label,"sand_basin")
	var surface := Art.Surface.new()
	var center := rect.get_center()+Vector2(rect.size.x*0.32,rect.size.y*0.29)
	for ring in 4:
		for i in 24:
			var a := TAU*i/24.0
			var b := TAU*(i+1)/24.0
			var inner := 0.15+ring*0.26
			var outer := inner+0.26
			var y := 0.045-float(3-ring)*0.017
			surface.quad(Vector3(center.x+cos(a)*inner,y,center.y+sin(a)*inner*0.72),Vector3(center.x+cos(a)*outer,y+0.005,center.y+sin(a)*outer*0.72),Vector3(center.x+cos(b)*inner,y,center.y+sin(b)*inner*0.72),Vector3(center.x+cos(b)*outer,y+0.005,center.y+sin(b)*outer*0.72),Color(1.06,1.0,0.86))
	_art.commit(root,surface,_art.sand,"SubtleSettlingSandRings")
	var grains := GPUParticles3D.new()
	grains.name = "FallingSandFromCeilingJoint"
	grains.position = Vector3(center.x,2.65,center.y)
	grains.amount = 36
	grains.lifetime = 1.4
	grains.preprocess = 1.4
	grains.visibility_aabb = AABB(Vector3(-0.6,-3.0,-0.6),Vector3(1.2,3.5,1.2))
	var flow := ParticleProcessMaterial.new()
	flow.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	flow.emission_box_extents = Vector3(0.09,0.025,0.08)
	flow.direction = Vector3.DOWN
	flow.spread = 8.0
	flow.initial_velocity_min = 0.2
	flow.initial_velocity_max = 0.55
	flow.gravity = Vector3(0,-3.0,0)
	flow.scale_min = 0.45
	flow.scale_max = 1.0
	grains.process_material = flow
	var grain := SphereMesh.new()
	grain.radius = 0.012
	grain.height = 0.024
	grain.radial_segments = 6
	grain.rings = 3
	grain.material = _art.sand
	grains.draw_pass_1 = grain
	root.add_child(grains)
	add_child(root)

func _reservoir_normal(ripples: FastNoiseLite) -> NoiseTexture2D:
	var normal := NoiseTexture2D.new()
	normal.width = 128
	normal.height = 128
	normal.noise = ripples
	normal.seamless = true
	normal.as_normal_map = true
	normal.bump_strength = 0.35
	return normal
