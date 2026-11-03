extends Node
## Knight-only presentation. Player remains the authority for dodge timing and movement.

const FORWARD: StringName = &"dodge/Dodge_Forward"
const BACKWARD: StringName = &"dodge/Dodge_Backward"
const LEFT: StringName = &"dodge/Dodge_Left"
const RIGHT: StringName = &"dodge/Dodge_Right"

@onready var _actor: CharacterBody3D = get_parent()
@onready var _visuals: Node3D = $"../Visuals"
@onready var _locomotion: Node = $"../LocomotionAnimation"
@onready var _hit_animation: Node = $"../HitAnimation"
@onready var _cast_animation: Node = $"../CastAnimation"
@onready var _animator: AnimationPlayer = $"../Visuals/Model/AnimationPlayer"

var _playing: bool = false
var _clip: StringName = &""
var _previous_callback_mode: int


func _ready() -> void:
	_actor.dodge_started.connect(_on_dodge_started)
	_actor.dodge_finished.connect(_on_dodge_finished)


func _physics_process(_delta: float) -> void:
	if _playing:
		_update_pose()


func _on_dodge_started() -> void:
	# Release lower-priority actions before taking animation control.
	_cast_animation.cancel()
	_hit_animation.cancel()
	# Visuals uses -Z forward; the imported Knight is corrected by Model's PI yaw.
	var local_direction: Vector3 = _visuals.global_basis.orthonormalized().inverse() * _actor.get_dodge_direction()
	# Nearest cardinal direction; exact diagonals consistently prefer forward/back.
	if absf(local_direction.x) > absf(local_direction.z) + 0.000001:
		_clip = RIGHT if local_direction.x > 0.0 else LEFT
	else:
		_clip = BACKWARD if local_direction.z > 0.0 else FORWARD
	_playing = true
	_locomotion.set_action_override(true)
	_previous_callback_mode = _animator.callback_mode_process
	_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_animator.speed_scale = 1.0
	_animator.play(_clip, 0.0)
	_update_pose()


func _update_pose() -> void:
	# Sample the full 0.4 s source clip over the physical dodge's 0.2 s clock.
	# No root motion or second timer can alter displacement or drift from its end.
	var animation := _animator.get_animation(_clip)
	_animator.seek(animation.length * _actor.get_dodge_progress(), true)


func _on_dodge_finished() -> void:
	if not _playing:
		return
	_update_pose()
	_playing = false
	_animator.pause()
	_animator.callback_mode_process = _previous_callback_mode
	_locomotion.set_action_override(false)


func _exit_tree() -> void:
	if _playing and is_instance_valid(_animator):
		_animator.callback_mode_process = _previous_callback_mode
