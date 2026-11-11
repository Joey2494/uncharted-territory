extends Node
## Layout in uniformly scaled UI units. The 3D render size stays independent.

const MARGIN: float = 24.0
const COLUMN_WIDTH: float = 336.0
const COMPACT_WIDTH: float = 960.0
@export var camera_path: NodePath = NodePath("../../DungeonTest/Camera3D")
@export var compact_combat_layout := false

@onready var _stats: Control = $"../HUD/Panel"
@onready var _items: PanelContainer = $"../HUD/ItemsPanel"
@onready var _cooldowns: HBoxContainer = $"../HUD/CooldownBar"
@onready var _boss_bar: PanelContainer = $"../BossHealthBar"
@onready var _camera: Camera3D = get_node(camera_path)

var _layout_pending: bool = false


func _ready() -> void:
	get_viewport().size_changed.connect(_queue_layout)
	_items.minimum_size_changed.connect(_queue_layout)
	_cooldowns.minimum_size_changed.connect(_queue_layout)
	_boss_bar.minimum_size_changed.connect(_queue_layout)
	_apply_layout()


func _queue_layout() -> void:
	if _layout_pending:
		return
	_layout_pending = true
	_apply_layout.call_deferred()


func _apply_layout() -> void:
	_layout_pending = false
	# 切关会先移出旧场景，已排队的布局回调可能仍然到达。
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var compact := viewport_size.x < COMPACT_WIDTH
	if compact and compact_combat_layout:
		_apply_compact_combat(viewport_size)
		return
	for control in [_stats, _items, _cooldowns, _boss_bar]:
		control.scale = Vector2.ONE
	var column_width := viewport_size.x - MARGIN * 2.0 if compact else COLUMN_WIDTH
	_place(_stats, Vector2.ONE * MARGIN, Vector2(column_width - 164.0 if compact else column_width, 108.0))
	var item_height := maxf(162.0, _items.get_combined_minimum_size().y)
	_place(_items, Vector2(MARGIN, viewport_size.y - MARGIN - item_height), Vector2(column_width, item_height))
	var boss_width := column_width if compact else 520.0
	var boss_height := maxf(88.0, _boss_bar.get_combined_minimum_size().y)
	var boss_position := Vector2(maxf((viewport_size.x - boss_width) * 0.5, _stats.get_rect().end.x + MARGIN), MARGIN)
	if compact:
		boss_position = Vector2(MARGIN, _stats.get_rect().end.y + 16.0)
	else:
		boss_width = minf(boss_width, viewport_size.x - boss_position.x - MARGIN - 164.0)
	_place(_boss_bar, boss_position, Vector2(boss_width, boss_height))
	var cooldown_y := _boss_bar.get_rect().end.y + 12.0 if compact else _stats.get_rect().end.y + 16.0
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


func _apply_compact_combat(viewport_size: Vector2) -> void:
	var margin := 16.0
	_stats.scale = Vector2.ONE * 0.7
	_items.scale = Vector2.ONE * 0.7
	_cooldowns.scale = Vector2.ONE * 0.7
	_boss_bar.scale = Vector2.ONE * 0.8
	_place(_stats, Vector2(margin, margin), Vector2((viewport_size.x - margin * 2 - 164.0) / 0.7, 108))
	_place(_boss_bar, Vector2(margin, 104), Vector2((viewport_size.x - margin * 2) / 0.8, 88))
	var item_height := maxf(162.0, _items.get_combined_minimum_size().y)
	_place(_items, Vector2(margin, viewport_size.y - margin - item_height * 0.7), Vector2(COLUMN_WIDTH, item_height))
	_place(_cooldowns, Vector2(viewport_size.x - margin - COLUMN_WIDTH * 0.7, viewport_size.y - margin - 82 * 0.7), Vector2(COLUMN_WIDTH, 82))
	var top := 190.0
	var bottom := _items.position.y - 12.0
	_camera.set_safe_frame(Rect2(Vector2(margin, top) / viewport_size, Vector2(viewport_size.x - margin * 2, maxf(100, bottom - top)) / viewport_size))


func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = at
	control.size = dimensions
