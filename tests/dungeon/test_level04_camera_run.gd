extends SceneTree
## 真实关卡中从 H 入口连续行走至 I。只预置已通过的前段与角色免伤，援军和半血推进走正式状态机。
const PLAN := preload("res://scenes/dungeon/level04/observatory_plan.gd")
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
	var wing := "E" if "--east" in OS.get_cmdline_user_args() else "F"
	var entry := PLAN.bridge_path("H",wing)
	var door := entry[0]
	var outward := door.direction_to(entry[1])
	player.position = Vector3(door.x + outward.x*3,0.05,door.y + outward.y*3)
	var into_dome := PLAN.bridge_path("H","I")
	into_dome.append(Vector2(i.x-2.5,i.z+4.4))
	var waypoint := 0
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
	while elapsed < 50.0:
		var next := Vector2(player.position.x,player.position.z)
		if not combat.is_clear("H"):
			if combat.active_room != "H":
				next = Vector2(h.x, h.z+4.0)
				if combat.demo_done and absf(player.position.x-h.x) < 1.0:
					next = Vector2(h.x,h.z+1.9)
			if combat.active_room == "H":
				h_age += root.get_process_delta_time()
				warning = warning or combat._markers.H.visible
				reinforced = reinforced or combat.enemy_count() == combat.ROSTERS["H"].size()+1
				if reinforced and h_age > 6.8:
					for guard: Node in combat._enemies.duplicate(): guard.take_damage(999)
		else:
			if level.layout.passage_open("H","I") and combat.active_room != "I":
				var pos := Vector2(player.position.x,player.position.z)
				if pos.distance_to(into_dome[waypoint]) < 0.24 and waypoint+1 < into_dome.size():
					waypoint += 1
				next = into_dome[waypoint]
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
		walk_toward(player,next)
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
	walk_toward(player,Vector2(player.position.x,player.position.z))
	var ok: bool = warning and reinforced and advance_finished and advanced_distance > 1.5 and not player.is_dead()
	ok = ok and is_equal_approx(h_reference,18.5) and is_equal_approx(i_reference,18.5) and h_drift < 0.001 and i_drift < 0.001 and max_speed < 0.001
	print("level04 camera run: warning=%s reinforced=%s half_advance=%s moved=%.2fm H_drift=%.3f I_drift=%.3f max_speed=%.2f" % [warning,reinforced,advance_finished,advanced_distance,h_drift,i_drift,max_speed])
	if not ok: print("CAMERA_ROUTE_DIAGNOSTIC position=",player.position," room=",combat.active_room," H_clear=",combat.is_clear("H")," I_age=",i_age)
	level.queue_free()
	for n in 3: await process_frame
	quit(0 if ok else 1)


func walk_toward(player: CharacterBody3D, target: Vector2) -> void:
	var delta := target-Vector2(player.position.x,player.position.z)
	var direction := Vector2.ZERO if delta.length() < 0.12 else delta.normalized()
	for action: String in ["move_left","move_right","move_forward","move_backward"]:
		Input.action_release(action)
	if absf(direction.x) > 0.05:
		Input.action_press("move_right" if direction.x > 0 else "move_left",absf(direction.x))
	if absf(direction.y) > 0.05:
		Input.action_press("move_backward" if direction.y > 0 else "move_forward",absf(direction.y))
