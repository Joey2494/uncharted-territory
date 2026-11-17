extends SceneTree
## 第三关独立预览的状态、实体门锁和交互回归。

const SCENE := "res://scenes/dungeon/level03/Level03Preview.tscn"

var level: Node3D
var player: CharacterBody3D
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var unique := "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	preload("res://scripts/integration/player_profile.gd").override_path = "user://tide-profile-" + unique + ".cfg"
	preload("res://scripts/integration/campaign_progress.gd").override_path = "user://tide-progress-" + unique + ".cfg"
	if not ResourceLoader.exists(SCENE):
		_check(false, "第三关必须有可独立启动的预览场景")
		quit(1)
		return
	await _start_level()
	_check(not await _use(&"director", false), "初始远离装置时不能遥控导体")
	_check(not _blocked(&"BC") and _blocked(&"BE"), "低水位只允许下层主通道")
	await _use(&"tide")
	_check(_blocked(&"BC") and not _blocked(&"BE"), "高水位物理交换主通道")
	_check(_blocked(&"EF"), "浮栈战区未清场时实体挡板阻止绕入 F")

	await _clear_room(&"E")
	_check(not _blocked(&"EF"), "高水位且浮栈战区清场后开放 F")
	await _clear_room(&"F")
	await _use(&"charge")
	_check(level.get_storage_state() == 0, "断开的输入不能充能")
	await _use(&"highwalk")
	_check(not _blocked(&"FB") and _blocked(&"CI"), "F 清场后可手动开高架，高水位仍封闭维修路")

	await _use(&"tide")
	_check(not _blocked(&"FB") and not _blocked(&"CI") and _blocked(&"EF") and _blocked(&"FH"), "低水位保留高架，收回浮栈")
	await _clear_room(&"C")
	await _use(&"conductor")
	await _use(&"director")
	await _use(&"director")
	await _use(&"release")
	_check(_blocked(&"BG") and level.get_storage_state() == 0, "空储能不能泄压")
	await _use(&"director")
	await _use(&"tide")
	await _use(&"charge")
	_check(level.get_storage_state() == 1, "东向高水位允许 F 储能")
	await _use(&"tide")
	_check(level.get_storage_state() == 1, "降潮保留储能")
	await _use(&"release")
	_check(_blocked(&"BG") and level.get_storage_state() == 1, "方向错误不消耗储能")
	await _use(&"director")
	await _use(&"release")
	_check(level.get_storage_state() == 2 and not _blocked(&"BG"), "西向低水位回流永久解锁 G")
	await _use(&"service")
	_check(not _blocked(&"ID"), "I 手动开启小回环")

	await _use(&"tide")
	await _use(&"reward")
	await _use(&"reward")
	var inventory = player.get_node("ItemInventory")
	_check(inventory.rune_count == 1, "H 奖励同局仅可领取一次")
	_check(not _blocked(&"BG"), "高水位不会让泄压后的闸门重新锁上")

	await _use(&"reset")
	_check(level.get_storage_state() == 2, "第一次按 E 只请求确认")
	await _use(&"reset")
	_check(level.get_storage_state() == 0 and _blocked(&"BG") and _blocked(&"BE") and not _blocked(&"BC"), "确认重置恢复初始谜题")
	_check(_blocked(&"FB") and _blocked(&"CI") and _blocked(&"ID"), "重置恢复三条谜题门")
	_check(level.get_node("Progress").is_complete(&"C") and level.get_node("Progress").is_complete(&"F"), "重置保留清敌")
	_check(inventory.rune_count == 1, "重置保留已领的奖励")
	await _use(&"conductor")
	await _use(&"director")
	await _use(&"tide")
	await _use(&"highwalk")
	await _use(&"charge")
	await _use(&"reward")
	_check(inventory.rune_count == 1, "谜题重置不能刷新 H 奖励")
	await _use(&"tide")
	await _use(&"director")
	await _use(&"release")
	_check(not level.is_victorious(), "解谜不能替代步入出口")
	await _clear_room(&"G")
	await create_timer(0.45).timeout
	_check(not level.is_victorious(), "击败守卫不能替代步入出口")
	player.global_position = level.get_node("Rooms/J").global_position
	await _settle()
	_check(level.is_victorious(), "出口门真正开放后走入 J 触发通关")

	await _walk_main_route()
	await _check_restart()
	print("Level03 tide regression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _start_level() -> void:
	level = (load(SCENE) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	player = level.get_node("Player")
	await _settle()


## 第二次从出生点连续移动，覆盖门洞、两条水位路线、两条回环和可跳过 H 的终点。
func _walk_main_route() -> void:
	level.free()
	paused = false
	await _start_level()
	Input.action_press("sprint")
	await _walk(Vector2(0, 22.5))
	await _press_e(&"model")
	# 交互台现在有真实碰撞，连续路线须绕开沙盘及潮位台，不能穿模抄近路。
	await _walk(Vector2(1.6, 22.5))
	await _walk(Vector2(1.6, 18))
	await _walk(Vector2(0, 18))
	await _walk(Vector2(0, 1.2))
	await _walk(Vector2(-2, 1.2))
	await _walk(Vector2(-2, 0))
	await _walk(Vector2(-22, 0))
	await _defeat(&"C")
	await create_timer(0.4).timeout
	await _walk(Vector2(-29, -0.9))
	await _press_e(&"conductor")
	await _walk(Vector2(-29, 0))
	await _walk(Vector2(-48, 0))
	await _press_e(&"director")
	await _walk(Vector2(-3, 0))
	await _walk(Vector2(-3, -1.2))
	await _walk(Vector2(0, -1.2))
	await _press_e(&"tide")
	await _walk(Vector2(2, -1.2))
	await _walk(Vector2(2, 0))
	await _walk(Vector2(22, 0))
	await _defeat(&"E")
	await create_timer(0.4).timeout
	await _walk(Vector2(25, 0))
	await _walk(Vector2(25, -20))
	await _defeat(&"F")
	await create_timer(0.4).timeout
	await _walk(Vector2(25, -21.9))
	await _press_e(&"charge")
	await _walk(Vector2(20, -25.9))
	await _press_e(&"highwalk")
	await _walk(Vector2(20, -24))
	await _walk(Vector2(12.5, -24))
	await _walk(Vector2(12.5, -7))
	await _walk(Vector2(0, -7))
	await _walk(Vector2(0, -1.2))
	await _press_e(&"tide")
	await _walk(Vector2(-2, -1.2))
	await _walk(Vector2(-2, 0))
	await _walk(Vector2(-48, 0))
	await _press_e(&"director")
	await _walk(Vector2(-25, 0))
	await _walk(Vector2(-25, -22.9))
	await _press_e(&"release")
	await _walk(Vector2(-29, -26.9))
	await _press_e(&"service")
	await _walk(Vector2(-29, -24))
	await _walk(Vector2(-49, -24))
	await _walk(Vector2(-49, -2))
	await _walk(Vector2(-48, -2))
	await _walk(Vector2(-48, 0))
	await _walk(Vector2(-2, 0))
	await _walk(Vector2(-2, -1.2))
	await _walk(Vector2(0, -1.2))
	await _walk(Vector2(0, -21))
	await _defeat(&"G")
	await create_timer(0.4).timeout
	await _walk(Vector2(0, -47))
	Input.action_release("sprint")
	_check(level.is_victorious(), "用常规输入可连续跑通主线，且可以跳过 H")


func _walk(target: Vector2) -> void:
	for i in 450:
		var point := Vector2(player.global_position.x, player.global_position.z)
		var offset := target - point
		if offset.length() <= 0.28 or level.is_victorious():
			break
		_drive_axis("move_left", "move_right", offset.x)
		_drive_axis("move_forward", "move_backward", offset.y)
		await physics_frame
	for action in ["move_left", "move_right", "move_forward", "move_backward"]:
		Input.action_release(action)
	var distance := Vector2(player.global_position.x, player.global_position.z).distance_to(target)
	_check(distance <= 0.4 or level.is_victorious(), "玩家可走到 %s，当前位置 %s" % [target, player.global_position])
	await _settle()


func _drive_axis(negative: StringName, positive: StringName, value: float) -> void:
	Input.action_release(negative)
	Input.action_release(positive)
	if absf(value) > 0.1:
		Input.action_press(negative if value < 0.0 else positive, minf(1.0, absf(value) * 2.0))


func _press_e(id: StringName) -> void:
	var inventory = player.get_node("ItemInventory")
	var station: Node3D = level.get_node("Stations/" + id)
	_check(inventory._get_nearest_interaction_target() == station, "到达 %s 时 E 选中对应装置" % id)
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	Input.parse_input_event(event)
	await _settle()
	event = InputEventAction.new()
	event.action = &"interact"
	event.pressed = false
	Input.parse_input_event(event)

func _check_restart() -> void:
	var old_id := level.get_instance_id()
	var restart_button: Button = _find_restart(level.get_node("HUD"))
	_check(restart_button != null and restart_button.is_visible_in_tree(), "终局界面提供重开")
	if restart_button == null:
		return
	restart_button.pressed.emit()
	for i in 10:
		await process_frame
	_check(current_scene != null and current_scene.get_instance_id() != old_id and not paused, "重开实际载入独立新局")
	if current_scene == null or current_scene.get_instance_id() == old_id:
		return
	level = current_scene
	player = level.get_node("Player")
	await _settle()
	_check(level.get_storage_state() == 0 and _blocked(&"BG") and not _blocked(&"BC"), "新局恢复低水位和闸门初态")
	_check(level.get_node("Enemies").get_child_count() == 4 and not level.get_node("Progress").is_complete(&"C"), "新局刷新四个战斗房")
	_check(player.get_node("ItemInventory").rune_count == 0 and not level.is_victorious(), "新局没有保留奖励或结算状态")


func _find_restart(parent: Node) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == "重新开始":
			return child
		var match_button := _find_restart(child)
		if match_button != null:
			return match_button
	return null

func _settle() -> void:
	for i in 5:
		await physics_frame


func _use(id: StringName, approach := true) -> bool:
	var station: Node3D = level.get_node("Stations/" + id)
	if approach:
		player.global_position = station.global_position + Vector3(0, 0, 1.1)
		await _settle()
	var used: bool = player.get_node("ItemInventory").try_interact_nearest()
	await _settle()
	return used


func _clear_room(id: StringName) -> void:
	player.global_position = level.get_node("Rooms/" + id).global_position + Vector3(0, 0, 3)
	await _settle()
	await _defeat(id)


func _defeat(id: StringName) -> void:
	var found := false
	for enemy in level.get_node("Enemies").get_children():
		if enemy.get_meta("room", &"") == id and not enemy.is_dead():
			found = true
			_check(enemy.take_damage(99), "%s 敌人入场后接受伤害" % id)
	await _settle()
	_check(found and level.get_node("Progress").is_complete(id), "%s 清场登记成功" % id)


func _blocked(id: StringName) -> bool:
	var barrier: StaticBody3D = level.get_node("Barriers/" + id)
	var direction := barrier.global_basis.z.normalized()
	var center := barrier.global_position + Vector3.UP
	var ray := PhysicsRayQueryParameters3D.create(center - direction, center + direction, 1)
	return not barrier.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		return
	failures += 1
	push_error(description)
