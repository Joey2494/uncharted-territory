extends PanelContainer

@onready var title_label: Label = %BossTitle
@onready var hp_label: Label = %BossHPText
@onready var hp_bar: ProgressBar = %BossHPBar
@onready var state_label: Label = %BossState

var _hide_remaining: float = 0.0
var _defeated: bool = false


func begin_encounter(display_name: String, current: int, maximum: int) -> void:
	_defeated = false
	_hide_remaining = 0.0
	title_label.text = display_name
	update_hp(current, maximum)
	show()


func update_hp(current: int, maximum: int) -> void:
	hp_bar.max_value = maxi(1, maximum)
	hp_bar.value = clampi(current, 0, maxi(0, maximum))
	hp_label.text = "%d / %d" % [clampi(current, 0, maxi(0, maximum)), maxi(0, maximum)]


func update_state(message: String) -> void:
	state_label.text = message


func show_defeated() -> void:
	_defeated = true
	_hide_remaining = 2.0
	state_label.text = "%s已击败" % title_label.text
	show()


func is_defeated() -> bool:
	return _defeated


func _process(delta: float) -> void:
	if _hide_remaining > 0.0:
		_hide_remaining = maxf(0.0, _hide_remaining - delta)
		if _hide_remaining == 0.0:
			hide()
