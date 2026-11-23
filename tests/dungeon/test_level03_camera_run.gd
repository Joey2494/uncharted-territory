extends SceneTree
## 固定 30 Hz 输入，从已泄压的北通道步入 G；真实敌人追击、预警与召援皆运行。
const Profile = preload("res://scripts/integration/player_profile.gd")
const Progress = preload("res://scripts/integration/campaign_progress.gd")
const FPS := 30

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	seed(1103)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 600)
	var token := "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	Profile.override_path = "user://camera-run-profile-" + token + ".cfg"
	Progress.override_path = "user://camera-run-progress-" + token + ".cfg"
	change_scene_to_file("res://scenes/dungeon/Level03Run.tscn")
	for i in 8: await process_frame
	var host: Node = current_scene
	host._on_run_started()
	var map: Node = host._dungeon
	var player: CharacterBody3D = host._player
	var camera: Camera3D = map.get_node("Camera3D")
	# 起点位于已泄压的 B—G 通道，小段路线只设置初始位置，随后全程物理行走。
	map._storage = map.Storage.RELEASED
	map._refresh_world()
	player.global_position = Vector3(0, 0.05, -11)
	player._invulnerability_remaining = 1000
	camera.reset_follow()
	var first := -1
	var clear := -1
	var start_distance: float = camera._distance
	var peak := start_distance
	var previous := start_distance
	var maximum_step := 0.0
	var combat_min := INF
	var combat_max := 0.0
	var summoned := false
	for tick in 240:
		match tick:
			8: Input.action_press("move_forward")
			70:
				Input.action_release("move_forward")
				Input.action_press("move_right")
			93:
				Input.action_release("move_right")
				Input.action_press("move_backward")
			111:
				Input.action_release("move_backward")
				Input.action_press("move_left")
			140:
				Input.action_release("move_left")
				host._boss.take_damage(45)
			170: Input.action_press("move_forward")
			192: Input.action_release("move_forward")
			205:
				for enemy in map.get_node("Enemies").get_children():
					if enemy.get_meta("room", &"") == &"G" and not enemy.is_dead():
						enemy.take_damage(999)
		var elapsed := 0.0
		while elapsed < 1.0 / FPS - 0.00001:
			await process_frame
			elapsed += root.get_process_delta_time()
		if map._active_room == &"G":
			if first < 0: first = tick
			# 留出入场缓动时间，随后的实际战斗不能随站位或援军反复升降。
			if tick > first + FPS:
				combat_min = minf(combat_min, camera._distance)
				combat_max = maxf(combat_max, camera._distance)
		elif first >= 0 and clear < 0:
			clear = tick
		summoned = summoned or map._summons.size() == 2
		var distance: float = camera._distance
		peak = maxf(peak, distance)
		maximum_step = maxf(maximum_step, absf(distance - previous))
		previous = distance
		if tick % 5 == 0 or tick == first or tick == clear:
			print("SAMPLE ", tick, " room=", map._active_room, " distance=", snappedf(distance, 0.01), " pos=",player.global_position.snapped(Vector3.ONE * 0.1), " target_count=",camera._get_actors().size(), " frame=",camera.get_safe_frame())
	var drift := combat_max-combat_min
	print("CAMERA_RUN entry=%d clear=%d summoned=%s start=%.2f peak=%.2f max_step=%.2f battle_drift=%.2f" % [first, clear, summoned, start_distance, peak, maximum_step, drift])
	var ok := first >= 0 and clear > first and summoned and peak < 35.0 and drift < 0.15 and maximum_step < 1.0
	host.queue_free()
	for i in 3: await process_frame
	root.get_node("MusicManager").stop_music()
	await create_timer(0.2).timeout
	for path in [Profile.override_path, Progress.override_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(0 if ok else 1)
