extends RefCounted
static func create_theme() -> Theme:
	var result: Theme = preload("res://scenes/ui/menu_theme.tres").duplicate(true)
	for state in ["normal","hover","pressed","disabled"]:
		var style: StyleBoxFlat = result.get_stylebox(state,"Button").duplicate()
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		style.content_margin_left = 12
		style.content_margin_right = 12
		result.set_stylebox(state,"Button",style)
	return result
