extends SceneTree
## Real map progression drives the compact tracker; no mocked completion flags.
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
const OUT := "D:/My File/Game/Team Game/output/hud-shop-objectives-2026-11-14"
var host: Node
var panel: Control
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func run() -> void:
	PROFILE.override_path = "user://objective-profile-%d.cfg" % Time.get_ticks_usec()
	PROGRESS.override_path = "user://objective-campaign-%d.cfg" % Time.get_ticks_usec()
	PROFILE.set_coins(300)
	PROFILE.unlock_character("lan")
	PROFILE.set_selected_character("lan")
	if "--capture" in OS.get_cmdline_user_args(): await shop_captures()
	await boot()
	verify("前往分流中庭","探索 1/8")
	check(panel.get_node("%ObjectiveCategory").text == "当前任务", "fresh scene does not celebrate historical or automatic arrival completion")
	if "--capture" in OS.get_cmdline_user_args(): await capture("objective-arrival")
	var map: Node3D = host._dungeon
	await go(Vector3(0,0.05,-26))
	verify("肃清中庭守卫","0/2")
	check(map.get_node("Enemies/Hub1").take_damage(999), "first actual guard accepts fatal damage")
	await frames(2)
	verify("肃清中庭守卫","1/2")
	check(panel.get_node("%ObjectiveCategory").text != "目标完成", "one defeated guard does not falsely complete the encounter")
	if "--capture" in OS.get_cmdline_user_args(): await capture("objective-combat")
	check(map.get_node("Enemies/Hub2").take_damage(999), "last actual guard accepts fatal damage")
	await frames(2)
	verify("前往导能回廊","探索 2/8")
	check(panel.get_node("%ObjectiveCategory").text == "目标完成", "encounter completion shows an inline acknowledgement while advancing to the next task")
	var remaining: float = panel._feedback_remaining
	await frames(3)
	check(panel._feedback_remaining < remaining, "unchanged completed state does not restart the feedback every frame")
	host.set_paused(true)
	remaining = panel._feedback_remaining
	await create_timer(0.18).timeout
	check(is_equal_approx(panel._feedback_remaining,remaining), "pause freezes lightweight feedback along with gameplay")
	host.set_paused(false)
	await create_timer(1.7).timeout
	check(panel.get_node("%ObjectiveCategory").text == "当前任务", "completion acknowledgement expires without adding a persistent text row")
	await go(Vector3(0,0.05,2))
	await go(Vector3(0,0.05,-26))
	check(panel.get_node("%ObjectiveCategory").text != "目标完成", "revisiting a cleared room does not celebrate it twice")
	await go(Vector3(34,0.05,-26))
	verify("肃清导能守卫","0/2")
	for enemy in ["Relay1","Relay2"]: map.get_node("Enemies/"+enemy).take_damage(999)
	await frames(2)
	verify("启动导能核心","待激活")
	await go(Vector3(34,0.05,-27.65))
	check(host._items.try_interact_nearest() and map.relay_activated, "real nearest-device interaction activates the relay")
	await frames(2)
	verify("进入共鸣前厅","探索 3/8")
	await go(Vector3(34,0.05,-56))
	verify("肃清前厅守卫","0/3")
	for enemy in ["Antechamber1","Antechamber2","Antechamber3"]: map.get_node("Enemies/"+enemy).take_damage(999)
	await frames(2)
	verify("前往灾厄大厅","探索 4/8")
	await go(Vector3(34,0.05,-80))
	verify("击败灾厄巨蝎","0/1")
	root.size = Vector2i(720,720)
	await frames(5)
	check(not panel.visible and host._boss_bar.visible, "compact combat retains the existing Boss-bar priority")
	check(map.get_node("Boss").take_damage(999), "actual Boss defeat advances the real room state")
	await frames(2)
	remaining = panel._feedback_remaining
	await create_timer(0.25).timeout
	check(remaining > 0 and is_equal_approx(panel._feedback_remaining,remaining), "hidden Boss tracker retains its completion acknowledgement for the next visible frame")
	await create_timer(1.9).timeout
	check(panel.visible and panel.get_node("%ObjectiveCategory").text == "目标完成", "tracker returns automatically after the defeated Boss bar fades")
	verify("前往遗迹出口","出口已开启")
	root.size = Vector2i(1280,720)
	await frames(4)
	if "--capture" in OS.get_cmdline_user_args(): await capture("objective-complete")
	await go(Vector3(34,0.05,-111))
	await frames(10)
	check(host.get_run_state() == host.RunState.VICTORY, "tracking objectives preserves the physical-exit victory flow")
	await boot()
	check(panel.get_node("%ObjectiveCategory").text == "当前任务" and panel._feedback_remaining == 0, "new run clears the tracker completion history")
	await puzzle_checks()
	paused = false
	root.get_node("MusicManager").stop_music()
	current_scene.queue_free()
	await frames(3)
	print("OBJECTIVE_HUD_RESULT %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func puzzle_checks() -> void:
	await go(Vector3(-34,0.05,-26))
	verify("校准碑文符文","0/3")
	check(panel.get_node("%ObjectiveCategory").text in ["支线任务","任务更新"], "optional room is presented as a side objective")
	check(await interact("RuneSun"), "actual first rune interaction succeeds")
	verify("校准碑文符文","1/3")
	check(await interact("RuneStar"), "wrong rune uses the existing reset behavior")
	await create_timer(0.78).timeout
	verify("校准碑文符文","0/3")
	check(panel.get_node("%ObjectiveCategory").text != "目标完成", "resetting a failed sequence does not claim completion")
	for name in ["RuneSun","RuneMoon","RuneStar"]: check(await interact(name), "actual calibration control: "+name)
	verify("调谐分流 A1 / B2","0/2")
	check(panel.get_node("%ObjectiveCategory").text == "目标完成", "calibration completion updates to routing and acknowledges the completed step")
	check(await interact("SwitchA"), "actual routing A switch succeeds")
	verify("调谐分流 A1 / B2","1/2")
	check(await interact("SwitchB") and await interact("SwitchB"), "actual routing B reaches the existing target")
	verify("调谐分流 A1 / B2","2/2")
	if "--capture" in OS.get_cmdline_user_args(): await capture("objective-side-routing")
	check(await interact("Confirm"), "actual routing confirmation starts opening the vault")
	verify("等待密室开启","开启中")
	await create_timer(1.05).timeout
	verify("领取密室奖励","待领取")
	check(await interact("Reward"), "actual inventory accepts the unique reward")
	verify("返回主路继续探索","支线完成")
	check(host._items.rune_count == 1 and panel.get_node("%ObjectiveCategory").text == "目标完成", "tracker celebrates only the successful reward delivery")
	await create_timer(1.65).timeout
	await go(Vector3(0,0.05,2))
	await go(Vector3(-34,0.05,-52))
	check(panel.get_node("%ObjectiveCategory").text != "目标完成" and host._items.rune_count == 1, "returning to the completed side room neither repeats completion nor grants another reward")
	for dimensions in [Vector2i(1280,720),Vector2i(720,720),Vector2i(480,800),Vector2i(640,360)]:
		root.size = dimensions
		await frames(5)
		verify("返回主路继续探索","支线完成")
		if "--capture" in OS.get_cmdline_user_args(): await capture("objective-compact")

func verify(title: String, progress: String) -> void:
	check(panel.get_node("%ObjectiveTask").text == title and panel.get_node("%ObjectiveDetail").text == progress, "actual objective and relevant progress: "+title+" / "+progress)
	check(panel.size.x <= 288 and panel.size.y <= 64, "tracker retains its compact footprint across task states")
	var label: Label = panel.get_node("%ObjectiveTask")
	check(label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x <= label.size.x, "short task title remains fully readable")

func boot(level: int = 2) -> void:
	paused = false
	change_scene_to_file("res://Main.tscn" if level == 1 else "res://scenes/dungeon/Level02Run.tscn")
	await frames(8)
	host = current_scene
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	host._on_run_started()
	host._player._invulnerability_remaining = 100000.0
	panel = host._hud.get_node_or_null("LevelObjective")
	if level == 1: host.get_node("RunBindings").tutorial.skip()
	await frames(5)

func interact(name: String) -> bool:
	var control: Node3D = host._dungeon.get_node("EnergyRelayPuzzle/"+name)
	await go(control.global_position+Vector3(0,0.05,1.35))
	var accepted: bool = host._items.try_interact_nearest()
	await frames(2)
	return accepted
func go(position: Vector3) -> void:
	host._player.global_position = position
	await frames(6)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures += 1
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT.path_join("%s-%dx%d.png" % [label,root.size.x,root.size.y]))

func shop_captures() -> void:
	await boot(1)
	var button: Button = host._commerce.shop_button
	for dimensions in [Vector2i(1280,720),Vector2i(720,720),Vector2i(480,800)]:
		root.size = dimensions
		await frames(5)
		await capture("shop-normal")
	root.size = Vector2i(1280,720)
	await frames(5)
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	root.push_input(motion,true)
	await frames(3)
	await capture("shop-hover")
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = motion.position
		event.pressed = pressed
		root.push_input(event,true)
		await frames(2)
		await capture("shop-pressed" if pressed else "shop-open")
	host._commerce.shop.back_requested.emit()
	await frames(3)
	button.disabled = true
	await capture("shop-disabled")
	button.disabled = false
