extends SceneTree
## 正式宿主、最近目标交互与实际 HUD 联合验证档案室的信息展示。
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
var host: Node
var puzzle: Node3D
var panel: Control
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	PROFILE.override_path = "user://archive-ui-profile-%d.cfg" % Time.get_ticks_usec()
	PROGRESS.override_path = "user://archive-ui-campaign-%d.cfg" % Time.get_ticks_usec()
	change_scene_to_file("res://scenes/dungeon/Level02Run.tscn")
	await frames(8)
	host = current_scene
	host._on_run_started()
	host._player._invulnerability_remaining = 100000.0
	puzzle = host._dungeon.puzzle
	panel = host._hud.get_node("LevelObjective")
	await go(puzzle.global_position + Vector3(0, 0.05, 0))
	verify_resources("手持 0｜托架 2｜桥 0｜门锁 0/2")
	await approach("BridgeSocket", Vector3(1.25, 0.05, 0))
	check(host._hud.pickup_prompt.text.contains("主供能中断") and host._hud.pickup_prompt.text.contains("[E]"), "断电目标说明检查动作与断电状态")
	# 供能本身由既有能源回归验证；本用例聚焦真实地图内之后的 UI 生命周期。
	puzzle.enable_supply()
	await frames(2)
	check(host._hud.pickup_prompt.text.contains("手持为空"), "空手检查空插槽不会宣称可以放入能源")
	await use_control("CoreRack")
	verify_resources("手持 2｜托架 0｜桥 0｜门锁 0/2")
	await approach("BridgeSocket", Vector3(1.25, 0.05, 0))
	check(host._hud.pickup_prompt.text.contains("桥台插槽") and host._hud.pickup_prompt.text.contains("放入一枚能源"), "当前目标完整说明桥台名称及准确插入动作")
	check(host._items.try_interact_nearest(), "真实最近目标为桥供能")
	await create_timer(3.2).timeout
	verify_resources("手持 1｜托架 0｜桥 1｜门锁 0/2")
	check(host._hud.pickup_prompt.text.contains("撤回能源"), "供桥后当前 E 动作更新为回收")
	await approach("BridgeSocket", Vector3(-1.2, 0.05, 0))
	check(host._hud.pickup_prompt.text.contains("先离开桥面"), "站在桥面时提示准确说明回收限制")
	await use_control("Lever")
	check(panel.get_node("%ObjectiveCategory").text == "步骤完成", "检修步骤完成不会宣称整个支线已完成")
	await use_control("BridgeSocket", Vector3(1.25, 0.05, 0))
	await create_timer(3.2).timeout
	verify_resources("手持 2｜托架 0｜桥 0｜门锁 0/2")
	for dimensions in [Vector2i(1280, 720), Vector2i(720, 720)]:
		root.size = dimensions
		await frames(5)
		verify_resources("手持 2｜托架 0｜桥 0｜门锁 0/2")
		var prompt: Label = host._hud.pickup_prompt
		for line in prompt.text.split("\n"):
			check(prompt.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, prompt.get_theme_font_size("font_size")).x <= prompt.size.x, "当前对象每行操作提示可完整容纳")
		var camera: Camera3D = host._dungeon.get_node("Camera3D")
		for name in ["CoreRack", "BridgeSocket", "Lever", "ReceiverA", "ReceiverB", "Inspect", "Hints", "ResetConsole"]:
			var label: Label3D = puzzle.get_node(name + "/Caption")
			var origin := camera.unproject_position(label.global_position)
			var top := camera.unproject_position(label.global_position + camera.global_basis.y * label.pixel_size * label.font_size * label.scale.y)
			check(origin.distance_to(top) >= 13.5 and origin.distance_to(top) <= 17.0, "完整取景时短标签保持可读屏幕字号：" + name)
	check(panel.get_node("%ObjectiveTask").text == "为双接收器供能", "回收后的常驻下一步仍来自真实检修线")
	await use_control("ReceiverA")
	verify_resources("手持 1｜托架 0｜桥 0｜门锁 1/2")
	await approach("ReceiverB")
	check(host._hud.pickup_prompt.text.contains("接收器二") and host._hud.pickup_prompt.text.contains("放入一枚能源"), "门前两接收器由当前目标完整区分")
	for name in ["CoreRack", "BridgeSocket", "Lever", "ReceiverA", "ReceiverB", "Inspect", "Hints", "ResetConsole"]:
		var control: Node3D = puzzle.get_node(name)
		check(control.get_node("Caption").text.length() <= 4, "远景短标识：" + name)
		var shape: CylinderShape3D = control.get_node("Base/CollisionShape3D").shape
		check(is_equal_approx(shape.radius, 0.54) and is_equal_approx(shape.height, 0.84), "外形变更保留碰撞：" + name)
	check(puzzle.get_node("BridgeSocket/Signal").mesh.get_class() != puzzle.get_node("ReceiverA/Signal").mesh.get_class(), "桥槽与接收器有不同实体轮廓")
	check(puzzle.get_node("Lever/Signal").mesh.get_class() != puzzle.get_node("ReceiverA/Signal").mesh.get_class(), "手柄与接收器有不同实体轮廓")
	check(not puzzle.get_node("Circuit/LineState").visible, "门前不叠加第三条检修线文字，状态交给 HUD")
	for name in ["Inspect", "Hints", "ResetConsole"]:
		check(puzzle.get_node(name + "/Caption").modulate.a < puzzle.get_node("BridgeSocket/Caption").modulate.a, "辅助设施降低标签权重：" + name)
	host.set_paused(true)
	await create_timer(0.1).timeout
	verify_resources("手持 1｜托架 0｜桥 0｜门锁 1/2")
	check(not host._items.try_interact_nearest(), "暂停时 UI 不绕过交互权限")
	host.set_paused(false)
	await use_control("ResetConsole")
	check(host._hud.pickup_prompt.text.contains("再次") and host._hud.pickup_prompt.text.contains("复位"), "复位第二次 E 明确确认语义")
	await use_control("ResetConsole")
	verify_resources("手持 0｜托架 2｜桥 0｜门锁 0/2")
	await go(Vector3(0, 0.05, 2))
	var resources := panel.get_node_or_null("%ObjectiveResources")
	check(resources != null and not resources.visible, "离开解谜房后收起资源行")
	root.get_node("MusicManager").stop_music()
	host.queue_free()
	await frames(3)
	finish.call_deferred()

func finish() -> void:
	print("ARCHIVE_PRESENTATION_RESULT %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func verify_resources(expected: String) -> void:
	var label := panel.get_node_or_null("%ObjectiveResources")
	check(label != null and label.visible and label.text == expected, "常驻真实能源归属：" + expected)
	if label != null:
		check(label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x <= label.size.x, "能源归属整行可读")

func approach(name: String, offset := Vector3(0, 0.05, 1.35)) -> void:
	await go(puzzle.get_node(name).global_position + offset)

func use_control(name: String, offset := Vector3(0, 0.05, 1.35)) -> void:
	await approach(name, offset)
	check(host._items.try_interact_nearest(), "实际交互：" + name)
	await frames(2)

func go(point: Vector3) -> void:
	host._player.global_position = point
	await frames(6)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL " + message)
