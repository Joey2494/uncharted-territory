extends PanelContainer
signal activation_requested
signal activation_started
signal activation_ended
var _mouse_held := false
## Displays authoritative action data and emits activation intents; owns no gameplay clock.

const READY_COLOR := Color("d2ae6a")
const COOLING_COLOR := Color("a39a87")
const BLOCKED_COLOR := Color("817b70")

@export var ability_name: String = "普攻"
@export var input_hint: String = "J"
@export var ability_icon: Texture2D
@export_multiline var ability_description: String = ""

@onready var icon: TextureRect = %AbilityIcon
@onready var state_label: Label = %StateLabel
@onready var progress: ProgressBar = %CooldownProgress

var _fill: StyleBoxFlat
var _mask: ShaderMaterial
var _frame: StyleBoxFlat


func _ready() -> void:
	_frame = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	add_theme_stylebox_override("panel", _frame)
	_mask = %CooldownMask.material.duplicate() as ShaderMaterial
	%CooldownMask.material = _mask
	%ActivateButton.pressed.connect(func() -> void: activation_requested.emit())
	%ActivateButton.button_down.connect(func() -> void:
		_mouse_held = true
		activation_started.emit())
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		%ActivateButton.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	resized.connect(_layout_badge)
	%AbilityName.text = ability_name
	%InputHint.text = input_hint
	if ability_icon != null:
		icon.texture = ability_icon
	_fill = progress.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	progress.add_theme_stylebox_override("fill", _fill)
	update_cooldown(0.0, 1.0, "未就绪")
	_layout_badge()


func update_cooldown(remaining: float, duration: float, blocked_reason: String = "") -> void:
	ability_name = %AbilityName.text
	input_hint = %InputHint.text
	var cooling := remaining > 0.0
	var available := not cooling and blocked_reason.is_empty()
	var color := READY_COLOR if available else (COOLING_COLOR if cooling else BLOCKED_COLOR)
	# Round up so a positive cooldown never displays a misleading "0.0 seconds".
	state_label.text = "%.1f" % (ceilf(remaining * 10.0) / 10.0) if cooling else ("可用" if available else blocked_reason.trim_prefix("持续 "))
	state_label.add_theme_color_override("font_color", color)
	icon.self_modulate = READY_COLOR if available else Color("69675e")
	_fill.bg_color = READY_COLOR if available else Color("756442")
	progress.value = clampf(1.0 - remaining / maxf(duration, 0.001), 0.0, 1.0)
	%CooldownMask.visible = not available
	_mask.set_shader_parameter("remaining", 1.0 - progress.value if cooling else (0.0 if available else 1.0))
	%ActivateButton.disabled = not available
	%ActivateButton.tooltip_text = "%s [%s] · %s" % [ability_name, input_hint, state_label.text]
	if not ability_description.is_empty():
		%ActivateButton.tooltip_text += "\n%s\n冷却 %s 秒" % [ability_description,str(duration).trim_suffix(".0")]
	_frame.border_color = READY_COLOR if available else Color("66573b")
	_frame.shadow_color = Color(0.73, 0.60, 0.35, 0.18) if available else Color(0, 0, 0, 0.45)
	_frame.shadow_size = 5 if available else 3

func configure_ability(display_name: String, display_icon: Texture2D, description: String) -> void:
	ability_name = display_name
	ability_icon = display_icon
	ability_description = description
	if is_node_ready():
		%AbilityName.text = ability_name
		icon.texture = ability_icon

func _input(event: InputEvent) -> void:
	# Continue observing release after active guard disables its own button.
	if _mouse_held and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_mouse_held = false
		activation_ended.emit()

func set_badge_size(diameter: float) -> void:
	custom_minimum_size = Vector2.ONE * diameter
	size = custom_minimum_size
	if is_node_ready():
		_layout_badge()

func _layout_badge() -> void:
	var diameter := minf(size.x, size.y)
	_frame.set_corner_radius_all(roundi(diameter * 0.5))
	var extent := Vector2.ONE * (diameter - 4)
	%ActivateButton.position = Vector2.ZERO
	%ActivateButton.size = extent
	%CooldownMask.position = Vector2.ZERO
	%CooldownMask.size = extent
	var icon_size := diameter * 0.32
	icon.position = Vector2((extent.x - icon_size) * 0.5, diameter * 0.32)
	icon.size = Vector2.ONE * icon_size
	%InputHint.add_theme_font_size_override("font_size", 12 if input_hint == "Space" else (24 if diameter > 90 else 18))
	%InputHint.position = Vector2(0, diameter * 0.08)
	%InputHint.size = Vector2(extent.x, diameter * 0.24)
	state_label.add_theme_font_size_override("font_size", 10 if diameter < 60 else (11 if diameter < 70 else 12))
	state_label.clip_text = true
	state_label.position = Vector2(0, diameter * 0.70)
	state_label.size = Vector2(extent.x, 18)
