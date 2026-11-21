extends SceneTree
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
var host: Node
var bubbles: Node
var checks := 0
var failures := 0
var capture_enabled := false
func _initialize() -> void: run.call_deferred()
func run() -> void:
	PROFILE.override_path = "user://bubble-profile.cfg"
	PROGRESS.override_path = "user://bubble-progress.cfg"
	capture_enabled = "--capture" in OS.get_cmdline_user_args()
	for level in [1,2,3]:
		change_scene_to_file("res://Main.tscn" if level == 1 else "res://scenes/dungeon/Level%02dRun.tscn" % level)
		await frames(12)
		host = current_scene
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280,720)
		host._on_run_started()
		host._player._invulnerability_remaining = 10000
		if level == 1: host.get_node("RunBindings").tutorial.skip()
		bubbles = host._hud.hint_dock.bubbles
		await sizing_checks(level)
		var object: Node3D = host._dungeon.get_node("EntrancePotion" if level == 1 else ("Devices/Relay" if level == 2 else "Stations/model"))
		if level == 2: object = host._dungeon.get_node("EnergyRelayPuzzle/Inspect")
		await go(object.global_position+Vector3(0,0.05,1.1))
		host._hud.show_item_message("")
		await frames(6)
		check(bubbles.target == host._items._get_nearest_interaction_target() and bubbles.target != null,"Bubble uses the same nearest target as actual E interaction")
		for size in [Vector2i(1280,720),Vector2i(720,720),Vector2i(480,800),Vector2i(640,360)]:
			root.size = size
			await frames(10)
			check(bubbles.interaction.visible,"Nearby object bubble is visible: level%d %s" % [level,size])
			check(not host._hud.pickup_prompt.is_visible_in_tree() and (not host._hud.feedback_panel.visible or not bubbles.has_keys(host._hud._feedback_active.get("text",""))),"Key instructions are absent from the fixed left panel; ordinary state feedback remains separate")
			if bubbles.interaction.visible:
				var rect: Rect2 = bubbles.interaction.get_global_rect()
				check(root.get_visible_rect().encloses(rect),"Bubble remains inside viewport")
				check(bubbles.interaction.mouse_filter == Control.MOUSE_FILTER_IGNORE,"Bubble preserves combat input")
				var camera: Camera3D = host._dungeon.get_node("Camera3D")
				var point := camera.unproject_position(bubbles.target.global_position+Vector3.UP*1.5)
				check(rect.get_center().distance_to(point) < maxf(400,rect.size.x),"Bubble stays adjacent to actual projected object")
			await capture("level%d-object-%dx%d" % [level,size.x,size.y])
		await go(Vector3(3,0.05,3) if level == 1 else (host._dungeon.get_node("Regions/Arrival").global_position+Vector3.UP*0.05 if level == 2 else host._dungeon.get_node("Rooms/B").global_position+Vector3(0,0.05,2)))
		await frames(6)
		check(not bubbles.interaction.visible,"Leaving the actual reach hides the bubble")
		root.size = Vector2i(1280,720)
		var button: Button = host._hud.get_node("LevelObjective/%MapButton")
		button.grab_focus()
		await frames(8)
		check(bubbles.map_tip.visible,"M bubble appears beside focused map button")
		await capture("level%d-map-button" % level)
		button.release_focus()
		await frames(3)
		check(not bubbles.map_tip.visible,"M bubble disappears after leaving the map operation position")
		check(host._hud.get_node("LevelObjective").quest_map.open_map(),"Existing map still opens")
		await frames(3)
		check(not bubbles.interaction.visible and not bubbles.map_tip.visible,"Opening map/pause hides bubbles")
		host._hud.get_node("LevelObjective").quest_map.close_map()
		await go(object.global_position+Vector3(0,0.05,1.1))
		check(host._items.try_interact_nearest(),"Original object still accepts actual E interaction")
		await frames(4)
		if level == 1: check(not host._dungeon.has_node("EntrancePotion"),"Actual pickup and inventory lifecycle are retained")
	paused = false
	root.get_node("MusicManager").stop_music()
	current_scene.queue_free()
	await frames(3)
	print("INTERACTION_BUBBLE_RESULT %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func sizing_checks(level: int) -> void:
	var fixture: PanelContainer = bubbles._bubble()
	for dimensions in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(720,720),Vector2i(480,800),Vector2i(640,360)]:
		root.size = dimensions
		await frames(4)
		bubbles._copy(fixture,["E"],"交互")
		var short: Vector2 = bubbles._measure(fixture)
		var factor: float = host._hud.hint_dock._text_scale()
		check(short.x/factor < 90 and short.y/factor < 50,"Short copy occupies only its key, glyphs and small margins")
		bubbles._copy(fixture,["E"],"拾取 生命药剂 ×12")
		var medium: Vector2 = bubbles._measure(fixture)
		check(medium.x > short.x and medium.y == short.y,"Single-line pickup content grows horizontally without excess height")
		bubbles._copy(fixture,["Space"],"闪避攻击")
		var cap: Control = fixture.get_child(0).get_child(0)
		var glyph: Label = cap.get_child(0)
		check(cap.size.x <= glyph.get_minimum_size().x+11*factor,"Wide key fits its actual letters and padding")
		for sample in [["E"],["W","A","S","D"]]:
			bubbles._copy(fixture,sample,"检查机关石刻与水路连接，观察周围装置的变化，靠近后交互以确认当前机关状态与可用通路")
			var long: Vector2 = bubbles._measure(fixture)
			var label: Label = fixture.get_child(0).get_child(sample.size())
			check(long.x <= minf(360*factor,root.get_visible_rect().size.x*0.44)+2,"Long content respects the responsive width cap")
			check(long.y > short.y and label.get_line_count() > 1,"Long content grows vertically with natural wrapping")
			check(label.size.y >= label.get_minimum_size().y and label.get_visible_line_count() == label.get_line_count(),"All wrapped content remains visible")
			check(float(label.get_theme_font_size("font_size"))*root.size.x/root.get_visible_rect().size.x >= 13,"Bubble type remains readable after window scaling")
		bubbles._copy(fixture,["E"],"交互")
		check(bubbles._measure(fixture).is_equal_approx(short),"Long-to-short update releases old blank space immediately")
		if level == 1:
			fixture.visible = bubbles.place_screen(fixture,root.get_visible_rect().size*0.5,[])
			await capture("compact-short-%dx%d" % [dimensions.x,dimensions.y])
			bubbles._copy(fixture,["Space"],"闪避攻击并观察周围机关的变化，寻找安全的行动位置")
			fixture.visible = bubbles.place_screen(fixture,root.get_visible_rect().size*0.5,[])
			await capture("compact-wrapped-%dx%d" % [dimensions.x,dimensions.y])
		fixture.hide()
	fixture.queue_free()
	root.size = Vector2i(1280,720)
	await frames(4)
func go(point: Vector3) -> void:
	host._player.global_position = point
	host._player.velocity = Vector3.ZERO
	await frames(8)
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func capture(name: String) -> void:
	if not capture_enabled: return
	var out := OS.get_environment("GODOT_TEST_OUTPUT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(out.path_join(name+".png")) == OK,"Capture "+name)
