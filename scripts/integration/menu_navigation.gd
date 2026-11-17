extends Node
static var pending_level_select := false
@onready var host = get_parent()
var progress := preload("res://scripts/integration/campaign_progress.gd").new()
var settings := preload("res://scripts/settings/game_settings.gd").new()
var level_select: Control
var settings_screen: Control
var character_select: Control
var load_error: Control
var _failed_transition: Dictionary = {}
var _levels_from_characters := false
var _guide_from_pause := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings.load_settings()
	settings.apply(get_tree().root)
	level_select = preload("res://scenes/ui/level_select.tscn").instantiate()
	settings_screen = preload("res://scenes/ui/settings_screen.tscn").instantiate()
	character_select = preload("res://scenes/ui/character_select.tscn").instantiate()
	character_select.hide()
	var layer := host.get_node("UILayer")
	layer.add_child(level_select)
	layer.add_child(character_select)
	# Full-screen settings/guide must cover HUD tutorials and the commerce layer.
	var settings_layer := CanvasLayer.new()
	settings_layer.name = "SettingsLayer"
	settings_layer.layer = 40
	add_child(settings_layer)
	settings_layer.add_child(settings_screen)
	# Keep failure actions above settlement and commerce UI, including while paused.
	var error_layer := CanvasLayer.new()
	error_layer.name = "LoadErrorLayer"
	error_layer.layer = 60
	add_child(error_layer)
	load_error = preload("res://scenes/ui/load_error.tscn").instantiate()
	error_layer.add_child(load_error)
	load_error.retry_requested.connect(_retry_failed_transition)
	load_error.back_requested.connect(_dismiss_load_error)
	level_select.hide()
	settings_screen.hide()
	var levels: Array[Dictionary] = [{"id": &"level1", "name": "第一关"}, {"id": &"level2", "name": "第二关"}]
	level_select.configure(levels, progress)
	settings_screen.configure(settings)
	level_select.back_requested.connect(_back_from_levels)
	character_select.back_requested.connect(_back_to_menu)
	character_select.character_confirmed.connect(_character_confirmed)
	character_select.character_purchased.connect(func() -> void: host._start_screen.character_purchased.emit())
	level_select.level_selected.connect(_launch)
	settings_screen.back_requested.connect(_close_settings)
	host._start_screen.configure(levels, progress)
	host._start_screen.start_requested.connect(_open_characters)
	host._start_screen.continue_requested.connect(_continue_campaign)
	host._start_screen.settings_requested.connect(open_settings)
	host._start_screen.quit_requested.connect(func() -> void: get_tree().quit())
	if pending_level_select:
		pending_level_select = false
		_open_levels.call_deferred()
	var pause_menu = host._commerce.pause_menu
	pause_menu.get_node("%SettingsButton").show()
	pause_menu.settings_requested.connect(open_settings)
	pause_menu.get_node("%ControlsGuideButton").show()
	pause_menu.controls_guide_requested.connect(open_controls_guide)
	pause_menu.resume_requested.connect(func() -> void: host.set_paused(false))
	host._commerce.restart_requested.connect(host._on_restart_requested)

func _open_levels() -> void:
	character_select.hide()
	host._start_screen.hide()
	level_select.start_button.text = "返回角色选择" if _levels_from_characters else "返回主菜单"
	level_select.show_menu()

func _open_characters() -> void:
	if host._run_state != host.RunState.MENU or host._transition_queued or host._commerce.view != host._commerce.View.NONE:
		return
	host._start_screen.hide()
	level_select.hide()
	character_select.show_selection(host._start_screen.selected_character_id)

func _character_confirmed(id: StringName) -> void:
	if host._transition_queued or not character_select.visible or not host.PROFILE.owns(String(id)):
		return
	if not host.PROFILE.set_selected_character(String(id)):
		character_select.show_confirmation_error(host.PROFILE.message)
		return
	host._start_screen.select_character(String(id))
	_levels_from_characters = true
	_open_levels()

func _back_from_levels() -> void:
	level_select.hide()
	if _levels_from_characters:
		_open_characters()
	else:
		_back_to_menu()

func _back_to_menu() -> void:
	character_select.hide()
	level_select.hide()
	_levels_from_characters = false
	host._start_screen.show_menu()

func _continue_campaign() -> void:
	var recent: StringName = progress.get_last_played_level()
	if not recent.is_empty():
		_launch(recent)

func return_to_level_select() -> void:
	host.request_scene_change("res://Main.tscn", {"show_levels": true})

func _launch(id: StringName) -> void:
	if host._transition_queued or host._run_state != host.RunState.MENU or not progress.is_unlocked(id): return
	if not host.PROFILE.owns(host._start_screen.selected_character_id):
		level_select.show_status("请先返回主菜单解锁角色或选择初始旅人")
		return
	var level := 2 if id == &"level2" else 1
	if level == host.level_id:
		host._on_run_started()
	else:
		host.request_scene_change("res://scenes/dungeon/Level02Run.tscn" if level == 2 else "res://Main.tscn",
			{"character_id": host._start_screen.selected_character_id, "start_run": true})
	# Capture the launching page before hiding it so failures can restore it.
	if host._transition_queued or host._run_state == host.RunState.PLAYING:
		level_select.hide()

func restore_after_load_failure(destination: String, request: Dictionary, message: String) -> void:
	_failed_transition = {"destination": destination, "handoff": request.handoff.duplicate(true)}
	var back_label := "返回结算界面"
	if host._run_state == host.RunState.MENU:
		settings_screen.hide()
		character_select.hide()
		if request.from_levels:
			_open_levels()
			level_select.show_status(message)
			back_label = "返回关卡选择"
		else:
			_back_to_menu()
			host._start_screen.show_status(message)
			back_label = "返回主菜单"
	elif host._run_state in [host.RunState.PAUSED, host.RunState.GUIDE, host.RunState.PLAYING]:
		back_label = "返回游戏" if host._run_state == host.RunState.PLAYING else "返回暂停菜单"
	load_error.show_failure(message, back_label)

func clear_load_error() -> void:
	_failed_transition.clear()
	load_error.hide()

func _dismiss_load_error() -> void:
	if not load_error.visible or host._transition_queued:
		return
	clear_load_error()
	if level_select.visible:
		level_select._focus_action()
	elif host._start_screen.visible:
		host._start_screen._focus_action()
	elif host._run_state in [host.RunState.PAUSED, host.RunState.GUIDE]:
		host._refresh_overlay()
	else:
		var result: Control = host._hud.get_result_screen()
		if is_instance_valid(result): result._focus_action()

func _retry_failed_transition() -> void:
	if _failed_transition.is_empty() or host._transition_queued:
		return
	# request_scene_change clears the panel only after it has accepted this copy.
	var request := _failed_transition.duplicate(true)
	host.request_scene_change(request.destination, request.handoff)

func open_settings() -> void:
	if host._transition_queued or load_error.visible:
		return
	_guide_from_pause = false
	host._start_screen.hide()
	host._commerce.pause_menu.hide()
	settings_screen.show_settings("返回暂停菜单" if host._run_state != host.RunState.MENU else "返回主菜单")

func open_controls_guide() -> void:
	if host._transition_queued or load_error.visible or host._run_state != host.RunState.PAUSED:
		return
	_guide_from_pause = true
	host._commerce.pause_menu.hide()
	settings_screen.show_controls_guide("返回暂停菜单")

func _close_settings() -> void:
	settings_screen.hide()
	if host._run_state == host.RunState.MENU: host._start_screen.show()
	elif host._run_state == host.RunState.GUIDE: host.close_guide()
	else: host._refresh_overlay()
	if _guide_from_pause:
		_guide_from_pause = false
		host._commerce.pause_menu._safe_focus.call_deferred(host._commerce.pause_menu.get_node("%ControlsGuideButton"))
