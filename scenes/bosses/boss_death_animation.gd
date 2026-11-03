extends Node
## Died stays immediate; only corpse cleanup waits for the complete Death_A.

signal death_finished

const DEATH: StringName = &"death/Death_A"

@onready var _actor: CharacterBody3D = get_parent()
@onready var _animator: AnimationPlayer = $"../Visuals/Model/AnimationPlayer"
@onready var _skeleton: Skeleton3D = $"../Visuals/Model/Barbarian/Rig_Medium/Skeleton3D"

var _started: bool = false
var _completed: bool = false
var _elapsed: float = 0.0
var _started_frame: int = -1


func _ready() -> void:
	# Last in the scene: hit, melee and charge release the skeleton on died first.
	_actor.died.connect(_on_died)
	set_physics_process(false)


func _on_died() -> void:
	if _started:
		return
	_started = true
	_started_frame = Engine.get_physics_frames()
	_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_animator.speed_scale = 1.0
	# Clear prior action poses on bones whose constant rest tracks were optimized out.
	_skeleton.reset_bone_poses()
	_animator.play(DEATH, 0.0)
	_animator.seek(0.0, true)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	# A lethal hit may occur earlier in this physics tick; do not charge its
	# already elapsed delta against the new animation's full 0.8-second duration.
	if Engine.get_physics_frames() == _started_frame:
		return
	var clip := _animator.get_animation(DEATH)
	_elapsed = minf(_elapsed + delta, clip.length)
	_animator.seek(_elapsed, true)
	if _elapsed < clip.length - 0.000001 or _completed:
		return
	_animator.seek(clip.length, true)
	_animator.pause()
	_completed = true
	set_physics_process(false)
	# RuinGatekeeper.tscn connects this once to the original actor's queue_free().
	death_finished.emit()
