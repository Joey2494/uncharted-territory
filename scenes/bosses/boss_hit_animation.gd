extends Node
## Accepted-damage presentation only; the Boss retains its unstaggered AI.

const HIT: StringName = &"hit/Hit_A"
const IDLE: StringName = &"locomotion/Idle_A"
const WALK: StringName = &"locomotion/Walking_A"

@export_range(0.0, 0.3, 0.01) var blend_duration: float = 0.10
@export_range(0.01, 0.2, 0.01) var stopped_speed: float = 0.04

@onready var _actor: CharacterBody3D = get_parent()
@onready var _attack: Node3D = $"../MeleeAttack"
@onready var _animator: AnimationPlayer = $"../Visuals/Model/AnimationPlayer"

var _playing: bool = false
var _elapsed: float = 0.0
var _previous_callback_mode: int


func _ready() -> void:
	_actor.damage_received.connect(_on_damage_received)
	_actor.state_changed.connect(_on_state_changed)
	_actor.died.connect(_on_died)
	# This node precedes the action nodes in the scene: release manual sampling
	# before MeleeAnimation captures its callback mode and starts a new swing.
	_attack.attack_started.connect(_on_attack_started)
	_update_locomotion()
	_animator.advance(0.0)


func _action_has_priority() -> bool:
	return _attack.is_attacking() or _actor.state in [
		_actor.State.SWING, _actor.State.CHARGE_WINDUP, _actor.State.CHARGE
	]


func _on_damage_received(amount: int) -> void:
	# Fatal hits already set the Boss dead flag before this signal is emitted.
	if amount <= 0 or _actor.is_dead() or _action_has_priority():
		return
	if not _playing:
		_previous_callback_mode = _animator.callback_mode_process
	_playing = true
	_elapsed = 0.0
	_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_animator.speed_scale = 1.0
	_animator.play(HIT, 0.0)
	_animator.seek(0.0, true)


func _physics_process(delta: float) -> void:
	if _actor.is_dead() or _action_has_priority():
		_cancel_hit(false)
		return
	if _playing:
		var clip := _animator.get_animation(HIT)
		_elapsed = minf(_elapsed + delta, clip.length)
		_animator.seek(_elapsed, true)
		if _elapsed >= clip.length - 0.000001:
			_cancel_hit(true)
		return
	_update_locomotion()


func _on_attack_started() -> void:
	_cancel_hit(false)


func _on_state_changed(_message: String) -> void:
	if _actor.is_dead() or _action_has_priority():
		_cancel_hit(false)
		if not _actor.is_dead() and _actor.state == _actor.State.CHARGE_WINDUP:
			# The current windup uses Idle_A while its original warning counts down.
			_play_locomotion(IDLE)


func _cancel_hit(resume_locomotion: bool) -> void:
	if not _playing:
		return
	_playing = false
	_animator.pause()
	_animator.callback_mode_process = _previous_callback_mode
	if resume_locomotion and not _actor.is_dead() and not _action_has_priority():
		_update_locomotion()


func _update_locomotion() -> void:
	var velocity := _actor.get_real_velocity()
	var moving := Vector2(velocity.x, velocity.z).length() > stopped_speed
	var clip := WALK if _actor.state == _actor.State.CHASE and moving else IDLE
	_play_locomotion(clip)


func _play_locomotion(clip: StringName) -> void:
	_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_animator.speed_scale = 1.0
	if _animator.current_animation != clip or not _animator.is_playing():
		_animator.play(clip, blend_duration)


func _on_died() -> void:
	_cancel_hit(false)
	set_physics_process(false)
