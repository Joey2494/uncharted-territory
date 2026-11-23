extends SceneTree
## 渲染截图验证，不需要桌面交互。
func _initialize() -> void: run.call_deferred()
func frames(count: int) -> void:
	for i in count: await process_frame
func save_frame(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://addons/ziyuan_level04/evidence/" + label + ".png")
func run() -> void:
	root.size = Vector2i(1280, 900)
	change_scene_to_file("res://addons/ziyuan_level04/previews/WitchPreview.tscn")
	await frames(12)
	current_scene.model.rotation.y = PI - 0.25
	await frames(3)
	await save_frame("witch_reference_model")
	current_scene.model.rotation.y = PI + 1.0
	await frames(3)
	await save_frame("witch_reference_side")
	change_scene_to_file("res://addons/ziyuan_level04/Prototype.tscn")
	await frames(8)
	var lab := current_scene
	var boss: Node = lab._actors[0]
	lab.player.set_physics_process(false)
	lab.player.global_position = Vector3(3, 0.05, 3)
	boss.set_physics_process(false)
	boss.global_position = Vector3(3, 0.05, -3)
	boss._visual.rotation.y = PI
	boss.state = boss.State.CHASE
	boss.begin_attack(0)
	boss._tick_strike(0.72)
	await frames(12)
	await save_frame("direct_spores")
	boss._clear_hazards()
	boss.state = boss.State.CHASE
	boss.begin_attack(3)
	for node in get_nodes_in_group("l4_hazards"):
		if node.get("_travel") != null: node._physics_process(0.8)
	await frames(12)
	await save_frame("direct_vine")
	lab.load_wave(1)
	await frames(8)
	await save_frame("reference_combat")
	print("LEVEL04_REFERENCE_CAPTURE PASS")
	quit()
