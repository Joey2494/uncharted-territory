extends SceneTree
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://addons/ziyuan_level03/evidence/"+name+".png")
func run() -> void:
	root.size=Vector2i(1440,900)
	change_scene_to_file("res://addons/ziyuan_level03/Prototype.tscn")
	await frames(8)
	var lab:=current_scene
	for index in 5:
		lab.load_wave(index)
		await frames(3)
		lab.player.set_physics_process(false)
		lab.player.global_position=Vector3(2,0.05,3)
		var actor: Node=lab._actors[0]
		for other in lab._actors: other.set_physics_process(false)
		actor.global_position=Vector3(2,0.05,-2)
		actor.state=actor.State.CHASE
		actor.begin_attack(1 if index==4 else -1)
		actor._tick_strike(actor._duration*0.4)
		actor._visual.pose(actor.state,0.4,0,0.1,actor._strike_index)
		await frames(3)
		await capture("direct_"+actor.enemy_id)
	print("LEVEL03_DIRECT_CAPTURE PASS")
	quit()
