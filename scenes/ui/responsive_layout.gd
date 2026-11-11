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
@onready var _cooldowns: HBoxContainer = $"../HUD/CooldownBar"
@onready var _hotbar: PanelContainer = $"../HUD/Hotbar"
@onready var _boss_bar: PanelContainer = $"../BossHealthBar"
@onready var _tutorial: PanelContainer = $"../HUD/%TutorialPrompt"
@onready var _objective: Control = get_node_or_null("../HUD/LevelObjective")
@export var camera_path: NodePath = NodePath("../../DungeonTest/Camera3D")
@export var compact_combat_layout: bool = false
@onready var _camera: Camera3D = get_node_or_null(camera_path)

var _layout_pending: bool = false


func _ready() -> void:
	get_viewport().size_changed.connect(_queue_layout)
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
	_apply_layout()


func _queue_layout() -> void:
	if _layout_pending:
		return
	_layout_pending = true
	_apply_layout.call_deferred()


func _on_tutorial_resized() -> void:
	# Containers can grow after placement when tutorial text wraps. Keep the
	# Boss below the actual panel immediately, before the deferred layout pass.
	if _tutorial.visible:
		_boss_bar.position.y = maxf(_boss_bar.position.y, _tutorial.get_rect().end.y + 12.0)
	_queue_layout()


func _apply_layout() -> void:
	_layout_pending = false
	if not is_inside_tree(): return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var wide := viewport_size.x >= WIDE_WIDTH
	var half_width := (viewport_size.x - MARGIN * 2.0 - GAP) * 0.5
	var left_width := COLUMN_WIDTH if wide else minf(COLUMN_WIDTH, half_width)
	var right_width := 256.0 if wide else left_width
	var stats_height := maxf(144.0, _stats.get_combined_minimum_size().y)
	_place(_stats, Vector2(MARGIN, MARGIN), Vector2(left_width, stats_height))
	var resource_height := maxf(114.0, _resources.get_combined_minimum_size().y)
	_place(_resources, Vector2(viewport_size.x - MARGIN - right_width, MARGIN), Vector2(right_width, resource_height))

	var feedback_height := _feedback.get_combined_minimum_size().y
	_place(_feedback, Vector2(MARGIN, viewport_size.y - MARGIN - feedback_height), Vector2(left_width, feedback_height))
	var cooldown_height := maxf(86.0, _cooldowns.get_combined_minimum_size().y)
	var cooldown_width := COLUMN_WIDTH if wide else left_width
	cooldown_width = minf(viewport_size.x - MARGIN * 2.0, maxf(cooldown_width, _cooldowns.get_combined_minimum_size().x))
	_place(_cooldowns, Vector2(viewport_size.x - MARGIN - cooldown_width, viewport_size.y - MARGIN - cooldown_height), Vector2(cooldown_width, cooldown_height))
	var hotbar_size := _hotbar.get_combined_minimum_size()
	_place(_hotbar, Vector2((viewport_size.x - hotbar_size.x) * 0.5, viewport_size.y - MARGIN - hotbar_size.y), hotbar_size)
	# Keep the six slots at bottom center. Compact windows lift the existing
	# corner controls one row rather than overlapping or hiding them.
	if _hotbar.get_rect().grow(GAP).intersects(_cooldowns.get_rect()):
		_place(_cooldowns, Vector2(_cooldowns.position.x, _hotbar.position.y - GAP - cooldown_height), Vector2(cooldown_width, cooldown_height))
	if _feedback.visible and _hotbar.get_rect().grow(GAP).intersects(_feedback.get_rect()):
		_place(_feedback, Vector2(_feedback.position.x, _hotbar.position.y - GAP - feedback_height), Vector2(left_width, feedback_height))

	var boss_width := minf(520.0, viewport_size.x - MARGIN * 2.0)
	var prompt_width := minf(520.0, viewport_size.x - MARGIN * 2.0)
	var prompt_position := Vector2((viewport_size.x - prompt_width) * 0.5, MARGIN)
	var prompt_height := maxf(128.0, _tutorial.get_combined_minimum_size().y)
	# Compact screens place the centered lesson just below the corner HUD panels.
	if prompt_position.x < _stats.get_rect().end.x + 4.0 or prompt_position.x + prompt_width > _resources.position.x - 4.0:
		prompt_position.y = maxf(_stats.get_rect().end.y, _resources.get_rect().end.y) + 12.0
	_place(_tutorial, prompt_position, Vector2(prompt_width, prompt_height))
	var boss_height := maxf(88.0, _boss_bar.get_combined_minimum_size().y)
	var boss_position := Vector2((viewport_size.x - boss_width) * 0.5, MARGIN)
	if not wide:
		boss_position.y = maxf(_stats.get_rect().end.y, _resources.get_rect().end.y) + 12.0
		if _objective != null:
			boss_position.y = maxf(boss_position.y, 244.0)
	if _tutorial.visible:
		boss_position.y = maxf(boss_position.y, _tutorial.get_rect().end.y + 12.0)
	_place(_boss_bar, boss_position, Vector2(boss_width, boss_height))
	if _objective != null:
		# During compact Boss fights the encounter bar takes the objective's place.
		_objective.visible = wide or not _boss_bar.visible
		_place(_objective, Vector2(MARGIN, maxf(244.0, _stats.get_rect().end.y + 76.0)),
			Vector2(left_width, _objective.get_combined_minimum_size().y))

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
		_camera.set_safe_frame(Rect2(0.10, 0.18, 0.80, 0.58) if compact_combat_layout else _bounded_safe_frame(frame_start, frame_end, viewport_size))


func _bounded_safe_frame(start: Vector2, end: Vector2, viewport_size: Vector2) -> Rect2:
	# Crowded/short windows may have no gap between the top and bottom HUD.
	# Clamp both edges and retain a useful minimum area instead of zooming into
	# a zero/negative-sized frame or a single-pixel fallback.
	var bounded_start := (start / viewport_size).clamp(Vector2.ZERO, Vector2.ONE - MIN_SAFE_FRAME_SIZE)
	var bounded_end := (end / viewport_size).clamp(bounded_start + MIN_SAFE_FRAME_SIZE, Vector2.ONE)
	return Rect2(bounded_start, bounded_end - bounded_start)


func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = at
	control.size = dimensions
