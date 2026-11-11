extends Control
## Presentation-only HUD. Call its methods after the scene has entered the tree.
## Room indices are zero-based: 0 -> room 1, 2 -> room 3.

const EMPTY_WEAPON_ICON: Texture2D = preload("res://assets/ui/weapon_empty.svg")
const EQUIPPED_WEAPON_ICON: Texture2D = preload("res://assets/ui/weapon_equipped.svg")
const DEATH_SCREEN: PackedScene = preload("res://scenes/ui/death_screen.tscn")
const WIN_SCREEN: PackedScene = preload("res://scenes/ui/win_screen.tscn")
const CURRENT_ROOM_COLOR: Color = Color("b99a5c")
const VISITED_ROOM_COLOR: Color = Color("756442")

signal restart_requested
signal next_level_requested
signal use_potion_requested
signal use_rune_requested

@export_range(1, 99, 1) var total_rooms: int = 3

@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_text: Label = %HPText
@onready var room_label: Label = %RoomLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var weapon_hint: Label = %WeaponHint
@onready var hp_state_label: Label = %HPStateLabel
@onready var weapon_icon: TextureRect = %WeaponIcon
@onready var weapon_badge: PanelContainer = %WeaponBadge
@onready var room_badge: PanelContainer = %RoomBadge
@onready var room_icon: TextureRect = %RoomIcon
@onready var room_segments: HBoxContainer = %RoomSegments
@onready var potion_button: Button = %PotionButton
@onready var rune_button: Button = %RuneButton
@onready var buff_label: Label = %BuffLabel
@onready var pickup_prompt: Label = %PickupPrompt
@onready var item_message: Label = %ItemMessage
@onready var melee_cooldown: PanelContainer = %MeleeCooldown
@onready var dodge_cooldown: PanelContainer = %DodgeCooldown
@onready var skill_cooldown: PanelContainer = %SkillCooldown

var _hp_fill: StyleBoxFlat
var _weapon_badge_style: StyleBoxFlat
var _result_layer: CanvasLayer
var _result_screen: Control
var _room_segment_fills: Array[StyleBoxFlat] = []
var _message_remaining: float = 0.0
var _combat_player: CharacterBody3D
var _combat_attack: Node3D
var _combat_skill: Node3D


func _ready() -> void:
	# Each HUD instance owns its changing styles; other instances keep their colors.
	_hp_fill = hp_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	hp_bar.add_theme_stylebox_override("fill", _hp_fill)
	_weapon_badge_style = weapon_badge.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	weapon_badge.add_theme_stylebox_override("panel", _weapon_badge_style)
	update_room_label(0)
	potion_button.pressed.connect(func() -> void: use_potion_requested.emit())
	rune_button.pressed.connect(func() -> void: use_rune_requested.emit())
	update_inventory(0, 0)
	update_attack_buff(1.0, 0.0)
	update_pickup_prompt("")


func _process(delta: float) -> void:
	_update_combat_cooldowns()
	if _message_remaining > 0.0:
		_message_remaining = maxf(0.0, _message_remaining - delta)
		if _message_remaining == 0.0:
			item_message.text = ""


func bind_combat_actions(player: CharacterBody3D) -> void:
	_combat_player = player
	_combat_attack = player.get_node_or_null("MeleeAttack") if is_instance_valid(player) else null
	_combat_skill = player.get_node_or_null("EnergyShock") if is_instance_valid(player) else null
	_update_combat_cooldowns()


func _update_combat_cooldowns() -> void:
	if not is_instance_valid(_combat_player) or not is_instance_valid(_combat_attack) or not is_instance_valid(_combat_skill):
		for indicator in [melee_cooldown, dodge_cooldown, skill_cooldown]:
			indicator.update_cooldown(0.0, 1.0, "未就绪")
		return
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
	var attack_duration := maxf(_combat_attack.attack_cooldown,
		_combat_attack.windup_duration + _combat_attack.active_duration + _combat_attack.recovery_duration)
	var inventory := _combat_player.get_node_or_null("ItemInventory")
	if inventory != null and inventory.equipped_weapon == inventory.FIREARM:
		var firearm := _combat_player.get_node("Firearm")
		if attack_block.is_empty() and inventory.ammo <= 0:
			attack_block = "无弹药"
		melee_cooldown.update_cooldown(firearm.get_cooldown_remaining(), firearm.cooldown, attack_block)
	else:
		melee_cooldown.update_cooldown(_combat_attack.get_cooldown_remaining(), attack_duration, attack_block)
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
	skill_cooldown.update_cooldown(_combat_skill.get_cooldown_remaining(), _combat_skill.cooldown, skill_block)


func update_inventory(potions: int, runes: int) -> void:
	potion_button.text = "R 生命药剂 ×%d" % potions
	rune_button.text = "F 强化符文 ×%d" % runes
	potion_button.disabled = potions <= 0
	rune_button.disabled = runes <= 0


func update_attack_buff(multiplier: float, remaining: float) -> void:
	buff_label.text = "攻击 ×%s · 剩余 %d 秒" % [str(multiplier).trim_suffix(".0"), int(ceil(remaining))] if remaining > 0.0 else "攻击强化：未激活"
	buff_label.add_theme_color_override("font_color", Color("d2ae6a") if remaining > 0.0 else Color("9a968b"))


func update_pickup_prompt(message: String) -> void:
	pickup_prompt.text = message if not message.is_empty() else "靠近道具按 E 拾取"


func show_item_message(message: String) -> void:
	item_message.text = message
	_message_remaining = 3.0


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
	weapon_label.text = "已装备" if has_weapon else "无武器"
	var state_color: Color = Color("b99a5c") if has_weapon else Color("9a968b")
	weapon_label.add_theme_color_override("font_color", state_color)
	weapon_icon.texture = EQUIPPED_WEAPON_ICON if has_weapon else EMPTY_WEAPON_ICON
	weapon_icon.self_modulate = state_color if has_weapon else Color("5f6055")
	_weapon_badge_style.bg_color = Color("242116") if has_weapon else Color("171815")
	_weapon_badge_style.border_color = Color("806b40") if has_weapon else Color("48463b")
	_weapon_badge_style.shadow_color = Color(0.73, 0.60, 0.35, 0.18)
	_weapon_badge_style.shadow_size = 5 if has_weapon else 0
	weapon_hint.text = "已拾取武器" if has_weapon else "拾取武器后才能攻击"


func _update_health_feedback(message: String, text_color: Color, fill_color: Color) -> void:
	hp_state_label.text = message
	hp_state_label.add_theme_color_override("font_color", text_color)
	_hp_fill.bg_color = fill_color


func show_death_screen(room_index: int) -> void:
	var screen = DEATH_SCREEN.instantiate()
	screen.total_rooms = total_rooms
	screen.set_room_index(room_index)
	_show_result_screen(screen)


func show_win_screen(result: Dictionary = {}, offer_next_level: bool = false) -> void:
	var screen = WIN_SCREEN.instantiate()
	screen.completed_rooms = total_rooms
	screen.set_run_result(result)
	screen.offer_next_level = offer_next_level
	screen.next_level_requested.connect(func() -> void: next_level_requested.emit())
	_show_result_screen(screen)


func get_result_screen() -> Control:
	return _result_screen


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
	_result_layer.add_child(screen)


## 将载入失败显示在当前结算卡片内，保留所有可用操作。
func show_result_error(message: String) -> void:
	if is_instance_valid(_result_screen):
		_result_screen.get_node("Center/Card/Padding/Content/Description").text = message
