extends Node
## Reads physical movement without moving or rotating the player or model.

const IDLE: StringName = &"locomotion/Idle_A"
const WALK: StringName = &"locomotion/Walking_A"
const RUN: StringName = &"locomotion/Running_A"

@export_node_path("CharacterBody3D") var actor_path: NodePath = NodePath("..")
@export_node_path("AnimationPlayer") var animation_player_path: NodePath = NodePath("../Visuals/Model/AnimationPlayer")
@export_range(0.1, 3.0, 0.05) var walk_playback_speed: float = 1.0
@export_range(0.1, 3.0, 0.05) var run_playback_speed: float = 1.25
@export_range(0.0, 0.5, 0.01) var blend_duration: float = 0.12
@export_range(0.01, 0.2, 0.01) var stopped_speed: float = 0.04

@onready var _actor: CharacterBody3D = get_node(actor_path)
@onready var _animator: AnimationPlayer = get_node(animation_player_path)

var _current_clip: StringName = &""
var _action_override: bool = false


func _ready() -> void:
	_actor.died.connect(_on_actor_died)
	_set_clip(IDLE, 1.0)
	# Apply the initial pose even while the dungeon is on the start screen.
	_animator.advance(0.0)


func _physics_process(_delta: float) -> void:
	if _action_override:
		return
	if _actor.is_dodging():
		# DodgeAnimation owns the pose until the physical dodge finishes.
		return
	var velocity := _actor.get_real_velocity()
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < stopped_speed:
		_set_clip(IDLE, 1.0)
		return
	# Hysteresis prevents rapid gait changes while sliding along obstacles.
	var threshold: float = (minf(_actor.walk_speed, _actor.move_speed) + _actor.move_speed) * 0.5
	var margin := 0.15 if _current_clip != RUN else -0.15
	var running := speed > threshold + margin
	var clip := RUN if running else WALK
	var playback := run_playback_speed if running else walk_playback_speed
	var gait_speed: float = _actor.move_speed if running else minf(_actor.walk_speed, _actor.move_speed)
	# Keep arm cadence natural independently of physical speed and stride length.
	# Partial movement can slow it further, but cannot exceed the chosen cadence.
	var speed_ratio := clampf(speed / maxf(gait_speed, stopped_speed), 0.25, 1.0)
	_set_clip(clip, playback * speed_ratio)


func set_action_override(active: bool) -> void:
	_action_override = active
	if not active and not _actor.is_dead():
		# Blend from the action pose instead of trusting the cached locomotion clip.
		_current_clip = _animator.current_animation
		_physics_process(0.0)


func _set_clip(clip: StringName, playback_speed: float) -> void:
	_animator.speed_scale = playback_speed
	if _current_clip != clip or not _animator.is_playing():
		var blend := blend_duration if _current_clip != &"" else 0.0
		_animator.play(clip, blend)
		_current_clip = clip


func _on_actor_died() -> void:
	_animator.pause()
	set_physics_process(false)
