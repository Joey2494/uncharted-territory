extends SceneTree
## 正式第三关接线回归：真实菜单、实际机关/伤害/出口，隔离用户档案。
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
const CHARACTERS = preload("res://scenes/player/character_catalog.gd")
const THIRD := "res://scenes/dungeon/Level03Run.tscn"
var host: Node
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var unique := "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	PROFILE.override_path = "user://third-profile-" + unique + ".cfg"
	PROGRESS.override_path = "user://third-progress-" + unique + ".cfg"
	PROFILE.set_coins(1000)
	for role in ["lan", "iron", "astra"]: PROFILE.unlock_character(role)
	var progress := PROGRESS.new()
	check(progress.is_unlocked(&"level3") and progress.completed.is_empty(), "测试版新档直接开放第三关且不伪造通关")
	progress.complete(1)
	check(progress.is_unlocked(&"level3") and not progress.is_completed(&"level2"), "第三关不依赖第二关通关记录")
	progress.complete(2)
	check(progress.is_unlocked(&"level3") and progress.recommended_level() == &"level3", "第二关完成后推荐并解锁第三关")
	var legacy := ConfigFile.new()
	legacy.set_value("campaign", "completed", ["level1", "level2"])
	legacy.set_value("campaign", "played", ["level1", "level2"])
	legacy.set_value("metadata", "kept", "legacy")
	var legacy_path := "user://third-legacy-" + unique + ".cfg"
	legacy.save(legacy_path)
	var active_path: String = PROGRESS.override_path
	PROGRESS.override_path = legacy_path
	var migrated := PROGRESS.new()
	check(migrated.is_unlocked(&"level3") and migrated.get_last_played_level() == &"level2", "旧双关存档解锁第三关且保留最近游玩")
	migrated.mark_played(3)
	legacy.load(legacy_path)
	check(legacy.get_value("metadata", "kept") == "legacy" and migrated.get_last_played_level() == &"level3", "升级保留无关字段并记录第三关")
	PROGRESS.override_path = active_path
	check(ResourceLoader.exists(THIRD), "正式第三关场景存在")
	if not ResourceLoader.exists(THIRD):
		finish()
		return
	# 用实际二关出口覆盖解锁、角色传递和直接开始。
	await second_to_third()
	if host.level_id != 3:
		finish()
		return
	await third_route()
	await lifecycle()
	finish()

func frames(count: int = 8) -> void:
	for i in count: await physics_frame

	# Transitions now await real threaded resources, not a fixed frame budget.
	var deadline := Time.get_ticks_msec()+15000
	while root.get_node_or_null("LoadingScreen") != null and Time.get_ticks_msec() < deadline:
		await process_frame

func go(point: Vector3) -> void:
	host._player.global_position = point
	host._player.velocity = Vector3.ZERO
	await frames()

func second_to_third() -> void:
	PROFILE.set_selected_character("lan")
	CHARACTERS.start_pending = false
	change_scene_to_file("res://Main.tscn")
	await frames()
	host = current_scene
	var nav: Node = host.get_node("MenuNavigation")
	nav._open_levels()
	check(nav.level_select.get_level_button(&"level3") != null, "正式选关目录包含第三关")
	# 清除单元检查记录，确认测试版选关不依赖完成记录。
	nav.progress.completed.erase("level2")
	nav.level_select.refresh_progress()
	check(not nav.level_select.get_level_button(&"level3").disabled, "二关未完成时第三关按钮仍可用")
	nav.level_select.get_level_button(&"level2").pressed.emit()
	await frames(12)
	host = current_scene
	check(host.level_id == 2 and host.get_run_state() == host.RunState.PLAYING, "真实选关直接开始第二关")
	host._player._invulnerability_remaining = 1000.0
	var map: Node = host._dungeon
	for room in ["Hub", "Relay", "Antechamber", "Boss"]:
		await go(map.get_node("Regions/" + room).global_position + Vector3(0, 0.05, 2))
		if room == "Boss":
			check(host._boss.take_damage(999), "第二关真实 Boss 死亡")
		else:
			for enemy in map.get_node("Enemies").get_children():
				if enemy.name.begins_with(room): check(enemy.take_damage(999), "清除二关守卫 " + String(enemy.name))
		if room == "Relay":
			await go(map.get_node("Devices/Relay").global_position + Vector3(0, 0.05, 1.35))
			check(host._items.try_interact_nearest(), "真实交互启动二关导能")
		await create_timer(1.1).timeout
	check(not host.get_node("MenuNavigation").progress.is_completed(&"level2"), "仅击败二关 Boss 不能伪造二关通关记录")
	var exit_point: Vector3 = map.get_node("ExitArea").global_position
	exit_point.y = 0.05
	await go(exit_point)
	check(host.get_run_state() == host.RunState.VICTORY and host.get_node("MenuNavigation").progress.is_unlocked(&"level3"), "二关实际出口结算解锁第三关")
	var result: Control = host._hud.get_result_screen()
	check(result != null and result.next_level_button.visible, "第二关结算提供第三关按钮")
	if result == null: return
	# 场景资源故障注入：保留真实二关结算，恢复资源后重试相同第三关交接。
	var original: PackedScene = load(THIRD)
	var broken := PackedScene.new()
	broken.take_over_path(THIRD)
	print("EXPECTED_LOAD_FAILURE_BEGIN third-next")
	result.next_level_button.pressed.emit()
	await frames()
	print("EXPECTED_LOAD_FAILURE_END third-next")
	original.take_over_path(THIRD)
	nav = host.get_node("MenuNavigation")
	check(host.get_run_state() == host.RunState.VICTORY and nav.load_error.visible and not host._transition_queued and not CHARACTERS.start_pending, "第三关载入失败保留二关结算并释放交接状态")
	for i in 4: nav.load_error.get_node("%RetryButton").pressed.emit()
	await frames(12)
	host = current_scene
	check(host.level_id == 3 and host.get_run_state() == host.RunState.PLAYING and host._player.character_id == "lan", "第二关结算直接进入第三关并保留岚")

func use_station(id: StringName) -> void:
	await go(host._dungeon.get_node("Stations/" + id).global_position + Vector3(0, 0.05, 1.1))
	check(host._items.try_interact_nearest(), "实际 E 交互 " + String(id))
	await frames()

func clear_room(id: StringName) -> void:
	await go(host._dungeon.get_node("Rooms/" + id).global_position + Vector3(0, 0.05, 3))
	for enemy in host._dungeon.get_node("Enemies").get_children():
		if enemy.get_meta("room", &"") == id and not enemy.get_meta("summoned", false) and not enemy.is_dead():
			check(enemy.take_damage(999), "实际伤害清除第三关 " + String(enemy.name))
	await create_timer(0.45).timeout

func third_route() -> void:
	var map: Node = host._dungeon
	host._player._invulnerability_remaining = 1000.0
	var wallet_before: int = PROFILE.coins
	check(host._items.add_gold(37) and PROFILE.coins == wallet_before, "第三关本局金币独立于永久钱包")
	check(host._boss != null and host._boss.enemy_id == "sand_king" and not host._boss_bar.visible, "第三关接入字远沙缚王，入场前隐藏 Boss 血条")
	check(root.get_node("MusicManager").current_context == &"level_3", "第三关进入自己的游戏音乐上下文")
	check(map.get_node_or_null("HUD") == null, "正式宿主不叠加独立白盒 HUD")
	check(host._hud.visible and map.get_room_count() == 10 and map.get_visited_count() == 1, "共享 HUD 与第三关到达进度已绑定")
	var objective: Dictionary = map.get_hud_objective()
	check(objective.has_all(["id", "title", "category", "progress", "completed"]), "第三关目标提供共享展示协议")
	check(objective.completed is Array and objective.resource_summary.contains("低水位"), "常驻目标协议包含完成列表和潮汐资源状态")
	await frames()
	check(host._hud.get_node("LevelObjective/%ObjectiveResources").text.contains("导体在沉沙库"), "共享 HUD 实际显示第三关持续资源状态")
	await go(map.get_node("Rooms/J").global_position)
	host._on_exit_reached()
	check(host.get_run_state() == host.RunState.PLAYING, "提前到出口或伪发出口信号不能结算")
	await use_station(&"tide")
	check(map.get_hud_objective().title.contains("降低水位"), "高水位且导体未取时明确要求先降潮")
	await use_station(&"tide")
	await clear_room(&"C")
	await use_station(&"conductor")
	await use_station(&"tide")
	check(map.get_hud_objective().title.contains("降低水位"), "已取导体但未东向时，高水位提示先降潮再去 D")
	await use_station(&"tide")
	await use_station(&"director")
	await use_station(&"tide")
	await clear_room(&"E")
	await clear_room(&"F")
	await use_station(&"charge")
	await use_station(&"highwalk")
	await use_station(&"tide")
	await use_station(&"director")
	# 最终守卫允许测试定位；泄压仍是不可绕过的独立胜利条件。
	await clear_room(&"G")
	await go(map.get_node("Rooms/J").global_position)
	host._on_exit_reached()
	check(host.get_run_state() == host.RunState.PLAYING, "G 清场及出口重叠不能绕过 I 泄压")
	await use_station(&"release")
	check(map.get_storage_state() == 2 and host.get_run_state() == host.RunState.PLAYING, "真实泄压仍不能替代实际出口")
	# 仅让钱包存档写入失败，保持同一档案的内存余额和本局结算身份。
	var profile_path: String = PROFILE.override_path
	PROFILE.override_path = "user://third-missing-%d/profile.cfg" % Time.get_ticks_usec()
	PROFILE._loaded_path = PROFILE.override_path
	await go(map.get_node("Rooms/J").global_position)
	check(host.get_run_state() == host.RunState.VICTORY and map.is_victorious(), "I 泄压、G 清场、门打开并走入 J 才通关")
	check(host.get_node("MenuNavigation").progress.is_completed(&"level3"), "第三关完成写入进度")
	var result: Control = host._hud.get_result_screen()
	check(result != null and not result.next_level_button.visible and not host.advance_to_next_level(), "第三关终局没有第四关按钮且拒绝越界跳转")
	check(result.summary_label.text.contains("沙缚王") and result.summary_label.text.contains("守卫") and result.get_node("%PuzzleLabel").text.contains("潮汐"), "结算如实显示沙缚王、守卫和潮汐机关")
	check(not host._settled and PROFILE.coins == wallet_before and host._items.gold == 37 and host._settlement_id not in PROFILE.settled_runs, "第三关结算保存失败回滚钱包并保留本局金币")
	check(result.get_node("%SettlementLabel").text.contains("金币保存失败") and result._retry.visible, "第三关结算显示金币失败文案和实际重试按钮")
	check(result.get_node("%RewardLabel").text == "溢流花园奖励：未领取", "金币保存失败不覆盖第三关奖励名称和实际领取状态")
	await result_layout(result)
	PROFILE.override_path = profile_path
	PROFILE._loaded_path = profile_path
	result._retry.pressed.emit()
	await frames()
	check(host._settled and PROFILE.coins == wallet_before + 37 and host._items.gold == 0, "胜利页真实按钮重试成功仅入账本局金币")
	check(result.get_node("%SettlementLabel").text == "通关结算：+37 金币 · 已存入永久钱包" and not result._retry.visible, "重试成功更新结算文案并隐藏重试按钮")
	check(result.summary_label.text == map.get_completion_snapshot().completion_summary and result.get_node("%PuzzleLabel").text == "潮汐机关：已解开" and result.get_node("%RewardLabel").text == "溢流花园奖励：未领取", "重试刷新保留第三关完成摘要与机关奖励字段")
	result._retry.pressed.emit()
	host._on_exit_reached()
	check(PROFILE.coins == wallet_before + 37, "重复保存重试与出口回调不重复入账")
	await result_layout(result)
	result.restart_button.pressed.emit()
	await frames(12)
	host = current_scene
	check(host.level_id == 3 and host.get_run_state() == host.RunState.PLAYING and host._dungeon.get_storage_state() == 0, "第三关胜利重开新局重置机关")

func result_layout(screen: Control) -> void:
	for dimensions in [Vector2i(1280, 720), Vector2i(720, 720)]:
		root.size = dimensions
		await frames()
		var panels: Array[Control] = [screen.get_node("%ResultDetails"), screen.get_node("%RewardsPanel"), screen.get_node("%SettlementLabel"), screen.get_node("%ProgressLabel"), screen.restart_button, screen.get_node("%LevelSelectButton"), screen.get_node("%MainMenuButton")]
		if screen._retry.visible: panels.append(screen._retry)
		var viewport := root.get_visible_rect()
		var bounded := true
		var separated := true
		for i in panels.size():
			bounded = bounded and viewport.encloses(panels[i].get_global_rect())
			for j in range(i + 1, panels.size()):
				if panels[i].get_global_rect().intersects(panels[j].get_global_rect()):
					print("LAYOUT_OVERLAP ", panels[i].name, " ", panels[j].name)
				separated = separated and not panels[i].get_global_rect().intersects(panels[j].get_global_rect())
		check(bounded and separated, "%s 金币状态、机关奖励、补给与操作按钮均在窗口内且互不重叠" % dimensions)
		var readable := true
		for name in ["PuzzleLabel", "RewardLabel", "SettlementLabel"]:
			var label: Label = screen.get_node("%" + name)
			readable = readable and label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x <= label.size.x
		check(readable, "%s 机关奖励与金币保存文案完整可读" % dimensions)
	root.size = Vector2i(1280, 720)
	await frames()

func lifecycle() -> void:
	for role in CHARACTERS.IDS:
		PROFILE.set_selected_character(role)
		CHARACTERS.start_pending = false
		change_scene_to_file("res://Main.tscn")
		await frames(12)
		host = current_scene
		var nav: Node = host.get_node("MenuNavigation")
		nav._open_levels()
		nav.level_select.get_level_button(&"level3").pressed.emit()
		await frames(12)
		host = current_scene
		check(host.level_id == 3 and host._player.character_id == role and host.get_run_state() == host.RunState.PLAYING, role + " 从正式选关进入第三关")
		check(host.set_paused(true) and paused and not host._dungeon.can_process(), role + " 暂停冻结地图")
		nav = host.get_node("MenuNavigation")
		host._commerce.pause_menu.get_node("%ControlsGuideButton").pressed.emit()
		var guide: Control = nav.settings_screen.get_node("ControlsGuide")
		var reference: Control = guide.find_child("LevelReference", true, false)
		check(guide.is_visible_in_tree() and reference != null and reference.is_visible_in_tree(), "共享指南显示第三关路线参考")
		if reference != null:
			check(reference.get_node("RouteBody").text.contains("C—D") and reference.get_node("RouteBody").text.contains("I 泄压"), "路线参考说明低潮路径和泄压出口")
		var elapsed: float = host._elapsed_seconds
		var position: Vector3 = host._player.global_position
		Input.action_press("move_forward")
		await create_timer(0.2).timeout
		Input.action_release("move_forward")
		check(host._elapsed_seconds == elapsed and host._player.global_position == position and not host._items.try_interact_nearest(), "查阅路线冻结计时、移动和机关交互")
		nav.settings_screen.go_back()
		check(host.get_run_state() == host.RunState.PAUSED and host._commerce.pause_menu.visible and paused, "关闭路线指南返回共享暂停菜单")
		nav.open_settings()
		check(nav.settings_screen.visible and paused, "暂停中打开设置")
		nav._close_settings()
		host._commerce.open_backpack()
		check(paused and host._commerce.view != host._commerce.View.NONE, "共享背包保持暂停")
		host._commerce.close_all()
		host._commerce.open_shop()
		check(paused and host._commerce.view == host._commerce.View.SHOP, "共享商城保持暂停")
		host._commerce.close_all()
		check(host.restart_run(), "暂停重开被接受")
		await frames(12)
		host = current_scene
		check(host.level_id == 3 and host._player.character_id == role and host.get_run_state() == host.RunState.MENU and not paused, role + " 暂停重开保留角色并回本关菜单")
		host._on_run_started()
		check(host._player.take_damage(999), "第三关真实死亡")
		await create_timer(2.0).timeout
		check(host.get_run_state() == host.RunState.DEAD, "死亡动画可结束并显示共享结算")
		check(host.restart_run(), "死亡重开被接受")
		await frames(12)
		host = current_scene
		check(host.level_id == 3 and host._player.hp == host._player.max_hp and host._dungeon.get_storage_state() == 0, "死亡重开刷新生命和机关")
	host.get_node("RunBindings").return_to_menu()
	await frames(12)
	host = current_scene
	check(host.level_id == 1 and host._start_screen.visible and not paused, "第三关返回正式主菜单")
	host.get_node("MenuNavigation")._continue_campaign()
	await frames(12)
	host = current_scene
	check(host.level_id == 3 and host.get_run_state() == host.RunState.PLAYING, "主菜单继续游戏进入最近第三关")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

func finish() -> void:
	paused = false
	root.get_node("MusicManager").stop_music()
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames(3)
	print("LEVEL03_CAMPAIGN: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
