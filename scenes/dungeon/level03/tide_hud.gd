extends CanvasLayer
## 独立预览显示当前位置、潮位和供电反馈。Esc 暂停，Tab 打开路线图。

const MAP := "　　　　　　　　　J 远航出口\n　　　　　　　　　│\n　　　　　　I　　G 中心闸庭　F 蓄能工房 ─ H\n　　　　　　│　　│　　　╱　│\nD 折流廊 ─ C ─ B 中央潮井 ─ E 浮栈战区\n　　　　　　　　　│\n　　　　　　　　　A 入口检修台"
const GUIDE := "主线：低潮西路 C、D；高潮东路 E、F。F 向西是返程高架，向东的 H 花园奖励可跳过。\nF 手柄可同时打开 C–I 维修门和两潮位通行的 F–B 高架。\nD 的 △ 端口接 F；□ 端口接 I。储能器在输入中断时仍保留能量。\nI 泄压后经 C 回 B，穿过北闸去 G。A 有生命药剂，F 西侧有星蓝药剂，北闸后左侧有守护符文。B 的重置台需要按两次 E 确认。"

var _level: Node3D
var _player: CharacterBody3D
var _inventory: Node
var _location: Label
var _states: Label
var _battle: Label
var _prompt: Label
var _message: Label
var _overlay: ColorRect
var _title: Label
var _body: Label
var _continue: Button
var _restart: Button
var _prompt_text := ""
var _message_until := 0.0
var _mode := ""


func _ready() -> void:
	_level = get_parent()
	_player = _level.get_node("Player")
	_inventory = _player.get_node("ItemInventory")
	_level.feedback.connect(_show_feedback)
	_level.finished.connect(_finish)
	_inventory.feedback.connect(_show_feedback)
	_inventory.pickup_prompt_changed.connect(_change_prompt)
	_player.feedback.connect(_show_feedback)
	_build()


func _process(delta: float) -> void:
	if not _mode.is_empty():
		return
	_location.text = "潮汐回流工坊   /   " + _level.get_location()
	_states.text = _level.get_state_text()
	_battle.text = "生命 %d/%d   能量 %d/%d   药剂 %d   符文 %d     %s" % [
		_player.hp, _player.max_hp, _player.energy, _player.max_energy, _inventory.potion_count, _inventory.rune_count, _level.get_battle_text()]
	_prompt.text = _prompt_text
	_prompt.visible = not _prompt_text.is_empty()
	_message_until = maxf(0.0, _message_until - delta)
	_message.visible = _message_until > 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or _mode in ["victory", "death"]:
		return
	if event.is_action_pressed("pause"):
		if _mode.is_empty():
			_open("pause")
		else:
			_close()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_TAB:
		if _mode == "guide":
			_close()
		elif _mode.is_empty():
			_open("guide")
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()


func _build() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	var top := PanelContainer.new()
	screen.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = 12
	top.add_theme_stylebox_override("panel", _panel(Color("111c26ec")))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stats := VBoxContainer.new()
	top.add_child(stats)
	_location = _label(stats, "", 21, Color("ffdca2"))
	_states = _label(stats, "", 17, Color("e2f2fb"))
	_battle = _label(stats, "", 15, Color("cad8e1"))

	var bottom := PanelContainer.new()
	screen.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_left = 14
	bottom.offset_right = -14
	bottom.offset_bottom = -12
	bottom.add_theme_stylebox_override("panel", _panel(Color("111c26ec")))
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var details := VBoxContainer.new()
	bottom.add_child(details)
	_prompt = _label(details, "", 18, Color("ffdf9e"))
	_message = _label(details, "", 16, Color("f1f6ff"))
	_label(details, "WASD 移动   Shift 奔跑   J 攻击   K/L 技能   空格 闪避   E 交互\nR 药剂   F 强化   Tab 路线图   Esc 暂停", 15, Color("b7c9d3"))

	_overlay = ColorRect.new()
	_overlay.color = Color("0d1722e8")
	screen.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	center.add_child(card)
	card.custom_minimum_size = Vector2(465, 0)
	card.add_theme_stylebox_override("panel", _panel(Color("182733ff")))
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(440, 0)
	content.add_theme_constant_override("separation", 16)
	card.add_child(content)
	_title = _label(content, "", 27, Color("ffdca2"))
	_body = _label(content, "", 16, Color("f1f6ff"))
	_continue = Button.new()
	_continue.text = "继续探索"
	_continue.focus_mode = Control.FOCUS_NONE
	content.add_child(_continue)
	_continue.pressed.connect(_close)
	_restart = Button.new()
	_restart.text = "重新开始"
	_restart.focus_mode = Control.FOCUS_NONE
	content.add_child(_restart)
	_restart.pressed.connect(_reload)
	_overlay.hide()


func _label(parent: Control, content: String, size: int, color: Color) -> Label:
	var line := Label.new()
	line.text = content
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_color_override("font_color", color)
	line.add_theme_font_size_override("font_size", size)
	parent.add_child(line)
	return line


func _panel(color: Color) -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = color
	panel.border_color = Color("577180")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(5)
	panel.content_margin_left = 14
	panel.content_margin_right = 14
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	return panel


func _open(mode: String) -> void:
	_mode = mode
	get_tree().paused = true
	_continue.visible = mode in ["pause", "guide"]
	_restart.visible = mode != "guide"
	match mode:
		"guide":
			_title.text = "潮汐工坊路线图"
			_body.text = MAP + "\n\n" + GUIDE
		"pause":
			_title.text = "探索暂停"
			_body.text = "继续探索，或重新从入口检修台开始。"
		"victory":
			_title.text = "已抵达远航出口"
			_body.text = "维修井已泄压，中心闸庭守卫已清除。"
		"death":
			_title.text = "探索中止"
			_body.text = "生命耗尽。重新开始将回到入口检修台。"
	_overlay.show()


func _close() -> void:
	if _mode not in ["pause", "guide"]:
		return
	_overlay.hide()
	_mode = ""
	get_tree().paused = false


func _reload() -> void:
	_restart.disabled = true
	_reload_scene.call_deferred()


func _reload_scene() -> void:
	var tree := get_tree()
	tree.paused = false
	var error := tree.reload_current_scene()
	if error != OK:
		tree.paused = true
		_restart.disabled = false
		_body.text = "无法重开关卡 · " + error_string(error)


func _finish(won: bool) -> void:
	_open("victory" if won else "death")


func _show_feedback(message: String) -> void:
	_message.text = message
	_message_until = 5.0


func _change_prompt(message: String) -> void:
	_prompt_text = message
