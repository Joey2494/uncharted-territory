extends SceneTree
## Shared UI entry points, live objectives, compact layouts and result copy.
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	PROFILE.override_path = "res://.godot/level02_ui_profile.cfg"
	PROGRESS.override_path = "res://.godot/level02_ui_progress.cfg"
	preload("res://scenes/player/character_catalog.gd").selected_id = "knight"
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)

func frames(count: int = 8) -> void:
	for i in count: await process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/level02_ui_%s.png" % label)

func run() -> void:
	for path in ["res://scenes/dungeon/Level02Run.tscn", "res://tests/scenes/Level02Preview.tscn"]:
		change_scene_to_file(path)
		await frames(12)
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		await frames()
		var host := current_scene
		var world := host.get_node("DungeonTest")
		var hud := host.get_node("UILayer/HUD")
		var objective := hud.get_node("LevelObjective")
		var boss_bar := host.get_node("UILayer/BossHealthBar")
		check(host.level_id == 2, "both entry points run second campaign")
		check(host._start_screen.start_button.text == "进入第二关", "second level menu copy")
		check(host._start_screen.theme == load("res://scenes/ui/menu_theme.tres"), "first level menu theme reused")
		host._on_run_started()
		await frames()
		check(objective.is_visible_in_tree(), "persistent objective shown after starting")
		check(objective.get_node("%ObjectiveTask").text.contains("向北"), "arrival objective from map")
		check(objective.get_node("%ObjectiveDetail").text.contains("1/8"), "actual exploration displayed")
		check(not objective.get_rect().intersects(hud.get_node("Panel").get_rect()), "objective clears health panel")
		await capture("wide")
		host.set_paused(true)
		await frames()
		var time_before: float = host._elapsed_seconds
		await frames()
		check(host._commerce.pause_menu.is_visible_in_tree(), "shared pause menu opens")
		check(host._elapsed_seconds == time_before, "pause freezes session clock")
		host.get_node("MenuNavigation").open_settings()
		check(host.get_node("MenuNavigation").settings_screen.visible, "shared settings accessible")
		host.get_node("MenuNavigation").settings_screen.go_back()
		check(host._commerce.pause_menu.visible, "settings returns to pause menu")
		host.set_paused(false)
		root.size = Vector2i(720, 720)
		await frames(20)
		check(objective.get_rect().end.x <= root.get_visible_rect().size.x, "compact objective stays in viewport")
		check(not objective.get_rect().intersects(host._overlay.get_node("Corner").get_rect()), "compact objective clears pause buttons")
		check(not host._commerce.shop_button.get_global_rect().intersects(hud.get_node("ResourcesPanel").get_global_rect()), "compact shop shortcut clears ammo and gold")
		await capture("compact")
		boss_bar.begin_encounter("灾厄巨蝎", 36, 36)
		await frames()
		check(not objective.visible, "compact Boss encounter reserves combat space")
		check(not boss_bar.get_rect().intersects(host._overlay.get_node("Corner").get_rect()), "compact Boss clears pause buttons")
		await capture("compact_boss")
		boss_bar.hide()
		await frames()
		check(objective.visible, "objective returns after Boss bar closes")
		world.player.global_position = world.get_node("Regions/Archive").global_position
		world.get_node("Camera3D").reset_follow()
		await frames()
		check(objective.get_node("%ObjectiveTask").text.contains("校准符文"), "branch objective follows actual puzzle")
		for control in [&"sun", &"moon", &"star", &"a", &"b", &"b", &"confirm"]:
			check(world.puzzle.perform_control(control, world.player), "puzzle interaction accepted")
		await create_timer(1.1).timeout
		check(world.puzzle.perform_control(&"reward", world.player), "real branch reward claimed")
		await frames()
		check(objective.get_node("%ObjectiveTask").text.contains("支线完成"), "objective reflects claimed reward")
		world.player.global_position = world.get_node("Regions/Boss").global_position
		await frames()
		check(objective.get_node("%ObjectiveTask").text.contains("灾厄巨蝎"), "Boss objective names actual second Boss")
		paused = true
		host._commerce.finish_run()
		hud.show_win_screen({"level_id": 2, "boss_name": "灾厄巨蝎", "player_hp": world.player.hp, "player_max_hp": world.player.max_hp, "rooms_total": 8, "rooms_visited": 8, "puzzle_solved": true, "reward_claimed": true}, false)
		await frames()
		var result: Control = hud.get_result_screen()
		check(result.get_node("%PuzzleLabel").text == "档案机关：已解开", "result names correct second puzzle")
		check(result.get_node("%RewardLabel").text == "密室奖励：已领取", "result shows reward state")
		check(not result.next_level_button.visible, "final level has no third-level button")
		await capture("result")
		paused = false
		current_scene = null
		host.free()
		await frames()
	print("LEVEL02 UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
