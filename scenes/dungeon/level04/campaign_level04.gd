extends "res://scenes/dungeon/level04/mirror_observatory.gd"
## 将观测站的实际房间、袍冠女巫、通路和结局交给共用战役宿主。
signal room_changed(room_name: String, visited_count: int)
signal progression_feedback(message: String)
signal exit_reached
signal exit_unlocked
signal exit_opening_started

var _running := false
var _exit_announced := false

func _ready() -> void:
	super._ready()
	combat.prepare_dome_boss()
	feedback.connect(func(message: String) -> void: progression_feedback.emit(message))
	completed.connect(func() -> void: exit_reached.emit())

func begin_run() -> bool:
	if _running or finished or get_tree().paused or player.is_dead(): return false
	_running = true
	_record_location()
	note("向北前往 B 装卸场。按 Tab 可查看观测站路线。")
	return true

func is_run_active() -> bool:
	return _running and not finished

func stop_run() -> void:
	_running = false
	combat.stop()

func _physics_process(delta: float) -> void:
	if not is_run_active(): return
	if not _exit_announced and is_exit_open():
		_exit_announced = true
		exit_unlocked.emit()
	super._physics_process(delta)

func _record_location() -> void:
	var last := current_room
	super._record_location()
	if last != current_room and NAMES.has(current_room):
		room_changed.emit(current_room + " " + NAMES[current_room], get_visited_count())

func _battle_cleared(id: String) -> void:
	super._battle_cleared(id)
	if id == "I": exit_opening_started.emit()

func get_current_room_id() -> StringName: return StringName(current_room)
func get_room_count() -> int: return NAMES.size()
func get_visited_count() -> int: return visited.size()
func get_campaign_boss() -> CharacterBody3D:
	return combat.prepared_dome_boss if is_instance_valid(combat.prepared_dome_boss) else null
func is_completion_ready() -> bool: return combat.is_clear("I")
func is_exit_open() -> bool: return is_completion_ready() and layout.passage_open("I","J")
func is_exit_opening() -> bool: return is_completion_ready() and not is_exit_open()

## 宿主在女巫倒下时调用，尖蓟近卫清除前保持实体北门封锁。
func unlock_exit() -> bool: return is_completion_ready()

func is_modal_open() -> bool:
	return puzzles.modal_open() or $RouteMap.is_open()

func get_completion_snapshot() -> Dictionary:
	var photo := "照相窗亮起，快门线后的人也回到了合影里。" if puzzles.film_claimed else "照相窗里有三个人，窗边挂着四枚工牌。"
	return {"completion_summary": "已抵达北侧升降台 · 支线 %d/4\n%s" % [optional_count(), photo],
		"puzzle_name": "曝光记录室密码柜", "puzzle_solved": puzzles.calibrated,
		"reward_name": "旧镜室星图符文", "reward_claimed": puzzles.mirror_claimed}

func get_hud_objective() -> Dictionary:
	var title := objective()
	var category := "当前任务"
	var detail := "探索 %d/%d · 支线 %d/4" % [get_visited_count(), get_room_count(), optional_count()]
	if combat.active_room != "":
		category = "战斗"
		title = "清除%s的守卫" % NAMES[combat.active_room]
		detail = "剩余 %d 名" % combat.enemy_count()
	elif current_room in PLAN.OPTIONAL and not optional_done(current_room):
		category = "支线任务"
		title = side_hint().trim_prefix("支线 · ")
	elif not puzzles.calibrated and combat.is_clear("B"):
		category = "解谜"
	var steps: Array[String] = []
	for id: String in combat.ROSTERS:
		if combat.is_clear(id): steps.append("combat_" + id)
	for id: String in PLAN.OPTIONAL:
		if optional_done(id): steps.append("optional_" + id)
	if puzzles.calibrated: steps.append("calibrated")
	return {"id":title, "title":title, "category":category, "progress":detail, "completed":steps}

func get_route_reference() -> Dictionary:
	return {"title":"日晷观测站 · 路线", "body":"按 Tab 打开路线图，查看所在房间与已完成支线。\n主路沿 A—B—C—E—F—H—I—J 北行。E 的曝光记录室控制北门和旧镜室的电源。\nC 西通配重井，E 东通旧镜室，F 西通邮轨检修台，H 东通夜班底片室。"}
