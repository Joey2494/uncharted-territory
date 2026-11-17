extends SceneTree
## 用真实物理运动与逐帧视图检查交互台、档案室出入，避免只验证节点属性。
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func run() -> void:
	preload("res://scripts/integration/player_profile.gd").override_path = "user://collision-profile-%d.cfg" % Time.get_ticks_usec()
	preload("res://scripts/integration/campaign_progress.gd").override_path = "user://collision-progress-%d.cfg" % Time.get_ticks_usec()
	var level: Node3D = load("res://scenes/dungeon/level03/Level03Preview.tscn").instantiate()
	root.add_child(level)
	await frames(5)
	var player: CharacterBody3D = level.get_node("Player")
	player.set_physics_process(false)
	for station: Node3D in level.get_node("Stations").get_children():
		for direction in [Vector3.RIGHT, Vector3.FORWARD]:
			var pose := player.global_transform
			pose.origin = station.global_position-direction*1.5+Vector3.UP*0.05
			check(player.test_move(pose, direction*3), "交互台阻止角色扫掠穿越："+station.name)
		var center := station.global_position+Vector3.UP*0.4
		var hit := level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center-Vector3.RIGHT*1.5,center+Vector3.RIGHT*1.5,1))
		check(not hit.is_empty(), "交互台实体阻挡射线："+station.name)
	player.global_position=level.get_node("Stations/tide").global_position+Vector3(0,0.05,1.2)
	check(level.get_node("Stations/tide").can_interact(player), "补碰撞后仍可在台前交互")
	level.queue_free()
	await frames(3)
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1152,720)
	root.add_child(viewport)
	var host: Node3D=load("res://scenes/dungeon/Level02Run.tscn").instantiate()
	viewport.add_child(host)
	host._on_run_started()
	await frames(5)
	var camera: Camera3D=host._dungeon.get_node("Camera3D")
	var puzzle: Node3D=host._dungeon.puzzle
	player=host._player
	player.set_physics_process(false)
	camera.set_process(false)
	# 东侧通道进出：每帧移动 0.06 米，模拟真实步行，不用跨地图瞬移代替过门。
	player.global_position=puzzle.to_global(Vector3(10,0.05,0))
	camera.reset_follow()
	for direction in [-1,1]:
		var worst:=0.0
		var visible_all:=true
		for i in 70:
			var before:=camera.global_position
			player.position.x+=direction*0.06
			camera._process(1.0/60.0)
			# 放行真实帧的延迟 HUD 布局回调，再检查屏幕最终构图。
			await process_frame
			worst=maxf(worst,before.distance_to(camera.global_position))
			for height: float in [0.05,2.0]:
				var point:=player.global_position+Vector3.UP*height
				visible_all=visible_all and not camera.is_position_behind(point) and camera.get_safe_frame().grow(0.01).has_point(camera.unproject_position(point)/Vector2(viewport.size))
		check(worst<0.9, "档案室东门双向切换无单帧跳变：%.3f" % worst)
		check(visible_all,"东门过渡逐帧保留玩家上下轮廓")
	# 北侧密室通道也覆盖往返，不能只修正东侧入口。
	player.global_position=puzzle.to_global(Vector3(0,0.05,-10))
	camera.reset_follow()
	for direction in [1,-1]:
		var worst:=0.0
		var visible_all:=true
		for i in 70:
			var before:=camera.global_position
			player.position.z+=direction*0.06
			camera._process(1.0/60.0)
			# 放行真实帧的延迟 HUD 布局回调，再检查屏幕最终构图。
			await process_frame
			worst=maxf(worst,before.distance_to(camera.global_position))
			for height: float in [0.05,2.0]:
				var point:=player.global_position+Vector3.UP*height
				visible_all=visible_all and not camera.is_position_behind(point) and camera.get_safe_frame().grow(0.01).has_point(camera.unproject_position(point)/Vector2(viewport.size))
		check(worst<0.9, "档案室北门双向切换无单帧跳变：%.3f" % worst)
		check(visible_all,"北门过渡逐帧保留玩家上下轮廓")
	# 门槛处轻微往返时不反复切换固定/跟随构图。
	player.global_position=puzzle.to_global(Vector3(7.9,0.05,0))
	camera._process(1.0/60.0)
	var changes:=0
	var previous: StringName=camera._framed_room
	for i in 12:
		player.global_position=puzzle.to_global(Vector3(8.05 if i%2==0 else 7.95,0.05,0))
		camera._process(1.0/60.0)
		if camera._framed_room!=previous: changes+=1
		previous=camera._framed_room
	check(changes==0,"门槛往返不来回切镜")
	# 门口视线不应被悬空连杆横切；低矮台沿保留可见且实体的边界。
	var crossbar: MeshInstance3D=puzzle.get_node("Circuit/Linkage/Crossbar")
	check(crossbar.position.y<0.3,"传动管线贴地，不横跨玩家头部")
	var rim: MeshInstance3D=puzzle.get_node("PoweredPassage/FrontRim/Panel")
	check(rim.mesh.get_aabb().size.y<=0.65,"桥台边缘不再呈现高墙")
	viewport.queue_free()
	await frames(3)
	root.get_node("MusicManager").stop_music()
	await create_timer(0.15).timeout # 等待音频混音线程释放已停止的播放实例。
	finish.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL ",message)
func finish() -> void:
	print("STATION_TRANSITION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
