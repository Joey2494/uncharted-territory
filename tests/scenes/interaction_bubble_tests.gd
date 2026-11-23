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
		if level == 2: await archive_copy_checks()
		if level == 3: await reset_copy_checks()
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

# Read the actual visible bubble, never the hidden legacy pickup label.
func visible_copy(expected: String, context: String) -> void:
	var panel: PanelContainer = bubbles.interaction
	var label: Label = panel.get_child(0).get_child(1)
	check(panel.is_visible_in_tree() and label.is_visible_in_tree(),context+": bubble is visible")
	check(label.text == expected,context+": complete name, action and restrictions: "+label.text)
	check(label.get_visible_line_count() == label.get_line_count() and label.size.y >= label.get_minimum_size().y,context+": all wrapped lines are visible")
	check(root.get_visible_rect().encloses(panel.get_global_rect()),context+": complete bubble fits viewport")
	for obstacle in host._hud.hint_dock.obstacles():
		check(not panel.get_global_rect().intersects(obstacle),context+": bubble avoids HUD and actors")

func archive_copy_checks() -> void:
	var puzzle: Node = host._dungeon.puzzle
	await go(puzzle.get_node("BridgeSocket").global_position+Vector3(1.25,0.05,0))
	# Allow the actual archive room camera to finish its entrance framing.
	await frames(60)
	visible_copy("桥台插槽 · 主供能中断\n检查供能来源","Archive offline")
	puzzle.enable_supply()
	await frames(3)
	visible_copy("桥台插槽 · 空槽\n检查空槽（手持为空）","Archive empty hands")
	await archive_use("CoreRack")
	await go(puzzle.get_node("BridgeSocket").global_position+Vector3(1.25,0.05,0))
	visible_copy("桥台插槽 · 空槽\n放入一枚能源","Archive insert")
	check(host._items.try_interact_nearest(),"Actual bridge insertion")
	await frames(3)
	visible_copy("桥台插槽 · 已供能\n撤回能源","Archive retrieve")
	await go(puzzle.get_node("BridgeSocket").global_position+Vector3(-1.2,0.05,0))
	visible_copy("桥台插槽 · 已供能\n检查插槽（先离开桥面）","Archive bridge safety")
	for dimensions in [Vector2i(1280,720),Vector2i(720,720),Vector2i(480,800),Vector2i(640,360)]:
		root.size = dimensions
		await go(puzzle.get_node("Lever").global_position+Vector3(0,0.05,1.35))
		visible_copy("步道开关 · 检修线断开\n拉下开关，展开返回步道并接通门锁","Archive long action %s" % dimensions)
		var label: Label = bubbles.interaction.get_child(0).get_child(1)
		check(label.get_line_count() >= 2,"Real action retains its explicit newline")
		if dimensions.x == 480: check(label.get_line_count() > 2,"Narrow viewport naturally wraps the real long action")
		await capture("archive-full-action-%dx%d" % [dimensions.x,dimensions.y])
	root.size = Vector2i(1280,720)

func archive_use(name: String) -> void:
	await go(host._dungeon.puzzle.get_node(name).global_position+Vector3(0,0.05,1.35))
	check(host._items.try_interact_nearest(),"Archive actual interaction: "+name)
	await frames(3)

func station_use(id: String) -> void:
	await go(host._dungeon.get_node("Stations/"+id).global_position+Vector3(0,0.05,1.1))
	check(host._items.try_interact_nearest(),"Tide actual interaction: "+id)
	await frames(3)

func reset_copy_checks() -> void:
	var map: Node = host._dungeon
	await station_use("tide")
	# Register real encounter deaths and collect the actual optional reward.
	for id in ["E","F"]:
		await go(map.get_node("Rooms/"+id).global_position+Vector3(0,0.05,3))
		for enemy in map.get_node("Enemies").get_children():
			if enemy.get_meta("room",&"") == StringName(id): check(enemy.take_damage(999),"Actual enemy death "+id)
		await frames(6)
	await station_use("highwalk")
	await station_use("reward")
	var reward_count: int = host._items.rune_count
	check(reward_count == 1 and map._progress.is_complete(&"F"),"Reset fixture has genuine reward and combat clear")
	await station_use("reset")
	check(map._high and map._highwalk,"First E does not reset puzzle")
	var expected := "重置机关\n4秒内再次按 E 确认\n重置水位、导体、储能和机关门\n清场记录与已领取奖励保留"
	for dimensions in [Vector2i(1280,720),Vector2i(720,720),Vector2i(480,800),Vector2i(640,360)]:
		root.size = dimensions
		await frames(4)
		visible_copy(expected,"Reset armed %s" % dimensions)
		await capture("reset-confirm-%dx%d" % [dimensions.x,dimensions.y])
	check(host._items.try_interact_nearest(),"Second E confirms within four seconds")
	await frames(4)
	visible_copy("重置机关\n请求重置","Reset confirmed")
	check(not map._high and not map._highwalk and map.get_storage_state() == 0,"Confirmation restores puzzle state")
	check(map._progress.is_complete(&"E") and map._progress.is_complete(&"F") and host._items.rune_count == reward_count and host._items.has_claimed(map.REWARD_ID),"Confirmation preserves clears and reward claim")
	root.size = Vector2i(1280,720)
	await station_use("tide")
	await station_use("reward")
	check(host._items.rune_count == reward_count,"Reset cannot duplicate reward")
	await station_use("reset")
	visible_copy(expected,"Reset armed before timeout")
	await create_timer(4.2).timeout
	await frames(3)
	visible_copy("重置机关\n请求重置","Timeout cancels confirmation")
	check(map._reset_armed == 0.0 and map._high and host._items.rune_count == reward_count and map._progress.is_complete(&"F"),"Timeout leaves gameplay and rewards unchanged")
	check(host._items.try_interact_nearest(),"E after timeout requests a fresh confirmation")
	await frames(3)
	visible_copy(expected,"Fresh request after timeout")
	check(map._high,"Late E cannot confirm expired request")
	await go(map.get_node("Rooms/B").global_position+Vector3(0,0.05,2))
	check(map._reset_armed == 0.0,"Leaving reset range still cancels confirmation")

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
