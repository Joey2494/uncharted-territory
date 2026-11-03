extends Node
## Knight-only presentation. EnergyShock alone creates and launches projectiles.

const SHOOT: StringName = &"magic/Ranged_Magic_Shoot"

# Source frame 9 at 30 FPS: the casting hand reaches its forward extension.
@export_range(0.0, 1.0, 0.01) var release_time: float = 0.3

@onready var _actor: CharacterBody3D = get_parent()
@onready var _skill: Node3D = $"../EnergyShock"
@onready var _locomotion: Node = $"../LocomotionAnimation"
@onready var _attack_animation: Node = $"../AttackAnimation"
@onready var _hit_animation: Node = $"../HitAnimation"
@onready var _visuals: Node3D = $"../Visuals"
@onready var _model: Node3D = $"../Visuals/Model"
@onready var _animator: AnimationPlayer = $"../Visuals/Model/AnimationPlayer"

var _playing: bool = false
var _elapsed: float = 0.0
var _source_start: float = 0.0
var _release_yaw: float = 0.0
var _rest_yaw: float = 0.0
var _previous_callback_mode: int


func _ready() -> void:
	_skill.released.connect(_on_released)
	_actor.died.connect(cancel)


func _on_released(projectile: Node3D) -> void:
	if _actor.is_dead() or _actor.is_dodging():
		return
	_hit_animation.cancel()
	if not _playing:
		_attack_animation.set_presentation_suspended(true)
		_previous_callback_mode = _animator.callback_mode_process
		_rest_yaw = _model.rotation.y
	_playing = true
	_elapsed = 0.0
	_source_start = clampf(release_time, 0.0, _animator.get_animation(SHOOT).length)
	_release_yaw = projectile.global_rotation.y
	_locomotion.set_action_override(true)
	_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_animator.speed_scale = 1.0
	_animator.play(SHOOT, 0.0)
	# The existing skill fires immediately: apply the release pose in this same call.
	# Animation never delays, calls try_cast(), or spawns a second projectile.
	_update_pose()


func _physics_process(delta: float) -> void:
	if not _playing:
		return
	if _actor.is_dead() or _actor.is_dodging():
		cancel()
		return
	_elapsed += delta
	_update_pose()
	if _source_start + _elapsed >= _animator.get_animation(SHOOT).length - 0.000001:
		cancel()


func _update_pose() -> void:
	var animation := _animator.get_animation(SHOOT)
	_animator.seek(minf(_source_start + _elapsed, animation.length), true)
	# Keep the cast facing the launched projectile while movement turns Visuals.
	_model.rotation.y = _rest_yaw + _release_yaw - _visuals.global_rotation.y


func cancel() -> void:
	if not _playing:
		return
	_playing = false
	_model.rotation.y = _rest_yaw
	_animator.pause()
	_animator.callback_mode_process = _previous_callback_mode
	_locomotion.set_action_override(false)
	_attack_animation.set_presentation_suspended(false)


func _exit_tree() -> void:
	if _playing and is_instance_valid(_animator):
		_animator.callback_mode_process = _previous_callback_mode
