extends "res://tests/dungeon/test_level04_routes.gd"
## 正式战役全支线沿双环外圈通过 12 房；加 --walk 可用真实移动输入重跑。
const CAMPAIGN := "res://scenes/dungeon/Level04Run.tscn"
const PROFILE := preload("res://scripts/integration/player_profile.gd")
const PROGRESS := preload("res://scripts/integration/campaign_progress.gd")

func run() -> void:
	var token := "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	PROFILE.override_path = "user://observatory-world-profile-%s.cfg" % token
	PROGRESS.override_path = "user://observatory-world-progress-%s.cfg" % token
	walking = "--walk" in OS.get_cmdline_user_args()
	await route(15)
	if not failures:
		var result: Dictionary = current_scene._run_result
		check(result.get("rooms_visited") == 12 and result.get("rooms_total") == 12, "战役正式结算记录十二个房间")
		check(current_scene._hud.room_label.text.ends_with("12/12"), "战役 HUD 显示实际全探索十二房")
		check(result.get("reward_claimed") and result.get("puzzle_solved"), "旧镜室符文与密码柜成果交给战役结算")
		check("支线 4/4" in result.get("completion_summary", "") and level.puzzles.film_claimed, "四条支线与底片结局来自本局")
	for action in MOVE + ["sprint"]: Input.action_release(action)
	paused = false
	if is_instance_valid(current_scene): current_scene.queue_free()
	root.get_node("MusicManager").stop_music()
	await frames(5)
	for path in [PROFILE.override_path, PROGRESS.override_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("LEVEL04_CAMPAIGN_ROUTES: %d checks, %d failures; input_walk=%s" % [checks, failures, walking])
	quit(1 if failures else 0)

func start() -> void:
	change_scene_to_file(CAMPAIGN)
	await frames(6)
	level = current_scene.get_node("DungeonTest")
	check(level.get_visited_count() == 0 and not level.is_run_active(), "等候开始时地图处于未探索状态")
	var boss: CharacterBody3D = level.get_campaign_boss()
	check(is_instance_valid(boss) and not boss.visible and boss.collision_layer == 0 and not boss.take_damage(1), "尚未出场的执刑官不影响地图")
	current_scene._on_run_started()
	await frames(5)
