extends SceneTree
## 墓穴专用相机继承共享构图，验证高墙淡出、原生敌人轮廓和隔离存档。
## 实战截图另由 test_level03_enemy_integration.gd -- --capture 验证。
const Profile = preload("res://scripts/integration/player_profile.gd")
const Progress = preload("res://scripts/integration/campaign_progress.gd")
var host: Node3D
var camera: Camera3D
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func frames(n := 6) -> void:
	for i in n:
		await physics_frame
		await process_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", message)
func fits(point: Vector3) -> bool:
	return not camera.is_position_behind(point) and camera.get_safe_frame().grow(0.001).has_point(camera.unproject_position(point) / camera.get_viewport().get_visible_rect().size)

func check_actors(label: String) -> void:
	var actors: Array[Node3D] = camera._get_actors()
	for actor in actors:
		var dimensions: Vector2 = camera._actor_dimensions(actor)
		var radius: float = dimensions.x + camera.actor_padding
		var visible := true
		for x: float in [-radius, radius]:
			for z: float in [-radius, radius]:
				for y: float in [0.0, dimensions.y + camera.actor_padding]:
					visible = visible and fits(actor.global_transform * Vector3(x,y,z))
		check(visible, label + " 完整角色轮廓在可视范围内：" + actor.name)

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	var token := "%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	Profile.override_path = "user://camera3-first-profile-" + token + ".cfg"
	Progress.override_path = "user://camera3-first-progress-" + token + ".cfg"
	var first: Node3D = load("res://scenes/dungeon/DungeonTest.tscn").instantiate()
	var reference: Camera3D = first.get_node("Camera3D")
	var preview: Node3D = load("res://scenes/dungeon/level03/Level03Preview.tscn").instantiate()
	var preview_camera: Camera3D = preview.get_node("Camera3D")
	var tomb_script = load("res://scenes/dungeon/level03/tomb_camera.gd")
	check(preview_camera.get_script() == tomb_script and tomb_script.get_base_script() == reference.get_script(), "墓穴专用相机继承共享相机")
	for key in ["near","far","follow_speed","zoom_speed","actor_padding"]:
		check(is_equal_approx(float(preview_camera.get(key)),float(reference.get(key))), "预览相机参数与第一关相同：" + key)
	check(is_equal_approx(preview_camera.pitch_degrees,55.0) and is_equal_approx(preview_camera.minimum_distance,15.0) and is_equal_approx(preview_camera.fov,60.0),"恢复墓穴相机俯角、最短距离与视场")
	preview.free()
	for size in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(720,720)]:
		root.size = size
		change_scene_to_file("res://scenes/dungeon/Level03Run.tscn")
		await frames(10)
		host = current_scene
		host._on_run_started()
		var map: Node3D = host._dungeon
		var player: CharacterBody3D = host._player
		player.set_physics_process(false)
		player._invulnerability_remaining = 1000
		camera = map.get_node("Camera3D")
		for enemy in map.get_node("Enemies").get_children(): enemy.set_physics_process(false)
		await frames()
		check(camera.get_script() == tomb_script, "%s 正式入口使用墓穴专用相机" % size)
		check(not host.get_node("UILayer/ResponsiveLayout").compact_combat_layout and not host._commerce.external_shortcut_layout, "第三关使用第一关的 HUD 与取景布局配置")
		check(is_equal_approx(camera.rotation_degrees.x,-55.0), "实际俯角使用墓穴构图")
		for key in ["near","far","follow_speed","zoom_speed","actor_padding"]:
			check(is_equal_approx(float(camera.get(key)),float(reference.get(key))), "正式入口参数与第一关相同：" + key)
		camera.reset_follow()
		var before: Vector3 = camera._focus
		player.global_position += Vector3(1.5,0,-1.5)
		var destination: Vector3 = camera._desired_focus(camera._get_actors())
		await frames(8)
		check(camera._focus.distance_to(destination) < before.distance_to(destination) and not camera._focus.is_equal_approx(before), "探索使用第一关的缓动跟随")
		for id in [&"C",&"E",&"F",&"G"]:
			player.global_position = map.get_node("Rooms/" + String(id)).global_position + Vector3(0,0.05,3)
			await frames()
			if id == &"G":
				host._boss._pursue(0.0)
				host._boss.take_damage(45)
				await frames()
				check(host._boss_bar.visible and map._summons.size() == 2, "第一关镜头下首领栏与半血援军正常")
			camera.reset_follow()
			await frames(12)
			check_actors("%s %s" % [size,id])
			check(camera._get_actors().all(func(actor: Node3D) -> bool: return actor == player or actor.get_meta("room", &"") == id), "取景只包含当前战斗房的敌人")
			for enemy in map.get_node("Enemies").get_children():
				if enemy.get_meta("room", &"") == id and not enemy.get_meta("summoned",false) and not enemy.is_dead(): enemy.take_damage(999)
			await frames()
		var paused_view: Transform3D = camera.get_camera_transform()
		host.set_paused(true)
		await create_timer(0.12).timeout
		check(camera.get_camera_transform().is_equal_approx(paused_view), "暂停冻结镜头")
		host.set_paused(false)
	first.free()
	host.queue_free()
	await frames(3)
	root.get_node("MusicManager").stop_music()
	await create_timer(0.15).timeout
	print("LEVEL03_CAMERA: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
