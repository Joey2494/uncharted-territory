extends "res://scenes/dungeon/level04/observatory_art_base.gd"
## No collision or puzzle state. Reflection cameras exclude all mirror surfaces.
const MIRROR_SHADER = preload("res://scenes/dungeon/level04/antique_mirror.gdshader")
const MIRROR_LAYER := 1 << 19
var _instrument: Node3D
var _reflections: Array[Dictionary] = []
var _tick := 0

func build(room: Node3D, instrument: Node3D) -> void:
	name = "MirrorRoomArt"
	room.add_child(self)
	_instrument = instrument
	# Preserve the installed background and the target's rotating puzzle heads.
	_wall_mirror()
	_records()
	_fragments()
	for i in 2: _working_mirror(i)
	_batch(self)

func _wall_mirror() -> void:
	var frame := Node3D.new()
	frame.name = "BrokenAntiqueMirror"
	add_child(frame)
	frame.position = Vector3(3.4,2.55,-6.35)
	frame.rotation.x = -0.10
	var outline := PackedVector2Array([Vector2(-1.75,-1.9),Vector2(-1.75,1.05),Vector2(-1.32,1.7),Vector2(0,2.18),Vector2(1.32,1.7),Vector2(1.75,1.05),Vector2(1.75,-1.9)])
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i+1)%outline.size()]
		_rod(frame,Vector3(a.x,a.y,0),Vector3(b.x,b.y,0),0.115,BRASS,true)
		_rod(frame,Vector3(a.x*0.94,a.y*0.94,0.035),Vector3(b.x*0.94,b.y*0.94,0.035),0.025,GOLD,true)
	for side: float in [-1,1]:
		for n in 7:
			var at := Vector3(side*1.79,-1.55+n*0.39,0.03)
			var curl := _ring(frame,at,0.12,0.022,GOLD,true)
			curl.rotation.x = PI/2
			_box(frame,at+Vector3(-side*0.05,0,0.03),Vector3(0.065,0.065,0.08),BRASS,true,true).rotation.z = PI/4
	var crest := _ring(frame,Vector3(0,2.23,0),0.29,0.042,BRASS,true)
	crest.rotation.x = PI/2
	for n in 8:
		var angle := n*TAU/8
		_rod(frame,Vector3(cos(angle)*0.32,2.23+sin(angle)*0.32,0),Vector3(cos(angle)*0.47,2.23+sin(angle)*0.47,0),0.025,GOLD,true)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		# Missing upper-left and lower-right panes reveal the empty old backing.
		if i in [1,5]: continue
		var vertices := [Vector2(0,-0.25),outline[i]*0.88,outline[(i+1)%outline.size()]*0.88]
		var center: Vector2 = (vertices[0]+vertices[1]+vertices[2])/3.0
		for vertex: Vector2 in vertices:
			var p := vertex.lerp(center,0.025)
			surface.set_normal(Vector3.FORWARD)
			surface.set_uv(Vector2((p.x+1.75)/3.5,1.0-(p.y+1.9)/4.08))
			surface.add_vertex(Vector3(p.x,p.y,0.07))
	for edge in [outline[0]*0.88,outline[3]*0.88,outline[4]*0.88]:
		_rod(frame,Vector3(0,-0.25,0.09),Vector3(edge.x,edge.y,0.09),0.009,Color(0.33,0.68,0.88,0.48))
	var glass := MeshInstance3D.new()
	glass.name = "FracturedReflection"
	glass.mesh = surface.commit()
	frame.add_child(glass)
	_reflector(glass,frame,Vector2i(256,320))
	_box(self,Vector3(3.4,0.26,-6.6),Vector3(4.15,0.5,0.85),STONE,false,true)
	_box(self,Vector3(3.4,0.55,-6.6),Vector3(4.38,0.09,1.0),PALE.darkened(0.18),false,true)
	for side: float in [-1,1]:
		_box(self,Vector3(3.4+side*1.5,0.3,-6.38),Vector3(0.19,0.48,0.14),BRASS,true,true)
	# A faint fractured pool beside the antique, clear of the active puzzle rays.
	for n in 3:
		var light := _box(self,Vector3(3.7+n*0.35,0.02,-4.9+n*0.13),Vector3(0.16,0.018,1.15-n*0.2),Color(0.28,0.60,0.85,0.15))
		light.rotation.y = -0.6
	_batch(frame)

func _working_mirror(index: int) -> void:
	var head: Node3D = _instrument.heads[index]
	# Replace only the old cyan face; the rotating head and normal stay authoritative.
	for view in head.get_children():
		if view is MeshInstance3D and view.mesh is BoxMesh and view.mesh.size.is_equal_approx(Vector3(1.03,0.65,0.04)) and view.position.is_equal_approx(Vector3(0,0,0.1)):
			view.hide()
	var art := Node3D.new()
	art.name = "CarvedMirrorFrame"
	head.add_child(art)
	for side: float in [-1,1]:
		_box(art,Vector3(side*0.62,0,0.09),Vector3(0.08,1.01,0.10),BRASS,true,true)
		_box(art,Vector3(0,side*0.47,0.09),Vector3(1.32,0.08,0.10),GOLD,true,true)
		for n in 4:
			var curl := _ring(art,Vector3(side*0.64,-0.32+n*0.21,0.15),0.058,0.012,GOLD,true)
			curl.rotation.x = PI/2
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.08,0.75)
	plane.orientation = PlaneMesh.FACE_Z
	var glass := MeshInstance3D.new()
	glass.name = "WorkingReflection"
	glass.mesh = plane
	glass.position.z = 0.135
	art.add_child(glass)
	_reflector(glass,glass,Vector2i(192,128))
	var station: Node3D = head.get_parent()
	_box(station,Vector3(0,0.28,0),Vector3(1.01,0.53,0.94),STONE,false,true)
	_box(station,Vector3(0,0.58,0),Vector3(1.12,0.09,1.02),PALE.darkened(0.22),false,true)
	for side: float in [-1,1]:
		_box(station,Vector3(side*0.38,0.33,0.48),Vector3(0.055,0.32,0.04),BRASS,true,true)
	_batch(art)

func _reflector(mesh: MeshInstance3D, plane: Node3D, dimensions: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.name = "MirrorReflection"
	viewport.size = dimensions
	viewport.world_3d = get_world_3d()
	viewport.transparent_bg = false
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var camera := Camera3D.new()
	camera.cull_mask = 1 # All mirror glass uses layer 20 to prevent recursion.
	camera.far = 64
	camera.current = true
	viewport.add_child(camera)
	var material := ShaderMaterial.new()
	material.shader = MIRROR_SHADER
	material.set_shader_parameter("reflection_texture",viewport.get_texture())
	mesh.material_override = material
	mesh.layers = MIRROR_LAYER
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.add_to_group("observatory_visual_occluders")
	mesh.set_meta("observatory_mirror_surface",true)
	mesh.set_meta("ignore_shutter_overlay",true)
	_reflections.append({"viewport":viewport,"camera":camera,"plane":plane,"mesh":mesh,"limit":dimensions})

func _process(_delta: float) -> void:
	_tick += 1
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var player: Node3D = _instrument.level.player
	if Vector2(player.global_position.x-global_position.x,player.global_position.z-global_position.z).length() > 14:
		for reflection in _reflections: reflection.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if _tick%4 != 0: return
	var reflection: Dictionary = _reflections[(_tick/4 as int)%_reflections.size()]
	var mirror: Node3D = reflection.plane
	var normal := mirror.global_basis.z.normalized()
	var origin := mirror.global_position
	var view := camera.get_camera_transform()
	var reflected := view.origin-2.0*normal*(view.origin-origin).dot(normal)
	var x := view.basis.x.bounce(normal)
	var y := view.basis.y.bounce(normal)
	var z := view.basis.z.bounce(normal)
	reflection.camera.global_transform = Transform3D(Basis(-x,y,z).orthonormalized(),reflected)
	var plane_depth: float = -(reflection.camera.global_transform.affine_inverse()*origin).z
	reflection.camera.near = clampf(plane_depth-0.15,0.05,60.0)
	var main_size := get_viewport().get_visible_rect().size.max(Vector2.ONE)
	var limit: Vector2i = reflection.limit
	var factor := minf(limit.x/main_size.x,limit.y/main_size.y)
	var dimensions := Vector2i(maxi(2,roundi(main_size.x*factor)),maxi(2,roundi(main_size.y*factor)))
	if reflection.viewport.size != dimensions: reflection.viewport.size = dimensions
	reflection.camera.keep_aspect = camera.keep_aspect
	reflection.camera.fov = camera.fov
	reflection.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _records() -> void:
	_box(self,Vector3(6.2,0.36,5.6),Vector3(2.0,0.68,0.95),STONE,false,true)
	_box(self,Vector3(6.2,0.73,5.6),Vector3(2.18,0.07,1.05),PALE.darkened(0.18),false,true)
	for i in 5:
		var page := Node3D.new()
		add_child(page)
		page.position = Vector3(5.6+(i%3)*0.43,0.78 if i<3 else 0.025,5.4+(i/3 as int)*0.6)
		page.rotation.y = i*0.48
		_box(page,Vector3.ZERO,Vector3(0.36,0.008,0.48),Color("a7a08a"))
		for n in 4:
			_box(page,Vector3(-0.035,0.006,-0.15+n*0.075),Vector3(0.19-0.03*(n%2),0.003,0.009),DARK)
		_ring(page,Vector3(0.08,0.007,-0.12),0.045,0.005,BRASS)
		_batch(page)
	var lens := _ring(self,Vector3(6.65,0.81,5.55),0.15,0.023,BRASS)
	lens.rotation.z = 0.2

func _fragments() -> void:
	for i in 12:
		var x := 1.2+(i%6)*0.75
		var z := -5.6+(i/6 as int)*0.45
		var chip := _chip(Vector3(x,0.019,z),0.38+0.08*(i%3),Color("567b86") if i%3 else BRASS)
		chip.rotation.y = i*1.27
	for x: float in [-7.4,7.5]:
		for n in 4:
			var stone := _chip(Vector3(x,0.02,-4.7+n*1.05),0.55,STONE)
			stone.rotation.y = n*0.78
