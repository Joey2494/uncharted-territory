extends Node
## Player-only presentation. MeleeAttack remains the authority for timing and hits.

const SLASH: StringName = &"melee/Melee_1H_Attack_Slice_Diagonal"

@export var weapon_scene: PackedScene = preload("res://assets/characters/kaykit/weapons/sword_1handed.gltf")
@export_range(0.0, 1.0, 0.01) var slash_start_ratio: float = 0.38
@export_range(0.0, 1.0, 0.01) var slash_end_ratio: float = 0.50

@onready var _actor: CharacterBody3D = get_parent()
@onready var _attack: Node3D = $"../MeleeAttack"
@onready var _locomotion: Node = $"../LocomotionAnimation"
@onready var _visuals: Node3D = $"../Visuals"
@onready var _model: Node3D = $"../Visuals/Model"
@onready var _skeleton: Skeleton3D = $"../Visuals/Model/Knight/Rig_Medium/Skeleton3D"
@onready var _animator: AnimationPlayer = $"../Visuals/Model/AnimationPlayer"

var _playing: bool = false
var _presentation_suspended: bool = false
var _start_cooldown: float = 0.0
var _rest_yaw: float = 0.0
var _previous_callback_mode: int


func _ready() -> void:
	_rest_yaw = _model.rotation.y
	_previous_callback_mode = _animator.callback_mode_process
	var socket := BoneAttachment3D.new()
	socket.name = "RightHandWeapon"
	socket.bone_name = "handslot.r"
	_skeleton.add_child(socket)
	socket.add_child(weapon_scene.instantiate())
	# Hide only this player's old procedural weapon. Its range preview stays intact.
	for mesh in _attack.get_node("SwingPivot").get_children():
		if mesh is MeshInstance3D:
			mesh.hide()
	_attack.attack_started.connect(_on_attack_started)
	_attack.attack_finished.connect(_on_attack_finished)
	_attack.hit_detected.connect(_on_hit_detected)


func _physics_process(_delta: float) -> void:
	if _playing and not _presentation_suspended:
		_update_pose()


func _on_attack_started() -> void:
	_start_cooldown = _attack.get_cooldown_remaining()
	_playing = true
	if not _presentation_suspended:
		_start_presentation()


func _start_presentation() -> void:
	_locomotion.set_action_override(true)
	_previous_callback_mode = _animator.callback_mode_process
	_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_animator.speed_scale = 1.0
	# Manual sampling keeps every pose tied to the existing hit clock, even at low FPS.
	_animator.play(SLASH, 0.0)
	_update_pose()


func _update_pose() -> void:
	# Existing public cooldown reports the same elapsed time as the attack's hit loop.
	var elapsed: float = maxf(_start_cooldown - _attack.get_cooldown_remaining(), 0.0)
	var windup: float = _attack.windup_duration
	var active: float = _attack.active_duration
	var recovery: float = _attack.recovery_duration
	var slash_start := clampf(slash_start_ratio, 0.0, 1.0)
	var slash_end := clampf(slash_end_ratio, slash_start, 1.0)
	var phase: float
	if elapsed < windup:
		phase = lerpf(0.0, slash_start, elapsed / windup)
	elif elapsed < windup + active:
		phase = lerpf(slash_start, slash_end, (elapsed - windup) / active)
	else:
		var progress := clampf((elapsed - windup - active) / maxf(recovery, 0.0001), 0.0, 1.0)
		phase = lerpf(slash_end, 1.0, progress)
	var animation := _animator.get_animation(SLASH)
	_animator.seek(animation.length * phase, true)
	# MeleeAttack snapshots its direction. Compensate for movement turning Visuals.
	_model.rotation.y = _rest_yaw + _attack.global_rotation.y - _visuals.global_rotation.y


func _on_hit_detected(_target: Node, _amount: int) -> void:
	if _playing and not _presentation_suspended:
		# Update before take_damage(), including frames that cross into the hit window.
		_update_pose()


func _on_attack_finished() -> void:
	if not _playing:
		return
	_playing = false
	if not _presentation_suspended:
		_release_presentation()


func _release_presentation() -> void:
	_model.rotation.y = _rest_yaw
	_animator.pause()
	_animator.callback_mode_process = _previous_callback_mode
	_locomotion.set_action_override(false)


func set_presentation_suspended(active: bool) -> void:
	# Hit/cast can own the skeleton while the original attack clock and hits continue.
	if _presentation_suspended == active:
		return
	_presentation_suspended = active
	if not _playing:
		return
	if active:
		_release_presentation()
	elif not _actor.is_dead() and not _actor.is_dodging():
		# Resume at the existing combat phase, never restart the swing or cooldown.
		_start_presentation()


func _exit_tree() -> void:
	if _playing and not _presentation_suspended and is_instance_valid(_animator):
		_animator.callback_mode_process = _previous_callback_mode
