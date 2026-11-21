extends Node
## UI-only projections of the inventory's existing interaction selection.
var dock: Node
var hud: Control
var host: Node
var target: Node3D
var feedback_visible := false
var interaction: PanelContainer
var action: PanelContainer
var map_tip: PanelContainer

func _ready() -> void:
	dock = get_parent()
	hud = dock.hud
	host = dock.host
	process_priority = 30
	interaction = _bubble()
	action = _bubble()
	map_tip = _bubble()

func _bubble() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 12
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.03,0.023,0.94)
	style.border_color = Color("bc9b59")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel",style)
	hud.add_child(panel)
	panel.hide()
	return panel

static func has_keys(text: String) -> bool:
	var regex := RegEx.new()
	regex.compile("(?:按\\s*|\\[)(?:Space|SPACE|Enter|Esc|Tab|空格|[A-Z])")
	return regex.search(text) != null

func _copy(panel: PanelContainer, keys: Array, text: String) -> void:
	var scale_factor: float = dock._text_scale()
	var viewport_width := hud.get_viewport_rect().size.x
	var signature := str(keys)+text+str(scale_factor)+str(viewport_width)
	if panel.get_meta("copy","") == signature: return
	panel.set_meta("copy",signature)
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gap := roundi(5*scale_factor)
	row.add_theme_constant_override("separation",gap)
	panel.add_child(row)
	var frame := panel.get_theme_stylebox("panel") as StyleBoxFlat
	frame.set_content_margin_all(6*scale_factor)
	var key_width := 0.0
	for key in keys:
		var cap := PanelContainer.new()
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxFlat.new()
		style.bg_color = Color("28251d")
		style.border_color = Color("a58a50")
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		style.content_margin_left = 5*scale_factor
		style.content_margin_right = 5*scale_factor
		style.content_margin_top = 2*scale_factor
		style.content_margin_bottom = 2*scale_factor
		cap.add_theme_stylebox_override("panel",style)
		var glyph := Label.new()
		glyph.text = key
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.add_theme_font_size_override("font_size",roundi(14*scale_factor))
		glyph.add_theme_color_override("font_color",Color("f1dba2"))
		cap.add_child(glyph)
		row.add_child(cap)
		key_width += cap.get_combined_minimum_size().x+gap
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",roundi(14*scale_factor))
	label.add_theme_color_override("font_color",Color("f3ce78"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var font := label.get_theme_font("font")
	var natural := font.get_multiline_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
	var max_width := minf(360*scale_factor,viewport_width*0.44)
	var text_width := minf(ceilf(natural)+1,maxf(48*scale_factor,max_width-key_width-12*scale_factor))
	label.custom_minimum_size.x = text_width
	label.size.x = text_width
	_measure(panel)

func _measure(panel: Control) -> Vector2:
	# Reset old long-content dimensions before measuring the new wrapped label.
	for i in 3:
		dock._sort_tree(panel)
		panel.size = panel.get_combined_minimum_size()
	return panel.size

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and is_node_ready(): _hide()

func _hide() -> void:
	for panel in [interaction,action,map_tip]: panel.hide()
	feedback_visible = false

func _process(_delta: float) -> void:
	_hide()
	if not dock.is_running(): return
	# Task rows retain actions/quantities; key instructions belong to bubbles.
	var quest: Control = hud.get_node_or_null("LevelObjective")
	if quest != null:
		for name in ["QuestDetail","QuestTarget"]:
			var label: Label = quest.get_node("%"+name)
			label.text = label.text.replace("[E] ","").replace("按 E ","").replace("[E]","")
	var items: Node = host._items
	target = items._get_nearest_interaction_target()
	if is_instance_valid(target):
		var text := "交互"
		if target.has_method("get_display_name"):
			text = "拾取 "+target.get_display_name()
			if "quantity" in target: text += " ×%d" % target.quantity
		elif target.has_method("get_interaction_prompt"):
			var prompt: String = target.get_interaction_prompt()
			text = prompt.replace("[E]","").strip_edges().split("\n")[0]
			if text.length() > 20: text = "交互 · "+_object_name(target)
		_copy(interaction,["E"],text)
		interaction.visible = place_world(interaction,target.global_position+Vector3.UP*1.5)
	var feedback: String = hud._feedback_active.get("text","")
	if has_keys(feedback):
		var keys: Array = ["Space"] if feedback.contains("闪避") or feedback.contains("空格") or feedback.contains("Space") else []
		if not keys.is_empty():
			_copy(action,keys,"闪避攻击")
			feedback_visible = place_world(action,host._player.global_position+Vector3.UP*2.2)
		elif not feedback.contains("按 E") and not feedback.contains("[E]"):
			var regex := RegEx.new()
			regex.compile("(?:按\\s*|\\[)([A-Z])")
			var match := regex.search(feedback)
			if match != null:
				var key: String = match.get_string(1)
				_copy(action,[key],{"R":"使用生命药剂","F":"使用强化符文","J":"攻击","K":"释放法术","L":"使用角色技能","M":"打开地图"}.get(key,"操作"))
				feedback_visible = place_world(action,host._player.global_position+Vector3.UP*2.2)
		action.visible = feedback_visible
		if not feedback_visible and is_instance_valid(target): feedback_visible = interaction.visible
	var button: Button = hud.get_node("LevelObjective/%MapButton")
	if not button.disabled and (button.is_hovered() or button.has_focus()):
		_copy(map_tip,["M"],"打开地图")
		map_tip.visible = place_screen(map_tip,Vector2(quest.get_global_rect().end.x,button.get_global_rect().get_center().y),dock.obstacles())

func _object_name(node: Node) -> String:
	if "action" in node and host.level_id == 3:
		return host._dungeon.STATIONS.get(node.action,[Vector3.ZERO,"机关"])[1]
	return "机关"

func place_world(panel: Control, point: Vector3) -> bool:
	var camera: Camera3D = host._dungeon.get_node("Camera3D")
	if camera.is_position_behind(point): return false
	var screen := camera.unproject_position(point)
	if not hud.get_viewport_rect().has_point(screen): return false
	return place_screen(panel,screen,dock.obstacles())

func place_screen(panel: Control, point: Vector2, obstacles: Array) -> bool:
	panel.scale = Vector2.ONE
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var size: Vector2
	if panel.has_meta("copy"):
		size = _measure(panel)
	else:
		# Existing tutorial/context cards retain their own content-based minima.
		if panel is Container:
			for i in 2: dock._sort_tree(panel)
		size = panel.get_combined_minimum_size()
	var bounds: Rect2 = hud.get_viewport_rect().grow(-8)
	var candidates := [point-Vector2(size.x*0.5,size.y+12),point+Vector2(18,-size.y*0.5),point-Vector2(size.x+18,size.y*0.5),point+Vector2(-size.x*0.5,20)]
	for position: Vector2 in candidates:
		var rect := Rect2(position,size)
		if not bounds.encloses(rect): continue
		var clear := true
		for obstacle: Rect2 in obstacles:
			if rect.intersects(obstacle): clear = false
		for other in [interaction,action,map_tip]:
			if other != panel and other.visible and rect.intersects(other.get_global_rect()): clear = false
		if clear:
			panel.position = position
			panel.size = size
			return true
	return false
