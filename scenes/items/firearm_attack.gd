extends Node3D

signal fired(projectile: Node3D)

const Catalog = preload("res://data/item_catalog.gd")
const BULLET: PackedScene = preload("res://scenes/skills/EnergyBolt.tscn")

@export_range(1, 20) var damage: int = 2
@export_range(0.1, 2.0, 0.05) var cooldown: float = 0.35
@export var projectile_speed: float = 30.0
@export var max_distance: float = 14.0

var _remaining := 0.0
var _gun: MeshInstance3D
@onready var _player: CharacterBody3D = get_parent()
@onready var _inventory: Node3D = $"../ItemInventory"


func _ready() -> void:
	_gun = MeshInstance3D.new()
	var barrel := BoxMesh.new()
	barrel.size = Vector3(0.18, 0.22, 0.65)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.65, 0.72)
	material.metallic = 0.7
	barrel.material = material
	_gun.mesh = barrel
	_gun.position = Vector3(0.48, 0.95, -0.35)
	_player.get_node("Visuals").add_child(_gun)
	_inventory.weapon_changed.connect(_on_weapon_changed)
	_on_weapon_changed(_inventory.equipped_weapon, _inventory.ammo)


func _on_weapon_changed(item_id: int, _ammunition: int) -> void:
	_gun.visible = item_id == Catalog.FIREARM
	var sword := _player.get_node_or_null("Visuals/Model/Knight/Rig_Medium/Skeleton3D/RightHandWeapon") as Node3D
	if sword != null:
		sword.visible = not _gun.visible


func _physics_process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)


func get_cooldown_remaining() -> float:
	return _remaining


func try_fire() -> bool:
	if not is_node_ready() or not can_process() or _remaining > 0.0 or _player.is_dead() or _player.is_dodging():
		return false
	if _inventory.equipped_weapon != Catalog.FIREARM or _player.get_node("MeleeAttack").is_attacking():
		return false
	if _inventory.ammo <= 0:
		_inventory.feedback.emit("弹药不足")
		return false
	_remaining = cooldown
	if not _inventory.try_spend_ammo():
		_remaining = 0.0
		return false
	var projectile := BULLET.instantiate() as CharacterBody3D
	var direction: Vector3 = -_player.get_node("Visuals").global_basis.z
	direction.y = 0.0
	_player.get_parent().add_child(projectile)
	projectile.global_position = _player.global_position + Vector3.UP * 0.95
	projectile.scale = Vector3.ONE * 0.4
	projectile.launch(direction.normalized(), _player.get_attack_damage(damage), projectile_speed, max_distance, _player)
	fired.emit(projectile)
	return true
