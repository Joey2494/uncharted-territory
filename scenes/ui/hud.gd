extends Control
## Presentation-only HUD. Call its methods after the scene has entered the tree.
## Room indices are zero-based: 0 -> room 1, 2 -> room 3.

const EMPTY_WEAPON_ICON: Texture2D = preload("res://assets/ui/weapon_empty.svg")
const EQUIPPED_WEAPON_ICON: Texture2D = preload("res://assets/ui/weapon_equipped.svg")
const POTION_ICON: Texture2D = preload("res://assets/ui/potion.svg")
const ATTACK_RUNE_ICON: Texture2D = preload("res://assets/ui/attack_rune.svg")
const DEATH_SCREEN: PackedScene = preload("res://scenes/ui/death_screen.tscn")
const WIN_SCREEN: PackedScene = preload("res://scenes/ui/win_screen.tscn")
const CURRENT_ROOM_COLOR: Color = Color("b99a5c")
const VISITED_ROOM_COLOR: Color = Color("756442")

signal restart_requested
signal next_level_requested
signal main_menu_requested
# Legacy request ports; generic hotbar selection is a separate UI-only request.
signal use_potion_requested
signal use_rune_requested
signal skip_tutorial_requested
signal hotbar_selection_requested(index: int, item_id: StringName)
signal combat_action_requested(action: StringName, pressed: bool)

@export_range(1, 99, 1) var total_rooms: int = 3

@onready var energy_bar: ProgressBar = %EnergyBar
@onready var energy_text: Label = %EnergyText
@onready var gold_label: Label = %GoldLabel
@onready var ammo_label: Label = %AmmoLabel
@onready var guard_rune_label: Label = %GuardRuneLabel
@onready var guard_rune_detail: Label = %GuardRuneDetail
@onready var guard_rune_icon: TextureRect = %GuardRuneIcon

@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_text: Label = %HPText
@onready var room_label: Label = %RoomLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var weapon_hint: Label = %WeaponHint
@onready var hp_state_label: Label = %HPStateLabel
@onready var weapon_icon: TextureRect = %WeaponIcon
@onready var room_badge: PanelContainer = %RoomBadge
@onready var room_icon: TextureRect = %RoomIcon
@onready var room_segments: HBoxContainer = %RoomSegments
@onready var feedback_panel: PanelContainer = %FeedbackPanel
@onready var hotbar: PanelContainer = %Hotbar
@onready var pickup_prompt: Label = %PickupPrompt
@onready var item_message: Label = %ItemMessage
@onready var melee_cooldown: PanelContainer = %MeleeCooldown
@onready var dodge_cooldown: PanelContainer = %DodgeCooldown
@onready var skill_cooldown: PanelContainer = %SkillCooldown
@onready var switch_cooldown: PanelContainer = %SwitchCooldown
@onready var replenish_cooldown: PanelContainer = %ReplenishCooldown

var _hp_fill: StyleBoxFlat
var _result_layer: CanvasLayer
var _result_screen: Control
var _room_segment_fills: Array[StyleBoxFlat] = []
var _message_remaining: float = 0.0
var _combat_player: CharacterBody3D
var _combat_attack: Node3D
var _combat_skill: Node3D
var _character_skill_id: String = ""
var _tutorial_mode: bool = false
var _tutorial_message: String = ""
var _tutorial_move_directions: Array[String] = []
var _revealed_actions: Array[String] = []
var _nearby_prompt: String = ""
var hint_dock: Node
var _feedback_queue: Array[Dictionary] = []
var _feedback_active := {}
var _feedback_clock := 0.0


func _ready() -> void:
	_hp_fill = hp_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	hp_bar.add_theme_stylebox_override("fill", _hp_fill)
	update_energy_bar(0.0, 0.0)
	update_gold(0)
	update_ammo(0)
	update_guard_rune(&"none")
	update_room_label(0)
	%TutorialPrompt.skip_requested.connect(func() -> void: skip_tutorial_requested.emit())
	hotbar.selection_requested.connect(func(index: int, item_id: StringName) -> void: hotbar_selection_requested.emit(index, item_id))
	replenish_cooldown.activation_requested.connect(func() -> void: combat_action_requested.emit(&"reload_weapon",true))
	switch_cooldown.activation_requested.connect(func() -> void: combat_action_requested.emit(&"switch_weapon", true))
	melee_cooldown.activation_requested.connect(func() -> void: combat_action_requested.emit(&"attack", true))
	skill_cooldown.activation_requested.connect(func() -> void: combat_action_requested.emit(&"skill_1", true))
	dodge_cooldown.activation_requested.connect(func() -> void: combat_action_requested.emit(&"dodge", true))
	%CharacterCooldown.activation_started.connect(func() -> void: combat_action_requested.emit(&"character_skill", true))
	%CharacterCooldown.activation_ended.connect(func() -> void: combat_action_requested.emit(&"character_skill", false))
	%CharacterCooldown.hide()
	item_message.hide()
	update_pickup_prompt("")
	hint_dock = preload("res://scenes/ui/right_hint_dock.gd").new()
	hint_dock.name = "RightHintDock"
	add_child(hint_dock)


func _process(delta: float) -> void:
	_update_combat_cooldowns()
	if is_instance_valid(hint_dock) and hint_dock.is_running(): _advance_feedback(delta)


func bind_combat_actions(player: CharacterBody3D) -> void:
	_combat_player = player
	_character_skill_id = ""
	_combat_attack = player.get_node_or_null("MeleeAttack") if is_instance_valid(player) else null
	_combat_skill = player.get_node_or_null("EnergyShock") if is_instance_valid(player) else null
	_update_combat_cooldowns()


func _update_combat_cooldowns() -> void:
	if not is_instance_valid(_combat_player) or not is_instance_valid(_combat_attack) or not is_instance_valid(_combat_skill):
		for indicator in [melee_cooldown, dodge_cooldown, skill_cooldown, switch_cooldown, replenish_cooldown]:
			indicator.update_cooldown(0.0, 1.0, "未就绪")
		%CharacterCooldown.hide()
		_character_skill_id = ""
		return
	var ability := _combat_player.get_node("CharacterAbility")
	if _character_skill_id != _combat_player.character_id:
		var configuration: Dictionary = ability.get_configuration()
		%CharacterCooldown.configure_ability(configuration.name,configuration.icon,configuration.description)
		%CharacterCooldown.visible = configuration.active
		_character_skill_id = _combat_player.character_id
	var ability_block := ""
	if _combat_player.is_dead() or not _combat_player.can_process():
		ability_block = "暂不可用"
	elif _combat_player.is_dodging():
		ability_block = "闪避中"
	elif ability.is_casting():
		ability_block = "施法中"
	elif ability.is_guarding():
		ability_block = "举盾中"
	elif ability.remaining > 0.0:
		ability_block = "持续 %.1fs" % ability.remaining
	%CharacterCooldown.update_cooldown(ability.get_cooldown_remaining(), ability.get_cooldown_duration(), ability_block)
	# Read the same timers and guards used by the actions, including freeze/death.
	# This HUD owns no cooldown clock and never changes an action's state.
	var blocked := ""
	if _combat_player.is_dead():
		blocked = "已死亡"
	elif not _combat_player.can_process():
		blocked = "暂不可用"
	var attack_block := blocked
	if attack_block.is_empty():
		if not _combat_attack.can_process() or not _combat_attack.attack_enabled:
			attack_block = "闪避中" if _combat_player.is_dodging() else "暂不可用"
		elif _combat_attack.is_attacking():
			attack_block = "攻击中"
		elif ability.is_guarding():
			attack_block = "举盾中"
		elif ability.is_casting() or _combat_skill.is_action_locked():
			attack_block = "施法中"
	var attack_duration := maxf(_combat_attack.attack_cooldown,
		_combat_attack.windup_duration + _combat_attack.active_duration + _combat_attack.recovery_duration)
	var loadout := _combat_player.get_node("WeaponLoadout")
	var switch_block := ""
	if not loadout.can_switch() and loadout.switch_remaining <= 0:
		switch_block = blocked if not blocked.is_empty() else ("举盾中" if ability.is_guarding() else "动作中")
	switch_cooldown.update_cooldown(loadout.switch_remaining,0.2,switch_block)
	var d: Dictionary = loadout.current()
	var slot: Dictionary = loadout.slots[loadout.active]
	var items := _combat_player.get_node("ItemInventory")
	var is_gun: bool = d.magazine > 0
	replenish_cooldown.configure_ability("补充弹药" if is_gun else ("补充蓝量" if not d.melee else "无需补给"),preload("res://assets/ui/ammo.svg") if is_gun else preload("res://assets/ui/energy_potion.svg"),"从当前枪械对应的备用弹药装填。" if is_gun else ("消耗一瓶星蓝药剂，恢复20法力；满蓝不消耗。" if not d.melee else "短剑无需弹药或法力。"))
	var refill_remaining: float = loadout.reload_remaining if is_gun else (items.get_use_cooldown_remaining() if not d.melee else 0.0)
	replenish_cooldown.update_cooldown(refill_remaining,d.reload if is_gun else items.use_cooldown,loadout.replenishment_block_reason())
	melee_cooldown.get_node("%AbilityName").text = d.name
	melee_cooldown.icon.texture = load("res://assets/weapons/icons/"+slot.id+".svg")
	if loadout.reload_remaining > 0: attack_block = "换弹中"
	elif loadout.switch_remaining > 0: attack_block = "切换中"
	elif d.magazine > 0 and slot.ammo <= 0: attack_block = "弹匣已空"
	elif _combat_player.energy < loadout.cost(): attack_block = "法力不足"
	melee_cooldown.update_cooldown(slot.cooldown,d.interval,attack_block)
	weapon_label.text = d.name
	weapon_hint.text = ""
	weapon_icon.texture = melee_cooldown.icon.texture
	if d.magazine > 0:
		ammo_label.text = "%d/%d" % [slot.ammo,d.magazine]
		ammo_label.tooltip_text = "弹匣 %d/%d · 备用 %d" % [slot.ammo,d.magazine,loadout.reserve_ammo()]
	elif loadout.cost() > 0:
		ammo_label.text = "耗能 %d" % loadout.cost()
		ammo_label.tooltip_text = "每次攻击消耗法力，当前余量见蓝条"
	else:
		ammo_label.text = "∞"
		ammo_label.tooltip_text = "无消耗"

	skill_cooldown.visible = false
	var dodge_block := blocked
	if dodge_block.is_empty():
		if _combat_player.is_dodging():
			dodge_block = "闪避中"
		elif not _combat_player.is_on_floor():
			dodge_block = "空中"
	var dodge_duration := maxf(_combat_player.dodge_cooldown, _combat_player.dodge_duration)
	dodge_cooldown.update_cooldown(_combat_player.get_dodge_cooldown_remaining(), dodge_duration, dodge_block)
	var skill_block := blocked
	if skill_block.is_empty():
		if not _combat_skill.can_process() or _combat_skill.projectile_scene == null:
			skill_block = "暂不可用"
		elif _combat_player.is_dodging():
			skill_block = "闪避中"
		elif ability.is_guarding():
			skill_block = "举盾中"
		elif ability.is_casting():
			skill_block = "施法中"
		elif not _combat_attack.can_chain_cast():
			skill_block = "攻击中"
		elif _combat_player.energy < _combat_player.get_spell_cost():
			skill_block = "能量不足"
	skill_cooldown.update_cooldown(_combat_skill.get_cooldown_remaining(), _combat_skill.get_cooldown_duration(), skill_block)
	if ability.prepared_remaining > 0.0 and not _combat_player.is_dead():
		skill_cooldown.icon.self_modulate = Color("ffe294")
		skill_cooldown.get_node("%AbilityName").text = "法术 · 整备"
	else:
		skill_cooldown.get_node("%AbilityName").text = "法术攻击"


func update_energy_bar(current: float, maximum: float) -> void:
	# This display accepts external resource data. It never spends energy or
	# blocks the existing spell; an unknown maximum is shown explicitly.
	if not is_finite(current) or not is_finite(maximum) or maximum <= 0.0:
		energy_bar.max_value = 1.0
		energy_bar.value = 0.0
		energy_text.text = "-- / --"
		energy_text.tooltip_text = ""
		return
	energy_bar.max_value = maximum
	energy_bar.value = clampf(current, 0.0, maximum)
	energy_text.text = "%s / %s" % [_resource_number(roundi(energy_bar.value)), _resource_number(roundi(maximum))]
	energy_text.tooltip_text = "法力 %s / %s" % [str(energy_bar.value), str(maximum)]


func update_gold(amount: int) -> void:
	gold_label.text = _resource_number(maxi(amount, 0))
	gold_label.tooltip_text = "金币 %d" % maxi(amount, 0)


func update_ammo(amount: int) -> void:
	if is_instance_valid(_combat_player):
		_update_combat_cooldowns()
		return
	ammo_label.text = _resource_number(maxi(amount, 0))
	ammo_label.tooltip_text = "弹药 %d" % maxi(amount, 0)


func update_guard_rune(state: StringName, charges: int = 0, remaining: float = 0.0) -> void:
	# Remaining time is supplied by the caller; the HUD owns no gameplay clock.
	var descriptions := {&"none": "未获得", &"ready": "可用", &"active": "生效中", &"depleted": "已耗尽"}
	var known: bool = descriptions.has(state)
	var lit := state in [&"ready", &"active"]
	guard_rune_label.text = "守护符文 · %s" % descriptions.get(state, "未知")
	guard_rune_label.add_theme_color_override("font_color", Color("d8b76d") if lit else Color("a29a86"))
	guard_rune_icon.self_modulate = Color("d6b568") if lit else Color("6e6b5b")
	var detail := ""
	if known and charges > 0:
		detail = "剩余 %s 次" % _resource_number(charges)
	if known and is_finite(remaining) and remaining > 0.0:
		detail += (" · " if not detail.is_empty() else "") + "%.1f 秒" % remaining
	guard_rune_detail.text = detail
	guard_rune_detail.visible = not detail.is_empty()


func _resource_number(value: int) -> String:
	if value >= 100000000:
		return "%.1f亿" % (value / 100000000.0)
	if value >= 1000000:
		return "%.1f万" % (value / 10000.0)
	return str(value)


func update_inventory(potions: int, runes: int) -> void:
	# GameRun already supplies the real ItemInventory counts on spawn, pickup,
	# use and checkpoint restore. Do not mix in the separate commerce demo data.
	set_hotbar_data([
		{"id": &"health_potion", "icon": POTION_ICON, "count": maxi(potions, 0), "tint": Color("9dbd8a")},
		{"id": &"attack_rune", "icon": ATTACK_RUNE_ICON, "count": maxi(runes, 0), "tint": Color("d6b46b")},
		{}, {}, {},
	])


func set_hotbar_data(items: Array, selected_index: int = -1) -> void:
	# Display caller-owned icons/counts. Do not infer inventory or apply effects.
	hotbar.set_items(items, selected_index)


func set_hotbar_selected(index: int) -> bool:
	return hotbar.set_selected(index)


func get_hotbar_selected_index() -> int:
	return hotbar.get_selected_index()


func update_attack_buff(_multiplier: float, _remaining: float) -> void:
	# Preserve the external update interface without owning or displaying buffs.
	pass


func update_pickup_prompt(message: String) -> void:
	_nearby_prompt = message
	pickup_prompt.text = message
	pickup_prompt.visible = not message.is_empty() and _tutorial_message.is_empty() and _feedback_active.is_empty()
	_update_feedback_visibility()


func _update_feedback_visibility() -> void:
	feedback_panel.visible = pickup_prompt.visible or item_message.visible

func has_pickup_prompt() -> bool:
	return not _nearby_prompt.is_empty() and _tutorial_message.is_empty()

func has_feedback_message() -> bool:
	return not _feedback_active.is_empty()


func set_tutorial_guidance(message: String, revealed: Array[String], move_directions: Array[String] = []) -> void:
	if _tutorial_mode and _tutorial_message == message and _revealed_actions == revealed and _tutorial_move_directions == move_directions:
		return
	_tutorial_mode = true
	_tutorial_message = message
	_revealed_actions.assign(revealed)
	_tutorial_move_directions.assign(move_directions)
	%TutorialPrompt.set_lesson(message, move_directions)
	melee_cooldown.get_node("%InputHint").visible = revealed.has("attack")
	skill_cooldown.get_node("%InputHint").visible = revealed.has("spell")
	dodge_cooldown.get_node("%InputHint").visible = revealed.has("dodge")
	update_pickup_prompt(_nearby_prompt)


func show_item_message(message: String, priority: int = -1) -> void:
	if message.is_empty():
		_feedback_queue.clear()
		_feedback_active.clear()
		_message_remaining = 0.0
		_sync_feedback()
		return
	if priority < 0: priority = feedback_priority(message)
	if _feedback_active.get("text","") == message: return
	for pending in _feedback_queue:
		if pending.text == message: return
	var entry := {"text":message,"priority":priority,"remaining":3.0,
		"expires":_feedback_clock+(2.8 if priority >= 80 else 18.0)}
	if _feedback_active.is_empty():
		_begin_feedback(entry)
	elif priority > int(_feedback_active.priority) or priority >= 80:
		# Resume ordinary messages after a warning; never replay an old telegraph.
		if int(_feedback_active.priority) < 80 and _message_remaining > 0.0:
			_feedback_active.remaining = _message_remaining
			_feedback_queue.push_front(_feedback_active)
		_begin_feedback(entry)
	else:
		if _feedback_queue.size() < 16: _feedback_queue.append(entry)

static func feedback_priority(message: String) -> int:
	for word in ["危险","狂暴","蓄力","齐射","缠绕","迟缓","沙咒","横扫","冲锋","诅咒","躲避","震荡","骨刺"]:
		if message.contains(word): return 100
	for word in ["无法","不足","失败","未能"]:
		if message.contains(word): return 60
	return 30

func _begin_feedback(entry: Dictionary) -> void:
	_feedback_active = entry
	_message_remaining = float(entry.remaining)
	_sync_feedback()

func _advance_feedback(delta: float) -> void:
	_feedback_clock += delta
	if not _feedback_active.is_empty():
		if (feedback_panel.is_visible_in_tree() and hint_dock.current == feedback_panel) or (is_instance_valid(hint_dock.bubbles) and hint_dock.bubbles.feedback_visible): _message_remaining = maxf(0.0,_message_remaining-delta)
		if _feedback_clock >= float(_feedback_active.expires) or _message_remaining <= 0.0:
			_feedback_active.clear()
	_feedback_queue = _feedback_queue.filter(func(entry: Dictionary) -> bool: return float(entry.expires) > _feedback_clock)
	if _feedback_active.is_empty() and not _feedback_queue.is_empty():
		var index := 0
		for i in _feedback_queue.size():
			if int(_feedback_queue[i].priority) > int(_feedback_queue[index].priority): index = i
		_begin_feedback(_feedback_queue.pop_at(index))
	else: _sync_feedback()

func _sync_feedback() -> void:
	item_message.text = _feedback_active.get("text","")
	item_message.visible = not _feedback_active.is_empty()
	update_pickup_prompt(_nearby_prompt)


func update_hp_bar(current: int, maximum: int) -> void:
	if maximum <= 0:
		hp_bar.max_value = 1
		hp_bar.value = 0
		hp_text.text = "HP --/--"
		_update_health_feedback("等待生命数据", Color("9a968b"), Color("7b2428"))
		return

	var displayed_hp: int = clampi(current, 0, maximum)
	# Set the range first so increasing maximum HP does not clamp the new value.
	hp_bar.max_value = maximum
	hp_bar.value = displayed_hp
	hp_text.text = "%d/%d HP" % [displayed_hp, maximum]
	if displayed_hp == 0:
		_update_health_feedback("生命耗尽", Color("bc8278"), Color("7b2428"))
	elif float(displayed_hp) / float(maximum) <= 0.4:
		_update_health_feedback("生命值偏低", Color("c99b79"), Color("a53632"))
	else:
		_update_health_feedback("状态稳定", Color("b6a47a"), Color("7b2428"))


func update_room_label(index: int) -> void:
	_ensure_room_segments()
	var valid: bool = index >= 0 and index < total_rooms
	for i in range(room_segments.get_child_count()):
		var segment: ProgressBar = room_segments.get_child(i)
		segment.value = 1.0 if valid and i <= index else 0.0
		_room_segment_fills[i].bg_color = CURRENT_ROOM_COLOR if i == index else VISITED_ROOM_COLOR
	if not valid:
		room_label.text = "房间 --/%d" % total_rooms
		return
	room_label.text = "房间 %d/%d" % [index + 1, total_rooms]


func _ensure_room_segments() -> void:
	var count: int = maxi(total_rooms, 0)
	if room_segments.get_child_count() == count and _room_segment_fills.size() == count:
		return
	if room_segments.get_child_count() != count:
		for old_segment in room_segments.get_children():
			room_segments.remove_child(old_segment)
			old_segment.queue_free()
		for i in range(count):
			var segment := ProgressBar.new()
			segment.name = "Room%d" % (i + 1)
			segment.custom_minimum_size = Vector2(0, 8)
			segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
			segment.max_value = 1.0
			segment.step = 1.0
			segment.show_percentage = false
			room_segments.add_child(segment)
	room_segments.add_theme_constant_override("separation", 4 if count <= 12 else 1)
	_room_segment_fills.clear()
	for segment in room_segments.get_children():
		var background := StyleBoxFlat.new()
		background.bg_color = Color("20221c")
		segment.add_theme_stylebox_override("background", background)
		var fill := StyleBoxFlat.new()
		fill.bg_color = VISITED_ROOM_COLOR
		segment.add_theme_stylebox_override("fill", fill)
		_room_segment_fills.append(fill)


func update_weapon_status(has_weapon: bool) -> void:
	if is_instance_valid(_combat_player):
		_update_combat_cooldowns()
		return
	weapon_label.text = "已装备" if has_weapon else "无武器"
	weapon_icon.texture = EQUIPPED_WEAPON_ICON if has_weapon else EMPTY_WEAPON_ICON
	weapon_hint.text = ""


func _update_health_feedback(message: String, text_color: Color, fill_color: Color) -> void:
	hp_state_label.text = message
	hp_state_label.add_theme_color_override("font_color", text_color)
	_hp_fill.bg_color = fill_color


func show_death_screen(room_index: int) -> void:
	var screen = DEATH_SCREEN.instantiate()
	screen.total_rooms = total_rooms
	screen.set_room_index(room_index)
	_show_result_screen(screen)


func show_win_screen(result: Dictionary = {}, can_advance: bool = false) -> void:
	var screen = WIN_SCREEN.instantiate()
	screen.completed_rooms = total_rooms
	screen.set_run_result(result)
	screen.offer_next_level = can_advance
	screen.next_level_requested.connect(func() -> void: next_level_requested.emit())
	_show_result_screen(screen)


func get_result_screen() -> Control:
	return _result_screen


func dismiss_result_screen() -> void:
	if is_instance_valid(_result_screen):
		_result_screen.hide()
		_result_screen.queue_free()
	_result_screen = null


func _show_result_screen(screen: Control) -> void:
	if not is_instance_valid(_result_layer):
		_result_layer = CanvasLayer.new()
		_result_layer.name = "ResultLayer"
		_result_layer.layer = 20
		add_child(_result_layer)
	if is_instance_valid(_result_screen):
		_result_screen.hide()
		_result_screen.queue_free()
	_result_screen = screen
	screen.connect("restart_requested", func() -> void: restart_requested.emit())
	if screen.has_signal("main_menu_requested"):
		screen.connect("main_menu_requested", func() -> void: main_menu_requested.emit())
	_result_layer.add_child(screen)


func show_result_error(message: String) -> void:
	if is_instance_valid(_result_screen):
		_result_screen.get_node("Center/Card/Padding/Content/Description").text = message
