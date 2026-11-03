extends Node
## Presentation only. MeleeEnemy retains AI, hurt timing and death detection.

signal death_finished

const IDLE: StringName = &"warrior/Idle_A"
const RUN: StringName = &"warrior/Running_A"
const HIT: StringName = &"warrior/Hit_A"
const DEATH: StringName = &"warrior/Death_A"

@export_range(0.0, 0.5, 0.01) var blend_duration: float = 0.1
@export_range(0.01, 0.2, 0.01) var stopped_speed: float = 0.04
@export_range(0.1, 3.0, 0.05) var run_playback_speed: float = 1.0

@onready var _actor: CharacterBody3D = get_parent()
@onready var _animator: AnimationPlayer = $"../Visuals/Model/AnimationPlayer"

var _clip: StringName = &""
var _hit_active: bool = false
var _hit_duration: float = 0.0
var _dying: bool = false
var _death_elapsed: float = 0.0


func _ready() -> void:
	_actor.damage_received.connect(_on_damage_received)
	_actor.died.connect(_on_died)
	_play_locomotion(IDLE, 1.0)
	# A fresh instance must already have its idle pose while the menu is frozen.
	_animator.advance(0.0)


func _physics_process(delta: float) -> void:
	if _dying:
		var animation := _animator.get_animation(DEATH)
		_death_elapsed = minf(_death_elapsed + delta, animation.length)
		_animator.seek(_death_elapsed, true)
		if _death_elapsed >= animation.length - 0.000001:
			_animator.seek(animation.length, true)
			_animator.pause()
			set_physics_process(false)
			# MeleeEnemy.tscn connects this once to the actor's queue_free().
			death_finished.emit()
		return
	if _hit_active:
		var remaining: float = _actor.get_hurt_time_remaining()
		var progress := clampf(1.0 - remaining / _hit_duration, 0.0, 1.0)
		_animator.seek(_animator.get_animation(HIT).length * progress, true)
		if remaining > 0.0:
			return
		_hit_active = false
	var velocity := _actor.get_real_velocity()
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < stopped_speed:
		_play_locomotion(IDLE, 1.0)
	else:
		var ratio := clampf(speed / maxf(_actor.move_speed, stopped_speed), 0.25, 1.0)
		_play_locomotion(RUN, run_playback_speed * ratio)


func _play_locomotion(clip: StringName, playback: float) -> void:
	_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_animator.speed_scale = playback
	if _clip != clip or not _animator.is_playing():
		_animator.play(clip, blend_duration if _clip != &"" else 0.0)
		_clip = clip


func _play_action(clip: StringName) -> void:
	_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_animator.speed_scale = 1.0
	_animator.play(clip, 0.0)
	_animator.seek(0.0, true)
	_clip = clip


func _on_damage_received(_amount: int) -> void:
	# Fatal damage is signaled before _die(); Death_A owns that transition.
	if _actor.is_dead() or _dying:
		return
	_hit_duration = _actor.get_hurt_time_remaining()
	if _hit_duration <= 0.0:
		_hit_active = false
		return
	_hit_active = true
	_play_action(HIT)


func _on_died() -> void:
	if _dying:
		return
	_dying = true
	_hit_active = false
	_death_elapsed = 0.0
	_play_action(DEATH)
