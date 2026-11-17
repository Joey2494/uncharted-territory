extends SceneTree
## 正式HUD与完整房间联合验收：不仅在屏幕内，还必须有可玩的尺寸及可辨识的门。
const Profile=preload("res://scripts/integration/player_profile.gd")
const Progress=preload("res://scripts/integration/campaign_progress.gd")
var checks:=0
var failures:=0
func _initialize() -> void: run.call_deferred()
func frames(n:=12) -> void:
	for i in n: await physics_frame
func run() -> void:
	Profile.override_path="user://playable-profile-%d.cfg" % Time.get_ticks_usec()
	Progress.override_path="user://playable-progress-%d.cfg" % Time.get_ticks_usec()
	Profile.set_coins(1000)
	Profile.unlock_character("astra")
	Profile.set_selected_character("astra")
	for dimensions in [Vector2i(1152,720),Vector2i(1280,720),Vector2i(720,720)]:
		var viewport:=SubViewport.new()
		viewport.size=dimensions
		root.add_child(viewport)
		var host: Node=load("res://scenes/dungeon/Level02Run.tscn").instantiate()
		viewport.add_child(host)
		host._on_run_started()
		host._player._invulnerability_remaining=10000
		var camera: Camera3D=host._dungeon.get_node("Camera3D")
		for room in ["Hub","Relay","Antechamber","Boss"]:
			host._player.global_position=host._dungeon.get_node("Regions/"+room).global_position+Vector3(0,0.05,3)
			await frames(70)
			var player_pos: Vector3=host._player.global_position
			var height:=camera.unproject_position(player_pos).distance_to(camera.unproject_position(player_pos+Vector3.UP*1.8))
			check(height>=19.0,"%s %s 玩家轮廓至少19逻辑像素（实际%.1f）" % [dimensions,room,height])
			check(camera.get_safe_frame().size.y>=0.53,"战斗视野保留至少53%%窗口高度")
			if room=="Boss":
				host._boss.set_physics_process(false)
				var bounds: Rect2=host._dungeon.get_node("Regions/Boss").get_world_bounds()
				for corner in [bounds.position+Vector2(2,2),bounds.end-Vector2(2,2)]:
					host._boss.global_position=Vector3(corner.x,0,corner.y)
					await frames(15)
					for x in [-4.7,4.7]:
						for z in [-4.7,4.7]:
							var point: Vector3=host._boss.global_position+Vector3(x,2.4,z)
							check(camera.get_safe_frame().grow(0.002).has_point(camera.unproject_position(point)/Vector2(dimensions)),"巨蝎靠近角落时真实轮廓不被裁切")
				host._boss.take_damage(999)
			else:
				for enemy in host._dungeon.get_node("Enemies").get_children():
					if String(enemy.name).begins_with(room): enemy.take_damage(999)
			await frames(65)
			if room=="Relay": host._dungeon.perform_control(&"relay",host._player)
		host._player.global_position=host._dungeon.puzzle.global_position+Vector3(1,0.05,0)
		await frames(30)
		var gate: Node=host._dungeon.get_node("Gates/Vault")
		check(not gate.is_open() and not gate.get_node("CollisionShape3D").disabled,"谜题未完成时门仍封锁")
		check(gate.get_node("Visuals/Slab").is_visible_in_tree() and gate.get_node("Visuals/Slab").get_active_material(0).albedo_color.a>=0.55,"关闭门不可被镜头淡成隐形墙")
		check(host._hud.hotbar.is_visible_in_tree() and host._hud.get_node("CooldownBar").is_visible_in_tree(),"档案室保留一致的操作栏")
		host._hud.show_item_message("进入档案室")
		await frames()
		check(host._hud.feedback_panel.get_global_rect().size.y<75,"单行提示没有大块空白")
		check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(host._commerce.shop_button.get_global_rect()),"商城按钮完整在窗口内")
		var pose:=camera.get_camera_transform()
		host._hud.show_item_message("")
		await frames()
		check(camera.get_camera_transform().is_equal_approx(pose),"反馈消失后镜头稳定")
		viewport.queue_free()
		await frames(3)
	root.get_node("MusicManager").stop_music()
	finish.call_deferred()

func finish() -> void:
	print("PLAYABLE_VIEW: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL ",label)
