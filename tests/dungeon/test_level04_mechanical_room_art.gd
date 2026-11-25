extends "res://tests/dungeon/test_level04_selected_room_art.gd"
const ADAPTER := preload("res://scenes/dungeon/level04/observatory_mechanical_room_art.gd")

func room_specific_checks(world: Node3D) -> void:
	world.set_physics_process(false)
	world.player._invulnerability_remaining = 100000
	for path in ["D/CounterweightWellArt","E/ExposureArchiveArt","H/ShutterTestArt","I/DomeArt","I/InstrumentIsland/AstronomicalEngine"]:
		check(world.layout.has_node(path),"Restored original structure "+path)
	var well: Node3D = world.layout.get_node("D/CounterweightWellArt")
	var cover: Node3D = well._opening_cover(world.layout.get_node("D"))
	check(cover != null and not cover.visible and not cover is CollisionObject3D,"Resolves and hides the target's unnamed WellOpeningCover without altering physics")
	check(well.weights.size() == 2 and well.pulleys.size() == 2,"Original paired counterweights and pulleys are restored")
	var spans: Array = well._wall_spans(Vector2(-4.5,-7),Vector2(4,-7))
	check(spans.size() == 1 and spans[0].is_equal_approx(Vector2(5,8.5)),"Rear masonry leaves the full five-metre DF doorway clear")
	var doorway_clear := true
	for section: Node3D in well.find_children("RearMasonrySection*","Node3D",false,false):
		for view: MeshInstance3D in section.get_children():
			var inverse := view.global_transform.affine_inverse()
			for x: float in [-4.2,-2.0,0.2]:
				var from: Vector3 = world.layout.room_center("D")+Vector3(x,1,-6)
				var to: Vector3 = world.layout.room_center("D")+Vector3(x,1,-8)
				if view.get_aabb().intersects_segment(inverse*from,inverse*to) != null: doorway_clear = false
	check(doorway_clear,"Actual rear masonry meshes do not bridge the PR #20 DF entrance")
	var query := PhysicsRayQueryParameters3D.create(world.layout.room_center("D")+Vector3(-1,0.2,0),world.layout.room_center("D")+Vector3(-1,-0.8,0),1)
	check(not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Original well floor collision remains under the visual opening")
	for spec in [["D",3],["I",8]]:
		var count := 0
		for view: MeshInstance3D in world.layout.get_node(spec[0]).find_children("*","MeshInstance3D",true,false):
			var kind: String = view.get_meta("observatory_background_surface","")
			if kind not in ["shaft","masonry","vault"]: continue
			count += 1
			var material := view.material_override as StandardMaterial3D
			check(material != null and material.normal_texture != null and material.cull_mode == BaseMaterial3D.CULL_DISABLED and view.get_meta("ignore_shutter_overlay",false) and view.material_overlay == null,"Tagged background remains separate, textured and excluded from warning: "+kind)
		check(count > 0,"Background surface tags survive batching in "+spec[0])
	var exposure: Node3D = world.layout.get_node("E/ExposureArchiveArt")
	check(exposure.cabinets.size() == 4 and exposure.exposure_units.size() == 3,"Archive cabinets and original exposure instruments are restored")
	check(world.puzzles.hood.has_node("HingedSafeTrim") and world.get_node("Stations/p_dial").has_node("ExposureIndexCollar"),"Visual controls attach to existing target stations and moving hood")
	var original_phases: Array = world.puzzles.phase_displays.duplicate()
	world.puzzles.exposure = 2
	world.player.global_position = world.layout.room_center("E")+Vector3(0,0.05,2)
	world.player.velocity = Vector3.ZERO
	for i in 60: exposure._process(1.0/60)
	check(absf(angle_difference(exposure.index_collar.rotation.y,TAU*2/3)) < 0.1 and world.puzzles.phase_displays == original_phases,"Exposure collar reads the target state without replacing phase clues")
	world.puzzles.restore_comparison_lamp()
	check(world.puzzles._table_lamp.visible,"PR #20 comparison lamp remains independently visible")
	var before_y: float = well.weights[0].node.position.y
	world.combat.cage_side = 1
	for i in 60: well._process(1.0/60)
	check(well.weights[0].node.position.y < before_y and world.combat.cage_side == 1 and not world.combat.cage_placed,"Decorative counterweight follows cage state without granting placement or rewards")
	world.combat.cage_side = 0
	for room: String in ["H","I"]:
		var light: Node3D = world.combat._sweeps[room]
		var original_script: Script = light.get_script()
		var floor_view: MeshInstance3D
		for child in world.layout.get_node(room+"/Deck").get_children():
			if child is MeshInstance3D: floor_view = child
		check(floor_view.material_overlay == light.effect,"Original live floor warning remains in "+room)
		var affected := 0
		var exclusions_clean := true
		for view: MeshInstance3D in world.layout.get_node(room).find_children("*","MeshInstance3D",true,false):
			if view.get_meta("ignore_shutter_overlay",false) and view.material_overlay == light.effect: exclusions_clean = false
			if view.get_meta("observatory_art_detail",false) and view.material_overlay == light.effect: affected += 1
		check(exclusions_clean and affected > 0,"New floor details receive warning while roofs, beams and background are excluded in "+room)
		light.begin(-1,false)
		light.advance(3.4,[])
		var elapsed: float = light.elapsed
		ADAPTER.new().sync_warning_surfaces(world)
		check(light.get_script() == original_script and light.active and light.side == -1 and is_equal_approx(light.elapsed,elapsed) and not light.harmless,"Render filtering preserves live timing, side and damage mode in "+room)
		light.stop()
	var shutter: Node3D = world.layout.get_node("H/ShutterTestArt")
	var light: Node3D = world.combat._sweeps.H
	world.player.global_position = world.layout.room_center("H")+Vector3(0,0.05,2)
	world.player.velocity = Vector3.ZERO
	light.begin(1,true)
	shutter._process(0.016)
	check(shutter.projections.visible and shutter.blue_parts[0].visible,"Blue calibration effects remain visible during the harmless trial")
	light.stop()
	light.begin(1,false)
	light.advance(3.3,[])
	shutter._process(0.016)
	check(not shutter.projections.visible and not shutter.blue_parts[0].visible,"Decorative blue light yields to the real combat warning")
	var angle: float = shutter.turntable.rotation.y
	shutter._process(0.1)
	check(is_equal_approx(angle,shutter.turntable.rotation.y),"Trial turntable stops during the locked dangerous sweep")
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(OS.get_environment("GODOT_TEST_OUTPUT_DIR"))
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280,720)
		var camera: Camera3D = world.get_node("Camera3D")
		for room: String in ["H","I"]:
			var sweep: Node3D = world.combat._sweeps[room]
			world.player.global_position = world.layout.room_center(room)+Vector3(3,0.05,2)
			world.player.velocity = Vector3.ZERO
			camera.reset_follow()
			sweep.begin(1,false)
			sweep.advance(3.3,[])
			await frames(25)
			RenderingServer.force_draw()
			check(root.get_texture().get_image().save_png(OS.get_environment("GODOT_TEST_OUTPUT_DIR").path_join(room+"-warning.png")) == OK,"Capture live warning "+room)
			sweep.stop()
	light.stop()
	world.puzzles.exposure = 0

func capture_rooms() -> Array[String]:
	return ["D","E","H","I"]
