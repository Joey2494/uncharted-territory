extends Node3D
## 独立的第三关白盒。谜题门可重置，战斗门复用共享封场和开门生命周期。

signal feedback(message: String)
signal finished(won: bool)

enum Conductor { RACK, CARRIED, EAST, WEST }
enum Storage { EMPTY, STORED, RELEASED }

const Layout = preload("res://scenes/dungeon/level03/tide_layout.gd")
const Station = preload("res://scenes/dungeon/level03/tide_station.gd")
const Encounter = preload("res://scenes/dungeon/components/combat_room_encounter.gd")
const Gate = preload("res://scenes/dungeon/components/ProgressionGate.tscn")
const Enemy = preload("res://scenes/enemies/MeleeEnemy.tscn")
const REWARD_ID := "level03_overflow_garden"

# 每条路在房间接缝单独封场；可重置挡板处在走廊中段。
const PUZZLE_BARRIERS := {
	&"BC": [Vector3(-14, 0, 0), true, "低水位 · 沉沙库"],
	&"CD": [Vector3(-37, 0, 0), true, "低水位 · 折流廊"],
	&"CI": [Vector3(-25, 0, -12), false, "低水位 · 维修井"],
	&"BE": [Vector3(14, 0, 0), true, "高水位 · 浮栈战区"],
	&"EF": [Vector3(25, 0, -12), false, "高水位且 E 清场 · 蓄能工房"],
	&"FH": [Vector3(36, 0, -24), true, "高水位 · 溢流花园"],
	&"FB": [Vector3(12.5, 0, -12), false, "高架捷径 · 由 F 开启"],
	&"BG": [Vector3(0, 0, -13.5), false, "中心闸门 · 等待 I 泄压"],
	&"ID": [Vector3(-39, 0, -24), true, "维修捷径 · 由 I 开启"],
}

const COMBAT_DOORS := {
	&"C": [[Vector3(-18, 0, 0), true], [Vector3(-32, 0, 0), true], [Vector3(-25, 0, -7), false]],
	&"E": [[Vector3(18, 0, 0), true], [Vector3(25, 0, -7), false]],
	&"F": [[Vector3(25, 0, -17), false], [Vector3(18, 0, -24), true], [Vector3(32, 0, -24), true]],
	&"G": [[Vector3(0, 0, -17), false]],
}

const STATIONS := {
	&"model": [Vector3(0, 0, 21.4), "检修沙盘"],
	&"tide": [Vector3(0, 0, 0), "潮位总控"],
	&"reset": [Vector3(4, 0, 3.5), "重置机关"],
	&"conductor": [Vector3(-29, 0, -2), "取用导体"],
	&"director": [Vector3(-49, 0, 0), "折流导向台"],
	&"charge": [Vector3(25, 0, -23), "蓄能器"],
	&"highwalk": [Vector3(20, 0, -27), "高架与维修门手柄"],
	&"release": [Vector3(-25, 0, -24), "泄压装置"],
	&"service": [Vector3(-29, 0, -28), "维修小回环手柄"],
	&"reward": [Vector3(46, 0, -24), "溢流记录与符文"],
}

var _high := false
var _conductor := Conductor.RACK
var _storage := Storage.EMPTY
var _highwalk := false
var _service := false
var _active_room: StringName = &""
var _encounters: Array[Node] = []
var _reset_armed := 0.0
var _terminal := false
var _won := false
var _exit_gate: StaticBody3D
var _exit_area: Area3D
var _station_lamps: Dictionary = {}

@onready var _layout := $Layout
@onready var _player := $Player
@onready var _inventory := $Player/ItemInventory
@onready var _progress := $Progress


func _ready() -> void:
	_layout.build($Rooms)
	_create_barriers()
	_create_stations()
	_create_encounters()
	_create_exit()
	_refresh_world()
	$Camera3D.set_safe_frame(Rect2(0.10, 0.22, 0.80, 0.63))
	_player.died.connect(_finish.bind(false))
	_inventory.grant_reward("level03_maintenance_supply", {_inventory.HEALTH_POTION: 2})
	feedback.emit("靠近检修沙盘按 E，了解潮位如何改变通路。")


func _physics_process(delta: float) -> void:
	if _terminal:
		return
	if _reset_armed > 0.0:
		var station: Node3D = $Stations/reset
		var offset: Vector3 = _player.global_position - station.global_position
		_reset_armed = maxf(_reset_armed - delta, 0.0) if offset.length() <= Station.REACH else 0.0
	for encounter in _encounters:
		encounter.try_activate()
	if _exit_gate.is_open() and _storage == Storage.RELEASED and _progress.is_complete(&"G") and _exit_area.overlaps_body(_player):
		_finish(true)


func get_storage_state() -> int:
	return _storage


func is_victorious() -> bool:
	return _won


func get_location() -> String:
	for id in Layout.ROOMS:
		if $Rooms.get_node(String(id)).get_world_bounds().has_point(Vector2(_player.position.x, _player.position.z)):
			return "%s  %s" % [id, Layout.ROOM_NAMES[id]]
	return "连接通道"


func get_state_text() -> String:
	var direction: String = ["导体在 C 托架", "导体已取用", "△ 东向 F", "□ 西向 I"][_conductor]
	var storage: String = ["未充能", "已存能", "已释放"][_storage]
	return "%s  ·  %s  ·  F %s  ·  G %s" % [
		"高水位 / 浮栈" if _high else "低水位 / 地沟",
		direction, storage, "已解锁" if _storage == Storage.RELEASED else "关闭"]


func get_battle_text() -> String:
	if _active_room == &"":
		return ""
	return "%s 战斗 · 剩余 %d" % [_active_room, _progress.get_remaining_enemies(_active_room)]


func is_camera_target_relevant(actor: Node3D, _target: Node3D) -> bool:
	return _active_room != &"" and actor.get_meta("room", &"") == _active_room and actor.can_process()


func station_available(action: StringName) -> bool:
	return not _terminal and STATIONS.has(action)


## 交互距离及视线由 Station 检查；这里检查该装置的水位、战斗与供能约束。
func use_station(action: StringName) -> bool:
	if not station_available(action) or not can_process():
		return false
	var message := ""
	match action:
		&"model":
			message = "低水位走西侧地沟，高水位走东侧浮栈。只有 B 可切潮。北方中心闸门由维修井泄压开启。"
		&"tide", &"reset":
			message = _use_tide_control(action)
		&"conductor":
			if not _progress.is_complete(&"C"):
				message = "沉沙库清场后可取用导体。"
			elif _high:
				message = "先降低水位，排空沉沙库通路。"
			elif _conductor == Conductor.RACK:
				_conductor = Conductor.CARRIED
				message = "取得导体 · 三角接口送往 F，方口接入 I。"
			else:
				message = "导体已离开托架。可在 D 使用，或在 B 重置。"
		&"director":
			if _high:
				message = "高水位隔离导向台；回 B 降潮后再调向。"
			elif _conductor == Conductor.RACK:
				message = "导向台缺少导体 · 查找 C 的托架。"
			elif _conductor == Conductor.EAST:
				_conductor = Conductor.WEST
				message = "□ 西向 · F 的储能可回供 I。"
			else:
				_conductor = Conductor.EAST
				message = "△ 东向 · 升到高水位后，主供能可送至 F。"
		&"charge":
			message = _charge()
		&"highwalk":
			if not _progress.is_complete(&"F"):
				message = "先清除 F 的守卫，再打开返程高架。"
			else:
				_highwalk = true
				message = "F–B 高架与 C–I 维修门已解锁。高架在两种水位均可通行。"
		&"release":
			message = _release()
		&"service":
			if _storage == Storage.RELEASED:
				_service = true
				message = "I–D 维修捷径已打开。"
			else:
				message = "泄压成功后可开启 I–D 小回环。"
		&"reward":
			message = _garden_reward()
	_refresh_world()
	feedback.emit(message)
	return true


func _use_tide_control(action: StringName) -> String:
	if _active_room != &"":
		return "当前有战斗进行中，潮位总控暂时锁定。"
	if _tidal_routes_occupied():
		return "潮位通道内有人，请等通道腾空。"
	if action == &"tide":
		_reset_armed = 0.0
		_high = not _high
		return "高水位 · 东侧浮栈升起，西侧地沟关闭。" if _high else "低水位 · 西侧地沟露出，东侧浮栈收回。"
	if _reset_armed <= 0.0:
		_reset_armed = 4.0
		return "4 秒内再按 E 确认重置水位、导体、储能和机关门。清场与奖励保留。"
	_reset_armed = 0.0
	_high = false
	_conductor = Conductor.RACK
	_storage = Storage.EMPTY
	_highwalk = false
	_service = false
	return "机关已重置 · 导体返回 C，保留清场记录和已领取奖励。"


func _tidal_routes_occupied() -> bool:
	var actors := $Enemies.get_children()
	actors.append(_player)
	for actor in actors:
		if not actor is CharacterBody3D or actor.is_dead():
			continue
		var point := Vector2(actor.position.x, actor.position.z)
		for id in Layout.LOW_ROUTES + Layout.HIGH_ROUTES + [&"FB", &"BG"]:
			for rect: Rect2 in Layout.ROUTES[id]:
				if rect.grow(0.5).has_point(point):
					return true
	return false


func _charge() -> String:
	if not _progress.is_complete(&"F"):
		return "蓄能器尚未安全 · 先清除 F 守卫。"
	if _storage == Storage.RELEASED:
		return "能量已用于泄压 · 中心闸门保持解锁。"
	if _storage == Storage.STORED:
		return "储能已满 · 停止输入、降潮或调向都能保留能量。"
	if not _high:
		return "蓄能输入只在高水位接通 · 通过高架返回 B 升潮。"
	if _conductor != Conductor.EAST:
		return "输入断开 · 检查 D 导向台的 △ 东向端口。可先开高架返回 B。"
	_storage = Storage.STORED
	return "已存能 · 停止输入后仍会保留。可到 I 检查回流条件。"


func _release() -> String:
	if _storage == Storage.RELEASED:
		return "已泄压 · G 保持开启。可拉维修手柄打开 I–D。"
	var missing: Array[String] = []
	if _high:
		missing.append("水位未降")
	if not _highwalk:
		missing.append("F 维修门手柄未拉")
	if _conductor != Conductor.WEST:
		missing.append("导体未指向 I 的 □ 西向端口")
	if _storage != Storage.STORED:
		missing.append("F 储能为空")
	if not missing.is_empty():
		return "泄压条件不足 · " + " / ".join(missing)
	_storage = Storage.RELEASED
	return "回流成功 · G 闸门永久解锁。"


func _garden_reward() -> String:
	if not _high:
		return "高水位浮栈升起后才可访问花园。"
	var record := "溢流记录 · 停机后，F 的储能可沿 □ 西向线路回流至 I。"
	if _inventory.has_claimed(REWARD_ID):
		return record
	if _inventory.grant_reward(REWARD_ID, {_inventory.ATTACK_RUNE: 1}):
		return record + " 获得攻击强化符文 ×1。"
	return record + " 背包已满，可稍后领取。"


func _create_barriers() -> void:
	for id in PUZZLE_BARRIERS:
		var entry: Array = PUZZLE_BARRIERS[id]
		var barrier := StaticBody3D.new()
		barrier.name = id
		barrier.position = entry[0]
		barrier.rotation.y = PI / 2.0 if entry[1] else 0.0
		barrier.collision_mask = 0
		$Barriers.add_child(barrier)
		_layout.add_shape(barrier, Vector3(5, 2.8, 0.35), Vector3.UP * 1.4)
		var view := Node3D.new()
		view.name = "View"
		barrier.add_child(view)
		var color := Color("267394") if id in Layout.LOW_ROUTES + Layout.HIGH_ROUTES else Color("835646")
		_layout.box(view, Vector3(0, 1.1, 0), Vector3(5, 0.23, 0.24), color)
		for x in [-2.4, -1.2, 0.0, 1.2, 2.4]:
			_layout.box(view, Vector3(x, 0.75, 0), Vector3(0.14, 1.5, 0.28), color)
		_layout.label(view, entry[2], Vector3(0, 1.85, 0), Color("fff1c7"))
	_exit_gate = _make_combat_gate($Barriers, &"GJ", Vector3(0, 0, -36), false, false, "最终守卫未清除")


func _create_stations() -> void:
	for id in STATIONS:
		var entry: Array = STATIONS[id]
		var station := Station.new()
		station.name = id
		station.action = id
		station.caption = entry[1]
		station.level = self
		station.position = entry[0]
		$Stations.add_child(station)
		_layout.box(station, Vector3(0, 0.38, 0), Vector3(1.25, 0.76, 0.9), Color("303b44"))
		var lamp: Node3D = _layout.box(station, Vector3(0, 0.8, 0), Vector3(0.66, 0.18, 0.5), Color("d5bb76"))
		_station_lamps[id] = lamp
		_layout.label(station, entry[1], Vector3(0, 1.55, 0), Color("fce9b5"))
	# A 的检修沙盘用路色和三块标记说明平面通路。
	_layout.box($Stations/model, Vector3(-0.8, 0.83, 0), Vector3(0.65, 0.11, 0.3), Color("aa8758"))
	_layout.box($Stations/model, Vector3(0.8, 0.83, 0), Vector3(0.65, 0.11, 0.3), Color("579bb2"))
	_layout.label($Rooms/B, "← C 低水位", Vector3(-7.2, 0.09, -1.7), Color("f9dc9d"), true)
	_layout.label($Rooms/B, "高水位 E →", Vector3(7.2, 0.09, -1.7), Color("b4f2ff"), true)
	_layout.label($Rooms/B, "↑ G 中心闸门", Vector3(0, 0.09, -6.2), Color("f9dc9d"), true)
	_layout.label($Rooms/B, "F 高架 ↗", Vector3(7.2, 0.09, -6.8), Color("f9dc9d"), true)
	_layout.label($Rooms/G, "最终守卫 · 白盒占位", Vector3(0, 0.09, 1.3), Color("ffc9a1"), true)


func _create_encounters() -> void:
	for id in COMBAT_DOORS:
		_progress.define_room(id, [], &"enemies")
		var gates: Array = []
		for index in COMBAT_DOORS[id].size():
			var entry: Array = COMBAT_DOORS[id][index]
			var gate_id := StringName("%s%d" % [id, index + 1])
			gates.append(_make_combat_gate($CombatGates, gate_id, entry[0], entry[1], true, "清除本室守卫后开放"))
		if id == &"G":
			gates.append(_exit_gate)
		var room: Node3D = $Rooms.get_node(String(id))
		var enemy = Enemy.instantiate()
		enemy.name = "%s_Guard" % id
		enemy.set_meta("room", id)
		enemy.position = room.position + Vector3(1.5, 0, -3)
		enemy.target_path = NodePath("../../Player")
		enemy.max_hp = 5 if id == &"G" else 3
		enemy.detection_range = 13.0
		enemy.lose_range = 17.0
		$Enemies.add_child(enemy)
		var encounter := Encounter.new()
		add_child(encounter)
		if not encounter.configure(_player, room, _progress, id, [enemy], gates):
			push_error("第三关战斗房配置失败：%s" % id)
		encounter.battle_started.connect(_battle_started)
		encounter.completed.connect(_battle_completed)
		_encounters.append(encounter)


func _make_combat_gate(parent: Node3D, id: StringName, location: Vector3, across_x: bool, opened: bool, caption: String) -> StaticBody3D:
	var gate = Gate.instantiate()
	gate.name = id
	gate.gate_id = id
	gate.position = location
	gate.rotation.y = PI / 2.0 if across_x else 0.0
	gate.initially_open = opened
	gate.opening_duration = 0.32
	gate.locked_message = caption
	parent.add_child(gate)
	return gate


func _create_exit() -> void:
	_exit_area = Area3D.new()
	_exit_area.name = "ExitTrigger"
	_exit_area.position = $Rooms/J.position + Vector3.UP
	_exit_area.collision_layer = 0
	_exit_area.collision_mask = 2
	$Rooms.add_child(_exit_area)
	_layout.add_shape(_exit_area, Vector3(8, 2.5, 7), Vector3.ZERO)
	_layout.label($Rooms/J, "抵达远航出口", Vector3(0, 1.5, -1.7), Color("a3ffdc"))


func _battle_started(id: StringName) -> void:
	_active_room = id
	feedback.emit("%s 战斗开始 · 守卫清除后解除封场。" % id)


func _battle_completed(id: StringName) -> void:
	if _active_room == id:
		_active_room = &""
	if id == &"G":
		_exit_gate.open_gate()
		feedback.emit("最终守卫已清除 · 等待门升起，步入 J 远航出口。")
	elif id == &"F":
		feedback.emit("F 已清场 · 检查蓄能器，或先开高架与维修门。")
	elif id == &"C":
		feedback.emit("C 已清场 · 从托架取用导体。")
	else:
		_refresh_world()
		feedback.emit("浮栈战区已清场 · 前往北侧 F。")


func _refresh_world() -> void:
	_layout.refresh(_high, _high and _conductor == Conductor.EAST, not _high and _conductor == Conductor.WEST and _storage == Storage.STORED)
	_set_blocked(&"BC", _high)
	_set_blocked(&"CD", _high)
	_set_blocked(&"CI", _high or not _highwalk)
	_set_blocked(&"BE", not _high)
	_set_blocked(&"EF", not _high or not _progress.is_complete(&"E"))
	_set_blocked(&"FH", not _high)
	_set_blocked(&"FB", not _highwalk)
	_set_blocked(&"BG", _storage != Storage.RELEASED)
	_set_blocked(&"ID", _high or not _service)
	_station_lamps[&"conductor"].visible = _conductor == Conductor.RACK
	_station_lamps[&"charge"].visible = _storage == Storage.STORED
	_station_lamps[&"release"].visible = _storage == Storage.RELEASED or (_storage == Storage.STORED and _conductor == Conductor.WEST and not _high)
	_station_lamps[&"reward"].visible = not _inventory.has_claimed(REWARD_ID)


func _set_blocked(id: StringName, blocked: bool) -> void:
	var barrier: StaticBody3D = $Barriers.get_node(String(id))
	barrier.get_node("View").visible = blocked
	var collider := barrier.get_child(0) as CollisionShape3D
	collider.set_deferred("disabled", not blocked)


func _finish(won: bool) -> void:
	if _terminal:
		return
	_terminal = true
	_won = won
	_progress.stop_run()
	for encounter in _encounters:
		encounter.stop()
	if won:
		_player.process_mode = Node.PROCESS_MODE_DISABLED
	finished.emit(won)
