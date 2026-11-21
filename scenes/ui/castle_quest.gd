extends PanelContainer
## First-level presentation; the real map remains the sole progression authority.
const PRESENTER = preload("res://scenes/ui/castle_objective_presenter.gd")
const GOLD := Color("f3ce78")
const MUTED := Color("9c9684")
const COMPLETED_TEXT := Color("c5b183")
var world: Node3D:
	set(value):
		world = value
		if is_node_ready(): _bind_world()
var _source_id := 0
var _snapshot := {}
var _compact := false
var _history_rows: Array[Control] = []
var _marks: Array[Control] = []
var _completed: Dictionary = {}
var _frame: StyleBoxFlat
var quest_map: CanvasLayer
var _history_expanded := false
var _history_scroll: ScrollContainer
var _history_body: VBoxContainer
var _empty_history: Label

func _ready() -> void:
	_frame = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	add_theme_stylebox_override("panel",_frame)
	for button in [%HistoryToggle,%MapButton]:
		button.custom_minimum_size.y = 24
		for state in ["normal","hover","pressed","disabled","focus"]:
			var style: StyleBox = button.get_theme_stylebox(state).duplicate()
			style.set_content_margin(SIDE_LEFT,6)
			style.set_content_margin(SIDE_RIGHT,6)
			style.set_content_margin(SIDE_TOP,3)
			style.set_content_margin(SIDE_BOTTOM,3)
			button.add_theme_stylebox_override(state,style)
	%HistoryToggle.toggled.connect(_set_history_expanded)
	for i in 6:
		var mark := HBoxContainer.new()
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_theme_constant_override("separation",1)
		var number := Label.new()
		number.text = str(i+1)
		number.hide()
		number.add_theme_font_size_override("font_size",10)
		number.add_theme_color_override("font_color",MUTED)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_child(number)
		mark.add_child(_marker())
		%QuestMarks.add_child(mark)
		_marks.append(mark)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation",4)
		row.add_child(_marker())
		var text := Label.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_font_size_override("font_size",11)
		text.add_theme_color_override("font_color",COMPLETED_TEXT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(text)
		row.hide()
		%QuestHistory.add_child(row)
		_history_rows.append(row)
	_history_scroll = ScrollContainer.new()
	_history_scroll.name = "HistoryScroll"
	_history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_history_scroll.follow_focus = true
	_history_scroll.hide()
	$Content.add_child(_history_scroll)
	_history_body = VBoxContainer.new()
	_history_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_history_scroll.add_child(_history_body)
	%QuestHistory.reparent(_history_body,false)
	_empty_history = Label.new()
	_empty_history.text = "暂无已完成的主线任务"
	_empty_history.add_theme_font_size_override("font_size",11)
	_empty_history.add_theme_color_override("font_color",MUTED)
	_empty_history.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_history_body.add_child(_empty_history)
	_history_body.minimum_size_changed.connect(_update_history_height)
	_bind_world()
	_apply_density()
	quest_map = preload("res://scenes/ui/quest_map.gd").new()
	quest_map.name = "QuestMap"
	quest_map.tracker = self
	add_child(quest_map)

func _marker() -> Label:
	var marker := Label.new()
	marker.custom_minimum_size = Vector2(14,14)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size",14)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_marker(marker,false)
	return marker

func _set_marker(marker: Label, done: bool, active: bool = false) -> void:
	marker.text = "✓" if done else "○"
	marker.add_theme_color_override("font_color",GOLD if done or active else MUTED)

func _bind_world() -> void:
	if not is_instance_valid(world): return
	if _source_id == world.get_instance_id(): return
	_source_id = world.get_instance_id()
	_snapshot.clear()
	_completed.clear()
	_set_history_expanded(false)
	for source in [world,world.get_node("RunePuzzle")]:
		for event in ["room_completed","exit_unlocked","exit_reached","solved","reward_claimed"]:
			if source.has_signal(event) and not source.is_connected(event,_on_source_changed):
				source.connect(event,_on_source_changed)
	refresh()

func _on_source_changed(_id: Variant = null) -> void:
	refresh()

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	if not is_instance_valid(world) or not world.is_node_ready(): return
	var status := PRESENTER.read(world)
	if status == _snapshot: return
	_snapshot = status
	for id: String in status.completed: _completed[id] = true
	%QuestBadge.text = "已完成" if status.complete else "当前目标"
	%QuestCount.text = "已完成 %d/%d" % [status.completed.size(),status.tasks.size()]
	%QuestHeader.add_theme_color_override("font_color",GOLD)
	for i in status.tasks.size():
		var task: Dictionary = status.tasks[i]
		_set_marker(_marks[i].get_child(1),task.done,i == status.current)
		_set_marker(_history_rows[i].get_child(0),task.done)
		_history_rows[i].visible = task.done
		_history_rows[i].get_child(1).text = "%s  %d/%d" % [task.title,task.count,task.total]
	if status.complete:
		%QuestTask.text = "关卡目标已完成"
		%QuestDetail.text = "已穿过出口，成功离开失落石堡"
		%QuestTarget.text = "主线目标全部完成"
		%QuestQuantity.text = "%d/%d" % [status.completed.size(),status.tasks.size()]
		%QuestProgress.value = 100.0
	else:
		var task: Dictionary = status.tasks[status.current]
		%QuestTask.text = task.title
		%QuestDetail.text = task.detail
		%QuestTarget.text = task.target
		%QuestQuantity.text = "%d/%d" % [task.count,task.total]
		%QuestProgress.value = float(task.count)*100.0/maxi(1,task.total)
	_set_marker(%ActiveMarker,status.complete,true)
	%QuestTask.add_theme_color_override("font_color",GOLD)
	%QuestQuantity.add_theme_color_override("font_color",GOLD)
	_apply_density()

func set_compact_mode(compact: bool) -> void:
	if _compact == compact: return
	_compact = compact
	_apply_density()

func get_preferred_width() -> float:
	return 280.0 if _compact else 288.0

func _set_history_expanded(expanded: bool) -> void:
	_history_expanded = expanded
	_apply_density()
	if _history_scroll != null: _history_scroll.scroll_vertical = 0

func _update_history_height() -> void:
	if _history_scroll == null or _history_body == null: return
	var limit := 112.0 if _compact else 132.0
	_history_scroll.custom_minimum_size.y = minf(limit,maxf(18.0,_history_body.get_combined_minimum_size().y))

func _apply_density() -> void:
	# Keep one current action, its route and its quantity. History is opt-in at every size.
	%QuestHistory.visible = not _completed.is_empty()
	%HistoryHeader.visible = _history_expanded
	%QuestMarks.hide()
	%QuestChapter.hide()
	$Content/ProgressRow.hide()
	%QuestProgress.hide()
	%HistoryToggle.text = "历史 %d %s" % [_completed.size(),"▴" if _history_expanded else "▾"]
	%HistoryToggle.set_pressed_no_signal(_history_expanded)
	%HistoryToggle.tooltip_text = "收起已完成任务记录" if _history_expanded else "展开已完成的主线任务记录"
	if _history_scroll != null:
		_history_scroll.visible = _history_expanded
		_empty_history.visible = _completed.is_empty()
		_update_history_height()
	%QuestTask.add_theme_font_size_override("font_size",16)
	%QuestQuantity.add_theme_font_size_override("font_size",14 if _compact else 16)
	%QuestDetail.show()
	%QuestDetail.add_theme_font_size_override("font_size",12)
	$Content.add_theme_constant_override("separation",3)
	_frame.content_margin_left = 10.0
	_frame.content_margin_right = 10.0
	_frame.content_margin_top = 7.0
	_frame.content_margin_bottom = 7.0
