extends SceneTree
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
const SIZES = [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(1180,720),Vector2i(1179,720),Vector2i(1024,768),Vector2i(800,600),Vector2i(720,720),Vector2i(640,360),Vector2i(480,800)]
const REVEALED: Array[String] = ["attack","spell","dodge"]
var host: Node
var hud: Control
var dock: Node
var checks := 0
var failures := 0
var captures := false
var out := "user://right-hints"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	PROFILE.override_path = "user://dock-profile.cfg"
	PROGRESS.override_path = "user://dock-progress.cfg"
	captures = "--capture" in OS.get_cmdline_user_args()
	if not OS.get_environment("GODOT_TEST_OUTPUT_DIR").is_empty(): out = OS.get_environment("GODOT_TEST_OUTPUT_DIR")
	if captures: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await boot(1)
	hud.show_item_message("普通提示 A")
	hud.show_item_message("普通提示 B")
	await frames(15)
	check(hud.item_message.text == "普通提示 A" and hud._feedback_queue.size() == 1,"Ordinary notifications retain FIFO order")
	var remaining: float = hud._message_remaining
	hud.show_item_message("普通提示 A")
	check(is_equal_approx(remaining,hud._message_remaining) and hud._feedback_queue.size() == 1,"Duplicate messages neither restart the timer nor duplicate the queue")
	hud.show_item_message("沙王狂暴 · 按 E 操作，按 Space 闪避")
	await frames(3)
	check(hud.item_message.text.contains("狂暴") and hud._feedback_active.priority == 100,"A real warning class preempts an ordinary notification immediately")
	check(dock._keys.get_child_count() == 2 and dock._header.text == "提示","Warning panel has distinct E/Space keycaps and the unified 提示 heading")
	verify("priority")
	await capture("01-priority-warning")
	hud._message_remaining = 0.01
	await frames(6)
	check(hud.item_message.text == "普通提示 A","Interrupted ordinary message resumes before later messages")
	hud._message_remaining = 0.01
	await frames(6)
	check(hud.item_message.text == "普通提示 B","The following ordinary message appears after the interrupted one")
	remaining = hud._message_remaining
	host.set_paused(true)
	await create_timer(0.15).timeout
	check(not hud.feedback_panel.visible and is_equal_approx(remaining,hud._message_remaining),"Pause hides the lane and freezes notification lifetime")
	host.set_paused(false)
	await frames(6)
	hud.show_item_message("")
	hud.set_tutorial_guidance("move",REVEALED)
	await frames(12)
	# The real entrance gate can finish opening during the queue exercise.
	hud.show_item_message("")
	await frames(4)
	if not hud.get_node("%TutorialPrompt").visible:
		print("TUTORIAL_DOCK_DIAGNOSTIC "+str({"lesson":hud.get_node("%TutorialPrompt")._lesson,"current":str(dock.current),"active":hud._feedback_active,"min":hud.get_node("%TutorialPrompt").get_combined_minimum_size(),"slot":dock.reserved_rect}))
	check(hud.get_node("%TutorialPrompt").visible,"The existing tutorial is presented in the same left-side lane")
	verify("tutorial")
	await capture("02-right-tutorial")
	hud.get_node("%TutorialPrompt").skip_button.pressed.emit()
	await frames(4)
	check(host.get_node("RunBindings").tutorial.finished,"The original tutorial skip connection still completes the real tutorial")
	hud.show_item_message("")
	host._player.global_position = Vector3(-2.4,0.05,0.5)
	await frames(15)
	hud.show_item_message("")
	await frames(5)
	check(hud.pickup_prompt.visible and hud.pickup_prompt.text.contains("生命药剂 ×1"),"Original proximity interaction still supplies the live item name and quantity")
	verify("pickup")
	await capture("03-right-pickup")
	check(host._items.try_interact_nearest(),"The relocated prompt retains the actual pickup interaction")
	await frames(4)
	check(not host._dungeon.has_node("EntrancePotion"),"The real pickup is removed through its existing inventory path")
	for level in [1,2,3]:
		await boot(level)
		for size in SIZES:
			root.size = size
			for boss in [false,true]:
				if boss: host._boss_bar.begin_encounter(host._boss.boss_name,20,40)
				else: host._boss_bar.hide()
				hud.show_item_message("")
				host._dungeon.progression_feedback.emit("危险预警 · 按 Space 闪避")
				await frames(18)
				check(hud.item_message.text.contains("危险预警"),"The original map feedback signal reaches the shared HUD in level %d" % level)
				verify("level%d/%s/boss=%s" % [level,size,boss])
				if size in [Vector2i(1280,720),Vector2i(720,720),Vector2i(480,800),Vector2i(640,360)] and boss:
					await capture("level%d-boss-%dx%d" % [level,size.x,size.y])
				elif size == Vector2i(1280,720) and not boss: await capture("level%d-exploration" % level)
		# A moving actor can occupy the preferred slot; the dock must move or defer.
		var camera: Camera3D = host._dungeon.get_node("Camera3D")
		camera.set_process(false)
		var old: Vector3 = host._player.global_position
		host._player.global_position = camera.project_position(dock.reserved_rect.get_center(),15.0)
		await frames(5)
		if hud.feedback_panel.visible: verify("occupied slot level%d" % level)
		else: check(not hud.feedback_panel.visible,"A blocked left slot defers rather than covering an actor")
		host._player.global_position = old
		camera.set_process(true)
	paused = false
	root.get_node("MusicManager").stop_music()
	current_scene.queue_free()
	await frames(3)
	print("RIGHT_HINT_DOCK_RESULT %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func boot(level: int) -> void:
	paused = false
	change_scene_to_file("res://Main.tscn" if level == 1 else "res://scenes/dungeon/Level%02dRun.tscn" % level)
	await frames(10)
	host = current_scene
	hud = host._hud
	dock = hud.hint_dock
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	host._on_run_started()
	host._player._invulnerability_remaining = 100000.0
	if level == 1: host.get_node("RunBindings").tutorial.skip()
	hud.show_item_message("")
	await frames(15)
func verify(label: String) -> void:
	var panel: Control = dock.current
	check(panel != null and panel.is_visible_in_tree(),label+": a hint is actually visible")
	if panel == null or not panel.visible:
		print("DOCK_DIAGNOSTIC "+label+" slot="+str(dock.reserved_rect)+" panel="+str(panel)+" rect="+(str(panel.get_global_rect()) if panel != null else "none"))
		return
	var rect := panel.get_global_rect()
	check(root.get_visible_rect().grow(1).encloses(rect) and rect.end.x <= root.get_visible_rect().size.x*0.5,label+": hint fits on the left side")
	var clear := true
	for obstacle in dock.obstacles():
		if rect.intersects(obstacle): clear = false
	check(clear,label+": hint avoids actors, enemies, objective, Boss bar, skills and hotbar")
	check(dock.reserved_rect.grow(1).encloses(rect),label+": hint uses the unified lane")
	check(panel.mouse_filter == Control.MOUSE_FILTER_IGNORE,label+": panel does not steal combat input")
	if panel == hud.feedback_panel:
		check(dock._header.text == "提示",label+": the panel is named 提示")
		var pixels: float = hud.item_message.get_theme_font_size("font_size")*float(root.size.x)/root.get_visible_rect().size.x
		check(pixels >= 12.5,label+": message type stays readable after canvas scaling")
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func capture(name: String) -> void:
	if not captures: return
	await process_frame
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(out.path_join(name+".png")) == OK,"Capture "+name)
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
