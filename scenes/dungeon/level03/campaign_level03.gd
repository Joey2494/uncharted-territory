extends "res://scenes/dungeon/level03/level03_preview.gd"
## 潮汐白盒的正式战役适配层。机关、敌人和碰撞仍由原地图裁定。
signal room_changed(room_name: String, visited_count: int)
signal progression_feedback(message: String)
signal exit_reached
signal exit_unlocked
signal exit_opening_started

var _visited: Array[StringName] = []
var _last_room: StringName = &""
var _exit_recorded := false

func _ready() -> void:
	super._ready()
	_run_active = false
	feedback.connect(func(message: String) -> void: progression_feedback.emit(message))
	_exit_gate.opening_started.connect(func(_id: StringName) -> void: exit_opening_started.emit())
	_exit_gate.opened.connect(func(_id: StringName) -> void: exit_unlocked.emit())

## Main 显式开始本局，菜单期间不登记到达或启动机关。
func begin_run() -> bool:
	if _terminal or _run_active or get_tree().paused or _player.is_dead(): return false
	_run_active = true
	_record_location()
	feedback.emit("靠近检修沙盘按 E，了解潮位如何改变通路。")
	return true

func is_run_active() -> bool:
	return _run_active and not _terminal

func _physics_process(delta: float) -> void:
	if not is_run_active(): return
	_record_location()
	super._physics_process(delta)

func get_current_room_id() -> StringName:
	var point := Vector2(_player.global_position.x, _player.global_position.z)
	for id in Layout.ROOMS:
		if $Rooms.get_node(String(id)).get_world_bounds().has_point(point): return id
	return &""

func _record_location() -> void:
	var room := get_current_room_id()
	if room == _last_room: return
	_last_room = room
	if room != &"" and room not in _visited: _visited.append(room)
	room_changed.emit(get_location(), get_visited_count())

func get_room_count() -> int: return Layout.ROOMS.size()
func get_visited_count() -> int: return _visited.size()
func is_exit_open() -> bool: return _exit_gate.is_open()
func is_exit_opening() -> bool: return not is_exit_open() and _progress.is_complete(&"G")
func is_player_in_exit_area() -> bool: return _exit_recorded or _exit_area.overlaps_body(_player)

## 无 Boss 关卡明确提供自己的通关权限；I 泄压、G 清场和实体出口均不可省略。
func is_completion_ready() -> bool:
	return _storage == Storage.RELEASED and _progress.is_complete(&"G")

func _finish(won: bool) -> void:
	if _terminal or not _run_active: return
	if not won:
		super._finish(false)
		return
	if _player.is_dead() or not is_completion_ready() or not is_exit_open() or not _exit_area.overlaps_body(_player): return
	# 在宿主停用碰撞前锁存真实重叠；之后 Main 仍独立复核条件。
	_exit_recorded = true
	_won = true
	exit_reached.emit()

func get_completion_snapshot() -> Dictionary:
	return {"completion_summary": "最终守卫已清除 · 成功抵达远航出口",
		"puzzle_name": "潮汐机关", "reward_name": "溢流花园奖励",
		"puzzle_solved": _storage == Storage.RELEASED, "reward_claimed": _inventory.has_claimed(REWARD_ID)}

## 正式关卡把路线放入共享暂停指南，独立预览仍由原 HUD 提供 Tab 路线图。
func get_route_reference() -> Dictionary:
	return {"title": "潮汐工坊 · 路线与回流", "body":
		"A 入口检修台 → B 中央潮井（只有 B 可切换潮位）\n"
		+ "低潮西路：B—C—D。C 沉沙库清敌后取得导体；D 折流廊调整方向。\n"
		+ "高潮东路：B—E—F—H。E 清场后通往 F 蓄能工房；H 为可选花园奖励。\n"
		+ "F 手柄：开启两种潮位均可通行的 F—B 高架，以及低潮可走的 C—I 维修路。\n"
		+ "回流顺序：D 东向 → 升潮 → F 蓄能 → 开 F 手柄 → 降潮 → D 西向 → I 泄压。\n"
		+ "储能在降潮和调向后保留。I 泄压后打开 B—G；清除 G 守卫后进入 J 远航出口。\n"
		+ "I 手柄还可打开低潮的 I—D 小回环；B 重置台连续确认两次重置机关，清场和奖励保留。"}

## 向共享目标展示器提供只读信息；展示层不能修改潮位或资源。
func get_hud_objective() -> Dictionary:
	var title := "查阅 A 沙盘，前往 B 潮位总控"
	var category := "探索"
	var completed: Array[String] = []
	for id in COMBAT_DOORS:
		if _progress.is_complete(id): completed.append(String(id))
	if _storage >= Storage.STORED: completed.append("charged")
	if _storage == Storage.RELEASED: completed.append("released")
	if _active_room != &"":
		title = "清除 %s 守卫 · 剩余 %d" % [_active_room, _progress.get_remaining_enemies(_active_room)]
		category = "战斗"
	elif is_completion_ready():
		title = "步入 J 远航出口" if is_exit_open() else "等待远航出口开启"
	elif _storage == Storage.RELEASED:
		title = "前往 G，清除最终守卫"
	elif _storage == Storage.STORED:
		if not _highwalk: title = "打开 F 高架与维修门手柄"
		elif _high: title = "返回 B，降低水位"
		elif _conductor != Conductor.WEST: title = "前往 D，将导体转向西方"
		else: title = "前往 I，操作泄压装置"
		category = "解谜"
	elif _conductor != Conductor.RACK:
		if _conductor != Conductor.EAST: title = "返回 B，降低水位后前往 D" if _high else "前往 D，将导体转向东侧"
		elif not _high: title = "返回 B，升高水位"
		elif not _progress.is_complete(&"E"): title = "前往 E，清除浮栈守卫"
		elif not _progress.is_complete(&"F"): title = "前往 F，清除蓄能工房守卫"
		else: title = "操作 F 蓄能器，保存能量"
		category = "解谜"
	elif _last_room != &"A":
		title = "返回 B，降低水位后前往 C" if _high else "低潮进入 C，清敌后取用导体"
	var direction: String = ["导体在 C", "导体手持", "导体东向 F", "导体西向 I"][_conductor]
	var storage: String = ["未蓄能", "已蓄能", "已释放"][_storage]
	return {"id": "level03_" + String(_last_room), "title": title, "category": category,
		"progress": "探索 %d/%d" % [get_visited_count(), get_room_count()], "completed": completed,
		"resource_summary": "%s · %s\nF %s · G %s" % ["高水位" if _high else "低水位", direction,
			storage, "已泄压" if _storage == Storage.RELEASED else "未泄压"]}
