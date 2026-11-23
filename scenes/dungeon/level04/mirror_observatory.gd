extends Node3D
## 日晷观测站共享地图。门、支线和终点共用同一局的物理与进度状态。
const CHARACTERS := preload("res://scenes/player/character_catalog.gd")
const STATION := preload("res://scenes/dungeon/level03/tide_station.gd")
const CATALOG := preload("res://data/item_catalog.gd")
const PLAN := preload("res://scenes/dungeon/level04/observatory_plan.gd")
const MAIN := ["A","B","C","E","F","H","I","J"]
const EDGES := PLAN.LINKS
const NAMES := PLAN.NAMES

signal feedback(message: String)
signal completed
signal failed

@onready var player := $Player
@onready var layout := $Layout
@onready var inventory := $Player/ItemInventory
@onready var combat := $Combat
@onready var puzzles := $Puzzles
@onready var mail := $Mail
var current_room := ""
var visited := {}
var finished := false
var won := false
var elapsed := 0.0
var _gate_state := {}
var _labels := {}

func _ready() -> void:
	$Camera3D.set_safe_frame(Rect2(0.04,0.18,0.91,0.74))
	layout.build()
	puzzles.setup(self)
	combat.setup(self)
	mail.setup(self)
	for data in [["left","D",-4.0,2.0,"左链轮"],["right","D",-4.0,-2.0,"右链轮"],
			["supply","H",3.0,5.5,"急救药箱"],["shutter","I",6.0,0.0,"百叶换向杆"]]:
		var at: Vector3 = layout.room_center(data[1]) + Vector3(data[2],0,data[3])
		var station := add_station(data[0], at, data[4])
		var handle = layout.block(station, Vector3(0,0.85,0),Vector3(0.22,0.56,0.22),Color("#e1aa63"))
		handle.rotation.z = -0.42
	var pad: Vector3 = layout.room_center("J") + Vector3(0,0.025,-1.8)

	layout.caption(layout,"登台离站",pad+Vector3(0,0.8,-0.8))

	combat.feedback.connect(note)
	combat.battle_started.connect(_battle_started)
	combat.battle_cleared.connect(_battle_cleared)
	player.died.connect(_die)
	_refresh_gates()

func _battle_started(id: String) -> void:
	layout.seal_room(id,true)
	note("%s封场 · 清除守卫" % NAMES[id])

func _battle_cleared(id: String) -> void:
	layout.seal_room(id,false)
	_refresh_gates()
	inventory.grant_reward("observatory_encounter_"+id,{},12 if id != "I" else 25)
	note("%s清场 · 获得补给金币" % NAMES[id])

func _refresh_gates() -> void:
	for edge: String in EDGES:
		var opened := true
		match edge:
			"BC": opened = combat.is_clear("B")
			"EF","EK": opened = puzzles.calibrated
			"FG","FH": opened = combat.is_clear("F")
			"HI","HL": opened = combat.is_clear("H")
			"IJ": opened = combat.is_clear("I")
		if _gate_state.get(edge) != opened:
			_gate_state[edge] = opened
			layout.set_passage(edge[0],edge[1],opened)

func add_station(id: StringName, point: Vector3, hint: String) -> Node3D:
	var station := STATION.new()
	station.name = id
	station.action = id
	station.level = self
	station.caption = hint
	station.position = point
	$Stations.add_child(station)
	layout.solid(station,Vector3(0,0.27,0),Vector3(0.86,0.54,0.86),Color("#364c59")).name = "Body"
	var label: Label3D = layout.caption(station,hint,Vector3(0,1.65,0))
	label.pixel_size = 0.006
	label.visible = false
	_labels[station] = label
	return station

func station_available(id: StringName) -> bool:
	if finished or not is_node_ready() or not can_process() or player.is_dead(): return false
	if String(id).begins_with("p_"): return puzzles.available(id)
	if String(id).begins_with("mail_"): return mail.available(id)
	match id:
		&"left",&"right": return combat.is_clear("D") and combat.active_room == ""
		&"supply": return not inventory.has_claimed("observatory_aid")
		&"shutter": return combat.shutter_available()
	return false

func use_station(id: StringName) -> bool:
	if not station_available(id): return false
	if String(id).begins_with("p_"):
		var used: bool = puzzles.interact(id)
		_refresh_gates()
		return used
	if String(id).begins_with("mail_"): return mail.interact(id)
	match id:
		&"left",&"right":
			var side := -1 if id == &"left" else 1
			if not combat.set_cage(side):
				note("吊笼暂不能移位，请先让出停靠区。")
				return false
			if combat.requested_cage_side != combat.cage_side:
				note("已挂好链轮，吊笼将在停靠区腾空后落下。")
			else:
				note("吊笼已降在%s廊。" % ("左" if side < 0 else "右"))
			if combat.is_clear("F") and not inventory.has_claimed("observatory_rigging"):
				claim("observatory_rigging",{CATALOG.GUARD_RUNE:1},"检修完成 · 获得守护符文")
			return true
		&"supply": return claim("observatory_aid",{CATALOG.HEALTH_POTION:1},"已收起生命药剂 · R 使用")
		&"shutter": return combat.operate_shutter()
	return false

func claim(key: String, items: Dictionary, success: String) -> bool:
	if inventory.grant_reward(key,items):
		note(success)
		return true
	note("背包已满，物资仍留在原处。")
	return false

func note(message: String) -> void:
	feedback.emit(message)

func optional_done(id: String) -> bool:
	match id:
		"D": return combat.cage_side != 0
		"G": return mail.chosen()
		"K": return puzzles.mirror_claimed
		"L": return puzzles.film_claimed
	return false

func optional_count() -> int:
	var count := 0
	for id in ["D","G","K","L"]:
		if optional_done(id): count += 1
	return count

func side_hint() -> String:
	match current_room:
		"D": return "支线 · 检修左右链轮，选择 F 的掩体位置"
		"G": return "支线 · 当场取药，或寄到穹顶领取双份物资"
		"K": return "支线 · 用两面单向镜照亮星图"
		"L": return "支线 · 用三张试片找出按下快门的人"
	return ""

func objective() -> String:
	if combat.active_room != "":
		return "%s · 清场   场内守卫 %d" % [NAMES[combat.active_room],combat.enemy_count()]
	if not combat.is_clear("B"): return "北行去 B 装卸场，清除守卫"
	if not puzzles.calibrated: return "在 E 记录室读曝光盘，校准三位密码柜"
	if not combat.is_clear("F"): return "前往 F 栈道，绕过隔墙迎击守卫"
	if not combat.is_clear("H"): return "去 H 试车场，看一次无伤示范后进入内场"
	if not combat.is_clear("I"): return "去 I 主穹顶，击败袍冠女巫与尖蓟近卫"
	return "穿过北门，在 J 升降台中央离站"

func _record_location() -> void:
	current_room = layout.room_at(player.position)
	if current_room != "": visited[current_room] = true

func _physics_process(delta: float) -> void:
	if finished or player.is_dead(): return
	elapsed += delta
	_record_location()
	var encounter_room := current_room
	match current_room:
		"D": if not combat.is_clear("B"): encounter_room = ""
		"F": if not combat.is_clear("B") or not puzzles.calibrated: encounter_room = ""
		"H": if not combat.is_clear("F"): encounter_room = ""
		"I": if not combat.is_clear("H"): encounter_room = ""
	combat.update_room(encounter_room,delta)
	if finished: return
	mail.advance(delta)
	_refresh_gates()
	for station: Node3D in _labels:
		_labels[station].visible = player.position.distance_squared_to(station.position) < 18.0
	if combat.is_clear("I") and layout.passage_open("I","J") and is_player_in_exit_area():
		finished = true
		won = true
		combat.stop()
		completed.emit()

## 到达升降台中央的同一组几何边界也供战役结算独立复核。
func is_player_in_exit_area() -> bool:
	var point: Vector3 = player.position - layout.room_center("J")
	return layout.room_at(player.position) == "J" and absf(point.x) < 1.9 and absf(point.z + 1.8) < 1.3 and absf(point.y) < 1.2

func _die() -> void:
	if finished: return
	finished = true
	combat.stop()
	failed.emit()
