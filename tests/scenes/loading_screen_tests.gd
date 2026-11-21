extends SceneTree
const SCREEN = preload("res://scenes/ui/loading_screen.gd")
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
var checks := 0
var failures := 0
var capture_enabled := false
func _initialize() -> void: run.call_deferred()
func run() -> void:
	PROFILE.override_path = "user://loading-profile.cfg"
	PROGRESS.override_path = "user://loading-progress.cfg"
	capture_enabled = "--capture" in OS.get_cmdline_user_args()
	root.mode = Window.MODE_WINDOWED
	for variant in 4:
		var screen := SCREEN.new()
		screen.variant = variant
		root.add_child(screen)
		var initial_tip: String = screen.tip.text
		screen._tip_origin_ms = Time.get_ticks_msec()
		screen._tip_cycle = 0
		screen._update_tip_clock(screen._tip_origin_ms+4999)
		check(screen.tip.text == initial_tip,"Tip remains unchanged before five seconds")
		screen._update_tip_clock(screen._tip_origin_ms+5000)
		check(screen.tip.text != initial_tip and screen.tip.text in SCREEN.TIPS,"Five-second boundary selects a different body without a heading")
		screen._tip_origin_ms = Time.get_ticks_msec()
		screen._tip_cycle = 0
		for dimensions in [Vector2i(1280,720),Vector2i(720,720),Vector2i(640,360),Vector2i(480,800)]:
			root.size = dimensions
			screen.set_progress(0.37)
			await frames(12)
			check(screen.percent.text == "37%" and screen.bar.value == 37,"Resource input maps directly to percentage and bar")
			check(screen.status.text == "正在加载","Loading text is retained without an extra heading")
			check(screen.tip.text in SCREEN.TIPS and not screen.tip.text.contains("技巧："),"Only the random tip body is shown")
			var texture: Texture2D = screen.art.texture
			check(texture.get_width() >= 1080 and texture.get_height() >= 1080,"Pre-rendered scene remains HD")
			check(screen.root.find_children("*","SubViewportContainer",true,false).is_empty(),"Loading UI avoids runtime 3D construction")
			check((texture.get_width() < texture.get_height()) == (root.get_visible_rect().size.x/root.get_visible_rect().size.y < 0.9),"Portrait uses its dedicated composition")
			await frames(5)
			check(screen.art.texture == texture and screen.ratio == 0.37,"Static scene does not alter real loading progress")
			var bounds := root.get_visible_rect().grow(1)
			check(bounds.encloses(screen.footer.get_global_rect()),"Loading footer remains within viewport: "+str(dimensions))
			check(screen.bar.size.x >= minf(960,root.get_visible_rect().size.x-48)-2,"Progress bar spans the intended bottom composition")
			check(screen.tip.get_visible_line_count() == screen.tip.get_line_count() and screen.tip.size.y >= screen.tip.get_minimum_size().y,"Tip body wraps fully")
			check(screen.tip.get_global_rect().end.y <= screen.bar.get_global_rect().position.y,"Tip body is above the progress bar")
			await capture(screen,"v%d-%dx%d" % [variant,dimensions.x,dimensions.y])
		screen.queue_free()
		await frames(3)
	# Real first launch and scene transition exercise actual resource status.
	change_scene_to_file("res://scenes/ui/LoadingEntry.tscn")
	await wait_scene("res://Main.tscn")
	check(current_scene != null and current_scene.scene_file_path == "res://Main.tscn","Startup loader reaches the real menu")
	var host: Node = current_scene
	check(host.request_scene_change("res://scenes/dungeon/Level02Run.tscn",{"start_run":true}),"Real transition request is accepted")
	check(not host.request_scene_change("res://Main.tscn"),"Loading preserves duplicate-request protection")
	await wait_scene("res://scenes/dungeon/Level02Run.tscn")
	check(current_scene.level_id == 2 and current_scene.get_run_state() == current_scene.RunState.PLAYING,"Real threaded load preserves destination and auto-start")
	check(preload("res://scripts/integration/resource_transition.gd").last_metrics.get("complete_frame_presented",false),"Resource-complete 100% is submitted to the display before instantiation")
	check(root.get_node_or_null("LoadingScreen") == null,"Loading overlay cleans up after scene ready")
	paused = false
	root.get_node("MusicManager").stop_music()
	current_scene.queue_free()
	await frames(3)
	print("LOADING_SCREEN_RESULT %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func wait_scene(path: String) -> void:
	var deadline := Time.get_ticks_msec()+30000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path and root.get_node_or_null("LoadingScreen") == null: return
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func capture(screen: Node, name: String) -> void:
	if not capture_enabled: return
	var out := OS.get_environment("GODOT_TEST_OUTPUT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(out.path_join(name+".png")) == OK,"Capture "+name)
