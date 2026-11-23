extends "res://tests/dungeon/test_level04_routes.gd"
## 由选关按钮进入试玩，以同一条最短路线验证共享 HUD、弹窗、重开、结算和存档隔离。
const Profile = preload("res://scripts/integration/player_profile.gd")
const Campaign = preload("res://scripts/integration/campaign_progress.gd")
const PRACTICE := "res://scenes/dungeon/Level04Practice.tscn"
const MENU := "res://Main.tscn"

func run() -> void:
	var token := "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	Profile.override_path = "user://week11-preview-profile-%s.cfg" % token
	Campaign.override_path = "user://week11-preview-campaign-%s.cfg" % token
	var progress := Campaign.new()
	progress.mark_played(2)
	Profile.set_coins(1000)
	Profile.unlock_character("lan")
	Profile.set_selected_character("lan")
	var profile_digest := FileAccess.get_sha256(Profile.override_path)
	var progress_digest := FileAccess.get_sha256(Campaign.override_path)
	change_scene_to_file(MENU)
	await frames(10)
	var nav: Node = current_scene.get_node("MenuNavigation")
	nav._open_levels()
	var button := nav.level_select.get_node("%PreviewButton") as Button
	check(button.is_visible_in_tree(), "选关页提供独立试玩")
	button.pressed.emit()
	button.pressed.emit()
	await frames(12)
	check(current_scene.scene_file_path == PRACTICE, "多次点击进入同一个试玩场景")
	if current_scene.scene_file_path == PRACTICE:
		await check_hud_and_inputs()
		await check_restarts()
		await check_pause_return()
		if failures == 0:
			# 从选关第二次开始，加上击败首领后离站的完整回程，检查通关也不会写盘。
			current_scene.get_node("MenuNavigation").level_select.get_node("%PreviewButton").pressed.emit()
			await frames(12)
			await route(0)
			if failures == 0: await check_victory()
	check(progress.played == ["level2"] and progress.completed.is_empty(), "保留正式战役的游玩和通关记录")
	check(progress.get_last_played_level() == &"level2", "继续游戏仍指向第二关")
	check(FileAccess.get_sha256(Profile.override_path) == profile_digest, "角色与金币存档逐字节一致")
	check(FileAccess.get_sha256(Campaign.override_path) == progress_digest, "正式进度存档逐字节一致")
	paused = false
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames(4)
	root.get_node("MusicManager").stop_music()
	await create_timer(0.2).timeout
	for path in [Profile.override_path, Campaign.override_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("LEVEL04_MENU: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

## 路线基类随后使用当前试玩宿主的世界，避免换成旧的单独测试场景。
func start() -> void:
	level = current_scene.get_node("DungeonTest")
	check(current_scene.scene_file_path == PRACTICE and current_scene.practice_run, "真实试玩宿主执行主线")

func check_hud_and_inputs() -> void:
	var host: Node = current_scene
	var hud: Control = host._hud
	var world: Node = host._dungeon
	var player: CharacterBody3D = host._player
	check(host.get_run_state() == host.RunState.PLAYING and hud.is_visible_in_tree(), "直接试玩自动开始并显示团队 HUD")
	check(player.character_id == "lan", "试玩沿用已选角色")
	check(hud.room_label.text.ends_with("1/12") and hud.hotbar.is_visible_in_tree(), "显示十二房间和物品快捷栏")
	check(hud.hp_bar.value == player.hp and hud.hp_state_label.text.contains("盾%d" % player.shield), "显示角色血量与护盾")
	player.take_damage(player.shield + 1)
	player.spend_energy(5)
	await frames(3)
	check(hud.hp_bar.value == player.hp and hud.hp_state_label.text.contains("盾0"), "受伤后血盾同步刷新")
	check(hud.energy_bar.value == player.energy, "能量消耗同步刷新")
	check(hud.get_node("%CharacterCooldown").is_visible_in_tree() and hud._character_skill_id == "lan", "显示游侠专属战技")
	world.inventory.add_item(0, 1)
	await tap(KEY_TAB)
	check(paused and world.get_node("RouteMap").is_open(), "Tab 打开观测站路线并暂停")
	var frozen: float = host._elapsed_seconds
	await tap(KEY_P)
	check(world.get_node("RouteMap").is_open() and not host._commerce.shop.visible and host._elapsed_seconds == frozen, "查地图时冻结计时并阻止商城抢占")
	await tap(KEY_TAB)
	check(not paused and not world.get_node("RouteMap").is_open(), "Tab 关闭持有焦点的路线图")
	check(world.use_station(&"p_photo") and paused, "查看照片冻结战斗")
	await tap(KEY_TAB)
	await tap(KEY_P)
	check(world.puzzles.modal_open() and not world.get_node("RouteMap").is_open() and not host._commerce.shop.visible, "读片时地图和商城保持关闭")
	await tap(KEY_ESCAPE)
	check(not paused and not world.puzzles.modal_open() and not host._commerce.pause_menu.visible, "Esc 收起照片并恢复战斗")
	await tap(KEY_P)
	check(paused and host._commerce.shop.is_visible_in_tree(), "共享商城响应 P")
	await tap(KEY_ESCAPE)
	check(not paused and not host._commerce.shop.visible, "离开商城继续本局")
	await tap(KEY_ESCAPE)
	host._commerce.pause_menu.get_node("%BackpackButton").pressed.emit()
	await frames(2)
	check(paused and host._commerce.backpack.is_visible_in_tree(), "从共享暂停菜单进入本局背包")
	await tap(KEY_ESCAPE)
	check(paused and host._commerce.pause_menu.is_visible_in_tree(), "离开背包回到共享暂停菜单")

func check_restarts() -> void:
	var first := current_scene.get_instance_id()
	var restart: Button = current_scene._commerce.pause_menu.get_node("%RestartButton")
	check(restart.is_visible_in_tree(), "暂停页显示重新挑战")
	restart.pressed.emit()
	await frames(12)
	check_fresh_run(first, "暂停重开")
	var second := current_scene.get_instance_id()
	current_scene._player.take_damage(999)
	for tick in 220:
		if current_scene.get_run_state() == current_scene.RunState.DEAD: break
		await physics_frame
	var result: Control = current_scene._hud.get_result_screen()
	check(is_instance_valid(result) and result.is_visible_in_tree(), "死亡动画结束后显示共享失败页")
	if not is_instance_valid(result): return
	result.get_node("%RestartButton").pressed.emit()
	await frames(12)
	check_fresh_run(second, "死亡重试")

func check_fresh_run(previous: int, source: String) -> void:
	var host: Node = current_scene
	check(host.scene_file_path == PRACTICE and host.get_instance_id() != previous, source + "进入新试玩")
	check(not paused and host.get_run_state() == host.RunState.PLAYING and host._player.character_id == "lan", source + "恢复角色和控制")
	check(host._dungeon.visited.size() == 1 and host._items.potion_count == 0 and host._items.gold == 0, source + "重置物资、金币与探索")

func check_pause_return() -> void:
	await tap(KEY_ESCAPE)
	var back: Button = current_scene._commerce.pause_menu.get_node("%MainMenuButton")
	check(back.is_visible_in_tree() and back.text.contains("关卡选择"), "试玩暂停页提供返回选关")
	back.pressed.emit()
	await frames(10)
	check(current_scene.scene_file_path == MENU and current_scene.get_node("MenuNavigation").level_select.is_visible_in_tree(), "从暂停直接回到选关")

func check_victory() -> void:
	var host: Node = current_scene
	var result: Control = host._hud.get_result_screen()
	check(is_instance_valid(result) and result.is_visible_in_tree(), "独立试玩离站显示共享胜利页")
	if not is_instance_valid(result): return
	check(host._run_result.get("settled_gold", -1) == 0 and host._run_result.settlement_ok, "试玩通关不会发放永久金币")
	check(result.get_node("%SettlementLabel").text.contains("试玩") and not result.next_level_button.visible, "结算标明试玩且结束于第四关")
	host.retry_settlement()
	result.get_node("%LevelSelectButton").pressed.emit()
	await frames(10)
	check(current_scene.scene_file_path == MENU and current_scene.get_node("MenuNavigation").level_select.is_visible_in_tree(), "从胜利页直接回到选关")

func tap(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)
