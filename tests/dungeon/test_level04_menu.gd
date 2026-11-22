extends SceneTree
## 通过正式菜单进入独立白盒，返回后仍可继续原有战役。
const Profile = preload("res://scripts/integration/player_profile.gd")
const Campaign = preload("res://scripts/integration/campaign_progress.gd")
const PREVIEW := "res://scenes/dungeon/level04/Level04Preview.tscn"
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func frames(count: int = 10) -> void:
	for i in count:
		await physics_frame

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ", description)

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
	change_scene_to_file("res://Main.tscn")
	await frames()
	var nav: Node = current_scene.get_node("MenuNavigation")
	nav._open_levels()
	var button := nav.level_select.get_node_or_null("%PreviewButton") as Button
	check(is_instance_valid(button) and button.is_visible_in_tree(), "选关页提供第四关白盒入口")
	if is_instance_valid(button):
		button.pressed.emit()
		button.pressed.emit()
		await frames()
		check(current_scene.scene_file_path == PREVIEW, "连按只进入白盒一次")
		if current_scene.scene_file_path == PREVIEW:
			check(current_scene.get_node("Player").character_id == "lan", "白盒沿用已选角色")
			current_scene.inventory.add_item(0, 1)
			var preview_id := current_scene.get_instance_id()
			await tap(KEY_TAB)
			check(paused and current_scene.get_node("HUD").map.is_visible_in_tree(), "Tab 打开实际路线图并暂停")
			await tap(KEY_TAB)
			check(not paused, "Tab 可关闭有焦点的路线图")
			await tap(KEY_P)
			check(paused and current_scene.commerce.shop.visible, "同一局打开商城")
			await tap(KEY_ESCAPE)
			check(not paused and not current_scene.commerce.shop.visible, "关闭商城恢复当前房间")
			await pause_preview()
			current_scene.get_node("HUD/Overlay/Card/Backpack").pressed.emit()
			await frames(2)
			check(paused and current_scene.commerce.backpack.visible, "暂停内可打开本局背包")
			await tap(KEY_ESCAPE)
			check(paused and current_scene.get_node("HUD/Overlay").visible, "离开背包返回原暂停菜单")
			await pause_preview()
			await pause_preview()
			var restart := current_scene.get_node("HUD/Overlay/Card/Restart") as Button
			check(restart.is_visible_in_tree(), "暂停菜单可以重开白盒")
			restart.pressed.emit()
			await frames()
			check(current_scene.get_instance_id() != preview_id and current_scene.inventory.potion_count == 0 and current_scene.visited.size() == 1 and not paused, "重开后恢复初始背包和探索进度的可操作场景")
			await return_from_preview()
		check(current_scene.scene_file_path == "res://Main.tscn", "回到战役宿主")
		if current_scene.scene_file_path == "res://Main.tscn":
			nav = current_scene.get_node("MenuNavigation")
			check(nav.level_select.is_visible_in_tree(), "直接回到选关页")
			check(progress.played == ["level2"] and progress.completed.is_empty(), "白盒不登记游玩或通关")
			check(progress.get_last_played_level() == &"level2", "保留原来的继续游戏目标")
			check(FileAccess.get_sha256(Profile.override_path) == profile_digest, "保留角色与钱包存档")
			check(FileAccess.get_sha256(Campaign.override_path) == progress_digest, "保留正式战役存档")
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames(4)
	root.get_node("MusicManager").stop_music()
	await create_timer(0.2).timeout
	for path in [Profile.override_path, Campaign.override_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("LEVEL04_MENU: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func pause_preview() -> void:
	await tap(KEY_ESCAPE)

func tap(key: Key) -> void:
	var cancel := InputEventKey.new()
	cancel.keycode = key
	cancel.physical_keycode = key
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await frames(2)
	cancel = cancel.duplicate()
	cancel.pressed = false
	Input.parse_input_event(cancel)
	await frames(2)

func return_from_preview() -> void:
	await pause_preview()
	var back := current_scene.get_node_or_null("HUD/Overlay/Card/Return") as Button
	check(is_instance_valid(back) and back.is_visible_in_tree(), "Esc 暂停后可返回选关")
	if is_instance_valid(back) and back.is_visible_in_tree():
		back.pressed.emit()
	await frames()
