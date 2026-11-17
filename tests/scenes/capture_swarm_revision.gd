extends SceneTree
const Profile = preload("res://scripts/integration/player_profile.gd")
const Campaign = preload("res://scripts/integration/campaign_progress.gd")
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	Profile.override_path = "res://tests/capture_profile.cfg"
	Campaign.override_path = "res://tests/capture_campaign.cfg"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/dungeon/Level02Run.tscn")
	for i in 6: await process_frame
	var h := current_scene
	h._on_run_started()
	var map: Node = h.get_node("DungeonTest")
	var player: Node3D = map.player
	player.set_physics_process(false)
	player.global_position = Vector3(0, 0.05, -27)
	await frames(8)
	for enemy in map.get_node("Enemies").get_children(): enemy.set_physics_process(false)
	var spider: Node = map.get_node("Enemies/Hub1")
	spider.global_position = Vector3(0, 0.05, -32)
	spider._aggro = true
	spider._direction = Vector3.BACK
	spider.get_node("Visuals").rotation.y = PI
	h.get_node("UILayer/ResponsiveLayout").free()
	var camera: Camera3D = map.get_node("Camera3D")
	camera.set_process(false)
	camera.h_offset = 0
	camera.v_offset = 0
	camera.global_position = Vector3(0, 8.0, -21)
	camera.look_at(Vector3(0, 0.55, -29.4))
	spider._release()
	await frames(12)
	await shot("res://docs/revision-silk-thread.png")
	await frames(14)
	await shot("res://docs/revision-web-wrap.png")
	player.web_remaining = 0
	player._web_visual.hide()
	player.global_position = Vector3(0, 0.05, -21)
	spider.global_position = Vector3(0, 0.05, -29)
	spider.attack_kind = 1
	spider._release()
	spider._release()
	await frames(36)
	await shot("res://docs/revision-burrows.png")
	await frames(40)
	await shot("res://docs/revision-dense-swarm.png")
	print("SWARM_CAPTURE_COMPLETE fps=", Engine.get_frames_per_second())
	quit()


