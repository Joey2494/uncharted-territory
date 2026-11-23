extends SceneTree
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
const OUT := "res://docs/change/week11-integration-evidence"
func _initialize() -> void:
	PROFILE.override_path = "res://.godot/integration-capture-profile.cfg"
	PROGRESS.override_path = "res://.godot/integration-capture-progress.cfg"
	run.call_deferred()
func frames(n := 12) -> void:
	for i in n: await process_frame
func capture(label: String) -> void:
	await frames()
	RenderingServer.force_draw()
	var result := root.get_texture().get_image().save_png(OUT.path_join(label+".png"))
	print("INTEGRATION_CAPTURE ",label," ",result)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_node("GameSettings").data.update({"fullscreen":false,"resolution":Vector2i(1280,720)})
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	PROFILE.ensure_loaded()
	PROFILE.unlocked.assign(["knight","lan","iron","astra"])
	PROFILE.set_selected_character("lan")
	change_scene_to_file("res://Main.tscn")
	await frames(20)
	var selector = current_scene.get_node("MenuNavigation").character_select
	selector.show_selection("lan")
	selector.get_node("%SkillJump").pressed.emit()
	await capture("character-lan-skills")
	selector.get_node("%WeaponsJump").pressed.emit()
	await capture("character-lan-weapons")
	change_scene_to_file("res://scenes/dungeon/Level04Run.tscn")
	await frames(20)
	var host := current_scene
	host._on_run_started()
	var level = host._dungeon
	var player = host._player
	player._invulnerability_remaining = 10000
	level.puzzles.calibrated = true
	level._refresh_gates()
	for room: String in ["B","D","F","H","I"]:
		level.combat.demo_done = true
		player.position = level.layout.room_center(room)+Vector3(2.5,0.06,3)
		await frames(80)
		await capture("level4-room-"+room)
		for tick in 4:
			for enemy in level.combat._enemies.duplicate(): enemy.take_damage(999)
			level.combat.update_room(room,6.1)
			await frames(4)
	root.get_node("MusicManager").stop_music()
	quit()
