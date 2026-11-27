extends "res://tests/dungeon/test_level04_routes.gd"
## 从正式选关开始，验证地图事件经过同一套 HUD、结算及持久化入口。
const PROFILE := preload("res://scripts/integration/player_profile.gd")
const PROGRESS := preload("res://scripts/integration/campaign_progress.gd")
const FOURTH := "res://scenes/dungeon/Level04Run.tscn"
var host: Node
var progress

func run() -> void:
	var token := "%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	PROFILE.override_path = "user://observatory-profile-%s.cfg" % token
	PROGRESS.override_path = "user://observatory-progress-%s.cfg" % token
	PROFILE.set_coins(50)
	progress = PROGRESS.new()
	change_scene_to_file("res://Main.tscn")
	await frames(12)
	var nav := current_scene.get_node("MenuNavigation")
	nav._open_levels()
	var selector: Button = nav.level_select.get_level_button(&"level4")
	check(is_instance_valid(selector) and selector.is_visible_in_tree() and not selector.disabled,"选关页正式第四关卡片")
	if selector:
		selector.pressed.emit()
		await wait_handoff(FOURTH)
		host = current_scene
		check(host.scene_file_path == FOURTH and host.get_run_state() == host.RunState.PLAYING,"从正式卡片进入战役宿主")
		if not failures: await play_campaign()
		if not failures: await continue_and_lose()
	paused = false
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames(4)
	root.get_node("MusicManager").stop_music()
	await create_timer(0.3).timeout
	for path in [PROFILE.override_path,PROGRESS.override_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("LEVEL04_CAMPAIGN: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func play_campaign() -> void:
	level = host._dungeon
	var hud: Control = host._hud
	check(hud.scene_file_path == "res://scenes/ui/hud.tscn" and hud.is_visible_in_tree(),"显示前三关使用的 HUD 实例")
	check(hud.hp_bar.is_visible_in_tree() and hud.energy_bar.is_visible_in_tree() and hud.hotbar.is_visible_in_tree(),"生命、能量与快捷道具均可见")
	check(progress.get_last_played_level() == &"level4" and not progress.is_completed(&"level4"),"进房写最近游玩，尚未通关")
	check(hud.total_rooms == 12 and hud.room_segments.get_child_count() == 12,"按 12 个房间显示探索段")
	var tracker: Control = hud.get_node("LevelObjective")
	check(tracker._snapshot.tasks.size() == 7 and tracker._snapshot.tasks[0].id == "combat_B", "统一任务栏读取第四关主线，不访问第二关接口")
	check(tracker.quest_map.open_map() and paused, "统一地图按钮可打开第四关地图")
	check(tracker.quest_map.view.snapshot.rooms.size() == 12 and tracker.quest_map.view.snapshot.paths.size() == 16 and tracker.quest_map.view.snapshot.target.id == "combat_B", "第四关地图来自十二房和实际通路，标记首个主线目标")
	tracker.quest_map.close_map()
	check(not paused and host.get_run_state() == host.RunState.PLAYING, "统一地图关闭后恢复原战役")
	var player: CharacterBody3D = level.player
	player.take_damage(player.shield+1)
	await frames(3)
	check(hud.hp_bar.value == player.hp and player.hp == player.max_hp-1 and player.shield == 0,"真实掉盾与失血后血条更新")
	player.spend_energy(6)
	await frames(3)
	check(absf(hud.energy_bar.value-player.energy) < 1 and player.energy < player.max_energy,"真实消耗驱动能量条")
	check(not host._boss_bar.visible,"终战前隐藏首领面板")
	await clear("B",1,3)
	check(tracker._snapshot.tasks[0].done, "B 清场更新正式任务栏")
	await cross("B","C")
	check(level.layout.passage_open("C","E") and level.layout.passage_open("C","F"), "正式战役分岔同时开放")
	check(tracker._snapshot.get("focus",{}).get("id") == "wings", "统一任务栏允许同时选择东西翼")
	check(tracker.quest_map.open_map(), "从 C 打开任务地图")
	var markers: Array = tracker.quest_map.view.snapshot.target.get("markers",[])
	var wings: Array[String] = []
	for marker in markers: wings.append(marker.id)
	wings.sort()
	check(wings == ["E","F"], "地图同时标记 E、F 两个选择")
	tracker.quest_map.close_map()
	await cross("C","F")
	await clear("F",-2,3)
	check(tracker._snapshot.tasks[tracker._snapshot.current].id == "calibrated", "先打 F 后任务栏指向 E 柜")
	check_trial_gates(false)
	await cross("F","E")
	await use(&"p_safe")
	if failures: return
	check(level.puzzles.modal_open() and paused,"开密码柜冻结玩法")
	await key_press(KEY_ESCAPE)
	check(not level.puzzles.modal_open() and not paused and host.get_run_state() == host.RunState.PLAYING,"Esc 只退出当前密码柜")
	await use(&"p_safe")
	for pair in [[0,4],[1,2],[2,5]]: level.puzzles.operate(&"digit",pair[0],pair[1])
	level.puzzles.operate(&"submit")
	await frames(75)
	check(level.puzzles.calibrated and not paused,"数字柜解开后恢复战役")
	await key_press(KEY_TAB)
	check(level.is_modal_open(),"Tab 打开路线图")
	await key_press(KEY_ESCAPE)
	check(not level.is_modal_open() and host.get_run_state() == host.RunState.PLAYING and not paused,"关闭地图后继续同一局")
	check_trial_gates(true)
	await cross("E","H")
	await frames(370)
	await clear("H",1,2)
	await cross("H","I")
	check(level.combat.active_room == "" and not host._boss_bar.visible, "安全门廊尚未激活首领")
	await go("I",3,4)
	var boss = level.combat.boss_guard()
	check(is_instance_valid(boss) and host._boss_bar.is_visible_in_tree(),"跨入主穹顶显示共享 Boss 条")
	if not is_instance_valid(boss): return
	boss.take_damage(1)
	check(host._boss_bar.hp_bar.value == boss.hp and host._boss_bar.hp_bar.max_value == boss.max_hp,"Boss 条跟随实际生命")
	boss.take_damage(999)
	await frames(2)
	check(level.combat.enemy_count() > 0 and not level.is_exit_open() and not progress.is_completed(&"level4"),"女巫先倒下，尖蓟近卫仍能守门")
	await clear("I",3,4)
	var earnings: int = level.inventory.gold
	check(earnings > 50 and PROFILE.coins == 50 and not progress.is_completed(&"level4"),"本轮金币成功之前不入永久钱包")
	var carried := {}
	for id in PROFILE.BAG_IDS: carried[id] = level.inventory.get_count(id)
	await cross("I","J")
	await go("J",0,-2)
	var result: Control = hud.get_result_screen()
	check(host.get_run_state() == host.RunState.VICTORY and is_instance_valid(result),"登台打开正式胜利结算")
	if not result: return
	check(not result.next_level_button.visible and not host.advance_to_next_level(),"第四关作为末关收尾")
	check(host._run_result.rooms_visited == 8 and host._run_result.rooms_total == 12,"零支线结算显示探索八房")
	check(progress.is_completed(&"level4") and PROFILE.coins == earnings,"通关写进度且不重复入账金币")
	check(PROFILE.inventory == carried,"成功通关将全部剩余道具保存到永久背包")
	check(tracker._snapshot.complete and tracker.get_node("%QuestTask").text == "关卡目标已完成", "实际登台同步更新统一任务栏完成状态")
	host._on_exit_reached()
	check(PROFILE.coins == earnings,"重复出口信号不重复发奖")

func continue_and_lose() -> void:
	var wallet: int = PROFILE.coins
	change_scene_to_file("res://Main.tscn")
	await frames(14)
	current_scene._start_screen.get_node("%ContinueButton").pressed.emit()
	await wait_handoff(FOURTH)
	host = current_scene
	check(host.scene_file_path == FOURTH and host.get_run_state() == host.RunState.PLAYING,"从主菜单继续正式第四关")
	if failures: return
	level = host._dungeon
	check(level.visited.size() == 1 and not level.puzzles.calibrated,"继续游戏按既有规则重新整备")
	level.inventory.add_gold(8)
	level.inventory.add_item(0,3)
	level.player.take_damage(999)
	await frames(180)
	check(host.get_run_state() == host.RunState.DEAD and is_instance_valid(host._hud.get_result_screen()),"死亡显示统一失败面板")
	check(PROFILE.coins == 0 and level.inventory.gold == 0 and level.inventory.potion_count == 0 and progress.is_completed(&"level4"),"最终失败清空所有携带金币道具，保留已完成记录")

func key_press(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)
