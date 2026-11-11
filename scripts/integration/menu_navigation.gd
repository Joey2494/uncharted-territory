extends Node
@onready var host = get_parent()
var progress := preload("res://scripts/integration/campaign_progress.gd").new()
var settings := preload("res://scripts/settings/game_settings.gd").new()
var level_select: Control
var settings_screen: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings.load_settings()
	settings.apply(get_tree().root)
	level_select = preload("res://scenes/ui/level_select.tscn").instantiate()
	settings_screen = preload("res://scenes/ui/settings_screen.tscn").instantiate()
	var layer := host.get_node("UILayer")
	layer.add_child(level_select)
	layer.add_child(settings_screen)
	level_select.hide()
	settings_screen.hide()
	var levels: Array[Dictionary] = [{"id": &"level1", "name": "第一关"}, {"id": &"level2", "name": "第二关"}]
	level_select.configure(levels, progress)
	settings_screen.configure(settings)
	level_select.back_requested.connect(func() -> void: level_select.hide(); host._start_screen.show())
	level_select.level_selected.connect(_launch)
	settings_screen.back_requested.connect(_close_settings)
	var content = host._start_screen.get_node("Center/Card/Padding/Content")
	for entry in [["选择关卡", _open_levels], ["设置与操作指南", open_settings]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		content.add_child(button)
	var pause_menu = host._commerce.pause_menu
	pause_menu.get_node("%SettingsButton").show()
	pause_menu.settings_requested.connect(open_settings)
	pause_menu.resume_requested.connect(func() -> void: host.set_paused(false))
	host._commerce.restart_requested.connect(host._on_restart_requested)

func _open_levels() -> void:
	host._start_screen.hide()
	level_select.show_menu()

func _launch(id: StringName) -> void:
	if host._run_state != host.RunState.MENU or not progress.is_unlocked(id): return
	if not host.PROFILE.owns(host._start_screen.selected_character_id):
		level_select.show_status("请先返回主菜单解锁角色或选择初始旅人")
		return
	var level := 2 if id == &"level2" else 1
	level_select.hide()
	if level == host.level_id:
		host._on_run_started()
	else:
		host.CHARACTERS.selected_id = host._start_screen.selected_character_id
		host.CHARACTERS.start_pending = true
		host._transition_queued = true
		host._change_scene.call_deferred("res://scenes/dungeon/Level02Run.tscn" if level == 2 else "res://Main.tscn")

func open_settings() -> void:
	host._start_screen.hide()
	host._commerce.pause_menu.hide()
	settings_screen.show_settings("返回暂停菜单" if host._run_state != host.RunState.MENU else "返回主菜单")

func _close_settings() -> void:
	settings_screen.hide()
	if host._run_state == host.RunState.MENU: host._start_screen.show()
	elif host._run_state == host.RunState.GUIDE: host.close_guide()
	else: host._refresh_overlay()
