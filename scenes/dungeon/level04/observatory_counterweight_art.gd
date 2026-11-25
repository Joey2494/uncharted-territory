extends "res://scenes/dungeon/level04/observatory_art_base.gd"
## Decorative shaft depth and machinery; the original guarded floor owns physics.
const SHAFT_DECK = preload("res://scenes/dungeon/level04/counterweight_deck.gdshader")
const GLOW = preload("res://scenes/dungeon/level04/well_glow.gdshader")
const PLAN = preload("res://scenes/dungeon/level04/observatory_plan.gd")
const WELL := Vector3(-1,0,0)
const IRON := Color("344149")
const RUST := Color("655044")
var weights: Array[Dictionary] = []
var pulleys: Array[Node3D] = []
var _layout: Node3D
var _blue: OmniLight3D

func build(layout: Node3D) -> void:
	name = "CounterweightWellArt"
	_layout = layout
	var room: Node3D = layout.get_node("D")
	room.add_child(self)
	# Retain the target background parameters outside the original visual shaft.
	var floor_view: MeshInstance3D
	for child in room.get_node("Deck").get_children():
		if child is MeshInstance3D: floor_view = child; break
	var material := ShaderMaterial.new()
	material.shader = SHAFT_DECK
	if floor_view != null:
		var previous := floor_view.material_override as ShaderMaterial
		if previous != null:
			for uniform: Dictionary in previous.shader.get_shader_uniform_list():
				var value: Variant = previous.get_shader_parameter(uniform.name)
				if value != null: material.set_shader_parameter(uniform.name,value)
		floor_view.material_override = material
	var opening := _opening_cover(room)
	if opening != null: opening.hide()
	_style_guardrail(room)
	_shaft()
	_rear_walls()
	_gallery(Vector3(0,2.65,-6.3),5.8)
	_gallery(Vector3(-1,-2.6,-1.55),2.5)
	_gallery(Vector3(-1,-6.8,1.68),2.5)
	_gallery(Vector3(-1,-10.5,-1.6),2.8)
	_machinery()
	_depth_light()
	_batch(self)
	# The deferred visual adapter runs after the target has built its stations.
	_attach_controls()

func _shaft() -> void:
	# Inner masonry continues beneath the actual safety rail, with inward normals.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier in 14:
		for i in 20:
			var a := i*TAU/20
			var b := (i+1)*TAU/20
			var y := -0.04-tier*0.96
			var low := y-0.91
			var p := WELL+Vector3(cos(a)*2.10,y,sin(a)*2.10)
			var q := WELL+Vector3(cos(b)*2.10,y,sin(b)*2.10)
			var r := Vector3(q.x,low,q.z)
			var s := Vector3(p.x,low,p.z)
			for point in [p,r,q,p,s,r]:
				surface.set_uv(Vector2(atan2(point.z,point.x+1)*2,point.y*0.7))
				surface.add_vertex(point)
	surface.generate_normals()
	var wall := _mesh(self,surface.commit(),Vector3.ZERO,STONE.darkened(0.25))
	wall.set_meta("observatory_background_surface","shaft")
	wall.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	for y: float in [-0.45,-3.6,-7.3,-11.5]:
		_ring(self,WELL+Vector3.UP*y,2.04,0.045,RUST)
	for side: float in [-1,1]:
		_box(self,WELL+Vector3(side*1.65,-6.6,-0.62),Vector3(0.13,13.0,0.16),IRON,true)
		for n in 7:
			_box(self,WELL+Vector3(side*1.65,-0.8-n*1.8,-0.62),Vector3(0.29,0.09,0.30),RUST,true)
	var bottom := CylinderMesh.new()
	bottom.top_radius = 2.05
	bottom.bottom_radius = 2.05
	bottom.height = 0.12
	bottom.radial_segments = 32
	bottom.rings = 0
	_mesh(self,bottom,WELL+Vector3.UP*-13.6,DARK)
	_ring(self,WELL+Vector3.UP*-13.5,1.25,0.08,BRASS)

func _rear_walls() -> void:
	# Leave the southern viewing side and eastern entrance open.
	var points := PLAN.outline("D")
	for i in points.size():
		var a := points[i]
		var b := points[(i+1)%points.size()]
		if (a.y+b.y)*0.5 > -3.9: continue
		var section := Node3D.new()
		section.name = "RearMasonrySection"
		add_child(section)
		# Follow the target's actual door cuts, including the PR #20 DF exit.
		var direction := a.direction_to(b)
		for span: Vector2 in _wall_spans(a,b):
			var distance := span.y-span.x
			var n := maxi(1,ceili(distance/1.0))
			for tier in 5:
				for j in n:
					var at := a+direction*(span.x+distance*(j+0.5)/n)
					var brick := _box(section,Vector3(at.x,0.43+tier*0.87,at.y),Vector3(distance/n-0.035,0.82,0.38),STONE.darkened(0.04*((j+tier)%3)))
					brick.rotation.y = -atan2(b.y-a.y,b.x-a.x)
		_batch(section)
		for view in section.get_children():
			if view is MeshInstance3D: view.set_meta("observatory_background_surface","masonry")
		_mark_blockers(section)
	for x: float in [-4.3,3.2]:
		if _near_door(Vector2(x,-6.35),0.5): continue
		_box(self,Vector3(x,2.65,-6.35),Vector3(0.72,5.3,0.70),DARK,false,true)
		for y: float in [0.3,2.6,4.9]:
			_box(self,Vector3(x,y,-6.35),Vector3(0.86,0.16,0.85),RUST,true,true)

func _gallery(at: Vector3, width: float) -> void:
	var gallery := Node3D.new()
	gallery.name = "SuspendedMaintenanceDeck_%d" % roundi(at.y*10)
	add_child(gallery)
	gallery.position = at
	# Below-floor decks stay inside the shaft; the upper deck hugs the rear wall.
	var depth := 0.70 if at.y > 0 else 0.43
	_box(gallery,Vector3.ZERO,Vector3(width,0.13,depth),IRON,true)
	for n in maxi(2,ceili(width/0.25)):
		_box(gallery,Vector3(-width/2+0.12+n*0.25,0.077,0),Vector3(0.055,0.025,depth*0.88),RUST,true)
	for side: float in [-1,1]:
		_rod(gallery,Vector3(side*width*0.45,-0.12,0),Vector3(side*width*0.32,-0.85,0.28),0.06,RUST)
		_rod(gallery,Vector3(side*width*0.45,0.03,depth*0.4),Vector3(side*width*0.45,0.60,depth*0.4),0.025,BRASS)
	_rod(gallery,Vector3(-width*0.45,0.60,depth*0.4),Vector3(width*0.45,0.60,depth*0.4),0.035,BRASS)
	_batch(gallery)
	if at.y > 0: _mark_blockers(gallery)

func _chain(at: Vector3, low: float, high: float) -> void:
	var chain := Node3D.new()
	chain.name = "HeavyBrassChain"
	add_child(chain)
	chain.position = at
	var link_mesh := TorusMesh.new()
	link_mesh.inner_radius = 0.085
	link_mesh.outer_radius = 0.137
	link_mesh.rings = 12
	link_mesh.ring_segments = 6
	for n in ceili((high-low)/0.245):
		var y := low+n*0.245
		var link := _mesh(chain,link_mesh,Vector3.UP*y,BRASS,true)
		link.scale = Vector3(0.75,1,1.33)
		link.rotation.x = PI/2
		if n%2: link.rotation.y = PI/2

	_batch(chain)
	_mark_blockers(chain)

func _weight(at: Vector3, direction: float) -> void:
	var weight := Node3D.new()
	weight.name = "IronCounterweight"
	add_child(weight)
	weight.position = at
	_box(weight,Vector3.ZERO,Vector3(1.12,2.65,0.96),IRON,true)
	for y: float in [-1.16,-0.55,0.55,1.16]:
		_box(weight,Vector3(0,y,0),Vector3(1.20,0.09,1.03),RUST,true)
	for x: float in [-0.43,0.43]:
		_box(weight,Vector3(x,0,0.51),Vector3(0.11,2.48,0.07),BRASS,true)
		for y: float in [-1.1,0,1.1]:
			_box(weight,Vector3(x,y,0.56),Vector3(0.12,0.12,0.035),GOLD,true)
	var bail := _ring(weight,Vector3(0,1.43,0),0.18,0.05,RUST)
	bail.rotation.x = PI/2
	_batch(weight)
	_mark_blockers(weight)
	weights.append({"node":weight,"rest":at.y,"direction":direction})

func _machinery() -> void:
	_box(self,Vector3(-1,4.9,-1.3),Vector3(5.1,0.42,0.56),IRON,true,true)
	for side: float in [-1,1]:
		var x := -1+side*1.12
		_rod(self,Vector3(x,4.75,-1.3),Vector3(-1+side*3.0,4.1,-5.8),0.12,RUST,true)
		_chain(Vector3(x,0,-0.63),-12.8,4.5)
		_chain(Vector3(x,0,-1.45),-12.8,4.5)
		var pulley := Node3D.new()
		pulley.name = "CounterweightPulley"
		add_child(pulley)
		pulley.position = Vector3(x,4.50,-1.04)
		pulley.rotation.x = PI/2
		_gear(pulley,Vector3.ZERO,0.64,28,0.07)
		_ring(pulley,Vector3.ZERO,0.47,0.04,IRON)
		for n in 6:
			var angle := n*TAU/6
			_rod(pulley,Vector3.ZERO,Vector3(cos(angle)*0.5,0,sin(angle)*0.5),0.05,RUST)
		_batch(pulley)
		for mesh: MeshInstance3D in pulley.get_children():
			mesh.add_to_group("observatory_visual_occluders")
			mesh.set_meta("ignore_shutter_overlay",true)
		pulleys.append(pulley)
	_weight(Vector3(-2.12,1.05,-0.63),-1)
	_weight(Vector3(0.12,-5.4,-0.63),1)

func _depth_light() -> void:
	var glow := Node3D.new()
	glow.name = "WellDepthGlow"
	add_child(glow)
	for i in 3:
		var plane := PlaneMesh.new()
		plane.size = Vector2(3.95,3.95)
		var view := _mesh(glow,plane,WELL+Vector3.UP*(-1.15-i*2.0),BLUE)
		var material := ShaderMaterial.new()
		material.shader = GLOW
		material.set_shader_parameter("opacity",0.22-i*0.05)
		view.material_override = material
		view.set_meta("ignore_shutter_overlay",true)
	_blue = OmniLight3D.new()
	_blue.position = WELL+Vector3.UP*-3.2
	_blue.light_color = Color("639edb")
	_blue.light_energy = 0.95
	_blue.omni_range = 7.0
	_blue.shadow_enabled = false
	add_child(_blue)

func _attach_controls() -> void:
	var world := _layout.get_parent()
	for id in ["left","right"]:
		var station := world.get_node_or_null("Stations/"+id)
		if station == null or station.has_node("BrassChainWheel"): continue
		var detail := Node3D.new()
		detail.name = "BrassChainWheel"
		station.add_child(detail)
		detail.position.y = 0.94
		detail.rotation.x = PI/2
		_gear(detail,Vector3.ZERO,0.31,18,0.028)
		for n in 4:
			var angle := n*TAU/4
			_rod(detail,Vector3.ZERO,Vector3(cos(angle)*0.27,0,sin(angle)*0.27),0.018,BRASS)
		_batch(detail)
		for view: MeshInstance3D in detail.get_children():
			view.add_to_group("observatory_visual_occluders")
			view.set_meta("ignore_shutter_overlay",true)

func _process(delta: float) -> void:
	var world := _layout.get_parent()
	var combat := world.get_node_or_null("Combat")
	if combat != null:
		var side: int = combat.cage_side
		for i in weights.size():
			var weight: Dictionary = weights[i]
			var desired: float = weight.rest+side*weight.direction*0.75
			weight.node.position.y = move_toward(weight.node.position.y,desired,delta*0.8)
			pulleys[i].quaternion = Quaternion(Vector3.RIGHT,PI/2)*Quaternion(Vector3.UP,(weight.node.position.y-weight.rest)/0.64)
	var player := world.get_node_or_null("Player") as Node3D
	_blue.visible = player != null and player.global_position.distance_squared_to(global_position)<400

func _style_guardrail(room: Node3D) -> void:
	for body in room.get_children():
		if not body is StaticBody3D or body.get_child_count()<2: continue
		var collision := body.get_child(0) as CollisionShape3D
		if collision == null or not collision.shape is BoxShape3D: continue
		var size: Vector3 = collision.shape.size
		if not size.is_equal_approx(Vector3(0.22,0.94,1.03)): continue
		var surface := body.get_node_or_null("Surface") as MeshInstance3D
		if surface != null: surface.material_override = _mat(STONE)
		_box(body,Vector3(0,0.50,0),Vector3(0.27,0.055,1.04),BRASS,true)

func _mark_blockers(parent: Node3D) -> void:
	for view in parent.get_children():
		if view is MeshInstance3D:
			view.add_to_group("observatory_visual_occluders")
			view.set_meta("ignore_shutter_overlay",true)

func _opening_cover(room: Node3D) -> Node3D:
	var named := room.get_node_or_null("WellOpeningCover") as Node3D
	if named != null: return named
	# The target architecture leaves this non-colliding cylinder unnamed.
	for body in room.get_children():
		if not body is Node3D or body is CollisionObject3D: continue
		if not body.position.is_equal_approx(WELL+Vector3.UP*0.026): continue
		for view in body.get_children():
			if view is MeshInstance3D and view.mesh is CylinderMesh and is_equal_approx(view.mesh.top_radius,2.15) and is_equal_approx(view.mesh.height,0.05): return body
	push_error("Missing original observatory well opening cover")
	return null

func _wall_spans(a: Vector2, b: Vector2) -> Array[Vector2]:
	var direction := a.direction_to(b)
	var cuts: Array[float] = []
	for link: String in PLAN.LINKS:
		if not link.contains("D"): continue
		var door := PLAN.doorway("D",link.replace("D",""))-Vector2(PLAN.CENTERS.D)
		if door.distance_to(Geometry2D.get_closest_point_to_segment(door,a,b)) < 0.02: cuts.append((door-a).dot(direction))
	cuts.sort()
	var spans: Array[Vector2] = []
	var start := 0.0
	for cut: float in cuts:
		if cut-_layout.HALF_BRIDGE > start: spans.append(Vector2(start,cut-_layout.HALF_BRIDGE))
		start = maxf(start,cut+_layout.HALF_BRIDGE)
	if a.distance_to(b) > start: spans.append(Vector2(start,a.distance_to(b)))
	return spans

func _near_door(at: Vector2, padding: float) -> bool:
	for link: String in PLAN.LINKS:
		if not link.contains("D"): continue
		var door := PLAN.doorway("D",link.replace("D",""))-Vector2(PLAN.CENTERS.D)
		if at.distance_to(door) < _layout.HALF_BRIDGE+padding: return true
	return false
