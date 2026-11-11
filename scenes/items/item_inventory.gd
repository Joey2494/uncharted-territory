extends Node3D

signal pickup_succeeded(target: Node)
signal item_used(item_type: int)
signal inventory_changed(potions: int, runes: int)
signal buff_changed(multiplier: float, remaining: float)
signal pickup_prompt_changed(message: String)
signal feedback(message: String)
signal state_changed(snapshot: Dictionary)
signal gold_changed(amount: int)
signal guard_changed(active: bool)
signal weapon_changed(item_id: int, ammunition: int)
signal purchase_completed(item_id: int, quantity: int, cost: int)

const Catalog = preload("res://data/item_catalog.gd")
const HEALTH_POTION: int = Catalog.HEALTH_POTION
const ATTACK_RUNE: int = Catalog.ATTACK_RUNE
const GUARD_RUNE: int = Catalog.GUARD_RUNE
const FIREARM: int = Catalog.FIREARM

@export_range(1, 100, 1) var potion_healing: int = 2
@export_range(1.1, 5.0, 0.1) var rune_multiplier: float = 2.0
@export_range(1.0, 60.0, 0.5) var rune_duration: float = 10.0
@export_range(0.1, 2.0, 0.05) var use_cooldown: float = 0.25

@onready var _player: CharacterBody3D = get_parent()
@onready var _sensor: Area3D = $PickupSensor
@onready var _heal_pulse: MeshInstance3D = $HealPulse
@onready var _buff_aura: MeshInstance3D = $BuffAura

var potion_count: int = 0
var rune_count: int = 0
var guard_count: int = 0
var gold: int = 0
var ammo: int = 0
var owns_firearm: bool = false
var equipped_weapon: int = Catalog.MELEE
var guard_active: bool = false
var _claimed_rewards: Dictionary = {}
var _publishing: bool = false
var _buff_remaining: float = 0.0
var _use_remaining: float = 0.0
var _heal_remaining: float = 0.0
var _last_buff_second: int = 0
var _last_prompt: String = ""
var _elapsed: float = 0.0


func _ready() -> void:
	_player.died.connect(_on_player_died)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("interact"):
		if try_interact_nearest():
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_health_potion"):
		try_use_potion()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_attack_rune"):
		try_use_rune()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_guard_rune"):
		try_use_guard()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("switch_weapon"):
		if _can_use() and not owns_firearm:
			feedback.emit("尚未获得手炮 · 可先在商城购买")
		else:
			try_equip(Catalog.MELEE if equipped_weapon == FIREARM else FIREARM)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_use_remaining = maxf(0.0, _use_remaining - delta)
	if _use_remaining < 0.000001:
		_use_remaining = 0.0
	if _buff_remaining > 0.0:
		_buff_remaining = maxf(0.0, _buff_remaining - delta)
		if _buff_remaining < 0.000001:
			_buff_remaining = 0.0
		var seconds := int(ceil(_buff_remaining))
		if seconds != _last_buff_second:
			_last_buff_second = seconds
			buff_changed.emit(get_multiplier(), _buff_remaining)
			if _buff_remaining == 0.0:
				feedback.emit("攻击强化已结束")
	_buff_aura.visible = _buff_remaining > 0.0
	_buff_aura.scale = Vector3.ONE * (1.0 + sin(_elapsed * 6.0) * 0.08)
	_heal_remaining = maxf(0.0, _heal_remaining - delta)
	_heal_pulse.visible = _heal_remaining > 0.0
	if _heal_pulse.visible:
		var progress := 1.0 - _heal_remaining / 0.45
		_heal_pulse.scale = Vector3.ONE * lerpf(0.6, 2.2, progress)
		_heal_pulse.transparency = progress
	var nearest := _get_nearest_interaction_target()
	var prompt: String = ""
	if nearest != null:
		prompt = nearest.get_interaction_prompt() if nearest.has_method("get_interaction_prompt") else "[E] 拾取 " + nearest.get_display_name()
	if prompt != _last_prompt:
		_last_prompt = prompt
		pickup_prompt_changed.emit(prompt)


func _can_use() -> bool:
	return is_node_ready() and can_process() and not _player.is_dead() and not _publishing


func _can_use_menu(menu: Node, purchasing: bool) -> bool:
	# Only the bound, open commerce view may transact while gameplay is paused.
	# Rewards, pickups, firing and hotkeys retain the normal processing guard.
	return is_node_ready() and not _publishing and not _player.is_dead() \
		and is_instance_valid(menu) and menu.is_in_group("commerce_controllers") \
		and menu.has_method("allows_inventory_action") \
		and menu.allows_inventory_action(self, purchasing)


func get_nearest_pickup() -> Area3D:
	if not _can_use():
		return null
	var nearest: Area3D = null
	var best_distance: float = INF
	for area in _sensor.get_overlapping_areas():
		if area.has_method("can_collect") and area.can_collect(_player):
			var distance := _player.global_position.distance_squared_to(area.global_position)
			if distance < best_distance:
				nearest = area
				best_distance = distance
	return nearest


func try_pickup_nearest() -> bool:
	var item := get_nearest_pickup()
	return item != null and item.try_collect(_player)


func _get_nearest_interaction_target() -> Node3D:
	if not _can_use():
		return null
	var nearest: Node3D = get_nearest_pickup()
	var best_distance := _player.global_position.distance_squared_to(nearest.global_position) if nearest != null else INF
	for node in get_tree().get_nodes_in_group("world_interactables"):
		if not node is Node3D or not _player.get_parent().is_ancestor_of(node) or node.is_queued_for_deletion():
			continue
		if not node.has_method("can_interact") or not node.can_interact(_player):
			continue
		var distance: float = _player.global_position.distance_squared_to(node.global_position)
		if distance < best_distance:
			nearest = node
			best_distance = distance
	return nearest


func try_interact_nearest() -> bool:
	var target := _get_nearest_interaction_target()
	if target == null:
		return false
	var success: bool = target.try_interact(_player) if target.has_method("try_interact") else target.try_collect(_player)
	if success:
		pickup_succeeded.emit(target)
	return success


func add_item(item_type: int, quantity: int = 1) -> bool:
	if not grant_reward("", {item_type: quantity}):
		return false
	feedback.emit("获得 %s ×%d" % [Catalog.get_item(item_type).name, quantity])
	return true


func try_use_potion(menu: Node = null) -> bool:
	if (not _can_use() and not _can_use_menu(menu, false)) or _use_remaining > 0.0:
		return false
	if potion_count <= 0:
		feedback.emit("没有生命药剂")
		return false
	_publishing = true
	var restored: int = _player.heal(potion_healing, menu)
	_publishing = false
	if restored <= 0:
		feedback.emit("生命值已满，药剂未消耗")
		return false
	potion_count -= 1
	_use_remaining = use_cooldown
	_heal_remaining = 0.45
	_heal_pulse.show()
	_heal_pulse.scale = Vector3.ONE * 0.6
	_heal_pulse.transparency = 0.0
	_publish_state()
	item_used.emit(HEALTH_POTION)
	feedback.emit("使用生命药剂 · 恢复 %d 点生命" % restored)
	return true


func try_use_rune(menu: Node = null) -> bool:
	if (not _can_use() and not _can_use_menu(menu, false)) or _use_remaining > 0.0:
		return false
	if rune_count <= 0:
		feedback.emit("没有攻击强化符文")
		return false
	var was_active := _buff_remaining > 0.0
	rune_count -= 1
	_buff_remaining = rune_duration
	_last_buff_second = int(ceil(_buff_remaining))
	_use_remaining = use_cooldown
	_buff_aura.show()
	_publish_state()
	buff_changed.emit(get_multiplier(), _buff_remaining)
	item_used.emit(ATTACK_RUNE)
	feedback.emit("攻击强化%s · 伤害 ×%s，持续 %s 秒" % ["已刷新" if was_active else "已激活", str(rune_multiplier).trim_suffix(".0"), str(rune_duration).trim_suffix(".0")])
	return true


func get_multiplier() -> float:
	return rune_multiplier if _buff_remaining > 0.0 else 1.0


func get_buff_remaining() -> float:
	return _buff_remaining


func get_use_cooldown_remaining() -> float:
	return _use_remaining


func get_attack_damage(base_damage: int) -> int:
	return maxi(0, roundi(base_damage * get_multiplier()))


func _on_player_died() -> void:
	_buff_remaining = 0.0
	_heal_remaining = 0.0
	guard_active = false
	_buff_aura.hide()
	_heal_pulse.hide()
	buff_changed.emit(1.0, 0.0)
	_publish_state()


func get_count(item_id: int) -> int:
	match item_id:
		HEALTH_POTION: return potion_count
		ATTACK_RUNE: return rune_count
		GUARD_RUNE: return guard_count
		FIREARM: return 1 if owns_firearm else 0
		Catalog.AMMO: return ammo
	return 0


func get_snapshot() -> Dictionary:
	return {
		"gold": gold, "items": {HEALTH_POTION: potion_count, ATTACK_RUNE: rune_count,
		GUARD_RUNE: guard_count, FIREARM: get_count(FIREARM), Catalog.AMMO: ammo},
		"equipped_weapon": equipped_weapon, "ammo": ammo, "guard_active": guard_active,
		"attack_multiplier": get_multiplier(), "buff_remaining": _buff_remaining,
	}


func _publish_state() -> void:
	# A synchronous UI callback cannot start a second transaction halfway through.
	_publishing = true
	inventory_changed.emit(potion_count, rune_count)
	gold_changed.emit(gold)
	guard_changed.emit(guard_active)
	weapon_changed.emit(equipped_weapon, ammo)
	state_changed.emit(get_snapshot())
	_publishing = false


func has_claimed(source_id: String) -> bool:
	return not source_id.is_empty() and _claimed_rewards.has(source_id)


func _can_receive(items: Dictionary, coins: int) -> bool:
	if coins < 0 or gold > Catalog.MAX_GOLD - coins:
		return false
	var added_ammo := int(items.get(Catalog.AMMO, 0))
	for item_id in items:
		var quantity = items[item_id]
		if not item_id is int or not quantity is int or quantity <= 0 or not Catalog.ITEMS.has(item_id):
			return false
		if item_id == FIREARM:
			if quantity != 1:
				return false
			added_ammo += Catalog.INITIAL_AMMO
		elif get_count(item_id) > Catalog.MAX_STACK - quantity:
			return false
	return ammo <= Catalog.MAX_STACK - added_ammo


func _receive(items: Dictionary, coins: int) -> void:
	gold += coins
	potion_count += int(items.get(HEALTH_POTION, 0))
	rune_count += int(items.get(ATTACK_RUNE, 0))
	guard_count += int(items.get(GUARD_RUNE, 0))
	ammo += int(items.get(Catalog.AMMO, 0))
	if items.has(FIREARM):
		# A second weapon reward becomes ammunition without creating two weapons.
		owns_firearm = true
		ammo += Catalog.INITIAL_AMMO


func grant_reward(source_id: String, items: Dictionary, coins: int = 0) -> bool:
	if not _can_use() or has_claimed(source_id) or (items.is_empty() and coins == 0) or not _can_receive(items, coins):
		return false
	if not source_id.is_empty():
		_claimed_rewards[source_id] = true
	_receive(items, coins)
	_publish_state()
	return true


func add_gold(amount: int, source_id: String = "") -> bool:
	return amount > 0 and grant_reward(source_id, {}, amount)


func get_purchase_error(item_id: int, quantity: int = 1, menu: Node = null) -> String:
	if not _can_use() and not _can_use_menu(menu, true):
		return "当前无法购买"
	var product := Catalog.get_item(item_id)
	if product.is_empty() or quantity <= 0 or quantity > 99:
		return "无效商品或数量"
	if item_id == FIREARM and (owns_firearm or quantity != 1):
		return "已拥有手炮" if owns_firearm else "每次只能购买一把手炮"
	if item_id == Catalog.AMMO and not owns_firearm:
		return "请先获得手炮"
	if gold < int(product.price) * quantity:
		return "金币不足"
	if not _can_receive({item_id: int(product.quantity) * quantity}, 0):
		return "背包已满"
	return ""


func try_purchase(item_id: int, quantity: int = 1, menu: Node = null) -> bool:
	if _publishing:
		return false
	var error := get_purchase_error(item_id, quantity, menu)
	if not error.is_empty():
		feedback.emit(error)
		return false
	var product := Catalog.get_item(item_id)
	var cost := int(product.price) * quantity
	# Commit both changes before any signal or user callback can observe them.
	gold -= cost
	_receive({item_id: int(product.quantity) * quantity}, 0)
	_publish_state()
	_publishing = true
	purchase_completed.emit(item_id, int(product.quantity) * quantity, cost)
	feedback.emit("购买成功：%s" % product.name)
	_publishing = false
	return true


func try_use_item(item_id: int, menu: Node = null) -> bool:
	match item_id:
		HEALTH_POTION: return try_use_potion(menu)
		ATTACK_RUNE: return try_use_rune(menu)
		GUARD_RUNE: return try_use_guard(menu)
		FIREARM: return try_equip(FIREARM, menu)
	return false


func try_use_guard(menu: Node = null) -> bool:
	if (not _can_use() and not _can_use_menu(menu, false)) or _use_remaining > 0.0 or guard_count <= 0:
		return false
	if guard_active:
		feedback.emit("守护已生效，符文未消耗")
		return false
	guard_count -= 1
	guard_active = true
	_use_remaining = use_cooldown
	_publish_state()
	feedback.emit("守护已激活")
	return true


func consume_guard() -> bool:
	if not _can_use() or not guard_active:
		return false
	guard_active = false
	_publish_state()
	feedback.emit("守护抵挡了一次伤害")
	return true


func try_equip(item_id: int, menu: Node = null) -> bool:
	if (not _can_use() and not _can_use_menu(menu, false)) or (item_id != Catalog.MELEE and item_id != FIREARM):
		return false
	if item_id == FIREARM and not owns_firearm:
		return false
	if _player.is_dodging() or _player.get_node("MeleeAttack").is_attacking():
		return false
	var ability := _player.get_node("CharacterAbility")
	if ability.is_guarding() or ability.is_casting() or _player.get_node("EnergyShock").is_action_locked():
		return false
	equipped_weapon = item_id
	_publish_state()
	feedback.emit("已切换手炮 · J 开火，I 切回近战" if item_id == FIREARM else "已切换近战 · J 攻击，I 切换手炮")
	return true


func try_spend_ammo() -> bool:
	if not _can_use() or equipped_weapon != FIREARM or not owns_firearm or ammo <= 0:
		return false
	ammo -= 1
	_publish_state()
	return true
