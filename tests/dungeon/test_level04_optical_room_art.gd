extends "res://tests/dungeon/test_level04_mechanical_room_art.gd"

func room_specific_checks(world: Node3D) -> void:
	await super.room_specific_checks(world)
	for path in ["F/WalkwayArt","G/MailMaintenanceArt","K/MirrorRoomArt","L/NightDarkroomArt"]:
		check(world.layout.has_node(path),"Restored optical/transport room "+path)
	var walkway: Node3D = world.layout.get_node("F/WalkwayArt")
	check(walkway.glass_surfaces.size() == 6,"Room and all five F passages use the restored prism material")
	for link: String in PLAN.LINKS:
		if not link.contains("F"): continue
		var deck: Node3D = world.layout.get_node(link+"/Deck")
		var view: MeshInstance3D = walkway._deck_surface(world.layout.get_node(link))
		var path := PLAN.bridge_path(link[0],link[1])
		var material := view.material_override as ShaderMaterial
		check(walkway.glass_surfaces.has(view) and material.get_shader_parameter("bridge_mode") and material.get_shader_parameter("segment_count") == path.size()-1,"Prism shader covers actual multi-segment Deck "+link)
		var colliders := deck.get_children().filter(func(c): return c is CollisionShape3D)
		check(colliders.size() == path.size()-1,"Every original collision segment remains in "+link)
		var segments: PackedVector4Array = material.get_shader_parameter("segments")
		var starts: PackedFloat32Array = material.get_shader_parameter("segment_starts")
		var length := 0.0
		for i in range(path.size()-1):
			check(segments[i].is_equal_approx(Vector4(path[i].x,path[i].y,path[i+1].x,path[i+1].y)) and is_equal_approx(starts[i],length),"Prism direction and phase follow target path "+link+" segment "+str(i))
			length += path[i].distance_to(path[i+1])
			var at: Vector2 = (path[i]+path[i+1])*0.5
			var query := PhysicsRayQueryParameters3D.create(Vector3(at.x,0.2,at.y),Vector3(at.x,-0.8,at.y),1)
			var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and hit.collider == deck and not colliders[i].disabled,"Transparent bridge keeps its original physical floor "+link+" segment "+str(i))
	check(not walkway.dressed_rails.is_empty() and walkway.dressed_rails.all(func(body): return body.has_node("CarvedBrassRail") and body.get_node("Surface").mesh != null),"Carved rails reuse existing solid rail bodies")
	check(is_instance_valid(world.combat._cage) and is_instance_valid(world.combat._window_lights),"PR #20 moving cage and observation window remain installed")
	var mail_art: Node3D = world.layout.get_node("G/MailMaintenanceArt")
	check(world.mail.cart.has_node("BrassTransportTrolley") and world.get_node("Stations/mail_take").has_node("TransportControlHousing") and world.get_node("Stations/mail_send").has_node("TransportControlHousing"),"Transport art attaches to the target cart and stations")
	var route: PackedVector3Array = world.mail.route.duplicate()
	var departure: Vector3 = world.mail.cart.position
	var prior_angle: Quaternion = mail_art.drive_gears[0].node.quaternion
	var energy: int = world.inventory.energy_potion_count
	check(world.mail.interact(&"mail_send"),"Original transport action still starts the target cart")
	world.mail.advance(0.3)
	mail_art._process(0.016)
	check(world.mail.cart.position != departure and mail_art.drive_gears[0].node.quaternion != prior_angle and world.mail.route == route and world.inventory.energy_potion_count == energy,"Drive gears follow actual motion without changing route or rewards")
	check(mail_art.indicators.all(func(item): return is_zero_approx(item.material.emission_energy_multiplier)),"Station lamps follow the target's unavailable state after dispatch")
	# Restore the fixture to its departure pose for room screenshots.
	world.mail.cart.position = departure
	world.mail.segment = 0
	world.mail.state = world.mail.State.WAITING
	mail_art._process(0.016)
	var darkroom: Node3D = world.layout.get_node("L/NightDarkroomArt")
	check(darkroom.hanging_films.size() == 8 and darkroom.racks.size() == 2,"Original developing racks and eight abstract negatives are restored")
	var doorway_clear := true
	for rack: Node3D in darkroom.racks:
		for view: MeshInstance3D in rack.find_children("*","MeshInstance3D",true,false):
			var inverse := view.global_transform.affine_inverse()
			for x: float in [-2.4,0,2.4]:
				var from: Vector3 = world.layout.room_center("L")+Vector3(x,1,-5.2)
				var to: Vector3 = world.layout.room_center("L")+Vector3(x,1,-7.8)
				if view.get_aabb().intersects_segment(inverse*from,inverse*to) != null: doorway_clear = false
	check(doorway_clear,"Developing racks preserve the full LI side-door opening")
	var clues: Array = world.puzzles.slide_knobs.duplicate()
	var photo: Sprite3D = world.puzzles.print_sprite
	world.puzzles.film_developed = true
	darkroom._process(0.016)
	check(darkroom._status.albedo_color == Color("6d98b0") and not world.puzzles.film_claimed and world.puzzles.slide_knobs == clues and world.puzzles.print_sprite == photo,"Developing status reads original state without replacing photographs, sliders or claims")
	world.puzzles.film_developed = false
	darkroom._process(0.016)
	var mirror_art: Node3D = world.layout.get_node("K/MirrorRoomArt")
	check(mirror_art._reflections.size() == 3,"One antique and two working mirrors have independent reflection viewports")
	var head: Node3D = world.puzzles.heads[0]
	var previous_turn: int = world.puzzles.turns[0]
	world.puzzles.calibrated = true
	world.puzzles.interact(&"p_alpha")
	check(world.puzzles.heads[0] == head and world.puzzles.turns[0] != previous_turn and head.has_node("CarvedMirrorFrame/WorkingReflection"),"Original mirror mechanism rotates the restored frame and reflection plane")
	world.player.global_position = world.layout.room_center("K")+Vector3(0,0.05,2)
	world.player.velocity = Vector3.ZERO
	var camera: Camera3D = world.get_node("Camera3D")
	camera.reset_follow()
	await frames(28)
	for reflection: Dictionary in mirror_art._reflections:
		check(reflection.viewport.world_3d == world.get_world_3d() and not reflection.viewport.own_world_3d and (reflection.camera.cull_mask & reflection.mesh.layers) == 0,"Reflection shares the real scene and excludes all mirror glass")
		var normal: Vector3 = reflection.plane.global_basis.z.normalized()
		var actual_distance: float = (camera.get_camera_transform().origin-reflection.plane.global_position).dot(normal)
		var reflected_distance: float = (reflection.camera.get_camera_transform().origin-reflection.plane.global_position).dot(normal)
		check(absf(actual_distance+reflected_distance)<0.02 and is_equal_approx(reflection.camera.fov,camera.fov),"Reflection eye mirrors the current player camera across the live mirror plane")
		check(reflection.viewport.size.x<=reflection.limit.x and reflection.viewport.size.y<=reflection.limit.y and reflection.viewport.size.x>1 and reflection.viewport.size.y>1,"Reflection resolution remains bounded")
	if "--capture" in OS.get_cmdline_user_args():
		await capture_at(world,"K-reflection",world.player.global_position)
		var varied := false
		for i in mirror_art._reflections.size():
			var reflection: Dictionary = mirror_art._reflections[i]
			var pixels: Image = reflection.viewport.get_texture().get_image()
			check(not pixels.is_empty() and pixels.save_png(OS.get_environment("GODOT_TEST_OUTPUT_DIR").path_join("mirror-"+str(i)+".png")) == OK,"Read actual reflection viewport "+str(i))
			var origin := pixels.get_pixel(0,0)
			for y in range(0,pixels.get_height(),8):
				for x in range(0,pixels.get_width(),8):
					var pixel := pixels.get_pixel(x,y)
					if absf(pixel.r-origin.r)+absf(pixel.g-origin.g)+absf(pixel.b-origin.b)>0.03: varied = true
		check(varied,"Reflection textures contain rendered scene detail")
		root.size = Vector2i(800,600)
		await frames(28)
		for reflection: Dictionary in mirror_art._reflections:
			check(absf(float(reflection.viewport.size.x)/reflection.viewport.size.y-4.0/3.0)<0.025,"Reflection viewport follows resized camera aspect")
		root.size = Vector2i(1280,720)
		for link in ["CF","DF","FH"]:
			var path := PLAN.bridge_path(link[0],link[1])
			await capture_at(world,link+"-bend",Vector3(path[1].x,0.05,path[1].y))
	world.player.global_position = world.layout.room_center("A")+Vector3(0,0.05,2)
	world.player.velocity = Vector3.ZERO
	await frames(3)
	check(mirror_art._reflections.all(func(item): return item.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED),"All reflection rendering stops when player leaves the room")

func capture_at(world: Node3D, label: String, at: Vector3) -> void:
	world.player.global_position = at
	world.player.velocity = Vector3.ZERO
	world.get_node("Camera3D").reset_follow()
	await frames(28)
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(OS.get_environment("GODOT_TEST_OUTPUT_DIR").path_join(label+".png")) == OK,"Capture "+label)

func capture_rooms() -> Array[String]:
	return ["F","G","K","L"]
