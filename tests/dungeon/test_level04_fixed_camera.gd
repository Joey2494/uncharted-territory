extends SceneTree
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
const PLAN = preload("res://scenes/dungeon/level04/observatory_plan.gd")
var checks := 0
var failures := 0
var world: Node3D
var camera: Camera3D
var max_zoom_drift := 0.0
var max_follow_gap := 0.0
func _initialize() -> void:
	PROFILE.override_path = "user://fixed-camera-profile.cfg"
	PROGRESS.override_path = "user://fixed-camera-campaign.cfg"
	run.call_deferred()
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL "+message)
func capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	var output := OS.get_environment("GODOT_TEST_OUTPUT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"Screenshot "+label)
func run() -> void:
	change_scene_to_file("res://scenes/dungeon/Level04Run.tscn")
	await frames(12)
	var host: Node = current_scene
	host._on_run_started()
	world = host._dungeon
	camera = world.get_node("Camera3D")
	world.player._invulnerability_remaining = 100000
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	# Survey only: actual combat and walking regressions run without this fixture.
	world.set_physics_process(false)
	for id: String in world.combat.ROSTERS: world.combat._cleared[id] = true
	world.puzzles.calibrated = true
	world._refresh_gates()
	await frames(75)
	var basis := camera.global_basis
	for id: String in PLAN.CENTERS:
		var at := Vector3(0,0.05,2)
		if id == "I": at = Vector3(4,0.05,3)
		elif id == "D": at = Vector3(3,0.05,2.4)
		world.player.global_position = world.layout.room_center(id)+at
		world.player.velocity = Vector3.ZERO
		camera.reset_follow()
		await frames(12)
		check(is_equal_approx(camera._distance,18.5) and camera.global_basis.is_equal_approx(basis) and is_equal_approx(camera.fov,52),"Same distance, pitch and FOV in "+id)
		check(camera._focus.distance_to(world.player.global_position+Vector3.UP)<0.1,"Focus belongs to player, not room centre "+id)
		await capture("room-"+id)
	for link: String in PLAN.LINKS:
		for reverse in [false,true]:
			var path := PLAN.bridge_path(link[1],link[0]) if reverse else PLAN.bridge_path(link[0],link[1])
			world.player.global_position = Vector3(path[0].x,0.05,path[0].y)
			world.player.velocity = Vector3.ZERO
			camera.reset_follow()
			for segment in range(path.size()-1):
				var steps := ceili(path[segment].distance_to(path[segment+1])/0.30)
				for n in range(1,steps+1):
					var at := path[segment].lerp(path[segment+1],float(n)/steps)
					world.player.global_position = Vector3(at.x,0.05,at.y)
					world.player.velocity = Vector3.ZERO
					await frames(1)
					max_zoom_drift = maxf(max_zoom_drift,absf(camera._distance-18.5))
					max_follow_gap = maxf(max_follow_gap,camera._focus.distance_to(world.player.global_position+Vector3.UP))
			check(max_zoom_drift < 0.001 and camera.is_position_in_frustum(world.player.global_position+Vector3.UP),"Fixed scale through corridor and bends "+link+str(reverse))
	check(max_follow_gap < 3.0,"Smooth player follow has a bounded lag through every corner")
	world.player.global_position = world.layout.room_center("I")+Vector3(4,0.05,3)
	camera.reset_follow()
	var actor := Node3D.new()
	world.add_child(actor)
	actor.add_to_group("camera_targets")
	actor.position = world.layout.room_center("I")+Vector3(-9,0,-6)
	await frames(6)
	check(is_equal_approx(camera._distance,18.5) and camera._focus.distance_to(world.player.global_position+Vector3.UP)<0.1,"Distant reinforcement never zooms or recentres camera")
	actor.queue_free()
	for dimensions in [Vector2i(800,600),Vector2i(720,720),Vector2i(480,800),Vector2i(1280,720)]:
		root.size = dimensions
		await frames(12)
		check(is_equal_approx(camera._distance,18.5),"HUD resizing retains distance "+str(dimensions))
	var tracker: Control = host._hud.get_node("LevelObjective")
	check(tracker.quest_map.open_map(),"Migrated M map remains available")
	var position := camera.global_transform
	await frames(5)
	check(camera.global_transform.is_equal_approx(position),"Map pause freezes camera")
	tracker.quest_map.close_map()
	check(world.has_node("RouteMap"),"Existing Tab route map remains installed")
	paused = false
	root.get_node("MusicManager").stop_music()
	host.queue_free()
	await frames(4)
	print("LEVEL04_FIXED_CAMERA_RESULT %d checks, %d failures; zoom_drift=%.5f follow_gap=%.3f" % [checks,failures,max_zoom_drift,max_follow_gap])
	quit(1 if failures else 0)
