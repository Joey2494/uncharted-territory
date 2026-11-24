extends SceneTree
## 直接检查 Godot 物理空间。逐条经过桥口，验证开合过程中实体门与进度状态一致。
const LAYOUT := preload("res://scenes/dungeon/level04/observatory_layout.gd")
const CAMERA := preload("res://scenes/dungeon/level04/observatory_camera.gd")
const PLAN := preload("res://scenes/dungeon/level04/observatory_plan.gd")
var arena := Node3D.new()
var layout := LAYOUT.new()
var walker := CharacterBody3D.new()
var camera := CAMERA.new()
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, context: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL " + context)

func frames(n: int) -> void:
	for i in n: await physics_frame

func intersects(start: Vector3, end: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(start,end,1,[walker.get_rid()])
	return not arena.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func run() -> void:
	root.add_child(arena)
	arena.add_child(layout)
	layout.build()
	walker.name = "Player"
	arena.add_child(walker)
	var body := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.6
	body.shape = capsule
	body.position.y = 0.8
	walker.add_child(body)
	arena.add_child(camera)
	await frames(3)
	for id: String in PLAN.CENTERS:
		var center := layout.room_center(id)
		check(layout.room_at(center) == id, "房间与轮廓 " + id)
		check(intersects(center + Vector3.UP*0.28,center + Vector3.DOWN*0.27),"实际地板 " + id)
	check(layout.room_at(Vector3(5.7,0,4)) == "", "楔形到达台的矩形包围盒外角不算进房")
	for link: String in PLAN.LINKS:
		var a := link.substr(0,1)
		var b := link.substr(1,1)
		check(layout.passage_open(a,b) == (link in PLAN.OPEN_AT_START),"初始门锁 " + link)
		layout.set_passage(a,b,false)
	await frames(70)
	for link: String in PLAN.LINKS:
		var a := link.substr(0,1)
		var b := link.substr(1,1)
		var path := PLAN.bridge_path(a,b)
		var n := PLAN.gate_segment(path)
		var middle := (path[n] + path[n+1])*0.5
		var delta := path[n].direction_to(path[n+1])
		var mid := Vector3(middle.x,0,middle.y)
		var dir := Vector3(delta.x,0,delta.y)
		var across := dir.cross(Vector3.UP)
		check(layout.room_at(mid) == "", "过桥与进房分别计 " + link)
		for x: float in [-2.05,0,2.05]:
			var eye := mid + Vector3.UP + across*x
			check(intersects(eye-dir,eye+dir), "关闭的门覆盖全桥宽 " + link)
		check(intersects(mid+Vector3.UP*0.45+across*2,mid+Vector3.UP*0.45+across*3),"实体护栏 " + link)
		layout.set_passage(b,a,true)
		check(not layout.passage_open(a,b),"抬升中不能登记通行 " + link)
	await frames(75)
	for link: String in PLAN.LINKS:
		var a := link.substr(0,1)
		var b := link.substr(1,1)
		check(layout.passage_open(a,b),"开门动画与物理确认 " + link)
		for origin in [a,b]:
			var target := a if origin == b else b
			var path := PLAN.bridge_path(origin,target)
			var leaving := path[0].direction_to(path[1])
			var arriving := path[-2].direction_to(path[-1])
			check(layout.room_at(world_point(path[0]-leaving)) == origin,"桥头位于出发房 " + link)
			check(layout.room_at(world_point(path[-1]+arriving)) == target,"桥尾位于目标房 " + link)
			path.insert(0,path[0]-leaving)
			path.append(path[-1]+arriving)
			walker.position = world_point(path[0])
			for point in path.slice(1):
				var end := world_point(point)
				while walker.position.distance_to(end) > 0.01:
					var hit := walker.move_and_collide((end-walker.position).limit_length(0.23))
					if hit: break
					if not intersects(walker.position+Vector3.UP*0.1,walker.position+Vector3.DOWN*0.4):
						check(false,"桥面缺口 " + link + str(walker.position))
						break
				check(walker.position.distance_to(end)<0.04,"胶囊连续过门与折廊 " + origin + target + str(point))
	# 通过每个战斗门口的进深与全幅采样验证实体封条，两侧高频复用的门均需独立关闭。
	for room in ["D","F","H","I"]:
		layout.seal_room(room,true)
		await frames(2)
		for link: String in PLAN.LINKS:
			if not room in link: continue
			var path := PLAN.bridge_path(room,link.replace(room,""))
			var out := path[0].direction_to(path[1])
			for x: float in [-2.05,0,2.05]:
				var at := path[0]+out.orthogonal()*x
				check(intersects(world_point(at-out)+Vector3.UP,world_point(at+out)+Vector3.UP),"全宽封场 " + room + link)
		layout.seal_room(room,false)
		await frames(65)
	var f := layout.room_center("F") + Vector3.UP
	check(intersects(f+Vector3(-1,0,-4.5),f+Vector3(2,0,-4.5)),"F 分隔石墙挡射线")
	check(not intersects(f+Vector3(-1,0,0),f+Vector3(2,0,0)),"F 中段有换廊缺口")
	var i := layout.room_center("I") + Vector3.UP
	check(intersects(i+Vector3(-3,0,0),i+Vector3(3,0,0)),"I 仪器岛挡射线")
	await camera_run()
	print("level04 geometry & camera: %d checks / %d failed" % [checks,failures])
	arena.queue_free()
	await frames(2)
	quit(1 if failures else 0)

func world_point(point: Vector2) -> Vector3:
	return Vector3(point.x,0.025,point.y)

func camera_run() -> void:
	# 延续第三关的连续过门测法。跨过 H/I 门槛后，玩家绕行及近卫刷新不应改变全场取景。
	var center := layout.room_center("I")
	walker.position = center + Vector3(0,0.025,12)
	camera.reset_follow()
	var previous := camera._distance
	var step_max := 0.0
	for n in 125:
		walker.position = center + Vector3(4.1 * sin(n*0.015),0.025,12-0.115*n)
		await process_frame
		step_max = maxf(step_max,absf(previous-camera._distance))
		previous = camera._distance
	check(step_max <= camera.ZOOM_UNITS_PER_SECOND*root.get_process_delta_time()+0.05, "入场视距每帧遵守速度上限")
	var stable := camera._distance
	var actor := Node3D.new()
	arena.add_child(actor)
	actor.add_to_group("camera_targets")
	actor.position = center + Vector3(-7,0,4.5)
	for n in 40:
		walker.position = center + Vector3(4.5,0.025,-1.5+n*0.1)
		if n == 20: actor.queue_free()
		await process_frame
	check(absf(camera._distance-stable) < 0.02,"穹顶内随增援与移位保持视距")
	check(camera.is_position_in_frustum(center+Vector3(-8,3,-6)) and camera.is_position_in_frustum(center+Vector3(8,0,6)),"同屏可见两侧行动区")
