extends Node3D
## 入口教学控制器。只消费实际角色动作、实物拾取和库存使用结果。

signal step_changed(prompt: String, step: int, total: int)
signal completed(skipped: bool)
signal feedback(message: String)
signal stopped

enum Step { MOVE, PICKUP_POTION, USE_POTION, MELEE, SPELL, DODGE, PICKUP_RUNE, USE_RUNE }

const PROMPTS: Array[String] = [
	"用 WASD 或方向键移动，累计行走 3 米。",
	"走到大厅左侧的生命药剂旁，按 E 拾取。",
	"按 R 使用生命药剂，恢复生命值。",
	"走近左侧靶，面向靶后按鼠标左键。",
	"从蓝圈沿虚线向靶走，面向靶后按 Q。",
	"前往右侧空地，按方向键与空格闪避。",
	"走到大厅右侧的攻击符文旁，按 E 拾取。",
	"按 F 使用攻击符文，获得攻击强化。"
]

@onready var _movement: Node3D = $MovementGuide
@onready var _melee_station: Node3D = $MeleeTargetPoint
@onready var _spell_station: Node3D = $SpellTargetPoint
@onready var _dodge_guide: Node3D = $DodgeGuide
@onready var _potion: Area3D = $PickupPoint/PracticePotion
@onready var _rune: Area3D = $RunePoint/PracticeRune

var _player: CharacterBody3D
var _items: Node3D
var _attack: Node3D
var _skill: Node3D
var _active := false
var _started := false
var _stopped := false
var _step := Step.MOVE
var _prompt := ""
var _walked := 0.0
var _previous_position: Vector3
var _last_potions := 0
var _last_runes := 0
var _last_hp := 0
var _heal_observed := false
var _demo_damage_applied := false
var _demo_damage_pending := false
var _dodge_started_in_step := false


func _ready() -> void:
	# 在玩家 move_and_slide 后核对实际位移，排除外部传送。
	process_physics_priority = 10
	_potion.collected.connect(_on_practice_pickup.bind(Step.PICKUP_POTION))
	_rune.collected.connect(_on_practice_pickup.bind(Step.PICKUP_RUNE))
	_update_stations()


## 每个场景实例仅可开始一次，传入本局的实际玩家。
func begin(player: CharacterBody3D) -> bool:
	if _started or _stopped or not can_process() or not is_instance_valid(player) or player.is_dead():
		return false
	_started = true
	_active = true
	_player = player
	_items = player.get_node("ItemInventory")
	_attack = player.get_node("MeleeAttack")
	_skill = player.get_node("EnergyShock")
	_previous_position = player.global_position
	_last_hp = player.hp
	_last_potions = _items.potion_count
	_last_runes = _items.rune_count
	_player.hp_changed.connect(_on_hp_changed)
	_player.dodge_started.connect(_on_dodge_started)
	_player.dodge_finished.connect(_on_dodge_finished)
	_player.died.connect(stop)
	_items.inventory_changed.connect(_on_inventory_changed)
	_attack.hit_detected.connect(_on_melee_hit)
	_skill.released.connect(_on_spell_released)
	_show_step(Step.MOVE)
	return true


## 暂停、未开始或已结束时拒绝跳过。只有本次演示扣除的生命会被补回。
func request_skip() -> bool:
	if not _can_advance():
		return false
	var restore := _demo_damage_pending
	stop()
	if restore:
		_player.heal(1)
	completed.emit(true)
	return true


## 清理本局教学实物与监听。死亡或其他终局调用时不触发完成。
func stop() -> void:
	if _stopped:
		return
	_stopped = true
	_active = false
	_update_stations()
	stopped.emit()
	# 已拾道具由原库存保留，剩余练习品随教学一起移除。
	if is_instance_valid(_potion):
		_potion.queue_free()
	if is_instance_valid(_rune):
		_rune.queue_free()
	if not is_instance_valid(_player):
		return
	_player.hp_changed.disconnect(_on_hp_changed)
	_player.dodge_started.disconnect(_on_dodge_started)
	_player.dodge_finished.disconnect(_on_dodge_finished)
	_player.died.disconnect(stop)
	_items.inventory_changed.disconnect(_on_inventory_changed)
	_attack.hit_detected.disconnect(_on_melee_hit)
	_skill.released.disconnect(_on_spell_released)


func is_active() -> bool:
	return _active


func get_step() -> int:
	return _step


func get_prompt() -> String:
	return _prompt


func _can_advance() -> bool:
	return _active and can_process() and is_instance_valid(_player) and not _player.is_dead()


func _physics_process(delta: float) -> void:
	if not _can_advance():
		return
	if _step == Step.USE_POTION:
		_prepare_potion_demo()
	if _step != Step.MOVE:
		return
	var position_delta := _player.global_position - _previous_position
	_previous_position = _player.global_position
	var walked := Vector2(position_delta.x, position_delta.z)
	var slide := _player.get_position_delta()
	var walk_direction := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var walk_velocity := Vector2(_player.velocity.x, _player.velocity.z)
	if _player.is_dodging() or walk_velocity.dot(walk_direction) <= 0.0:
		return
	# 既要求有方向输入，也要求位移吻合本帧移动结果和最大步长。
	if walked.distance_to(Vector2(slide.x, slide.z)) > 0.008 or walked.length() > _player.move_speed * delta + 0.008:
		return
	_walked += maxf(0.0, walked.dot(walk_direction.normalized()))
	if _walked >= 3.0:
		_show_step(Step.PICKUP_POTION)


func _show_step(step: Step, prefix: String = "") -> void:
	_step = step
	_prompt = prefix + PROMPTS[step]
	_update_stations()
	step_changed.emit(_prompt, _step, PROMPTS.size())


func _update_stations() -> void:
	_movement.visible = _active and _step == Step.MOVE
	_set_station(_melee_station, _active and _step == Step.MELEE)
	_set_station(_spell_station, _active and _step == Step.SPELL)
	_dodge_guide.visible = _active and _step == Step.DODGE
	_set_pickup(_potion, _active and _step == Step.PICKUP_POTION)
	_set_pickup(_rune, _active and _step == Step.PICKUP_RUNE)


func _set_station(station: Node3D, enabled: bool) -> void:
	station.visible = enabled
	station.get_node("Target").set_deferred("collision_layer", 4 if enabled else 0)
	if station.has_node("Backstop"):
		station.get_node("Backstop").set_deferred("collision_layer", 1 if enabled else 0)


func _set_pickup(pickup: Area3D, enabled: bool) -> void:
	if is_instance_valid(pickup) and not pickup.is_queued_for_deletion():
		pickup.visible = enabled
		pickup.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED


## 实物拾取复用库存模块的成功返回值，脚本无重复 E 监听。
func _on_practice_pickup(player: CharacterBody3D, step: Step) -> void:
	if not _can_advance() or player != _player or _step != step:
		return
	if step == Step.PICKUP_POTION:
		_potion = null
		if _player.max_hp <= 1:
			_show_step(Step.MELEE, "生命上限为 1，保留药剂。")
			return
		_show_step(Step.USE_POTION)
		_prepare_potion_demo()
	else:
		_rune = null
		_show_step(Step.USE_RUNE)


func _prepare_potion_demo() -> void:
	if _demo_damage_applied or _player.hp != _player.max_hp or _player.hp <= 1:
		return
	# 闪避或已有无敌帧时 take_damage 会拒绝，下一物理帧重试。
	if _player.take_damage(1):
		_demo_damage_applied = true
		_demo_damage_pending = true
		_show_step(Step.USE_POTION, "练习扣除 1 点生命。")
		feedback.emit("练习损失 1 点生命 · 按 R 恢复")


func _on_hp_changed(hp: int, maximum: int) -> void:
	_heal_observed = hp > _last_hp
	_last_hp = hp
	if hp >= maximum:
		_demo_damage_pending = false


func _on_inventory_changed(potions: int, runes: int) -> void:
	var healed_with_potion := potions < _last_potions and _heal_observed
	var applied_rune: bool = runes < _last_runes and _items.get_multiplier() > 1.0 and _items.get_buff_remaining() > 0.0
	_last_potions = potions
	_last_runes = runes
	_heal_observed = false
	if not _can_advance():
		return
	if _step == Step.USE_POTION and healed_with_potion:
		_demo_damage_pending = false
		_show_step(Step.MELEE)
	elif _step == Step.USE_RUNE and applied_rune:
		stop()
		completed.emit(false)


func _on_melee_hit(target: Node, _amount: int) -> void:
	if _can_advance() and _step == Step.MELEE and target == _melee_station.get_node("Target"):
		_show_step(Step.SPELL)


func _on_spell_released(projectile: Node3D) -> void:
	if _can_advance() and _step == Step.SPELL:
		projectile.impacted.connect(_on_spell_impact, CONNECT_ONE_SHOT)


func _on_spell_impact(target: Node) -> void:
	if _can_advance() and _step == Step.SPELL and target == _spell_station.get_node("Target"):
		_show_step(Step.DODGE)


func _on_dodge_started() -> void:
	_dodge_started_in_step = _can_advance() and _step == Step.DODGE


func _on_dodge_finished() -> void:
	if _dodge_started_in_step and _can_advance() and _step == Step.DODGE:
		_show_step(Step.PICKUP_RUNE)
	_dodge_started_in_step = false
