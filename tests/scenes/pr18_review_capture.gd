extends SceneTree
## 截图使用明确状态夹具；真实E操作和任务推进另由pr18_review_regression验收。
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
var out := "res://docs/review/pr18-evidence"
var failed := false
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func save_frame(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		failed = true
		push_error("Capture unavailable: "+name)
		return
	if image.save_png(out.path_join(name+".png")) != OK: failed = true
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	PROFILE.override_path="res://.godot/review-capture-profile.cfg"
	PROGRESS.override_path="res://.godot/review-capture-progress.cfg"
	root.size=Vector2i(1280,720)
	if "--mechanics-only" in OS.get_cmdline_user_args():
		await mechanics_capture()
		return
	change_scene_to_file("res://scenes/dungeon/Level03Run.tscn")
	await frames(10)
	var host: Node=current_scene
	host._on_run_started()
	var world: Node=host._dungeon
	var player: Node3D=host._player
	player.set_physics_process(false)
	player._invulnerability_remaining=100000
	player.global_position=world.get_node("Rooms/B").global_position+Vector3(0,0.05,2)
	await frames(3)
	for room in [&"C",&"E",&"F"]:
		player.global_position=world.get_node("Rooms/"+String(room)).global_position+Vector3(0,0.05,3)
		await frames(3)
		for enemy in world.get_node("Enemies").get_children():
			if enemy.get_meta("room",&"")==room: enemy.take_damage(999)
		await frames(3)
	world._high=false
	world._conductor=world.Conductor.WEST
	world._storage=world.Storage.STORED
	world._highwalk=true
	world._refresh_world()
	player.global_position=world.get_node("Rooms/I").global_position+Vector3(0,0.05,3)
	await frames(6)
	for enemy in world.get_node("Enemies").get_children(): enemy.set_physics_process(false)
	var camera: Camera3D=world.get_node("Camera3D")
	var tracker: Control=host._hud.get_node("LevelObjective")
	for size in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(720,720)]:
		root.size=size
		await frames(100)
		await save_frame("maintenance-battle-%dx%d" % [size.x,size.y])
	root.size=Vector2i(1280,720)
	await frames(8)
	tracker.quest_map.open_map()
	await frames(3)
	if tracker.quest_map.view.snapshot.target.id != "i_guards": failed=true
	await save_frame("maintenance-combat-map")
	tracker.quest_map.close_map()
	for enemy in world.get_node("Enemies").get_children():
		if enemy.get_meta("room",&"")==&"I": enemy.take_damage(999)
	await frames(20)
	await save_frame("maintenance-release-journal")
	tracker.quest_map.open_map()
	await frames(3)
	if tracker.quest_map.view.snapshot.target.id != "release": failed=true
	await save_frame("maintenance-release-map")
	tracker.quest_map.close_map()
	root.get_node("MusicManager").stop_music()
	print("PR18_REVIEW_CAPTURE ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func mechanics_capture() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(10)
	var host: Node=current_scene
	host._start_screen.start_button.pressed.emit()
	var selector: Control=host.get_node("MenuNavigation").character_select
	selector.show_selection("knight")
	selector.get_node("%MechanicsButton").pressed.emit()
	await frames(5)
	await save_frame("mechanics-no-passive-energy")
	root.get_node("MusicManager").stop_music()
	print("PR18_MECHANICS_CAPTURE ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
