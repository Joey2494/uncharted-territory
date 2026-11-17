extends Label3D
## Billboard bar. Ordinary: aggro or recent hit; elite: active encounter. Never draw through walls.
@export var hide_when_empty := true
@export var elite := false
var _source: WeakRef
var _bar: Control
var _current := 0
var _maximum := 1
var _recent := 0.0
static var _bars: Array[WeakRef] = []

class BarPaint extends Control:
	var ratio := 1.0
	var current := 0
	var maximum := 1
	var elite := false
	func _draw() -> void:
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color("111519")
		frame.border_color = Color("d9b66a") if elite else Color("bdc3c7")
		frame.set_border_width_all(1)
		frame.set_corner_radius_all(2)
		draw_style_box(frame, Rect2(Vector2(0, 12), Vector2(size.x, size.y - 12)))
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("ed3e38")
		fill.set_corner_radius_all(1)
		if ratio > 0: draw_style_box(fill, Rect2(Vector2(1, 13), Vector2((size.x - 2) * ratio, size.y - 14)))
		var value := get_hp_text()
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_string_outline(font, Vector2((size.x - width) * 0.5, 9), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 1, Color.BLACK)
		draw_string(font, Vector2((size.x - width) * 0.5, 9), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)

	func get_hp_text() -> String:
		return ("◆ " if elite else "") + "HP %d/%d" % [current, maximum]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	text = ""
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_bar = BarPaint.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.size = Vector2(84, 18) if elite else Vector2(72, 17)
	layer.add_child(_bar)
	_bars.append(weakref(self))
	update_hp(_current, _maximum)

func update_hp(current: int, maximum: int) -> void:
	if current < _current: _recent = 3.0
	_current = clampi(current, 0, maxi(0, maximum))
	_maximum = maximum
	var ratio := float(_current) / maxi(1, maximum)
	text = ""
	if is_instance_valid(_bar):
		_bar.ratio = ratio
		_bar.current = _current
		_bar.maximum = maxi(0, maximum)
		_bar.elite = elite
		_bar.size = Vector2(84, 18) if elite else Vector2(72, 17)
		_bar.queue_redraw()
	visible = _current > 0 and maximum > 0

func _process(delta: float) -> void:
	_recent = maxf(0, _recent - delta)
	var source = _source.get_ref() if _source != null else null
	if is_instance_valid(_bar): _bar.hide()
	if not is_instance_valid(source):
		hide()
		return
	var target = source.get("_target")
	var camera := get_viewport().get_camera_3d()
	visible = _current > 0 and source.can_process() and is_instance_valid(target) and not target.is_dead() and camera != null
	if not visible: return
	visible = (elite or source.get("_aggro") == true or _recent > 0) and not camera.is_position_behind(global_position)
	if visible:
		var ray := PhysicsRayQueryParameters3D.create(camera.global_position, global_position, 1)
		visible = get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
	if not visible: return
	var screen := get_viewport().get_visible_rect().size
	# Keep the full bar and HP readout above the anchor, leaving a clear pixel gap.
	var at := camera.unproject_position(global_position) - Vector2(_bar.size.x * 0.5, _bar.size.y + 14.0)
	if at.x < 0 or at.x + _bar.size.x > screen.x or at.y < 0 or at.y + _bar.size.y > screen.y:
		return
	# Resolve nearby overhead bars in stable instance order.
	for w in _bars:
		var other = w.get_ref()
		if not is_instance_valid(other) or other == self or other.get_instance_id() > get_instance_id(): continue
		if is_instance_valid(other._bar) and other._bar.visible:
			if Rect2(at, _bar.size).grow(2).intersects(other._bar.get_global_rect()):
				at.y = other._bar.position.y - _bar.size.y - 3
	_bar.position = at
	_bar.visible = at.y >= 0

func bind_health_source(source: Node, initial_hp: int, maximum: int) -> bool:
	unbind_health_source()
	if not is_instance_valid(source) or not source.has_signal("hp_changed"): return false
	_source = weakref(source)
	source.connect("hp_changed", update_hp)
	source.tree_exiting.connect(_on_source_exiting, CONNECT_ONE_SHOT)
	update_hp(initial_hp, maximum)
	return true

func unbind_health_source() -> void:
	var source = _source.get_ref() if _source != null else null
	if is_instance_valid(source):
		if source.is_connected("hp_changed", update_hp): source.disconnect("hp_changed", update_hp)
		if source.tree_exiting.is_connected(_on_source_exiting): source.tree_exiting.disconnect(_on_source_exiting)
	_source = null

func _on_source_exiting() -> void:
	unbind_health_source()
	hide()

func _exit_tree() -> void:
	unbind_health_source()
	_bars = _bars.filter(func(w: WeakRef) -> bool: return is_instance_valid(w.get_ref()) and w.get_ref() != self)
