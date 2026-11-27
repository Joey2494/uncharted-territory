extends SceneTree
## Regressions: map identity must not reveal shades; portrait attackers stay visible.
var failures := 0
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
func _initialize() -> void:
	PROFILE.override_path = "res://.godot/pr21-probe.cfg"
	PROGRESS.override_path = "res://.godot/pr21-probe-progress.cfg"
	run.call_deferred()
func frames(n := 8) -> void:
	for i in n: await process_frame
func run() -> void:
	change_scene_to_file("res://scenes/dungeon/Level04Run.tscn")
	await frames(16)
	var host := current_scene
	host._on_run_started()
	var world = host._dungeon
	var combat = world.combat
	var player = world.player
	world.set_physics_process(false)
	player._invulnerability_remaining = 10000
	player.position = world.layout.room_center("B")+Vector3(-3.8,0.06,3.3)
	combat.update_room("B",0.016)
	for enemy in combat._enemies: enemy.set_physics_process(false)
	var shade = combat._enemies[0]
	shade.position = world.layout.room_center("B")+Vector3(-6,0.06,-2)
	player.position = shade.position+Vector3(0,0,2)
	await frames()
	shade.take_damage(1)
	await frames(2)
	if ResourceLoader.exists("res://scenes/dungeon/level04/observatory_floor_map.gd"):
		var data: Dictionary = load("res://scenes/dungeon/level04/observatory_floor_map.gd").read(world)
		var echoes: Array = get_nodes_in_group("l4_enemies").filter(func(e): return e.has_method("is_decoy") and e.is_decoy())
		if echoes.size() != 2: failures += 1
		var fake_marks := 0
		for echo in echoes:
			for mark in data.enemies:
				if mark.point.distance_to(Vector2(echo.global_position.x,echo.global_position.z)) < 0.01: fake_marks += 1
		var true_marks := 0
		for mark in data.enemies:
			if mark.point.distance_to(Vector2(shade.global_position.x,shade.global_position.z)) < 0.01: true_marks += 1
		print("SHADE_MAP_PROBE real_actors=",combat._enemies.size()," decoys=",echoes.size()," map_marks=",data.enemies.size()," real_shade_mark=",true_marks," decoy_marks=",fake_marks)
		if fake_marks != 2 or true_marks != 1 or data.enemies.size() != 4: failures += 1
		paused = true
		var paused_map: Dictionary = load("res://scenes/dungeon/level04/observatory_floor_map.gd").read(world)
		if paused_map.enemies.size() != 4: failures += 1
		paused = false
	for enemy in combat._enemies.duplicate(): enemy.take_damage(999)
	combat.update_room("B",0.016)
	player.position = world.layout.room_center("I")+Vector3(6,0.06,-4)
	combat.update_room("I",0.016)
	var witch = combat.boss_guard()
	witch.position = world.layout.room_center("I")+Vector3(-4,0.06,-4)
	witch.set_physics_process(false)
	var camera = world.get_node("Camera3D")
	for dimensions in [Vector2i(1280,720),Vector2i(720,720),Vector2i(480,800)]:
		root.size = dimensions
		camera.reset_follow()
		await frames(90)
		if not camera.is_position_in_frustum(witch.global_position+Vector3.UP) or not camera.is_position_in_frustum(player.global_position+Vector3.UP): failures += 1
		var ui = host._hud.get_node("CooldownBar/MeleeCooldown")
		print("CAMERA_PROBE size=",dimensions," player_visible=",camera.is_position_in_frustum(player.global_position+Vector3.UP)," boss_visible=",camera.is_position_in_frustum(witch.global_position+Vector3.UP)," boss_can_see=",witch._can_see(player.global_position)," distance=",witch.global_position.distance_to(player.global_position)," native_attack_reach=",witch.definition.reach," J_size=",ui.size)
	witch._pursue(0.016)
	print("BOSS_PROBE native_state_after_pursue=",witch.state," windup_state=",witch.State.WINDUP)
	if witch.state != witch.State.WINDUP: failures += 1
	current_scene.queue_free()
	await frames()
	print("LEVEL04_COMBAT_VISIBILITY_RESULT failures=%d" % failures)
	quit(1 if failures else 0)
