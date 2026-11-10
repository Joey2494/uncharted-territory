extends Node3D
## 第一关地图：探索记录与房间完成独立；主线门由完成事件驱动。

signal room_changed(room_name: String, visited_count: int)
signal exit_reached
signal exit_unlocked
signal exit_opening_started
signal room_completed(room_id: StringName)
signal progression_feedback(message: String)

enum ExitState { LOCKED, OPENING, OPEN }

const REGION_IDS := {&"EntranceHall": &"l1_entrance", &"Crossroads": &"l1_crossroads", &"BossArena": &"l1_boss"}
@onready var _player: CharacterBody3D = $Player
@onready var _progress: Node = $RoomProgress
var _run_started := false
var _run_stopped := false
var _exit_tween: Tween

var _current_region: Node3D
var _visited: Dictionary = {}
var _exit_announced: bool = false
var _exit_state: ExitState = ExitState.LOCKED


func _ready() -> void:
	_progress.configuration_error.connect(_on_configuration_error)
	_progress.define_room(&"l1_entrance", [], &"arrival")
	_progress.define_room(&"l1_crossroads", [&"l1_entrance"], &"enemies", 1)
	_progress.define_room(&"l1_boss", [&"l1_crossroads"], &"enemies", 1)
	_progress.register_enemy(&"l1_crossroads", $MeleeEnemy)
	_progress.seal_enemy_roster(&"l1_crossroads")
	_progress.register_enemy(&"l1_boss", $RuinGatekeeper)
	_progress.seal_enemy_roster(&"l1_boss")
	_progress.room_completed.connect(_on_room_completed)
	_player.died.connect(stop_run)
	$Gates/CourtyardGate.opened.connect(_on_courtyard_gate_opened)
	_update_region()
	_start_standalone.call_deferred()


## F6独立地图也能游玩；主场景必须等开始按钮，不能在菜单期间推进。
func _start_standalone() -> void:
	if get_tree().current_scene == self:
		begin_run()


## 当前入口采用已批准的“到达即完成”，教程模式将在教学阶段单独接入。
func begin_run() -> bool:
	if _run_started or _run_stopped or not can_process() or _player.is_dead():
		return false
	_run_started = true
	_update_region()
	return true


## 终局取消开门Tween；死亡动画仍可播放，但旧开门回调不再修改世界。
func stop_run() -> void:
	_run_stopped = true
	_progress.stop_run()
	for gate in $Gates.get_children():
		gate.cancel_opening()
	if _exit_tween != null and _exit_tween.is_valid():
		_exit_tween.kill()


func _on_configuration_error(message: String) -> void:
	push_error(message)


func _on_room_completed(room_id: StringName) -> void:
	if _run_stopped or _player.is_dead():
		return
	match room_id:
		&"l1_entrance":
			$Gates/EntranceGate.open_gate()
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
	# 以正式死亡事件留下的房间完成记录为准。Boss可能在门外被击败，
	# 死亡动画结束释放实例后，玩家才走入大厅；不能因此永远无法开出口。
	# 仅删除活Boss不会产生该记录，仍然不能解锁。
	if not _progress.is_complete(&"l1_boss"):
		return false
	_exit_state = ExitState.OPENING
	$ExitGate/SealLabel.text = "出口封印解除中"
	_exit_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_exit_tween.tween_property($ExitGate/MeshInstance3D, "position:y", -3.6, 0.9)
	_exit_tween.finished.connect(_finish_exit_unlock)
	exit_opening_started.emit()
	return true


func _finish_exit_unlock() -> void:
	if _run_stopped or _player.is_dead() or not can_process():
		return
	$ExitGate/CollisionShape3D.set_deferred("disabled", true)
	$ExitGate.hide()
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
	# 每个物理帧重试激活，避免前置刚完成而玩家仍停在同一区域时漏掉状态。
	if _run_started and not _run_stopped and region != null and REGION_IDS.has(region.name):
		_progress.activate_room(REGION_IDS[region.name])
	if region == null or not region.visible or not region.exploration_room or region == _current_region:
		return
	_current_region = region
	_visited[region.name] = true
	room_changed.emit(region.display_name, _visited.size())


func _on_courtyard_gate_opened(_gate_id: StringName) -> void:
	$Doorways/MainRoute/Banner.text = "主路已开启 → 守门者大厅"
	progression_feedback.emit("主路已开启 · 可前往守门者大厅，也可返回补给支线")
