extends SceneTree
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1440,900))
	root.size=Vector2i(1440,900)
	change_scene_to_file("res://addons/ziyuan_level03/Prototype.tscn")
	await frames(8)
	var lab:=current_scene
	lab.show_gallery()
	await frames(15)
	await capture("res://addons/ziyuan_level03/evidence/roster.png")
	lab.load_wave(3)
	for actor in lab._actors:
		actor.set_physics_process(false)
		actor._aggro=true
		if actor.enemy_id=="chain_jailer": actor.begin_attack()
	lab.player.set_physics_process(false)
	await frames(12)
	await capture("res://addons/ziyuan_level03/evidence/chain.png")
	lab.load_wave(4)
	lab.player.global_position=Vector3(0,0.05,3)
	lab.player.set_physics_process(false)
	var boss: Node=lab._actors[0]
	boss.set_physics_process(false)
	boss._aggro=true
	boss._battle=true
	boss.battle_started.emit()
	boss.begin_attack(1)
	await frames(12)
	await capture("res://addons/ziyuan_level03/evidence/boss.png")
	print("LEVEL03_CAPTURE PASS")
	quit()
