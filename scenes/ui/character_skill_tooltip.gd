extends HBoxContainer
## Keep the complete skill description readable in narrow windows.
func _make_custom_tooltip(for_text: String) -> Object:
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
