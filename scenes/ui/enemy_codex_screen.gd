extends Control
signal back_requested
signal next_discovery_requested
signal retry_save_requested
const Catalog = preload("res://data/enemy_codex.gd")
const Preview = preload("res://scenes/ui/enemy_codex_preview.gd")
const Stat = preload("res://scenes/ui/character_stat.tscn")
const FONT = preload("res://scenes/ui/dungeon_font.tres")
const STONE = preload("res://scenes/ui/stone_material.tres")
var known: Array[String] = []
var selected_id := ""
var encounter_mode := false
var level_filter := 0
var _queue_remaining := 0
var _snapshots: Dictionary = {}
var _list: VBoxContainer
var _list_scroll: ScrollContainer
var _info: PanelContainer
var _preview: SubViewportContainer
var _viewport: SubViewport
var stage: Node3D
var _title: Label
var _status: Label
var _progress: Label
var _name: Label
var _role: Label
var _lore: Label
var _skills: Label
var _tips: Label
var _info_scroll: ScrollContainer
var _meters: Array[Control] = []
var _filter_row: HBoxContainer
var _next: Button
var _back: Button
var _retry: Button
var _dragging := false
var _rows: Dictionary = {}

func _ready() -> void:
	theme = preload("res://scenes/ui/menu_theme.tres")
	var background := ColorRect.new()
	background.color = Color("080b10")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_title = _label(self, "敌人图鉴", 34, Color("e8d5ad"))
	_progress = _label(self, "", 14, Color("b89c62"))
	_filter_row = HBoxContainer.new()
	_filter_row.add_theme_constant_override("separation", 8)
	add_child(_filter_row)
	for i in 5:
		var button := _button(_filter_row, "全部" if i == 0 else "第%d关" % i)
		button.pressed.connect(_filter.bind(i))
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.follow_focus = true
	add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_list_scroll.add_child(_list)
	_info = PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("11171d")
	frame.border_color = Color("685b40")
	frame.set_border_width_all(1)
	frame.content_margin_left = 18
	frame.content_margin_right = 18
	frame.content_margin_top = 18
	frame.content_margin_bottom = 18
	_info.add_theme_stylebox_override("panel", frame)
	add_child(_info)
	var stone := ColorRect.new()
	stone.material = STONE
	stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(stone)
	_info_scroll = ScrollContainer.new()
	_info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info.add_child(_info_scroll)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 12)
	_info_scroll.add_child(text)
	_name = _label(text, "", 28, Color("e8d5ad"))
	_role = _label(text, "", 14, Color("baa278"))
	var meters := GridContainer.new()
	meters.columns = 3
	meters.add_theme_constant_override("h_separation", 8)
	text.add_child(meters)
	for spec in [["生命", "heart"], ["伤害", "weapon_equipped"], ["移速", "dodge"]]:
		var meter := Stat.instantiate()
		meter.attribute_label = spec[0]
		meter.icon = load("res://assets/ui/" + spec[1] + ".svg")
		meter.custom_minimum_size = Vector2(76, 86)
		meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if spec[0] == "移速": meter.precision = 1
		meters.add_child(meter)
		_meters.append(meter)
	_lore = _label(text, "", 16, Color("c5c4b8"))
	_label(text, "招式记录", 17, Color("d4b575"))
	_skills = _label(text, "", 16, Color("c5c4b8"))
	_label(text, "应对要点", 17, Color("d4b575"))
	_tips = _label(text, "", 16, Color("c5c4b8"))
	_preview = SubViewportContainer.new()
	_preview.stretch = true
	_preview.gui_input.connect(_preview_input)
	add_child(_preview)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.size = Vector2i(500, 450)
	_viewport.msaa_3d = Viewport.MSAA_2X
	_preview.add_child(_viewport)
	stage = Preview.new()
	_viewport.add_child(stage)
	_back = _button(self, "返回")
	_back.pressed.connect(func() -> void: back_requested.emit())
	_next = _button(self, "继续战斗")
	_next.pressed.connect(func() -> void: next_discovery_requested.emit())
	_retry = _button(self, "重试保存")
	_retry.pressed.connect(func() -> void: retry_save_requested.emit())
	_status = _label(self, "", 13, Color("999e9d"))
	resized.connect(_layout)
	visibility_changed.connect(_update_preview)
	_layout()
	_update_preview()
	hide()

func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(button)
	return button

func present(discoveries: Array[String], id: String, fresh: bool, remaining: int, unsaved: bool, snapshots: Dictionary) -> void:
	known = discoveries.duplicate()
	encounter_mode = fresh
	_queue_remaining = remaining
	_snapshots = snapshots
	level_filter = 0
	_title.text = "新敌人已解锁" if fresh else "敌人图鉴"
	_progress.text = "已收录 %02d / %02d   ·   首次遭遇自动记录" % [known.size(), Catalog.IDS.size()]
	_filter_row.visible = not fresh
	_next.visible = fresh
	_next.text = "下一位 · 还有%d种" % remaining if remaining > 0 else "继续战斗"
	_back.text = "稍后查阅 · 继续战斗" if fresh else "返回"
	_retry.visible = unsaved
	_status.text = "存档失败，图鉴已暂存本次会话。" if unsaved else "拖动旋转 · 滚轮缩放 · Esc 返回 · B 图鉴"
	show()
	_rebuild_list()
	select_enemy(id if id in Catalog.IDS else (known[0] if not known.is_empty() else Catalog.IDS[0]))
	(_next if fresh else _back).grab_focus.call_deferred()
	_layout()

func _filter(level: int) -> void:
	level_filter = level
	_rebuild_list()
	for id in Catalog.IDS:
		if level == 0 or int(Catalog.ENTRIES[id].level) == level:
			select_enemy(id)
			break

func _rebuild_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	for id in Catalog.IDS:
		var data: Dictionary = Catalog.ENTRIES[id]
		if level_filter != 0 and data.level != level_filter: continue
		if encounter_mode and id not in known: continue
		var button := _button(_list, "%s\n第%d关 · %s" % [data.name if id in known else "未遭遇", data.level, "已解锁" if id in known else "待探索"])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 60
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(select_enemy.bind(id))
		_rows[id] = button

func select_enemy(id: String) -> void:
	if id not in Catalog.IDS: return
	selected_id = id
	var unlocked := id in known
	var data := Catalog.entry(id)
	_name.text = data.name if unlocked else "未遭遇的敌人"
	_role.text = "第%d关  /  %s" % [data.level, data.role] if unlocked else "第%d关 · 首次遇见后解锁" % data.level
	_lore.text = data.lore if unlocked else "继续探索新的房间，遇见它后即可查看模型与完整记录。"
	_skills.text = data.skills if unlocked else "尚无招式记录。"
	_tips.text = data.tips if unlocked else "尚无战斗记录。"
	var numbers: Dictionary = _snapshots.get(id, data.stats)
	for index in 3:
		_meters[index].visible = unlocked and (index != 0 or id != "broodling")
		if unlocked: _meters[index].set_stat(float(numbers[["hp", "damage", "speed"][index]]), [60.0, 5.0, 10.0][index], 0.0)
	for key in _rows:
		_rows[key].modulate = Color("ffdf94") if key == id else Color.WHITE
	_scroll_to_selected.call_deferred()
	_info_scroll.scroll_vertical = 0
	stage.show_enemy(id, unlocked)

func _scroll_to_selected() -> void:
	# The list can be rebuilt twice before a deferred layout runs (next entry,
	# filter, or save retry). Resolve the current row instead of retaining an old one.
	var row: Control = _rows.get(selected_id)
	if is_instance_valid(row) and _list_scroll.is_ancestor_of(row):
		_list_scroll.ensure_control_visible(row)

func _update_preview() -> void:
	if not is_node_ready(): return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	stage.process_mode = Node.PROCESS_MODE_ALWAYS if visible else Node.PROCESS_MODE_DISABLED

func _layout() -> void:
	if not is_node_ready(): return
	var narrow := size.x < 1000
	var margin := 24.0 if narrow else 36.0
	_place(_title, Vector2(margin, 24), Vector2(size.x - margin * 2, 44))
	_place(_progress, Vector2(margin, 74), Vector2(size.x - margin * 2, 24))
	_place(_filter_row, Vector2(margin, 106), Vector2(size.x - margin * 2, 36))
	var top := 112.0 if encounter_mode else 152.0
	var bottom := size.y - 92.0
	var list_width := 170.0 if narrow else 210.0
	_place(_list_scroll, Vector2(margin, top), Vector2(list_width, bottom - top))
	var left := margin + list_width + 16
	if narrow:
		var preview_height := minf(300, (bottom - top) * 0.44)
		_place(_preview, Vector2(left, top), Vector2(size.x - left - margin, preview_height))
		_place(_info, Vector2(left, top + preview_height + 10), Vector2(size.x - left - margin, bottom - top - preview_height - 10))
	else:
		var width := clampf(size.x * 0.31, 340, 430)
		_place(_info, Vector2(left, top), Vector2(width, bottom - top))
		_place(_preview, Vector2(left + width + 16, top), Vector2(size.x - left - width - margin - 16, bottom - top))
	_place(_back, Vector2(margin, size.y - 70), Vector2(210 if encounter_mode else 160, 42))
	_place(_next, Vector2(size.x - margin - 210, size.y - 70), Vector2(210, 42))
	_place(_retry, Vector2(size.x * 0.5 - 60, size.y - 70), Vector2(120, 42))
	_place(_status, Vector2(margin, size.y - 24), Vector2(size.x - margin * 2, 20))

func _place(control: Control, point: Vector2, dimensions: Vector2) -> void:
	control.position = point
	control.size = dimensions

func _preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: _dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: stage.zoom_model(0.9)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: stage.zoom_model(1.1)
	elif event is InputEventMouseMotion and _dragging: stage.rotate_model(event.relative.x * 0.012)

func _input(event: InputEvent) -> void:
	if not visible or event.is_echo(): return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and (event.physical_keycode if event.physical_keycode != 0 else event.keycode) == KEY_B):
		get_viewport().set_input_as_handled()
		back_requested.emit()
