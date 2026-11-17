extends SceneTree
const Profile = preload("res://scripts/integration/player_profile.gd")
const Campaign = preload("res://scripts/integration/campaign_progress.gd")
func _initialize() -> void: run.call_deferred()
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
	for i in 10: await physics_frame
	for enemy in map.get_node("Enemies").get_children():
		enemy.set_physics_process(false)
		if enemy.can_process() and enemy.has_method("_update_pursuit"): enemy._aggro = true
	map.get_node("Enemies/Hub1").take_damage(1)
	map.get_node("Enemies/Hub1")._update_pursuit(0.02)
	map.get_node("Camera3D").reset_follow()
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/revision-spiders.png")
	player.global_position = Vector3(34, 0.05, -82)
	map.boss.process_mode = Node.PROCESS_MODE_PAUSABLE
	map.boss.set_physics_process(false)
	map.boss.begin_attack(map.boss.Attack.SHOCKWAVE)
	map.boss.take_damage(8)
	map.get_node("Camera3D").reset_follow()
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/revision-boss.png")
	print("CAPTURE_COMPLETE")
	quit()

