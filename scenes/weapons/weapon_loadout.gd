extends Node3D
signal changed
signal fired(projectile: Node3D)
const CATALOG = preload("res://scenes/weapons/weapon_catalog.gd")
const BOLT = preload("res://scenes/skills/EnergyBolt.tscn")
var slots: Array[Dictionary] = []
var active: int = 0
var switch_remaining: float = 0.0
var reload_remaining: float:
	get:
		return slots[active].get("reload",0.0) if not slots.is_empty() else 0.0
	set(value):
		if not slots.is_empty(): slots[active].reload = value
var action_remaining: float = 0.0
var _socket: BoneAttachment3D
var _model: Node3D
var _recoil: float = 0.0
@onready var actor: CharacterBody3D = get_parent()

func _ready() -> void:
	for id in CATALOG.LOADOUTS[actor.character_id]: slots.append(CATALOG.state(id))
	actor.dodge_started.connect(cancel_reload)
	actor.died.connect(cancel_reload)
	actor.get_node("MeleeAttack").hit_confirmed.connect(_on_melee_hit)
	var skeleton: Skeleton3D = actor.get_node("Visuals/Model/Knight/Rig_Medium/Skeleton3D")
	_socket = BoneAttachment3D.new()
	_socket.name = "EquippedWeapon"
	_socket.bone_name = "handslot.r"
	skeleton.add_child(_socket)
	# Retire the old shop handcannon presentation and its independent combat path.
	actor.get_node("Firearm").set_process(false)
	actor.get_node("Firearm").set_physics_process(false)
	actor.get_node("Firearm")._gun.hide()
	_show_weapon()

func current() -> Dictionary:
	return CATALOG.definition(slots[active].id)

func cost() -> int:
	return CATALOG.energy_cost(slots[active].id,actor.character_id)

func available() -> bool:
	if not is_node_ready() or not can_process() or actor.is_dead() or actor.is_dodging(): return false
	var ability := actor.get_node("CharacterAbility")
	return not ability.is_guarding() and not ability.is_casting() and action_remaining <= 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo(): return
	if event.is_action_pressed("reload_weapon"):
		try_replenish()
		get_viewport().set_input_as_handled()

func can_switch() -> bool:
	return available() and switch_remaining <= 0.0 and actor.get_node("MeleeAttack").can_chain_cast()

func try_switch() -> bool:
	if not can_switch(): return false
	actor.get_node("MeleeAttack").cancel_attack()
	actor.get_node("CastAnimation").cancel()
	active = 1-active
	switch_remaining = 0.2
	_show_weapon()
	actor.feedback.emit("切换 · "+current().name)
	changed.emit()
	return true

func ammo_type() -> int:
	return 6 if slots[active].id == "pistol" else (7 if slots[active].id == "coil" else -1)

func reserve_ammo() -> int:
	return actor.get_node("ItemInventory").get_count(ammo_type()) if ammo_type() >= 0 else 0

func replenishment_block_reason() -> String:
	if not available(): return "暂不可用"
	if switch_remaining > 0: return "切换中"
	if not actor.get_node("MeleeAttack").can_chain_cast(): return "攻击中"
	if ammo_type() >= 0:
		if reload_remaining > 0: return "换弹中"
		if slots[active].ammo >= current().magazine: return "弹匣已满"
		if reserve_ammo() <= 0: return "弹药不足"
		return ""
	if current().melee: return "无需补给"
	var items := actor.get_node("ItemInventory")
	if actor.energy >= actor.max_energy: return "法力已满"
	if items.energy_potion_count <= 0: return "缺少蓝药"
	if items.get_use_cooldown_remaining() > 0: return "补给冷却"
	return ""

func try_replenish() -> bool:
	var reason := replenishment_block_reason()
	if not reason.is_empty():
		actor.feedback.emit(reason)
		return false
	if ammo_type() >= 0: return try_reload()
	if not current().melee: return actor.get_node("ItemInventory").try_use_energy_potion()
	return false

func try_reload() -> bool:
	if not available() or switch_remaining > 0 or reload_remaining > 0 or not actor.get_node("MeleeAttack").can_chain_cast(): return false
	if current().magazine == 0 or slots[active].ammo >= current().magazine: return false
	if reserve_ammo() <= 0:
		actor.feedback.emit("对应备用弹药不足")
		return false
	actor.get_node("MeleeAttack").cancel_attack()
	actor.get_node("CastAnimation").cancel()
	reload_remaining = current().reload
	actor.feedback.emit("换弹 · "+current().name)
	return true

func cancel_reload() -> void:
	reload_remaining = 0.0

func try_attack() -> bool:
	if not available() or switch_remaining > 0 or reload_remaining > 0 or slots[active].cooldown > 0: return false
	var melee := actor.get_node("MeleeAttack")
	if not melee.can_chain_cast(): return false
	var d := current()
	if current().magazine > 0 and slots[active].ammo <= 0:
		actor.feedback.emit("弹匣已空")
		return false
	if actor.energy < cost():
		actor.feedback.emit("法力不足")
		return false
	if d.melee:
		melee.attack_damage = d.damage
		melee.attack_cooldown = d.interval
		if not melee.try_melee_attack(): return false
	else:
		melee.cancel_attack()
		var projectile := BOLT.instantiate()
		actor.get_parent().add_child(projectile)
		projectile.global_position = actor.global_position + Vector3.UP*0.95
		projectile.scale = Vector3.ONE*0.52
		projectile.weapon_id = slots[active].id
		projectile.set_tint(d.color)
		var bonus := 0
		if active == 1: bonus = actor.get_node("CharacterAbility").consume_prepared_shot()
		var direction: Vector3 = -actor.visuals.global_basis.z
		projectile.launch(direction,actor.get_attack_damage(d.damage+bonus),d.speed,d.range,actor)
		actor.get_node("CharacterAbility").record_attack()
		actor.get_node("CastAnimation")._on_released(projectile)
		action_remaining = 0.18
		_recoil = 0.10
		fired.emit(projectile)
	# No resource is committed until an attack actually exists.
	if cost() > 0: actor.spend_energy(cost())
	if d.magazine > 0: slots[active].ammo -= 1
	slots[active].cooldown = d.interval / (1.3 if actor.get_node("CharacterAbility").is_focused() else 1.0)
	changed.emit()
	return true

func _physics_process(delta: float) -> void:
	for slot in slots: slot.cooldown = maxf(0,slot.cooldown-delta)
	switch_remaining = maxf(0,switch_remaining-delta)
	action_remaining = maxf(0,action_remaining-delta)
	if reload_remaining > 0:
		reload_remaining = maxf(0,reload_remaining-delta)
		if reload_remaining <= 0.000001:
			reload_remaining = 0
			var loaded: int = actor.get_node("ItemInventory").try_load_magazine(ammo_type(),current().magazine-slots[active].ammo)
			slots[active].ammo += loaded
			changed.emit()
	_recoil = maxf(0,_recoil-delta)
	if is_instance_valid(_model):
		_model.position.z = _recoil*0.5
		_model.rotation.z = sin(reload_remaining*8.0)*0.22 if reload_remaining > 0 else 0.0
		_model.scale = Vector3.ONE * (0.5 if switch_remaining > 0.1 else 1.0)
		_update_grip()

func _update_grip() -> void:
	# KayKit's sword socket points down at rest. Staves remain upright and gun
	# muzzles follow the same forward axis used by the actual projectile.
	if current().melee: return
	var size := _socket.global_basis.get_scale().x * (0.5 if switch_remaining > 0.1 else 1.0)
	var tilt := -0.35 if slots[active].id in ["pistol","coil"] else (-0.45 if action_remaining > 0 else 0.0)
	if reload_remaining > 0: tilt += sin(reload_remaining*8.0)*0.25
	var lean := 0.28 if slots[active].id == "fire" else 0.0
	_model.global_basis = (actor.get_node("Visuals").global_basis.orthonormalized()*Basis(Vector3.RIGHT,tilt)*Basis(Vector3.FORWARD,lean)).scaled(Vector3.ONE*size)

func _show_weapon() -> void:
	if is_instance_valid(_model):
		_socket.remove_child(_model)
		_model.queue_free()
	_model = (load("res://assets/weapons/models/"+slots[active].id+".tscn") as PackedScene).instantiate()
	_socket.add_child(_model)
	_update_grip()
	var old := actor.get_node_or_null("Visuals/Model/Knight/Rig_Medium/Skeleton3D/RightHandWeapon")
	if old != null: old.hide()

func _on_melee_hit(target: Node, _amount: int) -> void:
	if target is CharacterBody3D and not target.is_in_group("bosses"):
		var offset: Vector3 = target.global_position-actor.global_position
		offset.y = 0
		# Swept motion cannot push through walls.
		target.move_and_collide(offset.normalized()*0.12)

func replace_current(_incoming: Dictionary) -> bool:
	actor.feedback.emit("角色专属武器不可替换")
	return false
