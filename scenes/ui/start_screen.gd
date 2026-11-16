extends Control

signal shop_requested
signal backpack_requested

signal start_requested
signal continue_requested
signal settings_requested
signal quit_requested
signal character_purchased

const CHARACTERS = preload("res://scenes/player/character_catalog.gd")
const Profile = preload("res://scripts/integration/player_profile.gd")
var selected_character_id: String = "knight"

@onready var start_button: Button = %StartButton
@onready var status_label: Label = %StatusLabel
var _progress: RefCounted
var _levels: Array[Dictionary] = []
var _layout_pending := false
var _title_tween: Tween

func _ready() -> void:
	Profile.ensure_loaded()
	selected_character_id = CHARACTERS.selected_id
	%ShopButton.pressed.connect(func() -> void: shop_requested.emit())
	%BackpackButton.pressed.connect(func() -> void: backpack_requested.emit())
	_style_menu_buttons()
	start_button.pressed.connect(func() -> void: start_requested.emit())
	%ContinueButton.pressed.connect(func() -> void: continue_requested.emit())
	%SettingsButton.pressed.connect(func() -> void: settings_requested.emit())
	%QuitButton.pressed.connect(func() -> void: quit_requested.emit())
	visibility_changed.connect(_focus_action)
	resized.connect(_queue_layout)
	%Card.minimum_size_changed.connect(_queue_layout)
	%SecondaryPanel.minimum_size_changed.connect(_queue_layout)
	visibility_changed.connect(_update_preview)
	_layout_menu()
	_update_preview()
	select_character(selected_character_id)
	_focus_action()

func configure(levels: Array[Dictionary], progress: RefCounted) -> void:
	_progress = progress
	_levels = levels.duplicate()
	refresh_progress()

func refresh_progress() -> void:
	if _progress == null:
		return
	var recent: StringName = _progress.get_last_played_level()
	var available := not recent.is_empty()
	%ContinueButton.disabled = not available
	status_label.text = "暂无可继续的游戏 · 开始新的探索"
	%ContinueButton.tooltip_text = "进入过关卡后可继续最近的关卡"
	if available:
		var id := String(recent)
		status_label.text = "上次探索：第%s关" % id.trim_prefix("level")
		%ContinueButton.tooltip_text = "继续最近进入的关卡，重新整备生命和道具"
	if not _progress.message.is_empty():
		status_label.text = _progress.message

func show_menu() -> void:
	refresh_progress()
	show()
	_focus_action()

func show_status(message: String) -> void:
	status_label.text = message

func _focus_action() -> void:
	if is_node_ready() and is_visible_in_tree():
		start_button.grab_focus.call_deferred()

func _update_preview() -> void:
	var active := is_visible_in_tree()
	%PreviewViewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	%PreviewStage.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if active:
		_fade_in_title()
	elif _title_tween != null and _title_tween.is_valid():
		_title_tween.kill()

func _layout_menu() -> void:
	_layout_pending = false
	if not is_node_ready():
		return
	var width := size.x
	var compact := width < 1000.0
	var card: PanelContainer = %Card
	card.custom_minimum_size.x = 0
	%TitleLabel.add_theme_font_size_override("font_size", 56 if compact else 72)
	card.size = Vector2(clampf(width * 0.30, 290.0, 400.0), 0)
	var secondary: PanelContainer = %SecondaryPanel
	secondary.size = Vector2(card.size.x, 0)
	secondary.position = Vector2(maxf(32.0, width * 0.065), size.y - 24.0 - secondary.size.y)
	card.position = Vector2(secondary.position.x, maxf(28.0, minf((size.y - card.size.y) * 0.5, secondary.position.y - 24.0 - card.size.y)))
	var preview: SubViewportContainer = $DungeonPreview
	preview.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var art_left := card.position.x + card.size.x + 16.0
	preview.position = Vector2(art_left, 0)
	preview.size = Vector2(maxf(1.0, width - art_left), size.y)

func _queue_layout() -> void:
	if _layout_pending:
		return
	_layout_pending = true
	_layout_menu.call_deferred()

func _style_menu_buttons() -> void:
	# Duplicate the existing theme so other menus keep their own presentation.
	theme = theme.duplicate(true)
	var hover := theme.get_stylebox("hover", "Button") as StyleBoxFlat
	hover.shadow_color = Color(0.73, 0.60, 0.35, 0.22)
	hover.shadow_size = 8
	var focus := theme.get_stylebox("focus", "Button") as StyleBoxFlat
	focus.shadow_color = Color(0.73, 0.60, 0.35, 0.12)
	focus.shadow_size = 5

func _fade_in_title() -> void:
	if _title_tween != null and _title_tween.is_valid():
		_title_tween.kill()
	_title_tween = create_tween().set_parallel(true)
	var labels: Array[Label] = [%TitleLabel, %Eyebrow, %Tagline]
	for i in range(labels.size()):
		labels[i].modulate.a = 0.0
		_title_tween.tween_property(labels[i], "modulate:a", 1.0, 0.7).set_delay(i * 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func select_character(id: String) -> void:
	if id in CHARACTERS.IDS:
		selected_character_id = id
