extends SceneTree
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func save_frame(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://addons/ziyuan_level04/evidence/" + name + ".png")
func run() -> void:
	root.size = Vector2i(1440, 900)
	for name in ["DawnShade", "SunPuppet", "IronThistle", "RavenRoost"]:
		change_scene_to_file("res://addons/ziyuan_level04/previews/" + name + "Preview.tscn")
		await frames(8)
		current_scene.model.rotation.y = PI - 0.3
		await frames(3)
		await save_frame(name + "_model")
	var overview := Image.create(1440, 900, false, Image.FORMAT_RGBA8)
	var model_names := ["DawnShade", "SunPuppet", "IronThistle", "RavenRoost"]
	for i in 4:
		var shot := Image.load_from_file("res://addons/ziyuan_level04/evidence/" + model_names[i] + "_model.png")
		shot.convert(Image.FORMAT_RGBA8)
		shot.resize(720, 450, Image.INTERPOLATE_LANCZOS)
		overview.blit_rect(shot, Rect2i(0, 0, 720, 450), Vector2i((i % 2) * 720, (i / 2) * 450))
	overview.save_png("res://addons/ziyuan_level04/evidence/four_rooms_roster.png")
	change_scene_to_file("res://addons/ziyuan_level04/FourRooms.tscn")
	await frames(8)
	var lab := current_scene
	for index in 4:
		lab.load_wave(index)
		await frames(3)
		lab.player.set_physics_process(false)
		lab.player.global_position = Vector3(0, 0.05, 3)
		for actor in lab.encounter.actors: actor.set_physics_process(false)
		var actor: Node = lab.encounter.actors[0]
		if index == 0:
			actor.global_position = Vector3(-5, 0.05, 1)
			actor.take_damage(1)
		elif index == 1:
			actor.perform_attack()
			for hazard in get_nodes_in_group("l4_hazards"):
				if hazard.get("kind") == "heat":
					hazard.set_physics_process(false)
					hazard._physics_process(0.65)
		elif index == 2:
			actor._cycle = 1
			actor.perform_attack()
		elif index == 3:
			actor.perform_attack()
			actor._update_flock(0.4)
		await frames(5)
		await save_frame("room_%d_combat" % (index + 1))
	print("LEVEL04_FOUR_ROOMS_CAPTURE PASS")
	quit()
