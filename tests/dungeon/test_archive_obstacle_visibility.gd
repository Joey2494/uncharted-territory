extends SceneTree
## 同一碰撞隔断在房内、门槛、通道应始终可辨，不能再产生视觉上的空地。
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func run() -> void:
	preload("res://scripts/integration/player_profile.gd").override_path="user://obstacle-profile-%d.cfg" % Time.get_ticks_usec()
	preload("res://scripts/integration/campaign_progress.gd").override_path="user://obstacle-progress-%d.cfg" % Time.get_ticks_usec()
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1152,720)
	root.add_child(viewport)
	var host: Node3D=load("res://scenes/dungeon/Level02Run.tscn").instantiate()
	viewport.add_child(host)
	host._on_run_started()
	var puzzle: Node3D=host._dungeon.puzzle
	var player: CharacterBody3D=host._player
	for local: Vector3 in [Vector3(0,0.05,0),Vector3(1,0.05,-5.8),Vector3(7.9,0.05,0),Vector3(10,0.05,0),Vector3(0,0.05,0)]:
		player.global_position=puzzle.to_global(local)
		await frames(55)
		for name in ["NorthPartition","CenterPartition","SouthPartition"]:
			var body: StaticBody3D=puzzle.get_node(name)
			var mesh: MeshInstance3D=body.get_node("Mesh")
			check(mesh.is_visible_in_tree() and mesh.get_active_material(0).albedo_color.a>0.95,"进出档案室隔断不消失："+name)
			var shape: BoxShape3D=body.get_node("CollisionShape3D").shape
			check(shape.size.is_equal_approx(mesh.mesh.get_aabb().size),"隔断视觉占地对应碰撞："+name)
			var pose:=player.global_transform
			pose.origin=body.global_position+Vector3(shape.size.x/2+0.8,0,0)
			pose.origin.y=0.05
			check(player.test_move(pose,Vector3.LEFT*(shape.size.x+1.6)),"可见隔断仍阻挡穿行："+name)
	check(puzzle.get_node("Lever/Caption").text=="步道开关","开关名称直接说明对象")
	puzzle.enable_supply()
	check(puzzle.get_control_prompt(&"lever").contains("返回") and puzzle.get_control_prompt(&"lever").contains("门锁"),"提示说明返回通路和门锁双重作用")
	viewport.queue_free()
	await frames(3)
	root.get_node("MusicManager").stop_music()
	await create_timer(0.15).timeout
	finish.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL ",message)
func finish() -> void:
	print("ARCHIVE_OBSTACLES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
