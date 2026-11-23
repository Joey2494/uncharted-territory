extends "prototype.gd"
## 四房连续试炼；复用现有实验室场地和真实玩家。清房后主动进入下一房。
const RoomCatalog = preload("room_catalog.gd")
var encounter: Node3D
var _blind_overlay: ColorRect
var _next_button: Button
var _gallery: Control
var _room_label: Label
func _ready() -> void:
	# 基类创建场地/玩家，动态派发至本脚本 load_wave。
	super._ready()
	var extra := Label.new()
	extra.text = "1–4 选择房间 · N 清房后前进 · F5 重试"
	extra.add_theme_font_override("font", preload("res://scenes/ui/dungeon_font.tres"))
	extra.position = Vector2(20, 163)
	_content.add_child(extra)
	_gallery = extra
	var layer := CanvasLayer.new()
	layer.layer = 9
	arena.add_child(layer)
	_blind_overlay = ColorRect.new()
	_blind_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blind_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blind_overlay.color = Color(1, 0.94, 0.76, 0)
	layer.add_child(_blind_overlay)
	_next_button = Button.new()
	_next_button.text = "清房后前往下一房 · N"
	_next_button.pressed.connect(_advance_room)
	_content.add_child(_next_button)
	_next_button.position = Vector2(20, 200)
	_next_button.hide()
	# 基类按钮只支持三组，替换为四房独立按钮。
	for child in _content.get_children():
		if child is HBoxContainer:
			for button in child.get_children(): button.queue_free()
			for i in 4:
				var button := Button.new()
				button.text = ["1 曦影", "2 赤阳傀儡", "3 白芒尖蓟", "4 群鸦归巢"][i]
				button.custom_minimum_size = Vector2(120, 34)
				child.add_child(button)
				button.pressed.connect(load_wave.bind(i))
	var info := _message.get_parent()
	info.get_child(2).text = "1–4 房间   N 清房后继续   F5 重试   Esc 暂停"
func load_wave(index: int) -> void:
	if not is_instance_valid(player): return
	if player.is_dead():
		retry_wave = index
		get_tree().reload_current_scene()
		return
	if is_instance_valid(encounter):
		encounter.clear_encounter()
		encounter.queue_free()
	_clear_wave()
	if player.get_script() != preload("room_player.gd"):
		# 保留 @onready 绑定，脚本替换发生在已初始化真实玩家上。
		# 改为重建同一 PackedScene，确保所有继承属性正确初始化。
		var old_player := player
		player = preload("res://scenes/player/Player.tscn").instantiate()
		player.set_script(preload("room_player.gd"))
		arena.add_child(player)
		player.died.connect(_on_player_died)
		player.feedback.connect(show_message)
		old_player.queue_free()
	wave = clampi(index, 0, 3)
	player.global_position = Vector3(0, 0.05, 7)
	player.hp = player.max_hp
	player.energy = player.max_energy
	player._invulnerability_remaining = 0
	player._dodge_invulnerability_remaining = 0
	player.clear_room_status()
	player.get_node("ItemInventory").potion_count = 3
	player.get_node("ItemInventory").gold = 0
	if is_instance_valid(_next_button): _next_button.hide()
	encounter = preload("room_encounter.gd").new()
	arena.add_child(encounter)
	var points: Array[Vector3] = []
	for point in RoomCatalog.ROOMS[wave].spawns: points.append(point)
	encounter.spawn_at_positions(player, wave, "lab:four:%d:%d" % [_generation, wave], points, Vector3.ZERO)
	encounter.reward_requested.connect(func(id: String, coins: int) -> void:
		if not _claimed.has(id):
			_claimed[id] = true
			_pending += coins)
	encounter.room_cleared.connect(_room_finished)
	encounter.set_encounter_active(true)
	_banner.text = RoomCatalog.ROOMS[wave].name
	show_message(RoomCatalog.ROOMS[wave].tip, 99)
	_boss_bar.hide()
func _room_finished(_index: int) -> void:
	_ended = true
	player.clear_room_status()
	if wave < 3:
		show_message("本房已清理 · 按 N 或按钮前往下一房", 99)
		_next_button.show()
	else: show_message("前四房试炼完成 · 袍冠女巫可在 Prototype.tscn 单独挑战", 99)
func _advance_room() -> void:
	if _ended and wave < 3 and not player.is_dead(): load_wave(wave + 1)
func _on_player_died() -> void:
	if is_instance_valid(encounter): encounter.set_encounter_active(false)
	player.clear_room_status()
	super._on_player_died()
	show_message("本房失败 · 按 F5 重试，或 1–4 切换房间", 99)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4: load_wave(event.keycode - KEY_1)
		elif event.keycode == KEY_N: _advance_room()
		elif event.keycode == KEY_F5: load_wave(wave)
		elif event.keycode == KEY_ESCAPE:
			get_tree().paused = not get_tree().paused
			_pause.visible = get_tree().paused
func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(_blind_overlay) and is_instance_valid(player):
		_blind_overlay.color.a = player.blind_strength * minf(1, player.blind_remaining / 0.15)
	if is_instance_valid(encounter):
		_stats.text += "   敌人 %d" % encounter.living_count()
