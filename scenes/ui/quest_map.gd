extends CanvasLayer
## Owns only its own pause. Existing menu, combat and transition permissions apply.
const DATA = preload("res://scenes/ui/quest_map_data.gd")
const VIEW = preload("res://scenes/ui/quest_map_view.gd")
var tracker: Control
var host: Node
var root: Control
var card: PanelContainer
var content: VBoxContainer
var title: Label
var location: Label
var objective: Label
var legend: Label
var note: Label
var close_button: Button
var view: Control
var _owns_pause := false
var _prior_focus: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 45
	host = tracker.get_node("../../..")
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = tracker.theme
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.008,0.012,0.009,0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171b14")
	style.border_color = Color("9b8150")
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel",style)
	root.add_child(card)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation",8)
	card.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	title = _label(header,"关卡地图",22,Color("f3ce78"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = Button.new()
	close_button.text = "返回游戏 · Esc"
	close_button.add_theme_font_size_override("font_size",14)
	close_button.pressed.connect(close_map)
	header.add_child(close_button)
	location = _label(content,"",14,Color("73d5ec"))
	objective = _label(content,"",15,Color("f3ce78"))
	view = VIEW.new()
	view.mouse_filter = Control.MOUSE_FILTER_PASS
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(view)
	legend = _label(content,"● 你的位置    ◇ 主线目标    青色：可选路线    × 当前封锁",12,Color("c2c4af"))
	note = _label(content,"浅色房间已到达；暗色区域可探索。地图仅标记通路现状，机关线索请观察现场石刻与装置。",12,Color("a7a68e"))
	root.hide()
	tracker.get_node("%MapButton").pressed.connect(open_map)
	# Last sibling receives modal input before commerce and the host's Esc handler.
	reparent.call_deferred(host)

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func _process(_delta: float) -> void:
	var button: Button = tracker.get_node("%MapButton")
	button.disabled = not _can_open()
	if not root.visible: return
	if host.get_run_state() != host.RunState.PAUSED:
		root.hide()
		_owns_pause = false
		return
	_refresh()

func _can_open() -> bool:
	if not is_instance_valid(host) or not is_instance_valid(tracker.world) or host._transition_queued: return false
	return host.get_run_state() == host.RunState.PLAYING and not get_tree().paused and host._commerce.view == host._commerce.View.NONE

func open_map() -> bool:
	if root.visible or not _can_open(): return false
	_prior_focus = get_viewport().gui_get_focus_owner()
	if not host.set_paused(true): return false
	_owns_pause = true
	host._commerce.pause_menu.hide()
	tracker.refresh()
	root.show()
	_refresh()
	close_button.grab_focus()
	return true

func close_map() -> void:
	if not root.visible: return
	root.hide()
	var resume: bool = _owns_pause and host.get_run_state() == host.RunState.PAUSED and host._commerce.view == host._commerce.View.NONE
	_owns_pause = false
	if resume: host.set_paused(false)
	if is_instance_valid(_prior_focus) and _prior_focus.is_visible_in_tree(): _prior_focus.grab_focus()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if root.visible:
		if key in [KEY_M,KEY_ESCAPE]: close_map()
		# Modal map consumes action/shop keys, retaining the close button's Enter.
		if key != KEY_ENTER: get_viewport().set_input_as_handled()
	elif key == KEY_M and open_map(): get_viewport().set_input_as_handled()

func _refresh() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var factor := clampf(viewport.x/maxf(1,get_tree().root.size.x),1,2)
	var dimensions := Vector2(minf(1100,viewport.x-32),viewport.y-40)
	card.position = (viewport-dimensions)*0.5
	card.size = dimensions
	for pair in [[title,22],[location,14],[objective,15],[legend,12],[note,12],[close_button,14]]:
		var font_size := roundi(pair[1]*factor)
		if pair[0].get_theme_font_size("font_size") != font_size: pair[0].add_theme_font_size_override("font_size",font_size)
	view.custom_minimum_size = Vector2(0,maxf(100,dimensions.y-270*factor))
	view.text_scale = factor
	view.snapshot = DATA.read(tracker.world,tracker._snapshot,host.level_id)
	if host.level_id == 4:
		note.text = "菱形房号为可选探索。指向房间可查看名称，指向 × 可查看开门条件。"
	location.text = "你的位置："+view.snapshot.location
	var target: Dictionary = view.snapshot.target
	objective.text = "主线目标已全部完成" if target.is_empty() else "主线目标：%s\n%s  %s" % [target.name,target.action,target.quantity]
	view.queue_redraw()
