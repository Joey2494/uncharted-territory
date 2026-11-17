extends SceneTree
## 正式宿主的档案室取景回归：设施、HUD 安全区、稳定构图与离开恢复。
const Profile = preload("res://scripts/integration/player_profile.gd")
const Progress = preload("res://scripts/integration/campaign_progress.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Profile.override_path = "user://archive-camera-profile-%d.cfg" % Time.get_ticks_usec()
	Progress.override_path = "user://archive-camera-progress-%d.cfg" % Time.get_ticks_usec()
	for dimensions in [Vector2i(1280,720), Vector2i(720,720), Vector2i(1920,1080)]:
		var viewport := SubViewport.new()
		viewport.size = dimensions
		root.add_child(viewport)
		var host: Node3D = load("res://scenes/dungeon/Level02Run.tscn").instantiate()
		viewport.add_child(host)
		host._on_run_started()
		var world: Node3D = host.get_node("DungeonTest")
		var camera: Camera3D = world.get_node("Camera3D")
		var player: CharacterBody3D = world.player
		var puzzle: Node3D = world.puzzle
		player.global_position = puzzle.to_global(Vector3(1,0.05,0))
		await settle()
		check(camera.has_method("is_puzzle_framed") and camera.call("is_puzzle_framed"), "进入 G 启用解谜构图")
		for name in ["CoreRack","BridgeSocket","Lever","ReceiverA","ReceiverB","Inspect","Hints","ResetConsole"]:
			var control: Node3D = puzzle.get_node(name)
			check(fits(camera,control.global_position), "%s %s 基座完整可见" % [dimensions,name])
			check(fits(camera,control.global_position+Vector3.UP*2.1), "%s %s 标记完整可见" % [dimensions,name])
		for local in [Vector3(-7.8,0.05,-6.8),Vector3(7.8,0.05,-6.8),Vector3(-7.8,0.05,6.8),Vector3(7.8,0.05,6.8)]:
			check(fits(camera,puzzle.to_global(local)),"房间通路边缘在安全区内")
		var pose := camera.get_camera_transform()
		player.global_position = puzzle.to_global(Vector3(2.5,0.05,2.0))
		await settle()
		check(camera.get_camera_transform().is_equal_approx(pose),"档案室移动不漂移构图")
		host._hud.show_item_message("机械步道已卡合 · 检修线已接通")
		await settle()
		check(camera.get_camera_transform().is_equal_approx(pose),"交互反馈出现不改变构图")
		host._hud.show_item_message("")
		await settle()
		check(camera.get_camera_transform().is_equal_approx(pose),"反馈消失不改变构图")
		check(host._hud.hotbar.is_visible_in_tree(),"解谜区保留道具快捷栏")
		check(host._hud.get_node("CooldownBar").is_visible_in_tree(),"解谜区保留操作提示")
		player.global_position = world.get_node("Regions/Arrival").global_position + Vector3.UP*0.05
		await settle()
		check(host._hud.hotbar.is_visible_in_tree(),"离开解谜区恢复快捷栏")
		check(not camera.get_camera_transform().is_equal_approx(pose),"离开解谜区恢复跟随")
		viewport.queue_free()
		await process_frame
	print("ARCHIVE_FRAMING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func settle() -> void:
	for index in 12:
		await physics_frame
		await process_frame

func fits(camera: Camera3D, point: Vector3) -> bool:
	return not camera.is_position_behind(point) and camera.get_safe_frame().grow(0.002).has_point(camera.unproject_position(point)/camera.get_viewport().get_visible_rect().size)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ",label)
