extends Node
## Layout in uniformly scaled UI units. The 3D render size stays independent.

const MARGIN: float = 24.0
const COLUMN_WIDTH: float = 336.0
const COMPACT_WIDTH: float = 960.0
const TUTORIAL_WIDTH: float = 424.0
const TUTORIAL_HEIGHT: float = 100.0

@onready var _stats: Control = $"../HUD/Panel"
@onready var _items: PanelContainer = $"../HUD/ItemsPanel"
@onready var _cooldowns: HBoxContainer = $"../HUD/CooldownBar"
@onready var _boss_bar: PanelContainer = $"../BossHealthBar"
@onready var _tutorial_overlay: Control = get_node_or_null("../TutorialOverlay")
@onready var _tutorial_card: PanelContainer = get_node_or_null("../TutorialOverlay/Card")
@onready var _camera: Camera3D = $"../../DungeonTest/Camera3D"

var _layout_pending: bool = false


func _ready() -> void:
	get_viewport().size_changed.connect(_queue_layout)
	_items.minimum_size_changed.connect(_queue_layout)
	_cooldowns.minimum_size_changed.connect(_queue_layout)
	_boss_bar.minimum_size_changed.connect(_queue_layout)
	if is_instance_valid(_tutorial_card):
		_tutorial_card.minimum_size_changed.connect(_queue_layout)
		_tutorial_overlay.visibility_changed.connect(_queue_layout)
	_apply_layout()


func _queue_layout() -> void:
	if _layout_pending:
		return
	_layout_pending = true
	_apply_layout.call_deferred()


func _apply_layout() -> void:
	_layout_pending = false
	# 切关会先移出旧场景，已排队的布局回调可能仍然到达。
	if not is_inside_tree():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var compact := viewport_size.x < COMPACT_WIDTH
	var column_width := viewport_size.x - MARGIN * 2.0 if compact else COLUMN_WIDTH
	_place(_stats, Vector2.ONE * MARGIN, Vector2(column_width, 108.0))
	var item_height := maxf(162.0, _items.get_combined_minimum_size().y)
	_place(_items, Vector2(MARGIN, viewport_size.y - MARGIN - item_height), Vector2(column_width, item_height))
	var boss_width := column_width if compact else 520.0
	var boss_height := maxf(88.0, _boss_bar.get_combined_minimum_size().y)
	var boss_position := Vector2(maxf((viewport_size.x - boss_width) * 0.5, _stats.get_rect().end.x + MARGIN), MARGIN)
	if compact:
		boss_position = Vector2(MARGIN, _stats.get_rect().end.y + 16.0)
	_place(_boss_bar, boss_position, Vector2(boss_width, boss_height))
	var combat_row_end := _boss_bar.get_rect().end.y
	if is_instance_valid(_tutorial_card):
		var tutorial_height := maxf(TUTORIAL_HEIGHT, _tutorial_card.get_combined_minimum_size().y)
		if compact:
			# 教学和 Boss 战互斥，窄窗口可共用同一行而不盖住生命栏。
			_place(_tutorial_card, boss_position, Vector2(column_width, tutorial_height))
			if _tutorial_overlay.visible:
				combat_row_end = maxf(combat_row_end, _tutorial_card.get_rect().end.y)
		else:
			_place(_tutorial_card, Vector2(viewport_size.x - MARGIN - TUTORIAL_WIDTH, MARGIN), Vector2(TUTORIAL_WIDTH, tutorial_height))
	var cooldown_y := combat_row_end + 12.0 if compact else _stats.get_rect().end.y + 16.0
	var cooldown_height := maxf(82.0, _cooldowns.get_combined_minimum_size().y)
	_place(_cooldowns, Vector2(MARGIN, cooldown_y), Vector2(minf(COLUMN_WIDTH, column_width), cooldown_height))

	# Reserve actual HUD rectangles, including the stacked Boss bar in narrow
	# windows. Keep the same space before a battle begins to avoid camera jumps.
	var frame_start := Vector2(_stats.get_rect().end.x + MARGIN, _boss_bar.get_rect().end.y + MARGIN)
	var frame_end := viewport_size - Vector2.ONE * MARGIN
	if compact:
		frame_start.x = MARGIN
		frame_start.y = _cooldowns.get_rect().end.y + MARGIN
		frame_end.y = _items.position.y - MARGIN
	if is_instance_valid(_camera):
		_camera.set_safe_frame(Rect2(frame_start / viewport_size, (frame_end - frame_start) / viewport_size))


func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = at
	control.size = dimensions
