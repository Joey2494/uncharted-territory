extends SceneTree
func _initialize() -> void: run.call_deferred()
func frames(n: int = 8) -> void:
	for i in n: await physics_frame
	await process_frame
func capture(label: String) -> void:
	var camera := current_scene.get_node_or_null("DungeonTest/Camera3D")
	if camera != null: camera.reset_follow()
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/swap_%s.png" % label)
func run() -> void:
	var profile = preload("res://scripts/integration/player_profile.gd")
	profile.override_path = "res://.godot/swap_visual_profile.cfg"
	if FileAccess.file_exists(profile.override_path): DirAccess.remove_absolute(profile.override_path)
	profile.ensure_loaded()
	profile.set_coins(150)
	profile.unlock_character("iron")
	preload("res://scripts/integration/campaign_progress.gd").override_path = "res://.godot/swap_visual_campaign.cfg"
	preload("res://scenes/player/character_catalog.gd").selected_id = "iron"
	change_scene_to_file("res://Main.tscn")
	await frames()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main := current_scene
	await capture("guard_menu")
	main._on_run_started()
	await frames()
	var tutorial := main.get_node("RunBindings/TutorialController")
	tutorial.index = 6
	tutorial._show()
	await capture("opening_potion")
	var player := main.get_node("DungeonTest/Player")
	player.global_position = main._dungeon.get_node("AttackRune").global_position + Vector3(0, 0, 0.7)
	await capture("branch_rune_pickup")
	main._items.try_interact_nearest()
	await capture("branch_rune_use")
	tutorial.skip()
	player.global_position = Vector3(0, 0.05, -23)
	await frames()
	main._dungeon.get_node("MeleeEnemy").take_damage(1000)
	await frames(72)
	player.global_position = Vector3(22, 0.05, -23)
	await frames()
	var boss = main._dungeon.get_node("RuinGatekeeper")
	boss._begin_charge((player.global_position - boss.global_position).normalized())
	boss.set_physics_process(false)
	main._boss_bar.begin_encounter(boss.boss_name, boss.hp, boss.max_hp)
	main._boss_bar.update_state("铜甲冲锋 · 注意预警")
	await capture("boss_guard")
	current_scene = null
	main.free()
	await frames()
	quit()
