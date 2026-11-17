extends SceneTree
## Real HUD containers, lesson strings and input bindings; isolated user data.
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
const REFERENCE = preload("res://scenes/tutorial/control_reference.gd")
const SIZES := [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(1180,720),Vector2i(1179,720),Vector2i(1024,768),Vector2i(800,600),Vector2i(720,720),Vector2i(640,360),Vector2i(480,800)]
const OUT := "user://hud-layout-verification"
const REVEALED: Array[String] = ["attack","spell","dodge"]
var host: Node
var checks := 0
var failures := 0
var records: Array = []

func _initialize() -> void: run.call_deferred()
func run() -> void:
	# 测试记录跟随 Godot 用户目录，不依赖某位成员的本机磁盘布局。
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT)) != OK:
		push_error("Cannot create HUD verification output directory")
		quit(1)
		return
	PROFILE.override_path = "user://hud-layout-profile-%d.cfg" % Time.get_ticks_usec()
	PROGRESS.override_path = "user://hud-layout-campaign-%d.cfg" % Time.get_ticks_usec()
	PROFILE.set_coins(300)
	PROFILE.unlock_character("lan")
	PROFILE.set_selected_character("lan")
	if "--navigation-only" in OS.get_cmdline_user_args():
		for level in [1,2]:
			await boot(level)
			var navigation_sizes := [Vector2i(1280,720),Vector2i(720,720)] if level == 1 else [Vector2i(1280,720)]
			for dimensions in navigation_sizes:
				root.size = dimensions
				await frames(6)
				await pause_checks()
		await finish()
		return
	await boot(1)
	var sizes: Array = [Vector2i(720,720)] if "--baseline" in OS.get_cmdline_user_args() else SIZES
	var lessons: Array = ["move"] if "--baseline" in OS.get_cmdline_user_args() else REFERENCE.LESSONS.keys()
	for dimensions in sizes:
		root.size = dimensions
		for boss in [false,true]:
			if boss: host._boss_bar.begin_encounter(host._boss.boss_name, 12, 24)
			else: host._boss_bar.hide()
			for lesson in lessons:
				host._hud.show_item_message("已击败守卫 · 出口封印正在解除，请继续向前探索")
				host._hud.set_tutorial_guidance(lesson, REVEALED)
				await frames(6)
				verify_layout("level1/%s/%s/boss=%s" % [dimensions,lesson,boss])
				if "--capture" in OS.get_cmdline_user_args() and lesson == "move": await capture("tutorial" if not boss else "tutorial-boss")
	if "--baseline" not in OS.get_cmdline_user_args():
		await interaction_checks()
		await boot(2)
		for dimensions in SIZES:
			root.size = dimensions
			for boss in [false,true]:
				if boss: host._boss_bar.begin_encounter(host._boss.boss_name,24,24)
				else: host._boss_bar.hide()
				host._hud.show_item_message("已击败守卫 · 出口封印正在解除，请继续向前探索")
				await frames(6)
				verify_layout("level2/%s/boss=%s" % [dimensions,boss])
				if "--capture" in OS.get_cmdline_user_args(): await capture("level2-boss" if boss else "level2-objective")
		host._boss_bar.hide()
		root.size = Vector2i(1280,720)
		await frames(6)
		await pause_checks()
	await finish()

func finish() -> void:
	paused = false
	if not records.is_empty():
		var file := FileAccess.open(OUT.path_join("layout-records.json"),FileAccess.WRITE)
		if file == null:
			push_error("Cannot write HUD verification records")
			failures += 1
		else:
			file.store_string(JSON.stringify(records,"\t"))
	root.get_node("MusicManager").stop_music()
	current_scene.queue_free()
	await frames(3)
	print("HUD_COMPACT_LAYOUT_RESULT %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func boot(level: int) -> void:
	paused = false
	change_scene_to_file("res://Main.tscn" if level == 1 else "res://scenes/dungeon/Level02Run.tscn")
	await frames(8)
	host = current_scene
	root.mode = Window.MODE_WINDOWED
	host._on_run_started()
	host._player._invulnerability_remaining = 100000.0
	if level == 1: host.get_node("RunBindings").tutorial.set_physics_process(false)
	host._hud.show_item_message("已击败守卫 · 出口封印正在解除，请继续向前探索")
	host._hud._message_remaining = 100000.0
	await frames(4)

func visible_regions() -> Array[Control]:
	var regions: Array[Control] = []
	for control in [host._hud.get_node("Panel"),host._hud.get_node("ResourcesPanel"),host._hud.get_node("FeedbackPanel"),host._hud.get_node("CooldownBar"),host._hud.get_node("Hotbar"),host._hud.get_node("%TutorialPrompt"),host._boss_bar,host._commerce.shortcut,host._overlay.get_node("VersionFooter"),host._hud.get_node_or_null("LevelObjective")]:
		if is_instance_valid(control) and control.is_visible_in_tree(): regions.append(control)
	return regions

func verify_layout(label: String) -> void:
	var regions := visible_regions()
	var outside: Array[String] = []
	var overlaps: Array[String] = []
	var bounds := root.get_visible_rect().grow(1)
	var rectangles: Dictionary = {}
	for i in regions.size():
		var a := regions[i].get_global_rect()
		rectangles[String(regions[i].name)] = [a.position.x,a.position.y,a.size.x,a.size.y]
		if not bounds.encloses(a) or not a.has_area(): outside.append(String(regions[i].name))
		for j in range(i+1,regions.size()):
			if a.intersection(regions[j].get_global_rect()).get_area() > 1:
				overlaps.append("%s/%s" % [regions[i].name,regions[j].name])
	check(outside.is_empty(),label+": visible HUD regions fit the viewport "+str(outside))
	check(overlaps.is_empty(),label+": HUD regions do not overlap "+str(overlaps))
	var layout: Node = host.get_node("UILayer/ResponsiveLayout")
	var frame: Rect2 = layout._camera.get_safe_frame()
	var clear := Rect2(frame.position * root.get_visible_rect().size, frame.size * root.get_visible_rect().size)
	var blocked: Array[String] = []
	for control in regions:
		if clear.intersection(control.get_global_rect()).get_area() > 1: blocked.append(String(control.name))
	check(clear.has_area() and blocked.is_empty(),label+": camera-safe area avoids the complete HUD "+str(blocked))
	records.append({"case":label,"window":str(root.size),"viewport":str(root.get_visible_rect().size),"rects":rectangles,"overlaps":overlaps,"outside":outside})

func interaction_checks() -> void:
	host._boss_bar.hide()
	for dimensions in [Vector2i(1280,720),Vector2i(720,720)]:
		root.size = dimensions
		host._hud.set_tutorial_guidance("move",REVEALED)
		await frames(6)
		await pause_checks()
		await click(host._commerce.shop_button)
		check(host._commerce.view == host._commerce.View.SHOP and paused, "shop button remains clickable and pauses gameplay")
		host._commerce.shop.back_requested.emit()
		await frames(6)
		check(not paused and host._commerce.shortcut.visible, "closing shop restores its shortcut and gameplay")
		# Inventory refreshes used to independently reposition the shop shortcut.
		host._items._publish_state()
		await frames(5)
		verify_layout("after inventory/shop refresh "+str(dimensions))
	await click(host._hud.get_node("%TutorialPrompt").skip_button)
	check(not host._hud.get_node("%TutorialPrompt").visible and host.get_node("RunBindings").tutorial.finished, "tutorial skip button still completes and hides the tutorial")
	verify_layout("after tutorial skip")
	var actions := {"attack":0,"spell":0,"dodge":0}
	host._player.get_node("MeleeAttack").attack_started.connect(func() -> void: actions.attack += 1)
	host._player.get_node("EnergyShock").released.connect(func(_bolt: Node3D) -> void: actions.spell += 1)
	host._player.dodge_started.connect(func() -> void: actions.dodge += 1)
	await click(host._hud.melee_cooldown.get_node("%ActivateButton"))
	check(actions.attack == 1, "relocated attack badge still triggers one real attack")
	await create_timer(0.6).timeout
	await click(host._hud.skill_cooldown.get_node("%ActivateButton"))
	await create_timer(0.6).timeout
	check(actions.spell == 1, "relocated spell badge still triggers one real cast")
	await click(host._hud.dodge_cooldown.get_node("%ActivateButton"))
	check(actions.dodge == 1, "relocated dodge badge still triggers one real dodge")
	await create_timer(0.6).timeout
	host._player.hp = host._player.max_hp - 1
	var reward: Dictionary = {}
	reward[host._items.HEALTH_POTION] = 1
	host._items.grant_reward("hud-layout-potion",reward,0)
	await frames(4)
	await click(host._hud.hotbar.get_node("Slots/Slot1"))
	check(host._player.hp == host._player.max_hp and host._items.potion_count == 0, "relocated hotbar still uses its actual potion")

func pause_checks() -> void:
	var label := "level%d/%s: " % [host.level_id,str(root.size)]
	var old_shortcuts: Array[String] = []
	for button in host.find_children("*","Button",true,false):
		if button.is_visible_in_tree() and button.text in ["探索指引","Esc 暂停"]:
			old_shortcuts.append(button.text)
	check(old_shortcuts.is_empty(), label+"gameplay has no permanent guide or pause shortcuts")
	if "--capture" in OS.get_cmdline_user_args(): await capture("clean-hud-level%d" % host.level_id)
	await key(KEY_ESCAPE)
	var menu: Control = host._commerce.pause_menu
	check(paused and host.get_run_state() == host.RunState.PAUSED and menu.is_visible_in_tree(), label+"Esc opens the pause menu")
	var guide_button: Button = menu.get_node("%ControlsGuideButton")
	check(guide_button.is_visible_in_tree() and guide_button.text == "操作指南", label+"pause menu exposes the direct controls-guide entry")
	var elapsed: float = host._elapsed_seconds
	await frames(5)
	check(is_equal_approx(host._elapsed_seconds,elapsed), label+"pause freezes the actual run timer")
	if "--capture" in OS.get_cmdline_user_args(): await capture("pause-level%d" % host.level_id)
	await click(guide_button)
	var settings: Control = host.get_node("MenuNavigation").settings_screen
	var guide: Control = settings.get_node("ControlsGuide")
	check(settings.is_visible_in_tree() and guide.is_visible_in_tree() and not settings.get_node("Center").visible and not menu.visible, label+"pause entry opens the full guide directly")
	check(paused and host.get_run_state() == host.RunState.PAUSED and guide._close.text == "返回暂停菜单", label+"guide preserves pause and identifies its return destination")
	var motion := InputEventMouseMotion.new()
	motion.position = host._commerce.shop_button.get_global_rect().get_center()
	root.push_input(motion,true)
	var hovered := root.gui_get_hovered_control()
	check(hovered != null and settings.is_ancestor_of(hovered), label+"guide covers the HUD and intercepts its background shop shortcut")
	await key(KEY_P)
	check(guide.is_visible_in_tree() and paused and host._commerce.view == host._commerce.View.NONE, label+"shop hotkey cannot open a hidden panel behind the guide")
	await frames(5)
	check(is_equal_approx(host._elapsed_seconds,elapsed), label+"reading the guide does not advance the run")
	if "--capture" in OS.get_cmdline_user_args(): await capture("guide-level%d" % host.level_id)
	await key(KEY_ESCAPE)
	check(paused and menu.is_visible_in_tree() and not settings.visible and host.get_run_state() == host.RunState.PAUSED, label+"Esc closes the guide to pause without resuming gameplay")
	check(guide_button.has_focus(), label+"returning restores focus to the guide entry")
	await key(KEY_ENTER)
	check(guide.is_visible_in_tree() and paused, label+"Enter on the focused guide entry reopens it")
	await click(guide._close)
	check(menu.is_visible_in_tree() and not settings.visible and paused, label+"guide return button also restores the pause menu")
	await click(menu.get_node("%SettingsButton"))
	await click(settings.get_node("%ControlsGuideButton"))
	check(guide.is_visible_in_tree() and guide._close.text == "返回设置", label+"settings retains its original nested guide entry")
	await key(KEY_ESCAPE)
	check(settings.is_visible_in_tree() and settings.get_node("Center").visible and not guide.visible and paused, label+"nested guide returns to settings")
	await key(KEY_ESCAPE)
	check(menu.is_visible_in_tree() and not settings.visible and paused, label+"settings returns to pause")
	await click(menu.get_node("%ResumeButton"))
	check(not paused and host.get_run_state() == host.RunState.PLAYING, label+"resume button returns to gameplay")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	check(not paused and not menu.visible and host.get_run_state() == host.RunState.PLAYING, label+"Esc continues to toggle pause and resume")

func key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)
	await frames(3)

func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		root.push_input(event,true)
	await frames(3)
func capture(label: String) -> void:
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT.path_join("%s-%dx%d.png" % [label,root.size.x,root.size.y]))
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
