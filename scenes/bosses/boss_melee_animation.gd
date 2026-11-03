extends Node
## Boss presentation only; MeleeAttack owns hit queries, timing and cooldown.

const IDLE: StringName = &"locomotion/Idle_A"
const SWING: StringName = &"boss_melee/Melee_2H_Attack_Slice"
const AXE: PackedScene = preload("res://assets/characters/kaykit/barbarian/weapons/axe_2handed.gltf")

# Source-clip seconds, calibrated from the free Rig_Medium two-handed slice.
@export_range(0.0, 1.1, 0.01) var slash_start_time: float = 0.35
@export_range(0.0, 1.1, 0.01) var slash_end_time: float = 0.60
@export_range(0.0, 0.3, 0.01) var idle_blend_duration: float = 0.12

@onready var _actor: CharacterBody3D = get_parent()
@onready var _attack: Node3D = $"../MeleeAttack"
@onready var _visuals: Node3D = $"../Visuals"
@onready var _model: Node3D = $"../Visuals/Model"
@onready var _skeleton: Skeleton3D = $"../Visuals/Model/Barbarian/Rig_Medium/Skeleton3D"
@onready var _animator: AnimationPlayer = $"../Visuals/Model/AnimationPlayer"

var _playing: bool = false
var _start_cooldown: float = 0.0
var _rest_yaw: float = 0.0
var _previous_callback_mode: int


func _ready() -> void:
	_rest_yaw = _model.rotation.y
	_previous_callback_mode = _animator.callback_mode_process
	var socket := BoneAttachment3D.new()
	socket.name = "BossAxe"
	socket.bone_name = "handslot.r"
	_skeleton.add_child(socket)
	socket.add_child(AXE.instantiate())
	# Hide this Boss's procedural sword only; keep its existing range preview.
	for mesh in _attack.get_node("SwingPivot").get_children():
		if mesh is MeshInstance3D:
			mesh.hide()
	_attack.attack_started.connect(_on_attack_started)
	_attack.attack_finished.connect(_on_attack_finished)
	_attack.hit_detected.connect(_on_hit_detected)
	_actor.died.connect(_on_died)
	_animator.play(IDLE, 0.0)
	_animator.advance(0.0)


func _physics_process(_delta: float) -> void:
	if _playing:
		_update_pose()


func _on_attack_started() -> void:
	if _actor.is_dead():
		return
	_start_cooldown = _attack.get_cooldown_remaining()
	_playing = true
	_previous_callback_mode = _animator.callback_mode_process
	_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_animator.speed_scale = 1.0
	_animator.play(SWING, 0.0)
	_update_pose()


func _update_pose() -> void:
	# This public clock advances in the same physics step as the original hit loop.
	var elapsed: float = maxf(_start_cooldown - _attack.get_cooldown_remaining(), 0.0)
	var windup: float = _attack.windup_duration
	var active: float = _attack.active_duration
	var recovery: float = _attack.recovery_duration
	var clip := _animator.get_animation(SWING)
	var start := clampf(slash_start_time, 0.0, clip.length)
	var finish := clampf(slash_end_time, start, clip.length)
	var time: float
	if elapsed < windup:
		time = lerpf(0.0, start, elapsed / windup)
	elif elapsed < windup + active:
		time = lerpf(start, finish, (elapsed - windup) / active)
	else:
		var progress := clampf((elapsed - windup - active) / maxf(recovery, 0.0001), 0.0, 1.0)
		time = lerpf(finish, clip.length, progress)
	_animator.seek(time, true)
	# Keep the visible cut aligned with the direction already captured by combat.
	_model.rotation.y = _rest_yaw + _attack.global_rotation.y - _visuals.global_rotation.y


func _on_hit_detected(_target: Node, _amount: int) -> void:
	if _playing:
		# Synchronize the visible strike before the existing take_damage() call.
		_update_pose()


func _on_attack_finished() -> void:
	if not _playing:
		return
	_update_pose()
	_playing = false
	_model.rotation.y = _rest_yaw
	_animator.callback_mode_process = _previous_callback_mode
	if _actor.is_dead():
		_animator.pause()
	else:
		_animator.play(IDLE, idle_blend_duration)


func _on_died() -> void:
	# Release the skeleton before DeathAnimation handles the same immediate signal.
	_playing = false
	_model.rotation.y = _rest_yaw
	_animator.pause()
	_animator.callback_mode_process = _previous_callback_mode
	set_physics_process(false)
