extends SceneTree
## 孢冠女巫原型截图：四式预警与二阶段造型，供评审与视觉回归。
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	root.size = Vector2i(1440, 900)
	change_scene_to_file("res://addons/ziyuan_level04/Prototype.tscn")
	await frames(10)
	var lab := current_scene
	lab.load_wave(0)
	await frames(10)
	var witch: Node = null
	for actor in lab._actors:
		if actor.enemy_id == "witch": witch = actor
	lab.player.global_position = Vector3(0, 0.05, 3)
	lab.player.set_physics_process(false)
	witch.set_physics_process(false)
	witch._aggro = true
	witch._battle = true
	witch.battle_started.emit()
	# Move 枚举：TRIPLE=0、PULSE=1、GUARD=2、VINE=3。
	witch.begin_attack(0)
	await frames(14)
	await capture("res://addons/ziyuan_level04/evidence/triple_spore.png")
	witch.state = witch.State.CHASE
	witch.begin_attack(3)
	await frames(14)
	await capture("res://addons/ziyuan_level04/evidence/vine_sweep.png")
	witch.state = witch.State.CHASE
	witch.begin_attack(2)
	await frames(14)
	await capture("res://addons/ziyuan_level04/evidence/spore_guard_mark.png")
	lab.load_wave(1)
	await frames(14)
	await capture("res://addons/ziyuan_level04/evidence/guards.png")
	lab.load_wave(2)
	await frames(14)
	for actor in lab._actors:
		if actor.enemy_id == "witch": actor.state_changed.emit("二阶段 · 孢冠觉醒")
	await frames(10)
	await capture("res://addons/ziyuan_level04/evidence/phase_two.png")
	print("LEVEL04_CAPTURE PASS")
	quit()
