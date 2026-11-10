extends Node3D

@onready var _dungeon: Node3D = $DungeonTest
@onready var _player: CharacterBody3D = $DungeonTest/Player
@onready var _hud: Control = $UILayer/HUD
@onready var _items: Node3D = $DungeonTest/Player/ItemInventory
@onready var _boss: CharacterBody3D = $DungeonTest/RuinGatekeeper
@onready var _boss_bar: Control = $UILayer/BossHealthBar
@onready var _rune_puzzle: Node3D = $DungeonTest/RunePuzzle
@onready var _start_screen: Control = $UILayer/StartScreen
@onready var _commerce: CanvasLayer = $CommerceLayer

enum RunState { MENU, PLAYING, DEAD, VICTORY, DYING }

var _restart_queued: bool = false
var _run_state: RunState = RunState.MENU
var _elapsed_seconds: float = 0.0
var _boss_defeated: bool = false
var _boss_name: String = ""
var _run_result: Dictionary = {}
var _death_room_index: int = 0


func _ready() -> void:
	_hud.update_hp_bar(_player.hp, _player.max_hp)
	_hud.total_rooms = _dungeon.get_room_count()
	_hud.update_room_label(_dungeon.get_visited_count() - 1)
	_dungeon.room_changed.connect(_on_room_changed)
	_dungeon.exit_reached.connect(_on_exit_reached)
	_dungeon.exit_unlocked.connect(_on_exit_unlocked)
	_start_screen.start_requested.connect(_on_run_started)
	_commerce.bind_inventory(_items, func() -> bool: return _run_state == RunState.PLAYING,
		func() -> float: return _elapsed_seconds)
	_start_screen.shop_requested.connect(_commerce.open_menu_shop)
	_start_screen.backpack_requested.connect(_commerce.open_menu_backpack)
	_commerce.restart_requested.connect(_on_restart_requested)
	_commerce.main_menu_requested.connect(_on_restart_requested)
	_rune_puzzle.feedback.connect(_hud.show_item_message)
	_rune_puzzle.solved.connect(_on_rune_puzzle_solved)
	_hud.update_weapon_status(true)
	_hud.bind_combat_actions(_player)
	_player.hp_changed.connect(_hud.update_hp_bar)
	_player.died.connect(_on_player_died)
	_player.death_animation_finished.connect(_on_player_death_animation_finished)
	_hud.restart_requested.connect(_on_restart_requested)
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
	if _run_state == RunState.PLAYING:
		_elapsed_seconds += delta


func _on_run_started() -> void:
	if _run_state != RunState.MENU or _commerce.view != _commerce.View.NONE:
		return
	_run_state = RunState.PLAYING
	_elapsed_seconds = 0.0
	_start_screen.hide()
	_dungeon.process_mode = Node.PROCESS_MODE_INHERIT
	_hud.show()
	_commerce.set_run_active(true)


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
	_dungeon.process_mode = Node.PROCESS_MODE_DISABLED
	_boss_bar.hide()
	_hud.show_win_screen(_run_result)


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


func _on_player_death_animation_finished() -> void:
	if _run_state != RunState.DYING:
		return
	_run_state = RunState.DEAD
	_dungeon.process_mode = Node.PROCESS_MODE_DISABLED
	_hud.show_death_screen(_death_room_index)


func _on_restart_requested() -> void:
	if _restart_queued:
		return
	_restart_queued = true
	_commerce.close_all()
	_reload_scene.call_deferred()


func _reload_scene() -> void:
	var error := get_tree().reload_current_scene()
	if error != OK:
		_restart_queued = false
		push_error("Could not restart test dungeon: %s" % error_string(error))
