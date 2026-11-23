extends Button
## Long ability effects wrap inside the viewport; short legacy hints stay native.
func _has_point(point: Vector2) -> bool:
	# Adjacent arc controls have intersecting bounding boxes, but disjoint circles.
	# Only the visible circular area should receive clicks or tooltips.
	return point.distance_to(size*0.5) <= minf(size.x,size.y)*0.5

func _make_custom_tooltip(for_text: String) -> Object:
	if not for_text.contains("\n"): return null
	var panel := PanelContainer.new()
	panel.theme = preload("res://scenes/ui/menu_theme.tres")
	var padding := MarginContainer.new()
	for edge in ["left","right","top","bottom"]:
		padding.add_theme_constant_override("margin_"+edge,12)
	panel.add_child(padding)
	var label := Label.new()
	label.text = for_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = minf(360.0,maxf(160.0,get_viewport_rect().size.x-64.0))
	label.add_theme_font_size_override("font_size",15)
	padding.add_child(label)
	return panel
