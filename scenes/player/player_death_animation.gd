extends Node
## Died stays immediate; settlement waits until the complete Knight death pose.

const DEATH: StringName = &"death/Death_A"

@onready var _actor: CharacterBody3D = get_parent()
@onready var _animator: AnimationPlayer = $"../Visuals/Model/AnimationPlayer"

var _started: bool = false
var _completed: bool = false
var _elapsed: float = 0.0
var _previous_callback_mode: int


func _ready() -> void:
	# This node is last in Player.tscn so hit/cast/locomotion release on died first.
	_actor.died.connect(_on_actor_died)
	set_physics_process(false)


func _on_actor_died() -> void:
	if _started:
		return
	_started = true
	_previous_callback_mode = _animator.callback_mode_process
	_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_animator.speed_scale = 1.0
	_animator.play(DEATH, 0.0)
	_animator.seek(0.0, true)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	var animation := _animator.get_animation(DEATH)
	_elapsed = minf(_elapsed + delta, animation.length)
	_animator.seek(_elapsed, true)
	if _elapsed < animation.length - 0.000001:
		return
	# Apply and retain the final source pose before notifying the host to freeze.
	_animator.seek(animation.length, true)
	_animator.pause()
	_animator.callback_mode_process = _previous_callback_mode
	_completed = true
	set_physics_process(false)
	_actor.death_animation_finished.emit()


func _exit_tree() -> void:
	if _started and not _completed and is_instance_valid(_animator):
		_animator.callback_mode_process = _previous_callback_mode
