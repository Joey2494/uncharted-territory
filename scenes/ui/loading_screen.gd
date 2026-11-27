extends CanvasLayer
## Resource percentage is supplied exclusively by ResourceLoader, never time.
const IMAGES := [
	[preload("res://assets/loading/scene_0_wide.res"),preload("res://assets/loading/scene_0_portrait.res")],
	[preload("res://assets/loading/scene_1_wide.res"),preload("res://assets/loading/scene_1_portrait.res")],
	[preload("res://assets/loading/scene_2_wide.res"),preload("res://assets/loading/scene_2_portrait.res")],
	[preload("res://assets/loading/scene_3_wide.res"),preload("res://assets/loading/scene_3_portrait.res")]
]
const TIPS := [
	"靠近道具或机关时，气泡会显示当前可执行的操作。按 E 与眼前的目标交互。",
	"按 M 查看地图。青色标记是你的位置，金色菱形指向当前主线目标。",
	"观察敌人的起手动作，再用方向键配合空格闪避，为下一次攻击留出空间。",
	"部分房间会在战斗开始后封锁通道。清除房内守卫，才能继续前进。",
	"生命药剂和强化符文各有用途。查看持有数量，在需要时再使用。",
	"石刻、符文与装置外形往往彼此呼应。操作机关前，先观察周围环境。",
	"可选支路可能藏着补给和奖励；它们不会替代主线目标，也不必全部完成才能通关。",
	"击败首领后，仍需找到并穿过真正的出口。尚未升起的闸门不会成为通路。",
	"通关后可携带金币和剩余道具。最终失败会清空所有携带物资；持有复活卡时可先选择原地复活。",
	"潮汐不仅改变水面，也会改变古墓中的通路。留意曾经走过的地方出现的新变化。",
]
static var _previous_variant := -1
static var _previous_tip := -1
var root: Control
var footer: VBoxContainer
var tip: Label
var status: Label
var percent: Label
var bar: ProgressBar
var art: TextureRect
var variant := -1
var ratio := 0.0
var _last_size := Vector2.ZERO
var _tip_origin_ms := -1
var _tip_cycle := 0
var presented_ratios: Array[float] = []
var _tip_index := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	if variant < 0: variant = (randi_range(1,3)+_previous_variant)%4
	_previous_variant = variant
	var tip_index := (randi_range(1,TIPS.size()-1)+_previous_tip)%TIPS.size()
	_previous_tip = tip_index
	_tip_index = tip_index
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = preload("res://scenes/ui/menu_theme.tres")
	add_child(root)
	var backdrop := ColorRect.new()
	backdrop.color = Color("080b0c")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	art = TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(art)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025,0.022,0.012,0.24)
	root.add_child(shade)
	var gradient := Gradient.new()
	gradient.set_color(0,Color(0,0,0,0.08))
	gradient.set_color(1,Color(0.015,0.018,0.012,0.98))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0,0.45)
	texture.fill_to = Vector2(0,1)
	var fade := TextureRect.new()
	fade.texture = texture
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(fade)
	footer = VBoxContainer.new()
	footer.add_theme_constant_override("separation",14)
	root.add_child(footer)
	tip = _label(TIPS[tip_index],18,Color("d0c4a3"))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(tip)
	var row := HBoxContainer.new()
	footer.add_child(row)
	status = _label("正在加载",16,Color("b69b62"))
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(status)
	percent = _label("0%",16,Color("e0c68e"))
	row.add_child(percent)
	bar = ProgressBar.new()
	bar.custom_minimum_size.y = 5
	bar.show_percentage = false
	for entry in [["background",Color("292c23")],["fill",Color("b49856")]]:
		var style := StyleBoxFlat.new()
		style.bg_color = entry[1]
		bar.add_theme_stylebox_override(entry[0],style)
	footer.add_child(bar)
	footer.minimum_size_changed.connect(_layout.call_deferred)
	_layout()
	RenderingServer.frame_post_draw.connect(_first_present,CONNECT_ONE_SHOT)
	if DisplayServer.get_name() == "headless": _first_present.call_deferred()

func _first_present() -> void:
	_tip_origin_ms = Time.get_ticks_msec()
	presented_ratios.append(ratio)

func present() -> void:
	if DisplayServer.get_name() == "headless": await get_tree().process_frame
	else: await RenderingServer.frame_post_draw
	presented_ratios.append(ratio)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	return label

func set_progress(value: float) -> void:
	ratio = clampf(value,0,1)
	bar.value = ratio*100
	percent.text = "%d%%" % floori(ratio*100)

func _process(_delta: float) -> void:
	if root.size != _last_size: _layout()
	_update_tip_clock(Time.get_ticks_msec())

func _update_tip_clock(now_ms: int) -> void:
	if _tip_origin_ms < 0: return
	var cycle := maxi(0,(now_ms-_tip_origin_ms)/5000)
	if cycle <= _tip_cycle: return
	_tip_cycle = cycle
	_tip_index = (_tip_index+randi_range(1,TIPS.size()-1))%TIPS.size()
	_previous_tip = _tip_index
	tip.text = TIPS[_tip_index]
	_layout()

func _layout() -> void:
	_last_size = root.size
	var size := get_viewport().get_visible_rect().size
	art.texture = IMAGES[variant][1 if size.x/size.y < 0.9 else 0]
	var factor := clampf(size.x/maxf(1,get_tree().root.size.x),1,2)
	var width := minf(960,size.x-48)
	footer.position.x = (size.x-width)*0.5
	footer.size.x = width
	for label in [tip,status,percent]:
		var font_size := roundi((18 if label == tip else 16)*factor)
		if label.get_theme_font_size("font_size") != font_size: label.add_theme_font_size_override("font_size",font_size)
	footer.size.y = 0
	for i in 2: footer.notification(Container.NOTIFICATION_SORT_CHILDREN)
	footer.size.y = footer.get_combined_minimum_size().y
	footer.position.y = maxf(20,size.y-footer.get_combined_minimum_size().y-36*factor)

func finish() -> void:
	set_progress(1)
	await present()
	queue_free()

func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
