extends Node3D
## Shared aged stone, brass and batched decorative geometry for the observatory.
const STONE := Color("53636b")
const PALE := Color("a6afb0")
const DARK := Color("273840")
const BRASS := Color("987747")
const GOLD := Color("bda16b")
const BLUE := Color("9bdfee")
const FLOOR := preload("res://scenes/dungeon/level04/observatory_stone.gdshader")
var _materials := {}
var _stone_noise: NoiseTexture2D

func _mat(color: Color, metal := false, emission := 0.0) -> StandardMaterial3D:
	var key := str(color)+str(metal)+str(emission)
	if _materials.has(key): return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.58 if metal else 0.92
	material.metallic = 0.64 if metal else 0.0
	if color.a >= 1 and emission == 0:
		if _stone_noise == null:
			_stone_noise = NoiseTexture2D.new()
			_stone_noise.width = 256
			_stone_noise.height = 256
			var noise := FastNoiseLite.new()
			noise.seed = 144
			noise.frequency = 0.07
			noise.fractal_octaves = 3
			_stone_noise.noise = noise
			var gradient := Gradient.new()
			gradient.set_color(0,Color(0.38,0.46,0.47))
			gradient.set_color(1,Color(0.93,0.92,0.83))
			_stone_noise.color_ramp = gradient
		material.albedo_texture = _stone_noise
		material.uv1_scale = Vector3(2,2,2)
	if emission > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	if color.a < 1:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = material
	return material

func _mesh(parent: Node3D, shape: Mesh, at: Vector3, ink: Color, metal := false, emission := 0.0, occluder := false) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = shape
	view.material_override = _mat(ink,metal,emission)
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.set_meta("observatory_art_detail",true)
	view.set_meta("ignore_shutter_overlay",at.y > 0.3 or emission > 0 or occluder)
	parent.add_child(view)
	view.position = at
	if occluder: view.add_to_group("observatory_visual_occluders")
	return view

func _box(parent: Node3D, at: Vector3, dimensions: Vector3, ink: Color, metal := false, occluder := false) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = dimensions
	return _mesh(parent,shape,at,ink,metal,0,occluder)

func _ring(parent: Node3D, at: Vector3, radius: float, width: float, ink: Color, occluder := false) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = radius-width
	shape.outer_radius = radius+width
	shape.rings = 64
	shape.ring_segments = 6
	return _mesh(parent,shape,at,ink,true,0,occluder)

func _rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, ink: Color, occluder := false) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = a.distance_to(b)
	shape.radial_segments = 8
	shape.rings = 0
	var view := _mesh(parent,shape,(a+b)*0.5,ink,true,0,occluder)
	view.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return view

func _gear(parent: Node3D, at: Vector3, radius: float, teeth: int, width: float) -> void:
	_ring(parent,at,radius,width,BRASS)
	for i in teeth:
		var angle := i*TAU/teeth
		var p := at+Vector3(cos(angle),0,sin(angle))*(radius+width)
		var tooth := _box(parent,p,Vector3(width*1.9,0.045,width*1.65),GOLD,true)
		tooth.rotation.y = -angle

func _chip(at: Vector3, width: float, ink: Color) -> MeshInstance3D:
	var outline := PackedVector2Array([Vector2(-0.48,-0.28),Vector2(0.15,-0.35),Vector2(0.48,-0.05),Vector2(0.28,0.25),Vector2(-0.4,0.22)])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a := outline[i]*width
		var b := outline[(i+1)%outline.size()]*width
		for p in [Vector3(0,0.10,0),Vector3(b.x,0.035,b.y),Vector3(a.x,0.035,a.y)]:
			surface.set_uv(Vector2(p.x,p.z)*2)
			surface.add_vertex(p)
	surface.generate_normals()
	return _mesh(self,surface.commit(),at,ink)

func _batch(parent: Node3D) -> void:
	# Batch only our generated details. Existing decks, background shaders and
	# gameplay meshes belong to the target scene and must remain untouched.
	# Keep roof pieces separate so each can fade independently.
	var groups := {}
	for child in parent.get_children():
		if not child is MeshInstance3D or child.is_in_group("observatory_visual_occluders"): continue
		if not child.get_meta("observatory_art_detail",false): continue
		if child.has_meta("observatory_background_surface"): continue
		if child.mesh == null or child.mesh.get_surface_count() != 1: continue
		if child.get_child_count() > 0 or child.material_overlay != null: continue
		if not child.material_override is StandardMaterial3D: continue
		var material: StandardMaterial3D = child.material_override
		if material.albedo_color.a < 1: continue
		var key := str(material.get_instance_id())+str(child.get_meta("ignore_shutter_overlay",false))
		if not groups.has(key): groups[key] = []
		groups[key].append(child)
	for group: Array in groups.values():
		if group.size() < 2: continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for view: MeshInstance3D in group: surface.append_from(view.mesh,0,view.transform)
		var combined := MeshInstance3D.new()
		combined.name = "StaticDetails"
		combined.mesh = surface.commit()
		combined.material_override = group[0].material_override
		combined.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		combined.set_meta("observatory_art_detail",true)
		combined.set_meta("ignore_shutter_overlay",group[0].get_meta("ignore_shutter_overlay",false))
		parent.add_child(combined)
		for view: MeshInstance3D in group: view.free()
