extends PanelContainer
## Only presentation changes: progression and combat remain owned by the map.
const PRESENTER = preload("res://scenes/ui/objective_presenter.gd")
const ACCENT := Color("867044")
const HEADER_COLOR := Color("ba9e66")
const HIGHLIGHT := Color("edce8b")
var world: Node3D
var _source_id := 0
var _task_id := ""
var _completed: Dictionary = {}
var _feedback_remaining := 0.0
var _feedback_text := ""

func _process(delta: float) -> void:
	if not is_instance_valid(world) or not world.is_node_ready(): return
	var status := PRESENTER.read(world)
	var initial := _source_id != world.get_instance_id()
	if initial:
		_source_id = world.get_instance_id()
		_completed.clear()
		_feedback_remaining = 0.0
	var newly_completed := false
	for id: String in status.completed:
		if not _completed.has(id):
			_completed[id] = true
			newly_completed = not initial
	if newly_completed:
		_feedback_text = "目标完成"
		_feedback_remaining = 1.6
	elif status.id != _task_id and not initial:
		_feedback_text = "任务更新"
		_feedback_remaining = 1.2
	_task_id = status.id
	%ObjectiveTask.text = status.title
	%ObjectiveDetail.text = status.progress
	%ObjectiveCategory.text = _feedback_text if _feedback_remaining > 0.0 else status.category
	var emphasis := minf(1.0,_feedback_remaining)
	%ObjectiveAccent.color = ACCENT.lerp(HIGHLIGHT,emphasis)
	%ObjectiveCategory.self_modulate = HEADER_COLOR.lerp(HIGHLIGHT,emphasis)
	# A hidden compact Boss objective retains its feedback until it becomes visible.
	if is_visible_in_tree(): _feedback_remaining = maxf(0.0,_feedback_remaining-delta)
