extends Node
## Measure actual container minima; reserve one coherent camera-safe play area.

const MARGIN: float = 24.0
const GAP: float = 16.0
const WIDE_WIDTH: float = 1180.0
const COLUMN_WIDTH: float = 352.0
const MIN_SAFE_FRAME_SIZE := Vector2(0.25, 0.15)

@onready var _stats: Control = $"../HUD/Panel"
@onready var _resources: PanelContainer = $"../HUD/ResourcesPanel"
@onready var _feedback: PanelContainer = $"../HUD/FeedbackPanel"
@onready var _cooldowns: Control = $"../HUD/CooldownBar"
@onready var _hotbar: PanelContainer = $"../HUD/Hotbar"
@onready var _boss_bar: PanelContainer = $"../BossHealthBar"
@onready var _tutorial: PanelContainer = $"../HUD/%TutorialPrompt"
@onready var _objective: Control = get_node_or_null("../HUD/LevelObjective")
@onready var _shop_shortcut: Control = get_node_or_null("../../CommerceLayer/Shortcut")
@onready var _footer: Control = get_node_or_null("../RunOverlay/VersionFooter")
@export var camera_path: NodePath = NodePath("../../DungeonTest/Camera3D")
@export var compact_combat_layout: bool = false
@onready var _camera: Camera3D = get_node_or_null(camera_path)

var _layout_pending: bool = false


func _ready() -> void:
	get_viewport().size_changed.connect(_queue_layout)
	if is_instance_valid(_camera) and _camera.has_signal("framing_mode_changed"):
		_camera.connect("framing_mode_changed", _queue_layout)
	for control in [_stats, _resources, _feedback, _cooldowns, _hotbar, _boss_bar]:
		control.minimum_size_changed.connect(_queue_layout)
	_feedback.visibility_changed.connect(_queue_layout)
	_boss_bar.visibility_changed.connect(_queue_layout)
	if _objective != null:
		_objective.minimum_size_changed.connect(_queue_layout)
		_objective.resized.connect(_queue_layout)
	_tutorial.minimum_size_changed.connect(_queue_layout)
	_tutorial.visibility_changed.connect(_queue_layout)
	_tutorial.resized.connect(_on_tutorial_resized)
	_boss_bar.resized.connect(_queue_layout)
	for control in [_shop_shortcut, _footer]:
		if is_instance_valid(control):
			control.minimum_size_changed.connect(_queue_layout)
			control.visibility_changed.connect(_queue_layout)
			control.resized.connect(_queue_layout)
	_apply_layout()


func _queue_layout() -> void:
	if _layout_pending:
		return
	_layout_pending = true
	_apply_layout.call_deferred()


func _on_tutorial_resized() -> void:
	# Wrapping can change the height of either a stacked or a paired lesson row.
	_queue_layout()


func _apply_layout() -> void:
	_layout_pending = false
	if not is_inside_tree(): return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	if is_instance_valid(_camera) and (compact_combat_layout or _camera.has_method("is_puzzle_framed")):
		_apply_compact_combat_layout(viewport_size)
		return
	var wide := viewport_size.x >= WIDE_WIDTH
	var half_width := (viewport_size.x - MARGIN * 2.0 - GAP) * 0.5
	var left_width := COLUMN_WIDTH if wide else minf(COLUMN_WIDTH, half_width)
	var right_width := 256.0 if wide else left_width
	var stats_height := maxf(144.0, _stats.get_combined_minimum_size().y)
	_place(_stats, Vector2(MARGIN, MARGIN), Vector2(left_width, stats_height))
	var resource_height := maxf(114.0, _resources.get_combined_minimum_size().y)
	_place(_resources, Vector2(viewport_size.x - MARGIN - right_width, MARGIN), Vector2(right_width, resource_height))
	var bottom_edge := viewport_size.y - MARGIN
	if is_instance_valid(_footer) and _footer.is_visible_in_tree():
		var footer_size := _footer.get_combined_minimum_size()
		_place(_footer, Vector2(viewport_size.x - MARGIN - footer_size.x, viewport_size.y - 10.0 - footer_size.y), footer_size)
		# Reserve a footer strip so version text cannot sit inside skill or hotbar controls.
		bottom_edge = minf(bottom_edge, _footer.position.y - GAP)

	var feedback_height := _feedback.get_combined_minimum_size().y
	_place(_feedback, Vector2(MARGIN, bottom_edge - feedback_height), Vector2(left_width, feedback_height))
	_cooldowns.set_compact_mode(not wide or get_tree().root.size.x < 960 or get_tree().root.size.y < 600)
	var cooldown_height := _cooldowns.get_combined_minimum_size().y
	var cooldown_width := _cooldowns.get_combined_minimum_size().x
	_place(_cooldowns, Vector2(viewport_size.x - MARGIN - cooldown_width, bottom_edge - cooldown_height), Vector2(cooldown_width, cooldown_height))
	var hotbar_size := _hotbar.get_combined_minimum_size()
	_place(_hotbar, Vector2((viewport_size.x - hotbar_size.x) * 0.5, bottom_edge - hotbar_size.y), hotbar_size)
	# Keep the six slots at bottom center. Compact windows lift the existing
	# corner controls one row rather than overlapping or hiding them.
	if _hotbar.get_rect().grow(GAP).intersects(_cooldowns.get_rect()):
		_place(_cooldowns, Vector2(_cooldowns.position.x, _hotbar.position.y - GAP - cooldown_height), Vector2(cooldown_width, cooldown_height))
	if _feedback.visible and _hotbar.get_rect().grow(GAP).intersects(_feedback.get_rect()):
		_place(_feedback, Vector2(_feedback.position.x, _hotbar.position.y - GAP - feedback_height), Vector2(left_width, feedback_height))

	if _objective != null:
		# During compact Boss fights the encounter bar takes the objective's place.
		_objective.visible = wide or not _boss_bar.visible
		_place(_objective, Vector2(MARGIN, _stats.get_rect().end.y + GAP),
			Vector2(minf(288.0,left_width), _objective.get_combined_minimum_size().y))
	var obstacles: Array[Control] = [_stats, _resources, _shop_shortcut, _objective, _feedback, _cooldowns, _hotbar, _footer]
	var panel_width := minf(520.0, viewport_size.x - MARGIN * 2.0)
	var boss_minimum := _boss_bar.get_combined_minimum_size()
	var lesson_minimum := _tutorial.get_combined_minimum_size()
	if not wide and _tutorial.is_visible_in_tree() and _boss_bar.is_visible_in_tree() \
		and lesson_minimum.x + GAP + boss_minimum.x <= viewport_size.x - MARGIN * 2.0:
		# Share one row instead of consuming two full rows of the battle view.
		var row_top := maxf(_stats.get_rect().end.y, _resources.get_rect().end.y) + GAP
		for control in [_shop_shortcut]:
			if is_instance_valid(control) and control.is_visible_in_tree():
				row_top = maxf(row_top, control.get_global_rect().end.y + GAP)
		var lesson_width := minf(panel_width, viewport_size.x - MARGIN * 2.0 - GAP - boss_minimum.x)
		var row_left := (viewport_size.x - lesson_width - GAP - boss_minimum.x) * 0.5
		_place(_tutorial, Vector2(row_left,row_top), Vector2(lesson_width,maxf(128.0,lesson_minimum.y)))
		_place(_boss_bar, Vector2(row_left+lesson_width+GAP,row_top), Vector2(boss_minimum.x,maxf(88.0,boss_minimum.y)))
	else:
		_place_clear_panel(_tutorial, panel_width, 128.0, MARGIN, obstacles, viewport_size)
		if _tutorial.is_visible_in_tree(): obstacles.append(_tutorial)
		var boss_top := MARGIN
		if not wide:
			boss_top = maxf(_stats.get_rect().end.y, _resources.get_rect().end.y) + GAP
		if _tutorial.is_visible_in_tree(): boss_top = maxf(boss_top, _tutorial.get_rect().end.y + GAP)
		_place_clear_panel(_boss_bar, panel_width, 88.0, boss_top, obstacles, viewport_size)

	# Wide screens keep the established left-column composition; compact windows
	# use paired corner panels, leaving a central region clear for combat.
	var frame_start := Vector2(_stats.get_rect().end.x + MARGIN if wide else MARGIN,
		maxf(_boss_bar.get_rect().end.y, _resources.get_rect().end.y) + MARGIN)
	var frame_end := Vector2(viewport_size.x - MARGIN, minf(_cooldowns.position.y, _hotbar.position.y) - MARGIN)
	if not wide and _objective != null and _objective.visible:
		frame_start.y = maxf(frame_start.y, _objective.get_rect().end.y + MARGIN)
	if not wide and _feedback.visible:
		frame_end.y = minf(_feedback.position.y, _cooldowns.position.y) - MARGIN
	if is_instance_valid(_camera):
		var clear := _largest_clear_rect(viewport_size)
		if clear.has_area():
			_camera.set_safe_frame(Rect2(clear.position / viewport_size, clear.size / viewport_size))


## 紧凑战斗布局将控件放在画面边缘。区域切换不再隐藏操作栏，也不由临时消息决定镜头。
func _apply_compact_combat_layout(viewport: Vector2) -> void:
	var ui_scale := (0.72 if viewport.x < 900.0 else 0.8) if viewport.y < 900.0 else 1.0
	var margin := 16.0
	for control in [_stats, _resources, _feedback, _cooldowns, _hotbar, _boss_bar, _objective, _shop_shortcut]:
		if is_instance_valid(control): control.scale = Vector2.ONE * ui_scale
	_hotbar.show()
	_cooldowns.show()
	_cooldowns.set_compact_mode(true)
	_place(_stats, Vector2(margin,margin), Vector2(352,144))
	_place(_resources, Vector2(viewport.x-margin-256*ui_scale,margin), Vector2(256,114))
	if is_instance_valid(_shop_shortcut):
		_place(_shop_shortcut,Vector2(viewport.x-margin-64*ui_scale, margin+122*ui_scale),Vector2(64,64))
	var bottom := viewport.y-32.0
	if is_instance_valid(_footer):
		var footer_size := _footer.get_combined_minimum_size()
		_place(_footer, Vector2(viewport.x-margin-footer_size.x, viewport.y-10-footer_size.y), footer_size)
	var hotbar_size := _hotbar.get_combined_minimum_size()
	_place(_hotbar, Vector2((viewport.x-hotbar_size.x*ui_scale)*0.5,bottom-hotbar_size.y*ui_scale), hotbar_size)
	var skills := _cooldowns.get_combined_minimum_size()
	_place(_cooldowns,Vector2(viewport.x-margin-skills.x*ui_scale,bottom-skills.y*ui_scale),skills)
	var top := margin+144*ui_scale
	var middle_left := margin*2+352*ui_scale
	var middle_width := viewport.x-margin*4-(352+256)*ui_scale
	if _objective != null:
		_objective.visible = not _boss_bar.visible
		var objective_y := margin if middle_width >= 288*ui_scale else top+8
		var objective_x := middle_left+(middle_width-288*ui_scale)*0.5 if objective_y == margin else margin
		_place(_objective,Vector2(objective_x,objective_y),Vector2(288,_objective.get_combined_minimum_size().y))
		if _objective.visible: top = maxf(top,_objective.get_global_rect().end.y)
	var boss_width := minf(410.0,middle_width/ui_scale)
	var boss_y := margin
	if boss_width < _boss_bar.get_combined_minimum_size().x:
		boss_width = minf(410, (viewport.x-margin*2)/ui_scale)
		boss_y = margin+144*ui_scale+8
	var boss_x := middle_left+(middle_width-boss_width*ui_scale)*0.5 if boss_y == margin else (viewport.x-boss_width*ui_scale)*0.5
	_place(_boss_bar,Vector2(boss_x,boss_y),Vector2(boss_width,maxf(88,_boss_bar.get_combined_minimum_size().y)))
	if _boss_bar.visible or compact_combat_layout: top = maxf(top,_boss_bar.get_global_rect().end.y)
	if compact_combat_layout and _objective != null:
		top = maxf(top, _objective.get_global_rect().end.y)
	# 提示卡按内容收缩；始终保留同一条交互带，反馈消失不改变构图。
	var feedback_width := minf(420, (viewport.x-2*margin)/ui_scale)
	var feedback_height := _feedback.get_combined_minimum_size().y
	var feedback_bottom := bottom-hotbar_size.y*ui_scale-8
	_place(_feedback,Vector2(margin,feedback_bottom-feedback_height*ui_scale),Vector2(feedback_width,feedback_height))
	# 窄画幅下提示不压到右侧技能，长文本会在自身卡片中换行。
	if _feedback.get_global_rect().intersects(_cooldowns.get_global_rect()):
		_feedback.position.y = _cooldowns.get_global_rect().position.y-8-feedback_height*ui_scale
	var frame_bottom := minf(feedback_bottom-90*ui_scale-8, _cooldowns.get_global_rect().position.y-8)
	# 右上商城入口也属于遮挡区；固定预留其列，不因暂停时显隐而改变构图。
	_camera.set_safe_frame(_bounded_safe_frame(Vector2(margin,top+12),Vector2(viewport.x-margin-64*ui_scale-12,frame_bottom),viewport))


func _bounded_safe_frame(start: Vector2, end: Vector2, viewport_size: Vector2) -> Rect2:
	# Crowded/short windows may have no gap between the top and bottom HUD.
	# Clamp both edges and retain a useful minimum area instead of zooming into
	# a zero/negative-sized frame or a single-pixel fallback.
	var bounded_start := (start / viewport_size).clamp(Vector2.ZERO, Vector2.ONE - MIN_SAFE_FRAME_SIZE)
	var bounded_end := (end / viewport_size).clamp(bounded_start + MIN_SAFE_FRAME_SIZE, Vector2.ONE)
	return Rect2(bounded_start, bounded_end - bounded_start)


func _occupied_rects(viewport_size: Vector2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var bounds := Rect2(Vector2.ONE * MARGIN, viewport_size - Vector2.ONE * MARGIN * 2)
	for control in [_stats, _resources, _feedback, _cooldowns, _hotbar, _boss_bar, _tutorial, _objective, _shop_shortcut, _footer]:
		if is_instance_valid(control) and control.is_visible_in_tree():
			var rect: Rect2 = control.get_global_rect().grow(8).intersection(bounds)
			if rect.has_area():
				result.append(rect)
	return result


func _place_clear_panel(control: Control, preferred_width: float, minimum_height: float, top: float,
		obstacles: Array[Control], viewport_size: Vector2) -> void:
	var minimum := control.get_combined_minimum_size()
	var height := maxf(minimum_height, minimum.y)
	var rows: Array[float] = [top]
	var occupied: Array[Rect2] = []
	for obstacle in obstacles:
		if not is_instance_valid(obstacle) or not obstacle.is_visible_in_tree(): continue
		var rect := obstacle.get_global_rect().grow(GAP)
		occupied.append(rect)
		if rect.end.y > top and not rows.has(rect.end.y): rows.append(rect.end.y)
	rows.sort()
	# Keep the normal width when a clear row exists. Only narrow a panel when
	# a crowded square viewport needs it beside the lower skill controls.
	for allow_narrow in [false, true]:
		for y in rows:
			if y + height > viewport_size.y - MARGIN: continue
			var blocks: Array[Vector2] = []
			for rect in occupied:
				if rect.position.y < y + height and rect.end.y > y:
					blocks.append(Vector2(rect.position.x, rect.end.x))
			blocks.append(Vector2(viewport_size.x - MARGIN, viewport_size.x - MARGIN))
			blocks.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
			var cursor := MARGIN
			for block in blocks:
				var end := minf(block.x, viewport_size.x - MARGIN)
				var width := minf(preferred_width, end - cursor) if allow_narrow else preferred_width
				if width >= minimum.x and end - cursor >= width:
					var x := clampf((viewport_size.x - width) * 0.5, cursor, end - width)
					_place(control, Vector2(x,y), Vector2(width,height))
					return
				cursor = maxf(cursor, block.y)
	# Retain a bounded placement if future content exceeds the available space.
	_place(control, Vector2((viewport_size.x - preferred_width) * 0.5, clampf(top, MARGIN, maxf(MARGIN,viewport_size.y-MARGIN-height))), Vector2(preferred_width,height))


func _largest_clear_rect(viewport_size: Vector2) -> Rect2:
	# Search horizontal bands bounded by the actual HUD edges, then find the
	# widest unoccupied interval in each. Never enlarge a frame into a HUD panel.
	var obstacles := _occupied_rects(viewport_size)
	var ys: Array[float] = [MARGIN, viewport_size.y - MARGIN]
	for rect in obstacles:
		if not ys.has(rect.position.y):
			ys.append(rect.position.y)
		if not ys.has(rect.end.y):
			ys.append(rect.end.y)
	ys.sort()
	var best := Rect2()
	var best_area := 0.0
	for low in range(ys.size() - 1):
		for high in range(low + 1, ys.size()):
			var intervals: Array[Vector2] = []
			for rect in obstacles:
				if rect.position.y < ys[high] and rect.end.y > ys[low]:
					intervals.append(Vector2(rect.position.x, rect.end.x))
			intervals.append(Vector2(viewport_size.x - MARGIN, viewport_size.x - MARGIN))
			intervals.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
			var cursor := MARGIN
			for interval in intervals:
				var area: float = maxf(0, interval.x - cursor) * (ys[high] - ys[low])
				if area > best_area:
					best = Rect2(cursor, ys[low], interval.x - cursor, ys[high] - ys[low])
					best_area = area
				cursor = maxf(cursor, interval.y)
	return best


func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = at
	control.size = dimensions
