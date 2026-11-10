extends Node3D
## 独立 F6 预览：菜单、局内 HUD、地图指引及终局重开。世界由地图统一推进。

enum State { MENU, PLAYING, PAUSED, GUIDE, DEAD, VICTORY }

@onready var map := $Level02
@onready var _player := $Level02/Player
@onready var _boss := $Level02/Boss
@onready var _inventory := $Level02/Player/ItemInventory
@onready var _hud := $UI/HUD
@onready var _room := %Room
@onready var _objective := %Objective
@onready var _vitals := %Vitals
@onready var _health := %Health
@onready var _items := %Items
@onready var _prompt := %Prompt
@onready var _boss_panel := %BossPanel
@onready var _boss_health := %BossHealth
@onready var _overlay := $UI/Overlay
@onready var _overlay_title := %OverlayTitle
@onready var _overlay_body := %OverlayBody
@onready var _guide := %GuideDetails
@onready var _primary := %Primary
@onready var _restart := %Restart

var _state := State.MENU
var _reloading := false
var _pickup_prompt := ""
var _feedback := ""
var _feedback_remaining := 0.0

func _ready() -> void:
	_primary.pressed.connect(_on_primary)
	_restart.pressed.connect(restart_run)
	%GuideButton.pressed.connect(open_guide)
	%PauseButton.pressed.connect(set_paused.bind(true))
	_player.died.connect(_on_death)
	map.exit_reached.connect(_on_victory)
	map.feedback.connect(_show_feedback)
	_inventory.feedback.connect(_show_feedback)
	_inventory.pickup_prompt_changed.connect(func(message: String) -> void: _pickup_prompt = message)
	_refresh_overlay()

func get_run_state() -> State:
	return _state

func start_run() -> bool:
	if _state != State.MENU or not map.begin_run():
		return false
	_state = State.PLAYING
	_refresh_overlay()
	return true

## ESC 和界面按钮共用同一状态转移。死亡和胜利不能退回游戏。
func set_paused(value: bool) -> bool:
	if value and _state == State.PLAYING:
		_state = State.PAUSED
	elif not value and _state == State.PAUSED:
		_state = State.PLAYING
	else:
		return false
	get_tree().paused = value
	_refresh_overlay()
	return true

func open_guide() -> bool:
	if _state != State.PLAYING:
		return false
	_state = State.GUIDE
	get_tree().paused = true
	_refresh_overlay()
	return true

func close_guide() -> bool:
	if _state != State.GUIDE:
		return false
	_state = State.PLAYING
	get_tree().paused = false
	_refresh_overlay()
	return true

func restart_run() -> bool:
	if _reloading or _state not in [State.PAUSED, State.DEAD, State.VICTORY]:
		return false
	_reloading = true
	_reload.call_deferred()
	return true

func _reload() -> void:
	get_tree().paused = false
	var result := get_tree().reload_current_scene()
	if result != OK:
		_reloading = false
		get_tree().paused = _state == State.PAUSED
		push_error("无法重开第二关预览：%s" % error_string(result))

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("pause"):
		match _state:
			State.PLAYING:
				set_paused(true)
			State.PAUSED:
				set_paused(false)
			State.GUIDE:
				close_guide()
			_:
				return
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _state != State.PLAYING:
		return
	_feedback_remaining = maxf(0.0, _feedback_remaining - delta)
	var region = map.get_region_at(_player.global_position)
	_room.text = "%s     ·     %d/%d" % [region.display_name if region != null else "探索中", map.get_visited_count(), map.get_room_count()]
	_objective.text = map.get_objective()
	_vitals.text = "生命   %d / %d" % [_player.hp, _player.max_hp]
	_health.max_value = _player.max_hp
	_health.value = _player.hp
	_items.text = "R 药剂 %d     F 符文 %d" % [_inventory.potion_count, _inventory.rune_count]
	if _inventory.get_buff_remaining() > 0:
		_items.text += "     强化 %.0f 秒" % ceilf(_inventory.get_buff_remaining())
	_prompt.text = _pickup_prompt if not _pickup_prompt.is_empty() else (_feedback if _feedback_remaining > 0 else "")
	%PromptPanel.visible = not _prompt.text.is_empty()
	_boss_panel.visible = is_instance_valid(_boss) and _boss.can_process() and not _boss.is_dead()
	if _boss_panel.visible:
		_boss_health.max_value = _boss.max_hp
		_boss_health.value = _boss.hp

func _show_feedback(message: String) -> void:
	_feedback = message
	_feedback_remaining = 2.8

func _on_primary() -> void:
	match _state:
		State.MENU:
			start_run()
		State.PAUSED:
			set_paused(false)
		State.GUIDE:
			close_guide()
		State.DEAD, State.VICTORY:
			restart_run()

func _on_death() -> void:
	_state = State.DEAD
	_refresh_overlay()

func _on_victory() -> void:
	_state = State.VICTORY
	_refresh_overlay()

func _refresh_overlay() -> void:
	_overlay.visible = _state != State.PLAYING
	_hud.visible = _state == State.PLAYING
	_guide.visible = _state == State.GUIDE
	_restart.visible = _state == State.PAUSED
	match _state:
		State.MENU:
			_overlay_title.text = "第二关 · 失落导能遗迹"
			_overlay_body.text = "从到达平台出发，清除守卫并启动导能核心。穿过共鸣前厅，击败遗迹守门者后踏入出口。\n\n青色路线通向可选的符文档案室。"
			_primary.text = "开始探索"
		State.PAUSED:
			_overlay_title.text = "探索已暂停"
			_overlay_body.text = "继续当前探索，或从到达平台重新开始。"
			_primary.text = "继续探索"
		State.GUIDE:
			_overlay_title.text = "区域指引"
			_overlay_body.text = "北 ↑  W  ·  东 →  D  ·  南 ↓  S  ·  西 ←  A"
			_primary.text = "返回探索"
		State.DEAD:
			_overlay_title.text = "探索中止"
			_overlay_body.text = "生命耗尽。重新开始将回到到达平台。"
			_primary.text = "重新开始"
		State.VICTORY:
			_overlay_title.text = "第二关通过"
			_overlay_body.text = "遗迹守门者已击败，你已抵达出口。\n本次探索经过 %d / %d 个功能区域。" % [map.get_visited_count(), map.get_room_count()]
			_primary.text = "重新开始"
