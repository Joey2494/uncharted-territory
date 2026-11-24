extends SceneTree
## 真实关卡中从 H 入口连续行走至 I。只预置已通过的前段与角色免伤，援军和半血推进走正式状态机。
const SCENE := "res://scenes/dungeon/level04/Level04Preview.tscn"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(960,600)
	change_scene_to_file(SCENE)
	for n in 5: await physics_frame
	var level := current_scene
	var combat: Node = level.combat
	var player: CharacterBody3D = level.player
	var camera: Camera3D = level.get_node("Camera3D")
	for room in ["B","F"]: combat._cleared[room] = true
	level.puzzles.calibrated = true
	level._refresh_gates()
	var h: Vector3 = level.layout.room_center("H")
	var i: Vector3 = level.layout.room_center("I")
	player.position = h + Vector3(0,0.05,10)
	player._invulnerability_remaining = 1000
	camera.reset_follow()
	var previous: float = camera._distance
	var max_speed := 0.0
	var h_reference := -1.0
	var i_reference := -1.0
	var h_drift := 0.0
	var i_drift := 0.0
	var warning := false
	var reinforced := false
	var advance_seen := false
	var advance_finished := false
	var advanced_distance := 0.0
	var advance_start := Vector3.ZERO
	var h_age := 0.0
	var i_age := 0.0
	var elapsed := 0.0
	while elapsed < 38.0:
		var walking: bool
		if not combat.is_clear("H"):
			walking = player.position.z > h.z + (1.9 if combat.demo_done else 5.0)
			if combat.active_room == "H":
				h_age += root.get_process_delta_time()
				warning = warning or combat._markers.H.visible
				reinforced = reinforced or combat.enemy_count() == combat.ROSTERS["H"].size()+1
				if reinforced and h_age > 6.8:
					for guard: Node in combat._enemies.duplicate(): guard.take_damage(999)
		else:
			walking = level.layout.passage_open("H","I") and player.position.z > i.z + 4.4
			# Flock contact can move the actor sideways. Align with the real bridge
			# using movement input before continuing north through the angled wall.
			if player.position.z > h.z-10 and absf(player.position.x) > 0.18:
				walking = false
				Input.action_press("move_right" if player.position.x < 0 else "move_left")
			else:
				Input.action_release("move_left")
				Input.action_release("move_right")
			if combat.active_room == "I":
				i_age += root.get_process_delta_time()
				if i_age > 1.4 and not advance_seen and combat._jailer.hp * 2 > combat._jailer.max_hp:
					combat._jailer.take_damage(ceili(combat._jailer.max_hp / 2.0))
				if combat._jailer.advancing:
					if not advance_seen: advance_start = combat._jailer.position
					advanced_distance = maxf(advanced_distance,advance_start.distance_to(combat._jailer.position))
					advance_seen = true
				elif advance_seen:
					advance_finished = true
		if walking: Input.action_press("move_forward")
		else: Input.action_release("move_forward")
		await process_frame
		var step := root.get_process_delta_time()
		elapsed += step
		var distance: float = camera._distance
		max_speed = maxf(max_speed,absf(distance-previous)/maxf(step,0.00001))
		previous = distance
		if combat.active_room == "H" and h_age > 1.0:
			if h_reference < 0: h_reference = distance
			h_drift = maxf(h_drift,absf(distance-h_reference))
		if combat.active_room == "I" and i_age > 1.0:
			if i_reference < 0: i_reference = distance
			i_drift = maxf(i_drift,absf(distance-i_reference))
		if advance_finished: break
	Input.action_release("move_forward")
	Input.action_release("move_left")
	Input.action_release("move_right")
	var ok: bool = warning and reinforced and advance_finished and advanced_distance > 1.5 and not player.is_dead()
	ok = ok and h_reference > 0 and i_reference > 0 and h_drift < 0.10 and i_drift < 0.10 and max_speed < 12.1
	print("level04 camera run: warning=%s reinforced=%s half_advance=%s moved=%.2fm H_drift=%.3f I_drift=%.3f max_speed=%.2f" % [warning,reinforced,advance_finished,advanced_distance,h_drift,i_drift,max_speed])
	if not ok: print("CAMERA_ROUTE_DIAGNOSTIC position=",player.position," room=",combat.active_room," H_clear=",combat.is_clear("H")," I_age=",i_age)
	level.queue_free()
	for n in 3: await process_frame
	quit(0 if ok else 1)
