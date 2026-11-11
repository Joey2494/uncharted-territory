extends PanelContainer
## Displays authoritative action data; never advances a gameplay timer or handles input.

const READY_COLOR := Color("d2ae6a")
const COOLING_COLOR := Color("a39a87")
const BLOCKED_COLOR := Color("817b70")

@export var ability_name: String = "普攻"
@export var input_hint: String = "J"
@export var ability_icon: Texture2D

@onready var icon: TextureRect = %AbilityIcon
@onready var state_label: Label = %StateLabel
@onready var progress: ProgressBar = %CooldownProgress

var _fill: StyleBoxFlat


func _ready() -> void:
	%AbilityName.text = ability_name
	%InputHint.text = input_hint
	if ability_icon != null:
		icon.texture = ability_icon
	_fill = progress.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	progress.add_theme_stylebox_override("fill", _fill)
	update_cooldown(0.0, 1.0, "未就绪")


func update_cooldown(remaining: float, duration: float, blocked_reason: String = "") -> void:
	var cooling := remaining > 0.0
	var available := not cooling and blocked_reason.is_empty()
	var color := READY_COLOR if available else (COOLING_COLOR if cooling else BLOCKED_COLOR)
	# Round up so a positive cooldown never displays a misleading "0.0 seconds".
	state_label.text = "%.1f 秒" % (ceilf(remaining * 10.0) / 10.0) if cooling else ("可用" if available else blocked_reason)
	state_label.add_theme_color_override("font_color", color)
	icon.self_modulate = READY_COLOR if available else Color("69675e")
	_fill.bg_color = READY_COLOR if available else Color("756442")
	progress.value = clampf(1.0 - remaining / maxf(duration, 0.001), 0.0, 1.0)
