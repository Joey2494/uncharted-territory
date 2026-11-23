extends SceneTree
## 全程真实WASD跨入/离开I，战斗中不重置镜头。固定60FPS便于量化缩放连续性。
const Profile = preload("res://scripts/integration/player_profile.gd")
const Progress = preload("res://scripts/integration/campaign_progress.gd")
var checks := 0
var failures := 0
var host: Node
var player: CharacterBody3D
var map: Node3D
var camera: Camera3D
var capture_enabled := false
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ",message)
func actors_fit() -> bool:
	var frame: Rect2 = camera.get_safe_frame().grow(0.002)
	var viewport := camera.get_viewport().get_visible_rect().size
	for actor in camera._get_actors():
		var dims: Vector2 = camera._actor_dimensions(actor)
		var r: float = dims.x+camera.actor_padding
		for x in [-r,r]:
			for z in [-r,r]:
				for y in [0.0,dims.y+camera.actor_padding]:
					var at: Vector3 = actor.global_transform*Vector3(x,y,z)
					if camera.is_position_behind(at) or not frame.has_point(camera.unproject_position(at)/viewport): return false
	return true
func walk(to: Vector2, label: String) -> void:
	var previous: float = camera._distance
	var max_step := 0.0
	var active_ticks := 0
	var lost_frame := false
	var combat_low := INF
	var combat_high := 0.0
	for tick in 600:
		var offset := to-Vector2(player.global_position.x,player.global_position.z)
		if offset.length()<0.18: break
		var dir := offset.normalized()
		for pair in [["move_left",-dir.x],["move_right",dir.x],["move_forward",-dir.y],["move_backward",dir.y]]:
			if pair[1]>0.12: Input.action_press(pair[0],pair[1])
			else: Input.action_release(pair[0])
		await process_frame
		max_step=maxf(max_step,absf(camera._distance-previous))
		previous=camera._distance
		if map._active_room==&"I":
			active_ticks+=1
			if active_ticks>36:
				lost_frame=lost_frame or not actors_fit()
				combat_low=minf(combat_low,camera._distance)
				combat_high=maxf(combat_high,camera._distance)
	for action in ["move_left","move_right","move_forward","move_backward"]: Input.action_release(action)
	check(Vector2(player.global_position.x,player.global_position.z).distance_to(to)<0.3,label+" reaches destination through real physics")
	check(max_step<0.6,label+" camera moves continuously without a reset jump")
	check(not lost_frame,label+" complete actor silhouettes stay inside safe frame during battle")
	if combat_low<INF: check(combat_high-combat_low<0.15,label+" fixed battle framing stays stable")
func run() -> void:
	capture_enabled="--capture" in OS.get_cmdline_user_args()
	var token := "%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	Profile.override_path="res://.godot/review-camera-profile-"+token+".cfg"
	Progress.override_path="res://.godot/review-camera-progress-"+token+".cfg"
	for size in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(720,720)]:
		root.mode=Window.MODE_WINDOWED
		root.size=size
		change_scene_to_file("res://scenes/dungeon/Level03Run.tscn")
		await frames(10)
		host=current_scene
		host._on_run_started()
		map=host._dungeon
		player=host._player
		player._invulnerability_remaining=100000
		camera=map.get_node("Camera3D")
		# 仅设置初始主线状态与出发位置；之后全部实际行走且不调用reset_follow。
		map._highwalk=true
		map._high=false
		map._refresh_world()
		player.global_position=Vector3(-25,0.05,-11)
		await frames(100)
		await walk(Vector2(-25,-20),str(size)+" entering I")
		check(map._active_room==&"I" and map._progress.get_remaining_enemies(&"I")==1,"I encounter activates with one jailer at "+str(size))
		await frames(100)
		check(actors_fit(),"I full silhouettes fit after actual entry at "+str(size))
		await walk(Vector2(-21,-20),str(size)+" moving across I")
		await walk(Vector2(-21,-26),str(size)+" fighting along I side")
		check(camera._cached_arena==&"I" and is_equal_approx(camera._weight,1),"I selects fixed arena framing at "+str(size))
		if capture_enabled:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/review/pr18-evidence/maintenance-camera-%dx%d.png" % [size.x,size.y])
		for enemy in map.get_node("Enemies").get_children():
			if enemy.get_meta("room",&"")==&"I": enemy.take_damage(999)
		await frames(45)
		await walk(Vector2(-25,-20),str(size)+" leaving I center")
		await walk(Vector2(-25,-11),str(size)+" exiting I to corridor")
		await walk(Vector2(-25,-20),str(size)+" reentering cleared I")
		check(map._progress.is_complete(&"I") and map._active_room==&"","I remains cleared after continuous reentry at "+str(size))
	host.queue_free()
	await frames(3)
	root.get_node("MusicManager").stop_music()
	print("LEVEL03_MAINTENANCE_CAMERA %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
