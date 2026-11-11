extends Node3D
## 第一关地图：探索记录与房间完成独立；主线门由完成事件驱动。

signal room_changed(room_name: String, visited_count: int)
signal exit_reached
signal exit_unlocked
signal exit_opening_started
signal room_completed(room_id: StringName)
signal progression_feedback(message: String)

enum ExitState { LOCKED, OPENING, OPEN }

const TutorialLayout = preload("res://scenes/dungeon/tutorial/tutorial_layout.gd")
const TutorialOverlay = preload("res://scenes/dungeon/tutorial/TutorialOverlay.tscn")
const CombatRoomEncounter = preload("res://scenes/dungeon/components/combat_room_encounter.gd")
@onready var _player: CharacterBody3D = $Player
@onready var _progress: Node = $RoomProgress
@onready var _tutorial: TutorialLayout = get_node_or_null("Regions/EntranceHall/TutorialLayout") as TutorialLayout
var _tutorial_started := false
var _run_started := false
var _run_stopped := false
var _encounters: Array[CombatRoomEncounter] = []

var _current_region: Node3D
var _visited: Dictionary = {}
var _exit_announced: bool = false
var _exit_state: ExitState = ExitState.LOCKED
@export var room_gold_rewards: Dictionary = {"EntranceHall": 20, "Crossroads": 15, "SupplyChamber": 15}
@export var enable_debug_shop_stands: bool = false


func _ready() -> void:
	if enable_debug_shop_stands:
		for item_id in preload("res://data/item_catalog.gd").ITEMS:
			var stand := preload("res://scenes/items/shop_stand.gd").new()
			stand.name = "Shop%d" % item_id
			stand.product_id = item_id
			stand.position = Vector3(-6.0 + item_id * 3.0, 0.0, -3.0)
			add_child(stand)
	_progress.configuration_error.connect(_on_configuration_error)
	_progress.define_room(&"l1_entrance", [], &"tutorial")
	if is_instance_valid(_tutorial):
		_player.global_position = _tutorial.get_node("PlayerSpawn").global_position
		_tutorial.completed.connect(_on_tutorial_completed)
		_tutorial.feedback.connect(progression_feedback.emit)
	_progress.define_room(&"l1_crossroads", [&"l1_entrance"], &"enemies", 1)
	_progress.define_room(&"l1_boss", [&"l1_crossroads"], &"enemies", 1)
	_add_encounter($Regions/Crossroads, &"l1_crossroads", [$MeleeEnemy],
		[$Gates/CourtyardSouthSeal, $Gates/CourtyardWestSeal, $Gates/CourtyardGate])
	_add_encounter($Regions/BossArena, &"l1_boss", [$RuinGatekeeper],
		[$Gates/BossWestSeal, $Gates/BossNorthSeal, $ExitGate])
	_progress.room_completed.connect(_on_room_completed)
	_player.died.connect(stop_run)
	$Gates/EntranceGate.opened.connect(_on_entrance_gate_opened)
	$Gates/CourtyardGate.opened.connect(_on_courtyard_gate_opened)
	$ExitGate.opened.connect(_finish_exit_unlock)
	_update_region()
	_start_standalone.call_deferred()


## 绑定各房间的实物门与出生名单，进度登记由战斗房组件负责。
func _add_encounter(region: Node3D, room_id: StringName, enemies: Array, gates: Array) -> void:
	var encounter := CombatRoomEncounter.new()
	add_child(encounter)
	_encounters.append(encounter)
	if not encounter.configure(_player, region, _progress, room_id, enemies, gates):
		push_error("战斗房配置失败：%s" % room_id)


## F6独立地图也能游玩；主场景必须等开始按钮，不能在菜单期间推进。
func _start_standalone() -> void:
	if get_tree().current_scene == self:
		var layer := CanvasLayer.new()
		layer.layer = 10
		add_child(layer)
		var overlay := TutorialOverlay.instantiate()
		layer.add_child(overlay)
		overlay.bind(_tutorial)
		begin_run()


## 只有正式开始后，入口区域才能激活教学。
func begin_run() -> bool:
	if _run_started or _run_stopped or not can_process() or _player.is_dead():
		return false
	_run_started = true
	_update_region()
	return true


## 终局冻结门体并停止战斗；玩家死亡动画继续由玩家本身播放。
func stop_run() -> void:
	_run_stopped = true
	_progress.stop_run()
	if is_instance_valid(_tutorial):
		_tutorial.stop()
	for encounter in _encounters:
		encounter.stop()
	$Gates/EntranceGate.freeze_gate()


func _on_configuration_error(message: String) -> void:
	push_error(message)


func _on_room_completed(room_id: StringName) -> void:
	if _run_stopped or _player.is_dead():
		return
	match room_id:
		&"l1_entrance":
			$Gates/EntranceGate.open_gate()
			$Doorways/CourtyardEntrance/Banner.text = "北门正在开启"
		&"l1_crossroads":
			$Gates/CourtyardGate.open_gate()
			$Doorways/MainRoute/Banner.text = "中庭已清理 · 主路开启中"
			progression_feedback.emit("中庭守卫已清除 · 通往守门者的主路正在开启")
		&"l1_boss":
			unlock_exit()
	room_completed.emit(room_id)


func _physics_process(_delta: float) -> void:
	if not _run_started or _run_stopped or not is_instance_valid(_player) or _player.is_dead():
		return
	_update_region()
	if not _exit_announced and is_exit_open() and is_player_in_exit_area():
		_exit_announced = true
		exit_reached.emit()


func unlock_exit() -> bool:
	if _exit_state != ExitState.LOCKED or not _run_started or _run_stopped or not can_process() or _player.is_dead():
		return false
	# 只有登记的 Boss 真实死亡并完成战斗房才能解除出口进度锁。
	if not _progress.is_complete(&"l1_boss"):
		return false
	if not $ExitGate.open_gate():
		return false
	_exit_state = ExitState.OPENING
	exit_opening_started.emit()
	return true


func _finish_exit_unlock(_gate_id: StringName) -> void:
	if _run_stopped or _player.is_dead() or not can_process():
		return
	$ExitTrigger/PortalGlow.show()
	$Doorways/BossExit/Banner.text = "出口已开启 ↑ 前往通关"
	$Doorways/MapExit/Banner.text = "地牢出口 · 进入通关"
	_exit_state = ExitState.OPEN
	exit_unlocked.emit()


func is_exit_open() -> bool:
	return _exit_state == ExitState.OPEN


func is_exit_opening() -> bool:
	return _exit_state == ExitState.OPENING


func is_player_in_exit_area() -> bool:
	return is_instance_valid(_player) and not _player.is_dead() and $ExitTrigger.overlaps_body(_player)


func get_room_count() -> int:
	var count := 0
	for region in $Regions.get_children():
		if region.exploration_room and region.visible:
			count += 1
	return count


func get_visited_count() -> int:
	return _visited.size()


func get_region_at(point: Vector3) -> Node3D:
	for region in $Regions.get_children():
		if region.visible and region.contains_point(point):
			return region
	return null


func is_camera_target_relevant(actor: Node3D, player: Node3D) -> bool:
	var player_region := get_region_at(player.global_position)
	var actor_region := get_region_at(actor.global_position)
	if player_region != null and player_region == actor_region:
		return true
	# Show approaching combatants through a nearby doorway, without framing
	# remote rooms or revealing enemies through several intervening walls.
	if actor.global_position.distance_to(player.global_position) > 12.0:
		return false
	var start := player.global_position + Vector3.UP
	var end := Vector3(actor.global_position.x, start.y, actor.global_position.z)
	var ray := PhysicsRayQueryParameters3D.create(start, end, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _update_region() -> void:
	var region := get_region_at(_player.global_position)
	if _run_started and not _run_stopped:
		if region == $Regions/EntranceHall and not _tutorial_started:
			_activate_tutorial()
		# 战斗房要求玩家完整进入，不能用探索边界直接触发。
		for encounter in _encounters:
			encounter.try_activate()
	if region == null or not region.visible or not region.exploration_room or region == _current_region:
		return
	_current_region = region
	if not _visited.has(region.name) and room_gold_rewards.has(str(region.name)):
		preload("res://scenes/items/coin_pickup.gd").spawn(
			self, region.global_position + Vector3(1.2, 0.05, 1.2),
			int(room_gold_rewards[str(region.name)]), "room:" + str(region.name))
	_visited[region.name] = true
	room_changed.emit(region.display_name, _visited.size())


## 将入口房间激活后才开始教学，接线失效时维持实体锁门。
func _activate_tutorial() -> void:
	_tutorial_started = true
	if not _progress.activate_room(&"l1_entrance"):
		return
	if not is_instance_valid(_tutorial) or not _tutorial.begin(_player):
		_on_configuration_error("入口教学启动失败，北门保持封闭")


func get_tutorial() -> TutorialLayout:
	return _tutorial if is_instance_valid(_tutorial) else null


func request_tutorial_skip() -> bool:
	return is_instance_valid(_tutorial) and _tutorial.request_skip()


func _on_tutorial_completed(skipped: bool) -> void:
	if _progress.complete_objective(&"l1_entrance", &"tutorial"):
		progression_feedback.emit("已跳过教学 · 北门正在开启" if skipped else "入口教学已完成 · 北门正在开启")


func _on_entrance_gate_opened(_gate_id: StringName) -> void:
	$Doorways/CourtyardEntrance/Banner.text = "主路 ↑ 回廊中庭"
	progression_feedback.emit("北门已开 · 前往回廊中庭")


func _on_courtyard_gate_opened(_gate_id: StringName) -> void:
	$Doorways/MainRoute/Banner.text = "主路已开启 → 守门者大厅"
	progression_feedback.emit("主路已开启 · 可前往守门者大厅，也可返回补给支线")
