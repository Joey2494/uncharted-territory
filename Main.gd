extends Node3D
## 第一关会话状态、暂停、通关结算及跨关入口。

const LEVEL02_PATH := "res://scenes/dungeon/Level02Run.tscn"
const LEVEL_PATHS := {1: "res://Main.tscn", 2: LEVEL02_PATH}

@export var level_id: int = 1

const CHARACTERS = preload("res://scenes/player/character_catalog.gd")
const PROFILE = preload("res://scripts/integration/player_profile.gd")

func _enter_tree() -> void:
	PROFILE.ensure_loaded()
	# Restore before Player builds its model/stats; an explicit scene handoff wins in flight.
	if not CHARACTERS.start_pending:
		CHARACTERS.selected_id = PROFILE.get_selected_character()
	if not PROFILE.owns(CHARACTERS.selected_id): CHARACTERS.selected_id = "knight"
	$DungeonTest/Player.character_id = CHARACTERS.selected_id

@onready var _dungeon: Node3D = $DungeonTest
@onready var _player: CharacterBody3D = $DungeonTest/Player
@onready var _hud: Control = $UILayer/HUD
@onready var _items: Node3D = $DungeonTest/Player/ItemInventory
@onready var _boss: CharacterBody3D = $DungeonTest.get_node("Boss" if level_id == 2 else "RuinGatekeeper")
@onready var _boss_bar: Control = $UILayer/BossHealthBar
@onready var _rune_puzzle: Node3D = $DungeonTest.get_node_or_null("RunePuzzle")
@onready var _start_screen: Control = $UILayer/StartScreen
@onready var _commerce: CanvasLayer = $CommerceLayer

@onready var _overlay: Control = $UILayer/RunOverlay

enum RunState { MENU, PLAYING, DEAD, VICTORY, DYING, PAUSED, GUIDE }

var _transition_queued: bool = false
var _transition_executing: bool = false
var _transition_snapshot: Dictionary = {}
var _run_state: RunState = RunState.MENU
var _elapsed_seconds: float = 0.0
var _boss_defeated: bool = false
var _boss_name: String = ""
var _run_result: Dictionary = {}
var _death_room_index: int = 0


func _ready() -> void:
	PROFILE.ensure_loaded()
	_items.gold = PROFILE.coins
	if level_id == 2:
		_start_screen.get_node("Center/Card/Padding/Content/Description").text = "第二关 · 导能遗迹\n击败灾厄巨蝎，从开启的出口离开。"
		_start_screen.get_node("Center/Card/Padding/Content/Tagline").text = "循着金线，唤醒沉寂的遗迹。"
		_hud.get_node("LevelObjective").world = _dungeon
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
	_commerce.bind_inventory(_items, func() -> bool:
		var menus := get_node_or_null("MenuNavigation")
		return _run_state in [RunState.PLAYING, RunState.PAUSED] \
			and (menus == null or not menus.settings_screen.visible),
		func() -> float: return _elapsed_seconds)
	_commerce.external_pause_state = func() -> bool: return _run_state == RunState.PAUSED
	_start_screen.shop_requested.connect(_commerce.open_menu_shop)
	_start_screen.backpack_requested.connect(_commerce.open_menu_backpack)
	if _rune_puzzle != null:
		_rune_puzzle.feedback.connect(_hud.show_item_message)
		_rune_puzzle.solved.connect(_on_rune_puzzle_solved)
	_hud.update_weapon_status(true)
	_hud.bind_combat_actions(_player)
	_player.hp_changed.connect(_hud.update_hp_bar)
	_player.died.connect(_on_player_died)
	_player.death_animation_finished.connect(_on_player_death_animation_finished)
	_hud.restart_requested.connect(_on_restart_requested)
	_hud.next_level_requested.connect(advance_to_next_level)
	_hud.update_inventory(_items.potion_count, _items.rune_count)
	_hud.update_attack_buff(_items.get_multiplier(), _items.get_buff_remaining())
	_items.inventory_changed.connect(_hud.update_inventory)
	_items.buff_changed.connect(_hud.update_attack_buff)
	_items.pickup_prompt_changed.connect(_hud.update_pickup_prompt)
	_items.feedback.connect(_hud.show_item_message)
	_hud.use_potion_requested.connect(_items.try_use_potion)
	_hud.use_rune_requested.connect(_items.try_use_rune)
	_boss_bar.update_hp(_boss.hp, _boss.max_hp)
	_boss_name = _boss.boss_name
	_boss.hp_changed.connect(_boss_bar.update_hp)
	_boss.state_changed.connect(_boss_bar.update_state)
	_boss.battle_started.connect(_on_boss_battle_started)
	_boss.died.connect(_on_boss_died)
	_boss.tree_exiting.connect(_on_boss_exiting)
	_player.feedback.connect(_hud.show_item_message)
	_player.get_node("CharacterAbility").feedback.connect(_hud.show_item_message)
	var bindings := preload("res://scripts/integration/run_bindings.gd").new()
	bindings.name = "RunBindings"
	add_child(bindings)
	var navigation := preload("res://scripts/integration/menu_navigation.gd").new()
	navigation.name = "MenuNavigation"
	add_child(navigation)
	var victory_presentation := preload("res://scenes/ui/victory_battlefield.gd").new()
	victory_presentation.name = "VictoryPresentation"
	add_child(victory_presentation)
	if CHARACTERS.start_pending:
		CHARACTERS.start_pending = false
		_start_screen.hide()
		_on_run_started.call_deferred()
	else:
		MusicManager.play_context(&"menu")


func _process(delta: float) -> void:
	if _run_state == RunState.PLAYING and not get_tree().paused:
		_elapsed_seconds += delta


func _on_run_started() -> void:
	if _run_state != RunState.MENU or _transition_queued or _commerce.view != _commerce.View.NONE:
		return
	if not PROFILE.owns(_start_screen.selected_character_id):
		_start_screen.show_status("请先使用金币解锁该角色")
		return
	if _player.character_id != _start_screen.selected_character_id:
		request_scene_change("", {"character_id": _start_screen.selected_character_id, "start_run": true})
		return
	_run_state = RunState.PLAYING
	MusicManager.play_level(level_id)
	_elapsed_seconds = 0.0
	_start_screen.hide()
	_dungeon.process_mode = Node.PROCESS_MODE_PAUSABLE
	_hud.show()
	_dungeon.begin_run()
	get_node("MenuNavigation").progress.mark_played(level_id)
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
		_hud.show_item_message("已击败%s · 进入大厅解除出口封印" % _boss_name)


## 以世界真正开始开门的事件提示，不能把提前击败Boss误报为出口已解锁。
func _on_exit_opening_started() -> void:
	if _run_state == RunState.PLAYING:
		_hud.show_item_message("已击败%s · 出口封印正在解除" % _boss_name)


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
	MusicManager.play_context(&"victory")
	_commerce.finish_run()
	_run_result = {
		"elapsed_seconds": _elapsed_seconds,
		"rooms_visited": _dungeon.get_visited_count(),
		"rooms_total": _dungeon.get_room_count(),
		"player_hp": _player.hp,
		"player_max_hp": _player.max_hp,
		"boss_name": _boss_name,
		"boss_defeated": _boss_defeated,
		"puzzle_solved": _rune_puzzle.is_solved() if _rune_puzzle != null else _dungeon.puzzle.get_state() >= _dungeon.puzzle.State.OPEN,
		"reward_claimed": _rune_puzzle.is_reward_claimed() if _rune_puzzle != null else _dungeon.puzzle.get_state() == _dungeon.puzzle.State.CLAIMED,
		"level_id": level_id,
	}
	_player.velocity = Vector3.ZERO
	_dungeon.stop_run()
	_dungeon.process_mode = Node.PROCESS_MODE_DISABLED
	_boss_bar.hide()
	_refresh_overlay()
	get_node("MenuNavigation").progress.complete(level_id)
	_hud.show_win_screen(_run_result, LEVEL_PATHS.has(level_id + 1))


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
	_overlay.update_view(_run_state == RunState.PLAYING, false, false)
	if _commerce.view == _commerce.View.NONE:
		if _run_state == RunState.PAUSED:
			_commerce.pause_menu.show_pause(_elapsed_seconds)
		else:
			_commerce.pause_menu.hide()
	if _run_state == RunState.GUIDE:
		get_node("MenuNavigation").open_settings()


func _resume_playing() -> void:
	if not close_guide():
		set_paused(false)


func _input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("pause"):
		return
	var navigation := get_node_or_null("MenuNavigation")
	if navigation != null and navigation.load_error.visible:
		return
	if navigation != null and navigation.settings_screen.visible:
		navigation.settings_screen.go_back()
		get_viewport().set_input_as_handled()
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
	if _run_state == RunState.VICTORY:
		return request_scene_change("", {"character_id": _player.character_id, "start_run": true})
	return request_scene_change("")


## Settlement starts a fresh run with the live character; progress stays in the session.
func advance_to_next_level() -> bool:
	if _transition_queued or _run_state != RunState.VICTORY:
		return false
	var reason := get_next_level_block_reason()
	if not reason.is_empty():
		var screen: Control = _hud.get_result_screen()
		if is_instance_valid(screen): screen.show_progress_message(reason)
		return false
	return request_scene_change(LEVEL_PATHS[level_id + 1],
		{"character_id": _player.character_id, "start_run": true})


func get_next_level_block_reason() -> String:
	if not LEVEL_PATHS.has(level_id + 1):
		return "已完成全部关卡 · 可再次挑战，或返回关卡选择 / 主菜单"
	if not get_node("MenuNavigation").progress.is_unlocked(StringName("level%d" % (level_id + 1))):
		return "下一关尚未解锁 · 请先完成本关，或返回关卡选择"
	return ""


## Compatibility for existing callers; never loops the final level back to level two.
func advance_to_level02() -> bool:
	return advance_to_next_level()


## All live-run navigation queues here. The first accepted request owns the handoff.
func request_scene_change(destination: String, handoff: Dictionary = {}) -> bool:
	if _transition_queued or not is_inside_tree() or is_queued_for_deletion():
		return false
	var character_id: String = handoff.get("character_id", CHARACTERS.selected_id)
	if character_id not in CHARACTERS.IDS or not PROFILE.owns(character_id):
		return false
	_transition_queued = true
	var navigation: Node = get_node("MenuNavigation")
	_transition_snapshot = {
		"character_id": CHARACTERS.selected_id,
		"from_levels": navigation.level_select.visible,
		"handoff": {"character_id": character_id, "start_run": handoff.get("start_run", false),
			"show_levels": handoff.get("show_levels", false)},
	}
	CHARACTERS.selected_id = character_id
	CHARACTERS.start_pending = handoff.get("start_run", false)
	navigation.pending_level_select = handoff.get("show_levels", false)
	navigation.clear_load_error()
	_change_scene.call_deferred(destination)
	return true


func _change_scene(destination: String) -> void:
	# A detached old scene or an extra deferred callback cannot execute a second switch.
	if not _transition_queued or _transition_executing or not is_inside_tree() or is_queued_for_deletion():
		return
	_transition_executing = true
	var tree := get_tree()
	var was_paused := tree.paused
	_commerce.close_all()
	tree.paused = false
	var error := tree.reload_current_scene() if destination.is_empty() else tree.change_scene_to_file(destination)
	if error != OK:
		var failed_request := _transition_snapshot.duplicate(true)
		CHARACTERS.selected_id = failed_request.character_id
		# A failed arrival must never auto-start a later, unrelated navigation request.
		CHARACTERS.start_pending = false
		get_node("MenuNavigation").pending_level_select = false
		_transition_snapshot.clear()
		_transition_executing = false
		_transition_queued = false
		tree.paused = was_paused
		_refresh_overlay()
		const MESSAGE := "无法载入关卡，请重试。"
		get_node("MenuNavigation").restore_after_load_failure(destination, failed_request, MESSAGE)
		push_error("%s %s" % [MESSAGE, error_string(error)])
