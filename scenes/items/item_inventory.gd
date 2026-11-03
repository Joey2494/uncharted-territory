extends Node3D

signal inventory_changed(potions: int, runes: int)
signal buff_changed(multiplier: float, remaining: float)
signal pickup_prompt_changed(message: String)
signal feedback(message: String)

const HEALTH_POTION: int = 0
const ATTACK_RUNE: int = 1

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
	return is_node_ready() and can_process() and not _player.is_dead()


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
	return target.try_interact(_player) if target.has_method("try_interact") else target.try_collect(_player)


func add_item(item_type: int) -> bool:
	if not _can_use():
		return false
	match item_type:
		HEALTH_POTION:
			potion_count += 1
			feedback.emit("已拾取生命药剂 · 按 R 使用")
		ATTACK_RUNE:
			rune_count += 1
			feedback.emit("已拾取攻击强化符文 · 按 F 使用")
		_:
			return false
	inventory_changed.emit(potion_count, rune_count)
	return true


func try_use_potion() -> bool:
	if not _can_use() or _use_remaining > 0.0:
		return false
	if potion_count <= 0:
		feedback.emit("没有生命药剂")
		return false
	var restored: int = _player.heal(potion_healing)
	if restored <= 0:
		feedback.emit("生命值已满，药剂未消耗")
		return false
	potion_count -= 1
	_use_remaining = use_cooldown
	_heal_remaining = 0.45
	_heal_pulse.show()
	_heal_pulse.scale = Vector3.ONE * 0.6
	_heal_pulse.transparency = 0.0
	inventory_changed.emit(potion_count, rune_count)
	feedback.emit("使用生命药剂 · 恢复 %d 点生命" % restored)
	return true


func try_use_rune() -> bool:
	if not _can_use() or _use_remaining > 0.0:
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
	inventory_changed.emit(potion_count, rune_count)
	buff_changed.emit(get_multiplier(), _buff_remaining)
	feedback.emit("攻击强化%s · 伤害 ×%s，持续 %s 秒" % ["已刷新" if was_active else "已激活", str(rune_multiplier).trim_suffix(".0"), str(rune_duration).trim_suffix(".0")])
	return true


func get_multiplier() -> float:
	return rune_multiplier if _buff_remaining > 0.0 else 1.0


func get_buff_remaining() -> float:
	return _buff_remaining


func get_attack_damage(base_damage: int) -> int:
	return maxi(0, roundi(base_damage * get_multiplier()))


func _on_player_died() -> void:
	_buff_remaining = 0.0
	_heal_remaining = 0.0
	_buff_aura.hide()
	_heal_pulse.hide()
	buff_changed.emit(1.0, 0.0)
