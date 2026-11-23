extends CanvasLayer
## 观测台共用的近景读片面板。鼠标可直接点选；Tab、方向键与 Enter 可操作全部按钮。
const FONT := preload("res://scenes/ui/dungeon_font.tres")
const GOLD := Color("#e3bc80")
const PAPER := Color("#eee7d6")
const TEAL := Color("#9bd2c7")
const FRAME := Color("#69654f")
const PLATES := ["欠曝", "长曝", "侧光"]
const CUTS := ["Ⅰ", "Ⅱ", "Ⅲ"]
var instrument
var shade := ColorRect.new()
var title := Label.new()
var note := Label.new()
var line := Label.new()
var art := Control.new()
var actions := VBoxContainer.new()
var first_button: Button
var rails: Array[HSlider] = []
var rail_labels: Array[Label] = []
var undo_button: Button

func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("#061014dd")
	var center := CenterContainer.new()
	shade.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 610
	panel.add_theme_stylebox_override("panel", _box(Color("#16232a"), FRAME, 18, 1))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	_label(column, title, 26, GOLD)
	_label(column, note, 16, PAPER)
	art.custom_minimum_size.y = 195
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(art)
	art.draw.connect(_draw_art)
	_label(column, line, 16, TEAL)
	column.add_child(actions)
	actions.add_theme_constant_override("separation", 6)
	shade.hide()

func _box(bg: Color, border: Color, padding: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(3)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding/2.0
	box.content_margin_bottom = padding/2.0
	return box

func _label(parent: Control, widget: Label, pixels: int, tint: Color) -> void:
	parent.add_child(widget)
	widget.add_theme_font_override("font", FONT)
	widget.add_theme_color_override("font_color", tint)
	widget.add_theme_font_size_override("font_size", pixels)
	widget.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func present() -> void:
	shade.show()
	refresh()
	if first_button: first_button.grab_focus()

func dismiss() -> void:
	shade.hide()

func _input(event: InputEvent) -> void:
	if not shade.visible: return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if instrument.plate_zoom >= 0:
			instrument.operate(&"zoom", -1)
		else:
			instrument.operate(&"close")
		get_viewport().set_input_as_handled()

func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	actions.add_child(row)
	return row

func _button(row: HBoxContainer, label: String, action: StringName, index := 0, delta := 1) -> Button:
	var button := Button.new()
	button.set_meta("key", "%s/%d/%d" % [action,index,delta])
	button.text = label
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_stylebox_override("normal", _box(Color("#22343c"), Color("#486069"), 9, 1))
	button.add_theme_stylebox_override("hover", _box(Color("#314b52"), TEAL, 9, 1))
	button.add_theme_stylebox_override("pressed", _box(Color("#40565b"), GOLD, 9, 1))
	var focus := _box(Color.TRANSPARENT, GOLD, 9, 2)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 34
	row.add_child(button)
	button.pressed.connect(func(): instrument.operate(action,index,delta))
	if first_button == null: first_button = button
	return button

func refresh() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	var key: String = str(owner.get_meta("key", "")) if owner else ""
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	first_button = null
	rails.clear()
	rail_labels.clear()
	undo_button = null
	var state = instrument
	match state.display:
		&"p_dial":
			title.text = "曝光轮   /   " + state.PHASES[state.exposure] + "片"
			note.text = "左侧为计数样片。旋轮依次投亮三份记录，对照墙上的日相。"
			line.text = "亮孔留下星点。中央细十字是对位线。"
			var row := _row()
			_button(row, "◀  逆时转", &"turn", 0, -1)
			_button(row, "顺时转  ▶", &"turn")
			_button(row, "离台", &"close")
		&"p_safe":
			title.text = "曝光记录柜"
			note.text = "柜面刻着三枚日相。将各班次的读数拨入相应轮位。"
			var hints := ["可回到曝光轮复看三个班次的记录。", "只数发亮的星点，略过十字与暗孔。", "墙片从暮到晨；柜门从晨到暮，请按柜门刻字输入。"]
			line.text = (state.status + "  " if state.status != "" else "") + hints[state.hint_depth]
			var row := _row()
			for i in 3:
				_button(row, "＋ " + state.PHASES[i], &"digit", i, 1)
			var lower := _row()
			for i in 3:
				_button(lower, "－ " + state.PHASES[i], &"digit", i, -1)
			var bottom := _row()
			_button(bottom, "试开柜门", &"submit")
			_button(bottom, "翻提示  %d/2" % state.hint_depth, &"hint").disabled = state.hint_depth == 2
			_button(bottom, "离台", &"close")
		&"p_lightbox":
			title.text = "夜班冲洗灯台"
			note.text = "先透过放大镜观察三张试片，再移动遮片。试片与灯台边缘有成组的定位缺口。"
			if state.plate_zoom >= 0:
				line.text = ["Ⅰ  欠曝片  ·  三张脸在暗处留下清晰轮廓。", "Ⅱ  长曝片  ·  人脸过曝，铜镜里浮出相机。", "Ⅲ  侧光片  ·  握着快门线的手露了出来。"][state.plate_zoom]
			elif state.film_developed:
				line.text = "铜镜里，第四名值班员正替同伴按下快门。"
			else:
				line.text = "拖动滑轨，或选中滑轨后按左右键，把快门线接到相机上。"
			var zoom_row := _row()
			for i in 3: _button(zoom_row, CUTS[i] + "  放大" + PLATES[i] + "片", &"zoom", i)
			if not state.film_developed:
				var track := _row()
				for i in 3: _add_rail(track, i)
			var bottom := _row()
			if not state.film_developed:
				undo_button = _button(bottom, "撤销上次移动", &"undo")
				undo_button.disabled = state.previous_plates.is_empty()
			_button(bottom, "离台取片" if state.film_developed and not state.film_claimed else "离台", &"close")
		_:
			var final_print: bool = state.display == &"p_window" and state.film_claimed
			title.text = "照相窗" if state.display == &"p_window" else "交班合影"
			note.text = "照片背面写着「交班前，再拍一张」。"
			line.text = "镜头后的人也留在了相纸上。" if final_print else "照片里有三个人。玻璃下挂着四枚工牌。"
			_button(_row(), "放回照片", &"close")
	art.queue_redraw()
	if key != "":
		for row in actions.get_children():
			for button in row.get_children():
				if button is Button and button.get_meta("key") == key and not button.disabled:
					button.grab_focus()
					return
		if first_button: first_button.grab_focus()

func _add_rail(row: HBoxContainer, index: int) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var label := Label.new()
	_label(column, label, 16, PAPER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rail_labels.append(label)
	var rail := HSlider.new()
	rail.min_value = 0
	rail.max_value = 2
	rail.step = 1
	rail.tick_count = 3
	rail.ticks_on_borders = true
	rail.scrollable = false
	rail.custom_minimum_size.y = 24
	column.add_child(rail)
	rail.set_meta("key", "rail/%d" % index)
	rails.append(rail)
	_sync_rail(index)
	rail.value_changed.connect(func(value: float):
		instrument.operate(&"plate", index, int(value) - int(instrument.plates[index])))

func _sync_rail(index: int) -> void:
	var selected: int = instrument.plates[index]
	rail_labels[index].text = ["人像", "镜面", "侧光窗"][index] + "  /  " + PLATES[selected]
	rails[index].set_value_no_signal(selected)

## 不重建正在拖动的滑块，保留鼠标捕获与键盘焦点。
func update_rails() -> void:
	if rails.size() != 3 or instrument.film_developed:
		refresh()
		return
	for i in 3: _sync_rail(i)
	line.text = "拖动滑轨，或选中滑轨后按左右键，把快门线接到相机上。"
	undo_button.disabled = instrument.previous_plates.is_empty()
	art.queue_redraw()

func _draw_art() -> void:
	var size := art.size
	art.draw_rect(Rect2(Vector2.ZERO, size), Color("#09151c"))
	art.draw_rect(Rect2(Vector2.ZERO, size), FRAME, false, 1)
	match instrument.display:
		&"p_dial":
			var sample := Vector2(size.x*0.23, 95)
			var sky := Vector2(size.x*0.70, 94)
			art.draw_line(Vector2(size.x*0.43, 16),Vector2(size.x*0.43,size.y-16),FRAME,1)
			for i in 3:
				var pos := sample + Vector2((i-1)*34,0)
				art.draw_circle(pos, 10, GOLD if i != 1 else Color("#202d32"), true, -1, true)
				art.draw_arc(pos, 11, 0, TAU, 32, FRAME, 1, true)
			_text("样片    /    记录 2", Vector2(sample.x-59, 155), 17, PAPER)
			art.draw_arc(sky, 66, 0, TAU, 90, Color("#45595b"),1,true)
			art.draw_line(sky-Vector2(17,0),sky+Vector2(17,0),FRAME,1)
			art.draw_line(sky-Vector2(0,17),sky+Vector2(0,17),FRAME,1)
			for point: Vector2 in instrument.STARS[instrument.exposure]:
				var pos := sky + point*72
				art.draw_circle(pos, 7, Color("#5d503c"),true,-1,true)
				art.draw_circle(pos, 4, GOLD,true,-1,true)
			_text(instrument.PHASES[instrument.exposure]+"相记录", Vector2(sky.x-32, 184), 16, GOLD)
		&"p_safe":
			for i in 3:
				var center := Vector2(size.x*(i+1)/4, size.y/2)
				art.draw_rect(Rect2(center-Vector2(44,66),Vector2(88,132)),Color("#1d3036"))
				art.draw_rect(Rect2(center-Vector2(44,66),Vector2(88,132)),FRAME,false,1)
				_text(instrument.PHASES[i],center+Vector2(-10,-37),20,GOLD)
				_text(str(instrument.digits[i]),center+Vector2(-17,39),60,PAPER)
		_:
			_draw_photo_view()

func _text(content: String, pos: Vector2, px: int, tint: Color) -> void:
	art.draw_string(FONT, pos, content, HORIZONTAL_ALIGNMENT_LEFT, -1, px, tint)

func _region(frame: int, x: float, width: float, dest: Rect2) -> void:
	var source := Rect2(frame*440+x,0,width,206)
	art.draw_texture_rect_region(instrument.PHOTO,dest,source)

func _draw_photo_view() -> void:
	var area := Rect2((art.size.x-365)/2, 9, 365, 171)
	var state = instrument
	var composite: bool = state.display == &"p_lightbox" and not state.film_developed and state.plate_zoom < 0
	if composite:
		var cuts := [0.0, 273.0, 373.0, 440.0]
		for i in 3:
			var w: float = cuts[i+1]-cuts[i]
			var dest := Rect2(area.position+Vector2(area.size.x*cuts[i]/440.0,0),Vector2(area.size.x*w/440.0,area.size.y))
			_region(state.plates[i], cuts[i], w, dest)
			# 相同数量的缺口冲印在试片与灯台边缘；位置正确时重合。
			for j in i+1:
				var notch := Vector2(dest.position.x+4+j*4,area.end.y+5)
				art.draw_line(notch,notch+Vector2(0,6),GOLD,2)
			for j in state.plates[i]+1:
				var notch := Vector2(dest.position.x+4+j*4,area.end.y-4)
				art.draw_line(notch,notch+Vector2(0,5),TEAL,2)
	else:
		var frame := 0
		if state.display == &"p_lightbox":
			frame = state.plate_zoom if state.plate_zoom >= 0 else 3
		elif state.display == &"p_window" and state.film_claimed: frame = 3
		if state.display == &"p_lightbox" and state.plate_zoom >= 0:
			# 放大该片最有辨识力的部位，细看脸、相机镜头与持线的手。
			var crops := [Rect2(15,42,231,108), Rect2(259,38,180,84), Rect2(311,78,125,59)]
			var src: Rect2 = crops[frame]
			src.position.x += frame*440
			art.draw_texture_rect_region(instrument.PHOTO, area, src)
		else:
			_region(frame, 0, 440, area)
		if state.display == &"p_lightbox" and state.plate_zoom >= 0:
			for j in frame+1:
				var notch := area.position + Vector2(6+j*4,area.size.y-5)
				art.draw_line(notch,notch+Vector2(0,5),TEAL,2)
	art.draw_rect(area.grow(1), Color("#c8bb98"),false,1)
