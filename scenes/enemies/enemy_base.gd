extends CharacterBody3D
signal enemy_died(enemy: Node3D)
signal pickup_spawned(pickup: Area3D)

const Stats = preload("res://data/enemy_stats.gd")
const HealPickup = preload("res://scenes/items/heal_pickup.tscn")
@export var stats_overrides: Dictionary = {}
var player_ref: CharacterBody3D
var hp: int = 3
var speed: float = 3.0
var damage: int = 1
var drop_chance: float = 0.5
var detect_range: float = 8.0
var _dead: bool = false
var _flash: float = 0.0
var _material: StandardMaterial3D
@onready var detection: Area3D = $DetectionArea
@onready var contact: Area3D = $ContactArea
@onready var cooldown: Timer = $AttackCooldown
@onready var hp_label: Label3D = $HPLabel

func _ready() -> void:
	var values: Dictionary = Stats.DEFAULT.duplicate()
	values.merge(stats_overrides, true)
	hp = maxi(1, int(values["hp"]))
	speed = maxf(0.0, float(values["speed"]))
	damage = maxi(0, int(values["damage"]))
	drop_chance = clampf(float(values["drop_chance"]), 0.0, 1.0)
	detect_range = maxf(0.1, float(values["detect_range"]))
	cooldown.wait_time = maxf(0.01, float(values["attack_cooldown"]))
	var sphere: SphereShape3D = $DetectionArea/CollisionShape3D.shape.duplicate()
	sphere.radius = detect_range
	$DetectionArea/CollisionShape3D.shape = sphere
	_material = $Mesh.mesh.material.duplicate()
	$Mesh.material_override = _material
	hp_label.text = str(hp)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_flash = maxf(0.0, _flash - delta)
	_material.albedo_color = Color.WHITE if _flash > 0 else Color(0.95, 0.19, 0.27)
	if not is_instance_valid(player_ref):
		player_ref = null
		for body in detection.get_overlapping_bodies():
			if body is CharacterBody3D and body.is_in_group("player"):
				player_ref = body
				break
	velocity.x = 0.0
	velocity.z = 0.0
	if is_instance_valid(player_ref):
		var offset: Vector3 = player_ref.global_position - global_position
		if offset.length() <= detect_range:
			offset.y = 0.0
			if offset.length() > 0.8:
				var direction: Vector3 = offset.normalized()
				velocity.x = direction.x * speed
				velocity.z = direction.z * speed
			if cooldown.is_stopped() and contact.overlaps_body(player_ref):
				if player_ref.has_method("take_damage"):
					cooldown.start()
					player_ref.take_damage(damage)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func take_damage(amount: int) -> void:
	if _dead or amount <= 0:
		return
	hp = maxi(0, hp - amount)
	hp_label.text = str(hp)
	_flash = 0.12
	if hp == 0:
		_dead = true # 先防重入，再通知房间/特效。
		velocity = Vector3.ZERO
		enemy_died.emit(self)
		_finish_death.call_deferred()

func _finish_death() -> void:
	# Area3D 回调可能在刷新物理查询；延后实例化避免修改物理世界报错。
	var container: Node = get_parent()
	if is_instance_valid(container) and not container.is_queued_for_deletion():
		if randf() < drop_chance:
			var pickup: Area3D = HealPickup.instantiate()
			pickup.player_ref = player_ref
			pickup.position = (container as Node3D).to_local(global_position)
			container.add_child(pickup)
			pickup_spawned.emit(pickup) # 接收者应在这里连接 item_picked。
	queue_free()

