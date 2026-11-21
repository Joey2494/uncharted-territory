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
	for control in [_stats, _resources, _cooldowns, _hotbar, _boss_bar]:
		control.minimum_size_changed.connect(_queue_layout)
	_boss_bar.visibility_changed.connect(_queue_layout)
	if _objective != null:
		_objective.minimum_size_changed.connect(_queue_layout)
		_objective.resized.connect(_queue_layout)
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
	if is_instance_valid(_camera) and _camera.has_method("is_puzzle_framed"):
		_apply_level02_layout(viewport_size)
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

	if _objective != null:
		# During compact Boss fights the encounter bar takes the objective's place.
		if _objective.has_method("set_compact_mode"):
			# Castle objectives keep their current action and permanent gold checkmarks in combat.
			_objective.set_compact_mode(not wide or _boss_bar.visible)
			_objective.show()
		else:
			_objective.visible = wide or not _boss_bar.visible
		_place(_objective, Vector2(MARGIN, _stats.get_rect().end.y + GAP),
			Vector2(minf(_objective.get_preferred_width() if _objective.has_method("get_preferred_width") else 288.0,left_width), _objective.get_combined_minimum_size().y))
	var obstacles: Array[Control] = [_stats, _resources, _shop_shortcut, _objective, _cooldowns, _hotbar, _footer]
	var panel_width := minf(520.0, viewport_size.x - MARGIN * 2.0)
	var boss_minimum := _boss_bar.get_combined_minimum_size()
	var castle_side := not wide and _objective != null and _objective.has_method("set_compact_mode") and _boss_bar.is_visible_in_tree()
	var side_left: float = _objective.get_rect().end.x+GAP if castle_side else 0.0
	var side_width := viewport_size.x-MARGIN-side_left
	if castle_side and side_width >= boss_minimum.x:
		var side_top := _resources.get_rect().end.y+GAP
		if is_instance_valid(_shop_shortcut): side_top = maxf(side_top,_shop_shortcut.get_global_rect().end.y+GAP)
		_place(_boss_bar,Vector2(side_left,side_top),Vector2(side_width,maxf(88.0,boss_minimum.y)))
	else:
		_place_clear_panel(_boss_bar,panel_width,88.0,MARGIN if wide else _resources.get_rect().end.y+GAP,obstacles,viewport_size)
	_refresh_hint_dock()

	# Wide screens keep the established left-column composition; compact windows
	# use paired corner panels, leaving a central region clear for combat.
	var frame_start := Vector2(_stats.get_rect().end.x + MARGIN if wide else MARGIN,
		maxf(_boss_bar.get_rect().end.y, _resources.get_rect().end.y) + MARGIN)
	var frame_end := Vector2(viewport_size.x - MARGIN, minf(_cooldowns.position.y, _hotbar.position.y) - MARGIN)
	if not wide and _objective != null and _objective.visible:
		frame_start.y = maxf(frame_start.y, _objective.get_rect().end.y + MARGIN)
	if is_instance_valid(_camera):
		var clear := _largest_clear_rect(viewport_size)
		if clear.has_area():
			_camera.set_safe_frame(Rect2(clear.position / viewport_size, clear.size / viewport_size))


## 二关统一使用紧凑边缘HUD。区域切换不再隐藏操作栏，也不由临时消息决定镜头。
func _apply_level02_layout(viewport: Vector2) -> void:
	var ui_scale := (0.72 if viewport.x < 900.0 else 0.8) if viewport.y < 900.0 else 1.0
	var margin := 16.0
	for control in [_stats, _resources, _cooldowns, _hotbar, _boss_bar, _objective, _shop_shortcut]:
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
		_objective.show()
		_objective.set_compact_mode(viewport.x < WIDE_WIDTH or get_tree().root.size.x < 960 or _boss_bar.visible)
		_place(_objective,Vector2(margin,top+12),Vector2(_objective.get_preferred_width() if _objective.has_method("get_preferred_width") else 320.0,_objective.get_combined_minimum_size().y))
		if _objective.visible: top = maxf(top,_objective.get_global_rect().end.y)
	var boss_width := minf(410.0,middle_width/ui_scale)
	var boss_y := margin
	if boss_width < _boss_bar.get_combined_minimum_size().x:
		boss_width = minf(410, (viewport.x-margin*2)/ui_scale)
		boss_y = margin+144*ui_scale+8
		if _objective != null: boss_y = maxf(boss_y,_objective.get_global_rect().end.y+12)
	var boss_x := middle_left+(middle_width-boss_width*ui_scale)*0.5 if boss_y == margin else (viewport.x-boss_width*ui_scale)*0.5
	_place(_boss_bar,Vector2(boss_x,boss_y),Vector2(boss_width,maxf(88,_boss_bar.get_combined_minimum_size().y)))
	if _boss_bar.visible: top = maxf(top,_boss_bar.get_global_rect().end.y)
	_refresh_hint_dock()
	var frame_bottom := minf(_hotbar.get_global_rect().position.y-12,_cooldowns.get_global_rect().position.y-12)
	var dock: Node = _feedback.get_parent().hint_dock
	var frame_left: float = dock.reserved_rect.end.x+12 if dock.reserved_rect.has_area() else margin
	var frame_right: float = viewport.x-margin-64*ui_scale-12
	_camera.set_safe_frame(_bounded_safe_frame(Vector2(frame_left,top+12),Vector2(frame_right,frame_bottom),viewport))

func _refresh_hint_dock() -> void:
	var dock: Node = _feedback.get_parent().hint_dock
	if is_instance_valid(dock): dock.refresh_layout()



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
	for control in [_stats, _resources, _cooldowns, _hotbar, _boss_bar, _objective, _shop_shortcut, _footer]:
		if is_instance_valid(control) and control.is_visible_in_tree():
			var rect: Rect2 = control.get_global_rect().grow(8).intersection(bounds)
			if rect.has_area():
				result.append(rect)
	var dock: Node = _feedback.get_parent().hint_dock
	if is_instance_valid(dock) and dock.reserved_rect.has_area(): result.append(dock.reserved_rect.grow(8).intersection(bounds))
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
