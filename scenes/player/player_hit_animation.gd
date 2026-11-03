extends Node
## Knight-only reaction to accepted damage; never changes HP, immunity, or combat.

const HIT: StringName = &"hit/Hit_A"

@onready var _actor: CharacterBody3D = get_parent()
@onready var _locomotion: Node = $"../LocomotionAnimation"
@onready var _attack_animation: Node = $"../AttackAnimation"
@onready var _cast_animation: Node = $"../CastAnimation"
@onready var _animator: AnimationPlayer = $"../Visuals/Model/AnimationPlayer"

var _playing: bool = false
var _elapsed: float = 0.0
var _previous_callback_mode: int


func _ready() -> void:
	_actor.damage_received.connect(_on_damage_received)
	_actor.died.connect(cancel)


func _on_damage_received(_amount: int) -> void:
	# Player sets its death flag before emitting damage_received, even on lethal hits.
	if _actor.is_dead() or _actor.is_dodging():
		return
	_cast_animation.cancel()
	if not _playing:
		_attack_animation.set_presentation_suspended(true)
		_previous_callback_mode = _animator.callback_mode_process
	_playing = true
	_elapsed = 0.0
	_locomotion.set_action_override(true)
	_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_animator.speed_scale = 1.0
	# A new accepted hit restarts the reaction; rejected hits never emit this signal.
	_animator.play(HIT, 0.0)
	_animator.seek(0.0, true)


func _physics_process(delta: float) -> void:
	if not _playing:
		return
	if _actor.is_dead() or _actor.is_dodging():
		cancel()
		return
	var animation := _animator.get_animation(HIT)
	_elapsed = minf(_elapsed + delta, animation.length)
	_animator.seek(_elapsed, true)
	if _elapsed >= animation.length - 0.000001:
		cancel()


func cancel() -> void:
	if not _playing:
		return
	_playing = false
	_animator.pause()
	_animator.callback_mode_process = _previous_callback_mode
	_locomotion.set_action_override(false)
	_attack_animation.set_presentation_suspended(false)


func _exit_tree() -> void:
	if _playing and is_instance_valid(_animator):
		_animator.callback_mode_process = _previous_callback_mode
