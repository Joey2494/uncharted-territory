extends Node3D

signal released(projectile: Node3D)

@export var projectile_scene: PackedScene = preload("res://scenes/skills/EnergyBolt.tscn")
@export_range(1, 100, 1) var damage: int = 2
@export_range(1.0, 100.0, 0.5) var projectile_speed: float = 18.0
@export_range(1.0, 30.0, 0.5) var max_distance: float = 10.0
@export_range(0.1, 10.0, 0.1) var cooldown: float = 2.0
@export_range(0.05, 1.0, 0.01) var release_effect_duration: float = 0.18

@onready var _caster: CharacterBody3D = get_parent()
@onready var _facing: Node3D = $"../Visuals"
@onready var _effect: Node3D = $CastEffect

var _cooldown_remaining: float = 0.0
var _effect_remaining: float = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skill_1") and not event.is_echo():
		try_cast()
		get_viewport().set_input_as_handled()


func try_cast() -> bool:
	if not is_node_ready() or not can_process() or _cooldown_remaining > 0.0:
		return false
	if _caster.is_dead() or _caster.is_dodging() or projectile_scene == null:
		return false
	var direction := -_facing.global_basis.z
	direction.y = 0.0
	direction = direction.normalized()
	var projectile: Node3D = projectile_scene.instantiate()
	# A sibling of the caster moves independently and shares the world's pause
	# and restart lifecycle. Spawn at body centre so the muzzle cannot skip walls.
	_caster.get_parent().add_child(projectile)
	projectile.global_position = _caster.global_position + Vector3.UP * 0.95
	projectile.launch(direction, _caster.get_attack_damage(damage), projectile_speed, max_distance, _caster)
	_cooldown_remaining = cooldown
	_effect_remaining = release_effect_duration
	_effect.global_rotation = Vector3(0.0, atan2(-direction.x, -direction.z), 0.0)
	_update_effect()
	released.emit(projectile)
	return true


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if _cooldown_remaining < 0.000001:
		_cooldown_remaining = 0.0
	_effect_remaining = maxf(0.0, _effect_remaining - delta)
	_update_effect()


func _update_effect() -> void:
	_effect.visible = _effect_remaining > 0.0
	if not _effect.visible:
		return
	var progress := 1.0 - _effect_remaining / release_effect_duration
	_effect.scale = Vector3.ONE * lerpf(0.35, 1.4, progress)
	for mesh in _effect.get_children():
		(mesh as GeometryInstance3D).transparency = progress
