extends Node3D
## 第一关会话状态、暂停、通关结算及跨关入口。

const LEVEL02_PATH := "res://tests/scenes/Level02Preview.tscn"

@onready var _dungeon: Node3D = $DungeonTest
@onready var _player: CharacterBody3D = $DungeonTest/Player
@onready var _hud: Control = $UILayer/HUD
@onready var _items: Node3D = $DungeonTest/Player/ItemInventory
@onready var _boss: CharacterBody3D = $DungeonTest/RuinGatekeeper
@onready var _boss_bar: Control = $UILayer/BossHealthBar
@onready var _rune_puzzle: Node3D = $DungeonTest/RunePuzzle
@onready var _start_screen: Control = $UILayer/StartScreen
@onready var _commerce: CanvasLayer = $CommerceLayer

@onready var _overlay: Control = $UILayer/RunOverlay

enum RunState { MENU, PLAYING, DEAD, VICTORY, DYING, PAUSED, GUIDE }

var _transition_queued: bool = false
var _run_state: RunState = RunState.MENU
var _elapsed_seconds: float = 0.0
var _boss_defeated: bool = false
var _boss_name: String = ""
var _run_result: Dictionary = {}
var _death_room_index: int = 0


func _ready() -> void:
	$UILayer/TutorialOverlay.bind(_dungeon.get_tutorial())
	_overlay.pause_requested.connect(set_paused.bind(true))
	_overlay.guide_requested.connect(open_guide)
	_overlay.resume_requested.connect(_resume_playing)
	_overlay.restart_requested.connect(_on_restart_requested)
	_overlay.shop_requested.connect(_commerce.open_shop)
	_overlay.backpack_requested.connect(_commerce.open_backpack)
	_hud.update_hp_bar(_player.hp, _player.max_hp)
	_hud.total_rooms = _dungeon.get_room_count()
	_hud.update_room_label(_dungeon.get_visited_count() - 1)
	_dungeon.room_changed.connect(_on_room_changed)
	_dungeon.progression_feedback.connect(_hud.show_item_message)
	_dungeon.exit_reached.connect(_on_exit_reached)
	_dungeon.exit_unlocked.connect(_on_exit_unlocked)
	_dungeon.exit_opening_started.connect(_on_exit_opening_started)
	_start_screen.start_requested.connect(_on_run_started)
	_commerce.bind_inventory(_items, func() -> bool:
		return _run_state in [RunState.PLAYING, RunState.PAUSED],
		func() -> float: return _elapsed_seconds)
	_commerce.external_pause_state = func() -> bool: return _run_state == RunState.PAUSED
	_start_screen.shop_requested.connect(_commerce.open_menu_shop)
	_start_screen.backpack_requested.connect(_commerce.open_menu_backpack)
	_rune_puzzle.feedback.connect(_hud.show_item_message)
	_rune_puzzle.solved.connect(_on_rune_puzzle_solved)
	_hud.update_weapon_status(true)
	_hud.bind_combat_actions(_player)
	_player.hp_changed.connect(_hud.update_hp_bar)
	_player.died.connect(_on_player_died)
	_player.death_animation_finished.connect(_on_player_death_animation_finished)
	_hud.restart_requested.connect(_on_restart_requested)
	_hud.next_level_requested.connect(advance_to_level02)
	_hud.update_inventory(_items.potion_count, _items.rune_count)
	_hud.update_attack_buff(_items.get_multiplier(), _items.get_buff_remaining())
	_items.inventory_changed.connect(_hud.update_inventory)
	_items.buff_changed.connect(_hud.update_attack_buff)
	_items.pickup_prompt_changed.connect(_hud.update_pickup_prompt)
	_items.feedback.connect(_hud.show_item_message)
	var economy := preload("res://scenes/items/economy_hud.gd").new()
	economy.name = "Economy"
	_hud.get_node("ItemsPanel/Padding/Content").add_child(economy)
	economy.bind_inventory(_items)
	_hud.use_potion_requested.connect(_items.try_use_potion)
	_hud.use_rune_requested.connect(_items.try_use_rune)
	_boss_bar.update_hp(_boss.hp, _boss.max_hp)
	_boss_name = _boss.boss_name
	_boss.hp_changed.connect(_boss_bar.update_hp)
	_boss.state_changed.connect(_boss_bar.update_state)
	_boss.battle_started.connect(_on_boss_battle_started)
	_boss.died.connect(_on_boss_died)
	_boss.tree_exiting.connect(_on_boss_exiting)


func _process(delta: float) -> void:
	if _run_state == RunState.PLAYING and not get_tree().paused:
		_elapsed_seconds += delta


func _on_run_started() -> void:
	if _run_state != RunState.MENU or _commerce.view != _commerce.View.NONE:
		return
	_run_state = RunState.PLAYING
	_elapsed_seconds = 0.0
	_start_screen.hide()
	_dungeon.process_mode = Node.PROCESS_MODE_PAUSABLE
	_hud.show()
	_dungeon.begin_run()
	_commerce.set_run_active(true)
	_refresh_overlay()


func _on_room_changed(room_name: String, visited_count: int) -> void:
	_hud.total_rooms = _dungeon.get_room_count()
	_hud.update_room_label(visited_count - 1)
	_hud.show_item_message("%s · 已探索 %d/%d" % [room_name, visited_count, _dungeon.get_room_count()])


func _on_rune_puzzle_solved() -> void:
	_hud.total_rooms = _dungeon.get_room_count()
	_hud.update_room_label(_dungeon.get_visited_count() - 1)


func _on_boss_battle_started() -> void:
	_boss_bar.begin_encounter(_boss.boss_name, _boss.hp, _boss.max_hp)


func _on_boss_died() -> void:
	if _run_state != RunState.PLAYING or _player.is_dead() or _boss_defeated:
		return
	_boss_defeated = true
	_boss_bar.show_defeated()
	_dungeon.unlock_exit()
	if not _dungeon.is_exit_opening() and not _dungeon.is_exit_open():
		_hud.show_item_message("已击败遗迹守门者 · 进入守门者大厅解除出口封印")


## 以世界真正开始开门的事件提示，不能把提前击败Boss误报为出口已解锁。
func _on_exit_opening_started() -> void:
	if _run_state == RunState.PLAYING:
		_hud.show_item_message("已击败遗迹守门者 · 出口封印正在解除")


func _on_exit_unlocked() -> void:
	if _run_state == RunState.PLAYING:
		_hud.show_item_message("地牢出口已开启 · 进入出口区域即可通关")


func _on_exit_reached() -> void:
	if _run_state != RunState.PLAYING or not _boss_defeated or _player.is_dead():
		return
	if not _dungeon.is_exit_open() or not _dungeon.is_player_in_exit_area():
		return
	# Set the terminal state before any UI signals; death/exit cannot replace it.
	_run_state = RunState.VICTORY
	_commerce.finish_run()
	_run_result = {
		"elapsed_seconds": _elapsed_seconds,
		"rooms_visited": _dungeon.get_visited_count(),
		"rooms_total": _dungeon.get_room_count(),
		"player_hp": _player.hp,
		"player_max_hp": _player.max_hp,
		"boss_name": _boss_name,
		"boss_defeated": _boss_defeated,
		"puzzle_solved": _rune_puzzle.is_solved(),
		"reward_claimed": _rune_puzzle.is_reward_claimed(),
	}
	_player.velocity = Vector3.ZERO
	_dungeon.stop_run()
	_dungeon.process_mode = Node.PROCESS_MODE_DISABLED
	_boss_bar.hide()
	_refresh_overlay()
	_hud.show_win_screen(_run_result, true)


func _on_boss_exiting() -> void:
	if is_instance_valid(_boss_bar) and not _boss_bar.is_defeated():
		_boss_bar.hide()


func _on_player_died() -> void:
	if _run_state != RunState.PLAYING:
		return
	# Stop the run clock and reject victory immediately; keep the world processing
	# while the already input-locked player completes Death_A.
	_run_state = RunState.DYING
	_commerce.finish_run()
	_death_room_index = _dungeon.get_visited_count() - 1
	$UILayer/TutorialOverlay.hide()
	_refresh_overlay()


func _on_player_death_animation_finished() -> void:
	if _run_state != RunState.DYING:
		return
	_run_state = RunState.DEAD
	_dungeon.process_mode = Node.PROCESS_MODE_DISABLED
	_hud.show_death_screen(_death_room_index)


## 暂停与指引共用世界冻结机制。终局和切换期间拒绝状态变更。
func set_paused(value: bool) -> bool:
	if _transition_queued:
		return false
	if value and _run_state == RunState.PLAYING:
		_set_play_mode(RunState.PAUSED)
	elif not value and _run_state == RunState.PAUSED:
		_set_play_mode(RunState.PLAYING)
	else:
		return false
	return true


func open_guide() -> bool:
	if _transition_queued or _run_state != RunState.PLAYING:
		return false
	_set_play_mode(RunState.GUIDE)
	return true


func close_guide() -> bool:
	if _transition_queued or _run_state != RunState.GUIDE:
		return false
	_set_play_mode(RunState.PLAYING)
	return true


func get_run_state() -> RunState:
	return _run_state


func _set_play_mode(state: RunState) -> void:
	_run_state = state
	get_tree().paused = state != RunState.PLAYING
	_refresh_overlay()


func _refresh_overlay() -> void:
	_overlay.update_view(_run_state == RunState.PLAYING, _run_state == RunState.PAUSED, _run_state == RunState.GUIDE)


func _resume_playing() -> void:
	if not close_guide():
		set_paused(false)


func _input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("pause"):
		return
	if _commerce.view != _commerce.View.NONE:
		return
	if _run_state == RunState.PLAYING:
		if set_paused(true):
			get_viewport().set_input_as_handled()
	elif _run_state in [RunState.PAUSED, RunState.GUIDE]:
		_resume_playing()
		get_viewport().set_input_as_handled()


func _on_restart_requested() -> void:
	restart_run()


func restart_run() -> bool:
	if _transition_queued or _run_state not in [RunState.PAUSED, RunState.DEAD, RunState.VICTORY]:
		return false
	_transition_queued = true
	_change_scene.call_deferred("")
	return true


## 只有出口确认后的胜利界面可前往第二关。每局数据由新场景初始化。
func advance_to_level02() -> bool:
	if _transition_queued or _run_state != RunState.VICTORY:
		return false
	_transition_queued = true
	_change_scene.call_deferred(LEVEL02_PATH)
	return true


func _change_scene(destination: String) -> void:
	_commerce.close_all()
	var tree := get_tree()
	tree.paused = false
	var error := tree.reload_current_scene() if destination.is_empty() else tree.change_scene_to_file(destination)
	if error != OK:
		_transition_queued = false
		tree.paused = _run_state == RunState.PAUSED
		const MESSAGE := "无法载入关卡，请重试。"
		if tree.paused:
			_overlay.show_error(MESSAGE)
		else:
			_hud.show_result_error(MESSAGE)
		push_error("%s %s" % [MESSAGE, error_string(error)])
