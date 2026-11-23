extends CanvasLayer
## 在共用战斗 HUD 旁提供第四关自己的实况路线图；打开时独占暂停和输入。
@onready var world := get_parent()
@onready var shop_shortcut: Control = world.get_node_or_null("../CommerceLayer/Shortcut")
@onready var map: Control = $Overlay/Center/Card/Rows/Map
@onready var button: Button = $MapButton
@onready var overlay: ColorRect = $Overlay

func _ready() -> void:
	map.level = world
	button.pressed.connect(open_map)
	$Overlay/Center/Card/Rows/Resume.pressed.connect(close_map)

func _process(_delta: float) -> void:
	if not world.is_node_ready(): return
	button.visible = world.is_run_active() and not get_tree().paused and not world.puzzles.modal_open()
	if button.visible and is_instance_valid(shop_shortcut):
		var bounds := shop_shortcut.get_global_rect()
		button.scale = shop_shortcut.scale
		button.size = Vector2(shop_shortcut.size.x, 34)
		button.position = Vector2(bounds.end.x - button.size.x * button.scale.x, bounds.end.y + 6)

func is_open() -> bool:
	return overlay.visible

func open_map() -> void:
	if not world.is_run_active() or get_tree().paused or world.puzzles.modal_open(): return
	overlay.show()
	button.hide()
	get_tree().paused = true
	map.queue_redraw()
	$Overlay/Center/Card/Rows/Resume.grab_focus()

func close_map() -> void:
	if not is_open(): return
	overlay.hide()
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if not world.is_node_ready() or event.is_echo(): return
	var tab: bool = event is InputEventKey and event.pressed and event.keycode == KEY_TAB
	if is_open():
		if tab or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			close_map()
			get_viewport().set_input_as_handled()
	elif tab and world.is_run_active() and not get_tree().paused:
		open_map()
		get_viewport().set_input_as_handled()
