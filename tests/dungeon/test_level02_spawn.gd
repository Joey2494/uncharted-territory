extends SceneTree
const Profile = preload("res://scripts/integration/player_profile.gd")
const Progress = preload("res://scripts/integration/campaign_progress.gd")
const Characters = preload("res://scenes/player/character_catalog.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func frames(n := 6) -> void:
	for i in n:
		await physics_frame
		await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)
func run() -> void:
	var token := "%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	Profile.override_path = "user://spawn-profile-" + token + ".cfg"
	Progress.override_path = "user://spawn-progress-" + token + ".cfg"
	Profile.set_coins(1000)
	for role in ["lan","iron","astra"]: Profile.unlock_character(role)
	var probe := "--probe" in OS.get_cmdline_user_args()
	for direct in ([false] if probe else [false,true]):
		for role in (["knight"] if probe else Characters.IDS):
			Profile.set_selected_character(role)
			Characters.selected_id = role
			Characters.start_pending = direct
			change_scene_to_file("res://scenes/dungeon/Level02Run.tscn")
			await frames()
			var host: Node3D = current_scene
			if not direct: host._on_run_started()
			var player: CharacterBody3D = host._player
			var initial: Vector3 = player.global_position
			print("SPAWN mode=",direct," role=",role," position=",initial," mask=",player.collision_mask)
			var arrival: Node3D = host._dungeon.get_node("Regions/Arrival")
			var bounds: Rect2 = arrival.get_world_bounds()
			check(bounds.grow(-0.4).has_point(Vector2(initial.x,initial.z)), "角色在到达平台安全边界内")
			await frames(2)
			for z: float in [initial.z,arrival.global_position.z]:
				var point := Vector3(initial.x,0.5,z)
				var hit := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point,point-Vector3.UP*2,1))
				print("FLOOR_PROBE bounds=",bounds," z=",z," hit=",hit.get("position","none"))
			var minimum := initial.y
			for i in 120:
				await frames(1)
				minimum = minf(minimum,player.global_position.y)
			check(host.get_run_state() == host.RunState.PLAYING and minimum > -0.05 and player.is_on_floor(), "%s direct=%s 开局两秒稳定落地，最低 %.3f 最终 %s" % [role,direct,minimum,player.global_position])
			check(player.character_id == role and player.hp == player.max_hp, "开局角色和生命正确")
			print("SETTLED position=",player.global_position," velocity=",player.velocity," on_floor=",player.is_on_floor())
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames(3)
	root.get_node("MusicManager").stop_music()
	await create_timer(0.15).timeout
	print("LEVEL02_SPAWN: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
