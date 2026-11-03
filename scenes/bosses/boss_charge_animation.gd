extends Node
## Presentation only. The Boss state machine owns charge movement and contact.

const IDLE: StringName = &"locomotion/Idle_A"
const RUN: StringName = &"locomotion/Running_A"

@export_range(0.0, 0.3, 0.01) var idle_blend_duration: float = 0.10

@onready var _actor: CharacterBody3D = get_parent()
@onready var _animator: AnimationPlayer = $"../Visuals/Model/AnimationPlayer"

var _charging: bool = false
var _previous_callback_mode: int


func _ready() -> void:
	_actor.state_changed.connect(_on_state_changed)
	_actor.died.connect(_on_died)
	_on_state_changed("")


func _on_state_changed(_message: String) -> void:
	if not _actor.is_dead() and _actor.state == _actor.State.CHARGE:
		if not _charging:
			_charging = true
			_previous_callback_mode = _animator.callback_mode_process
			_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
			_animator.speed_scale = 1.0
			_animator.play(RUN, 0.0)
			_animator.advance(0.0)
	elif _charging:
		_stop_charge()


func _stop_charge() -> void:
	_charging = false
	_animator.callback_mode_process = _previous_callback_mode
	if _actor.is_dead():
		_animator.pause()
	else:
		_animator.play(IDLE, idle_blend_duration)
		_animator.advance(0.0)


func _on_died() -> void:
	if _charging:
		_stop_charge()
