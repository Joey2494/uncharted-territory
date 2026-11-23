extends Node
## One presentation lane. Reads actors/HUD only; never changes a gameplay trigger.
const GOLD := Color("f3ce78")
@onready var hud: Control = get_parent()
@onready var host: Node = hud.get_node_or_null("../..")
var reserved_rect := Rect2()
var current: Control
var _header: Label
var _keys: HBoxContainer
var _last_copy := ""
var bubbles: Node

func _ready() -> void:
	bubbles = preload("res://scenes/ui/interaction_bubbles.gd").new()
	add_child.call_deferred(bubbles)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.023,0.019,0.92)
	style.border_color = Color("a4874e")
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0,0,0,0.35)
	style.shadow_size = 5
	hud.feedback_panel.add_theme_stylebox_override("panel",style)
	var lesson_style := style.duplicate() as StyleBoxFlat
	lesson_style.content_margin_left = 12
	lesson_style.content_margin_right = 12
	lesson_style.content_margin_top = 8
	lesson_style.content_margin_bottom = 10
	hud.get_node("%TutorialPrompt").add_theme_stylebox_override("panel",lesson_style)
	hud.feedback_panel.get_node("StoneSurface").hide()
	var content: VBoxContainer = hud.feedback_panel.get_node("Padding/Content")
	content.add_theme_constant_override("separation",6)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(row)
	content.move_child(row,0)
	_header = Label.new()
	_header.add_theme_font_size_override("font_size",12)
	_header.add_theme_color_override("font_color",GOLD)
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_header)
	_keys = HBoxContainer.new()
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys.add_theme_constant_override("separation",4)
	row.add_child(_keys)
	for label in [hud.pickup_prompt,hud.item_message]:
		label.custom_minimum_size = Vector2.ZERO
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size",14)
	hud.pickup_prompt.add_theme_color_override("font_color",GOLD)
	hud.item_message.add_theme_color_override("font_color",Color("e5ddc9"))
	hud.feedback_panel.z_index = 6
	var local := hud.get_node_or_null("CastleHints")
	if local != null:
		local.card.add_theme_stylebox_override("panel",style)
		local.guide.add_theme_stylebox_override("panel",style)
		local.get_node("%HintBody").add_theme_font_size_override("font_size",14)
		local.get_node("%HintCategory").add_theme_color_override("font_color",GOLD)

func is_running() -> bool:
	if not hud.is_visible_in_tree() or get_tree().paused: return false
	if is_instance_valid(host) and host.has_method("get_run_state"):
		return host.get_run_state() == host.RunState.PLAYING
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and is_node_ready(): _hide_all()

func _process(_delta: float) -> void:
	refresh_layout()

func refresh_layout() -> void:
	_update_slot()
	if not is_running():
		_hide_all()
		return
	var tutorial: Control = hud.get_node("%TutorialPrompt")
	var text_scale := _text_scale()
	tutorial.set_dock_compact(reserved_rect.size.y < 180.0*text_scale,text_scale)
	var chosen: Control
	if not hud._feedback_active.is_empty():
		chosen = hud.feedback_panel
	elif not tutorial._lesson.is_empty(): chosen = tutorial
	else:
		var hints := hud.get_node_or_null("CastleHints")
		if hints != null:
			if hints.card.visible: chosen = hints.card
			elif hints.guide.visible: chosen = hints.guide
		if chosen == null and not hud._nearby_prompt.is_empty() and hud._tutorial_message.is_empty(): chosen = hud.feedback_panel
	_set_visible(hud.feedback_panel,chosen == hud.feedback_panel)
	_set_visible(tutorial,chosen == tutorial)
	var local := hud.get_node_or_null("CastleHints")
	if local != null:
		if chosen != local.card: local.card.hide()
		if chosen != local.guide: local.guide.hide()
	current = chosen
	if current == null: return
	if current == hud.feedback_panel:
		hud.pickup_prompt.hide()
		if hud._feedback_active.is_empty() or bubbles.has_keys(hud._feedback_active.get("text","")):
			current.hide()
			return
	if current == tutorial:
		tutorial.set_dock_compact(true,text_scale)
		if tutorial._lesson in ["interact","rune_pickup"]:
			current.hide()
			return
		current.visible = bubbles.place_world(current,host._player.global_position+Vector3.UP*2.4)
		return
	if local != null and current == local.card and bubbles.has_keys(local.get_node("%HintBody").text):
		var anchor: Node3D = local._active.get("anchor")
		current.visible = is_instance_valid(anchor) and bubbles.place_world(current,anchor.global_position+Vector3.UP*1.8)
		return
	if current == hud.feedback_panel: _decorate()
	if current == hud.feedback_panel:
		_font(hud.pickup_prompt,roundi(14*text_scale))
		_font(hud.item_message,roundi(14*text_scale))
		_font(_header,roundi(12*text_scale))
		for cap in _keys.get_children(): _font(cap.get_child(0),roundi(13*text_scale))
	var width := reserved_rect.size.x
	if local != null and current == local.guide: width = minf(width,current.size.x)
	var height: float = maxf(64.0,current.get_combined_minimum_size().y)
	if local != null and current == local.card: height = 94.0 if local._active.get("kind","") == "puzzle" else 78.0
	if local != null and current == local.guide: height = 40.0
	var dimensions := _context_size(current,Vector2(width,height)) if local != null and current in [local.card,local.guide] else Vector2(width,height)
	if not _fit(current,dimensions): current.hide()

func _text_scale() -> float:
	return clampf(hud.get_viewport_rect().size.x/maxf(1.0,get_tree().root.size.x),1.0,2.0)

func _font(node: Control, size: int) -> void:
	if node.get_theme_font_size("font_size") != size: node.add_theme_font_size_override("font_size",size)

func _context_size(control: Control, dimensions: Vector2) -> Vector2:
	var local: Node = hud.get_node_or_null("CastleHints")
	if local == null: return dimensions
	var factor := _text_scale()
	if control == local.card:
		dimensions.x = reserved_rect.size.x
		control.size.x = dimensions.x
		var title: Label = local.get_node("%HintCategory")
		var body: Label = local.get_node("%HintBody")
		var progress: Label = local.get_node("%HintProgress")
		_font(title,roundi(12*factor))
		_font(body,roundi(14*factor))
		_font(progress,roundi(11*factor))
		title.position = Vector2(12,8)
		title.size = Vector2(dimensions.x-24,ceilf(16*factor))
		body.position = Vector2(12,title.position.y+title.size.y+6)
		body.size.x = dimensions.x-24
		body.update_minimum_size()
		body.size.y = body.get_minimum_size().y
		progress.position = Vector2(12,body.position.y+body.size.y+6)
		progress.size = Vector2(dimensions.x-24,ceilf(15*factor))
		dimensions.y = (progress.position.y+progress.size.y if progress.visible else body.position.y+body.size.y)+10
	elif control == local.guide:
		var text: Label = local.get_node("%GuideText")
		_font(text,roundi(13*factor))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dimensions.x = minf(reserved_rect.size.x,(220.0 if text.text.length() > 5 else 110.0)*factor)
		control.size.x = dimensions.x
		text.position.x = 42*factor
		text.size.x = dimensions.x-50*factor
		text.update_minimum_size()
		dimensions.y = maxf(40*factor,text.get_minimum_size().y+12)
		var icon: Control = control.get_node("Icon")
		icon.position = Vector2(8*factor,(dimensions.y-28*factor)*0.5)
		icon.size = Vector2.ONE*28*factor
	return dimensions

func _set_visible(control: Control, state: bool) -> void:
	if control.visible != state: control.visible = state

func _hide_all() -> void:
	hud.feedback_panel.hide()
	hud.get_node("%TutorialPrompt").hide()
	var hints := hud.get_node_or_null("CastleHints")
	if hints != null:
		hints.card.hide()
		hints.guide.hide()
	current = null

func _decorate() -> void:
	var copy: String = hud.item_message.text if not hud._feedback_active.is_empty() else hud._nearby_prompt
	var priority := int(hud._feedback_active.get("priority",0))
	_header.text = "提示"
	hud.item_message.add_theme_color_override("font_color",GOLD if priority >= 80 else Color("e5ddc9"))
	if copy == _last_copy: return
	_last_copy = copy
	for child in _keys.get_children():
		_keys.remove_child(child)
		child.queue_free()
	var regex := RegEx.new()
	regex.compile("(?:\\[|按\\s*)(Space|Enter|Esc|Tab|[EJKLRF])(?=\\]|[^A-Za-z]|$)")
	var unique := {}
	for match in regex.search_all(copy): unique[match.get_string(1)] = true
	if copy.contains("翻滚") or copy.contains("闪避") or copy.contains("空格"): unique["Space"] = true
	for key: String in unique:
		var cap := PanelContainer.new()
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color("322c1e")
		style.border_color = GOLD
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		style.content_margin_left = 7
		style.content_margin_right = 7
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		cap.add_theme_stylebox_override("panel",style)
		var text := Label.new()
		text.text = key
		text.add_theme_font_size_override("font_size",13)
		text.add_theme_color_override("font_color",GOLD)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.add_child(text)
		_keys.add_child(cap)

func _update_slot() -> void:
	var viewport := hud.get_viewport_rect().size
	var margin := 16.0
	var width := clampf(viewport.x*0.30,220.0,304.0)
	var x := margin
	var top := viewport.y*0.30
	var bottom := minf(viewport.y-margin,hud.hotbar.get_global_rect().position.y-12.0)
	for control in [hud.get_node("Panel"),hud.get_node("ResourcesPanel"),hud.get_node_or_null("LevelObjective"),hud.get_node("CooldownBar"),_boss(),_shop()]:
		if not is_instance_valid(control) or not control.is_visible_in_tree(): continue
		var rect: Rect2 = control.get_global_rect()
		if rect.end.x <= x or rect.position.x >= x+width: continue
		if control == hud.get_node("CooldownBar"): bottom = minf(bottom,rect.position.y-12.0)
		else: top = maxf(top,rect.end.y+12.0)
	reserved_rect = Rect2(x,top,width,maxf(0.0,bottom-top))

func _boss() -> Control:
	return host.get_node_or_null("UILayer/BossHealthBar") if is_instance_valid(host) else null

func _shop() -> Control:
	return host.get_node_or_null("CommerceLayer/Shortcut") if is_instance_valid(host) else null

func place_context(control: Control, dimensions: Vector2) -> bool:
	_update_slot()
	if not is_running() or not hud._feedback_active.is_empty() or not hud._tutorial_message.is_empty(): return false
	dimensions.x = minf(dimensions.x,reserved_rect.size.x)
	return _fit(control,_context_size(control,dimensions))

func obstacles() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for control in [hud.get_node("Panel"),hud.get_node("ResourcesPanel"),hud.get_node_or_null("LevelObjective"),hud.get_node("CooldownBar"),hud.hotbar,_boss(),_shop(),host.get_node_or_null("UILayer/RunOverlay/VersionFooter") if is_instance_valid(host) else null]:
		if is_instance_valid(control) and control.is_visible_in_tree(): result.append(control.get_global_rect().grow(8))
	if not is_instance_valid(host): return result
	var world := host.get_node_or_null("DungeonTest")
	if world == null: return result
	var camera: Camera3D = world.get_node_or_null("Camera3D")
	if camera == null: return result
	# Reuse the combat-camera registry instead of scanning thousands of art nodes.
	for actor in get_tree().get_nodes_in_group("camera_targets"):
		if not actor is CharacterBody3D or not world.is_ancestor_of(actor): continue
		if not actor.has_method("is_dead"): continue
		if not actor.is_visible_in_tree() or camera.is_position_behind(actor.global_position): continue
		var dimensions := Vector2(0.65,2.2)
		if camera.has_method("_actor_dimensions"): dimensions = camera._actor_dimensions(actor)
		var low := Vector2(INF,INF)
		var high := Vector2(-INF,-INF)
		for dx in [-dimensions.x,dimensions.x]:
			for dz in [-dimensions.x,dimensions.x]:
				for dy in [0.0,dimensions.y]:
					var point := camera.unproject_position(actor.global_position+Vector3(dx,dy,dz))
					low = low.min(point)
					high = high.max(point)
		var rect := Rect2(low,high-low).grow(8)
		if rect.intersects(hud.get_viewport_rect()): result.append(rect)
	return result

func _fit(control: Control, dimensions: Vector2) -> bool:
	control.scale = Vector2.ONE
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.size = dimensions
	# Hidden wrapping containers otherwise keep their first one-character width.
	# Measure at the real dock width before deciding whether the card fits.
	if control is Container:
		for i in 2: _sort_tree(control)
		dimensions.y = maxf(64.0,control.get_combined_minimum_size().y)
	dimensions = dimensions.max(control.get_combined_minimum_size())
	if dimensions.x > reserved_rect.size.x+0.5 or dimensions.y > reserved_rect.size.y: return false
	var desired := clampf(hud.get_viewport_rect().size.y*0.61-dimensions.y*0.5,reserved_rect.position.y,reserved_rect.end.y-dimensions.y)
	var rows: Array[float] = [desired,reserved_rect.position.y,reserved_rect.end.y-dimensions.y]
	var blocked := obstacles()
	for obstacle in blocked:
		rows.append(obstacle.end.y+2.0)
		rows.append(obstacle.position.y-dimensions.y-2.0)
	for y in rows:
		var rect := Rect2(Vector2(reserved_rect.position.x,y),dimensions)
		if not reserved_rect.grow(0.5).encloses(rect): continue
		var clear := true
		for obstacle in blocked:
			if rect.intersects(obstacle):
				clear = false
				break
		if clear:
			control.position = rect.position
			control.size = rect.size
			return true
	return false

func _sort_tree(node: Node) -> void:
	if node is Container: node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children(): _sort_tree(child)
	if node is Control: node.update_minimum_size()
