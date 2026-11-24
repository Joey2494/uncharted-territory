extends "res://scenes/ui/castle_quest.gd"
## Reuse the castle's rendering vocabulary; only map snapshots differ.
const CAMPAIGN = preload("res://scenes/ui/campaign_objective_presenter.gd")
var _flow: HFlowContainer
var _side_completed := {}
var _feedback_remaining := 0.0
var _feedback_text := ""

func _ready() -> void:
	super._ready()
	_flow = HFlowContainer.new()
	_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flow.add_theme_constant_override("h_separation",2)
	_flow.add_theme_constant_override("v_separation",0)
	%QuestMarks.hide()
	$Content.add_child(_flow)
	$Content.move_child(_flow,$Content.get_children().find(%HistoryHeader)+1)
	for mark in _marks: mark.reparent(_flow)
	%QuestHistory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	%ObjectiveResources.reparent(_history_body,false)
	%OptionalContext.reparent(_history_body,false)
	for row in _history_rows: _wrap_history(row)
	_apply_density()

func _bind_world() -> void:
	if not is_instance_valid(world) or _source_id == world.get_instance_id(): return
	_source_id = world.get_instance_id()
	_snapshot.clear()
	_completed.clear()
	_set_history_expanded(false)
	_side_completed.clear()
	_feedback_remaining = 0.0
	# Exit/result handling can pause the tree in the same physics frame.
	# Observe the already-written map state synchronously, as in level one.
	for event in ["exit_reached","exit_unlocked"]:
		if world.has_signal(event) and not world.is_connected(event,_on_source_changed):
			world.connect(event,_on_source_changed)
	refresh()

func _wrap_history(row: Control) -> void:
	var text: Label = row.get_child(1)
	text.clip_text = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _ensure_rows(count: int) -> void:
	while _marks.size() < count:
		var mark := HBoxContainer.new()
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var number := Label.new()
		number.hide()
		mark.add_child(number)
		mark.add_child(_marker())
		_flow.add_child(mark)
		_marks.append(mark)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation",4)
		row.add_child(_marker())
		var text := Label.new()
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_font_size_override("font_size",11)
		text.add_theme_color_override("font_color",COMPLETED_TEXT)
		row.add_child(text)
		%QuestHistory.add_child(row)
		_history_rows.append(row)
		_wrap_history(row)

func _process(delta: float) -> void:
	refresh()
	if is_visible_in_tree(): _feedback_remaining = maxf(0.0,_feedback_remaining-delta)
	var category: String = _snapshot.get("context",{}).get("category","当前任务")
	%ObjectiveCategory.text = _feedback_text if _feedback_remaining > 0 else category

func refresh() -> void:
	if not is_instance_valid(world) or not world.is_node_ready() or _flow == null: return
	var status := CAMPAIGN.read(world)
	if status == _snapshot: return
	var initial := _snapshot.is_empty()
	_snapshot = status
	_ensure_rows(status.tasks.size())
	%QuestChapter.text = status.chapter
	%QuestBadge.text = "已完成" if status.complete else "当前目标"
	%QuestCount.text = "已完成 %d/%d" % [status.completed.size(),status.tasks.size()]
	for i in status.tasks.size():
		var task: Dictionary = status.tasks[i]
		if task.done: _completed[task.id] = task.duplicate()
		var active: bool = i == status.current or (status.get("focus",{}).get("id","") == "wings" and task.id == "combat_F")
		_set_marker(_marks[i].get_child(1),task.done,active)
		_marks[i].tooltip_text = task.title + (" · 已完成" if task.done else " · 未完成")
		_history_rows[i].visible = _completed.has(task.id)
		if _completed.has(task.id):
			var past: Dictionary = _completed[task.id]
			_set_marker(_history_rows[i].get_child(0),true)
			_history_rows[i].get_child(1).text = "%s  %d/%d%s" % [past.title,past.count,past.total,"" if task.done else " · 当前需重做"]
	if status.complete:
		%QuestTask.text = "关卡目标已完成"
		%QuestDetail.text = status.ending
		%QuestTarget.text = "主线目标全部完成"
		%QuestQuantity.text = "%d/%d" % [status.completed.size(),status.tasks.size()]
		%QuestProgress.value = 100
	else:
		var task: Dictionary = status.get("focus",status.tasks[status.current])
		%QuestTask.text = task.title
		%QuestDetail.text = task.detail
		%QuestTarget.text = task.target
		%QuestQuantity.text = "%d/%d" % [task.count,task.total]
		%QuestProgress.value = float(task.count)*100.0/maxi(1,task.total)
	_set_marker(%ActiveMarker,status.complete,true)
	%QuestTask.add_theme_color_override("font_color",GOLD)
	%QuestQuantity.add_theme_color_override("font_color",GOLD)
	# Optional archive information never replaces or completes the main journal.
	var context: Dictionary = status.context
	var side_new := false
	for id: String in context.completed:
		if not _side_completed.has(id):
			_side_completed[id] = true
			side_new = not initial
	if side_new:
		_feedback_text = "步骤完成" if context.category == "支线任务" else "目标完成"
		_feedback_remaining = 1.6
	%ObjectiveTask.text = context.title
	%ObjectiveDetail.text = context.progress
	%ObjectiveResources.text = context.get("resource_summary","")
	%ObjectiveResources.visible = not %ObjectiveResources.text.is_empty()
	%OptionalContext.visible = context.category == "支线任务" if world.has_method("optional_count") else (not world.has_method("get_storage_state") and world.get_current_room_id() in [world.ARCHIVE,world.VAULT])
	_apply_density()

func _apply_density() -> void:
	super._apply_density()
	if _flow == null: return
	%QuestMarks.hide()
	_flow.hide()
	%QuestTarget.clip_text = false
	%QuestTarget.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
