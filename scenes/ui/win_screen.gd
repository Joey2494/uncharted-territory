extends Control

signal restart_requested
signal main_menu_requested
signal level_select_requested
signal next_level_requested

@export_range(1, 99, 1) var completed_rooms: int = 3

@onready var restart_button: Button = %RestartButton
@onready var summary_label: Label = %SummaryLabel

var _run_result: Dictionary = {}
var _reveal: Tween
var _layout_pending := false
var offer_next_level := false
@onready var next_level_button: Button = %NextLevelButton


func _ready() -> void:
	var host := _run_host()
	if host != null:
		var items: Node = host.get_node("DungeonTest/Player/ItemInventory")
		_run_result["potions_remaining"] = items.potion_count
		_run_result["runes_remaining"] = items.rune_count
		%LevelSelectButton.pressed.connect(host.get_node("MenuNavigation").return_to_level_select)
		host.get_node("VictoryPresentation").present()
		var next_level_message: String = host.get_next_level_block_reason()
		if not next_level_message.is_empty(): show_progress_message(next_level_message)
	next_level_button.visible = offer_next_level
	next_level_button.pressed.connect(func() -> void: next_level_requested.emit())
	theme = theme.duplicate(true)
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	%MainMenuButton.pressed.connect(func() -> void: main_menu_requested.emit())
	%LevelSelectButton.pressed.connect(func() -> void: level_select_requested.emit())
	visibility_changed.connect(_focus_action)
	resized.connect(_queue_layout)
	_build_rewards()
	_refresh_result()
	_queue_layout()
	_focus_action()
	_play_reveal()

func _run_host() -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method("get_run_state"):
			return node
		node = node.get_parent()
	return null


func set_run_result(result: Dictionary) -> void:
	_run_result = result.duplicate(true)
	if is_node_ready():
		_refresh_result()


func show_progress_message(message: String) -> void:
	%ProgressLabel.text = message


func _refresh_result() -> void:
	%ResultDetails.visible = not _run_result.is_empty()
	if _run_result.is_empty():
		summary_label.text = "本次探索已结束"
		return
	summary_label.text = "%s%s · 成功离开地牢" % [_run_result.get("boss_name", "最终Boss"), "已击败" if _run_result.get("boss_defeated", false) else "战斗结束"]
	var seconds := floori(maxf(0.0, float(_run_result.get("elapsed_seconds", 0.0))))
	%TimeLabel.text = "通关用时：%02d:%02d" % [floori(seconds / 60.0), seconds % 60]
	%ExplorationLabel.text = "探索区域：%d/%d" % [_run_result.get("rooms_visited", 0), _run_result.get("rooms_total", completed_rooms)]
	%HealthLabel.text = "剩余生命：%d/%d" % [_run_result.get("player_hp", 0), _run_result.get("player_max_hp", 0)]
	%PuzzleLabel.text = "%s：%s" % ["档案机关" if _run_result.get("level_id", 1) == 2 else "符文机关", "已解开" if _run_result.get("puzzle_solved", false) else "未解开"]
	%RewardLabel.text = "密室奖励：%s" % ("已领取" if _run_result.get("reward_claimed", false) else "未领取")


func _focus_action() -> void:
	if is_node_ready() and is_visible_in_tree():
		var target := next_level_button if next_level_button.visible and not next_level_button.disabled else restart_button
		target.grab_focus.call_deferred()


func _play_reveal() -> void:
	$Backdrop.modulate.a = 0.0
	$GoldGlow.modulate.a = 0.0
	%Card.self_modulate.a = 0.0
	_reveal = create_tween().set_parallel(true)
	_reveal.tween_property($Backdrop, "modulate:a", 1.0, 0.85)
	_reveal.tween_property($GoldGlow, "modulate:a", 1.0, 1.2).set_delay(0.2)
	_reveal.tween_property(%Card, "self_modulate:a", 1.0, 0.6).set_delay(0.3)
	var entries: Array[Control] = []
	for child in $Center/Card/Padding/Content.get_children():
		if child == %ResultDetails:
			for row in child.get_children():
				entries.append(row)
		else:
			entries.append(child)
	for i in range(entries.size()):
		entries[i].modulate.a = 0.0
		_reveal.tween_property(entries[i], "modulate:a", 1.0, 0.45).set_delay(0.30 + i * 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _build_rewards() -> void:
	%RewardsPanel.tooltip_text = "本局实际剩余补给；结算展示不会重复发放物品。"
	var definitions := [[preload("res://assets/ui/potion.svg"), "生命药剂", "potions_remaining"], [preload("res://assets/ui/attack_rune.svg"), "强化符文", "runes_remaining"]]
	for entry in definitions:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.texture = entry[0]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.self_modulate = Color("c7ad70")
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		%RewardsRow.add_child(icon)
		var label := Label.new()
		label.text = "%s ×%d" % [entry[1], maxi(0, int(_run_result.get(entry[2], 0)))]
		label.add_theme_font_size_override("font_size", 14)
		%RewardsRow.add_child(label)


func _queue_layout() -> void:
	if _layout_pending:
		return
	_layout_pending = true
	_layout_result.call_deferred()


func _layout_result() -> void:
	_layout_pending = false
	var margin := 32.0
	var wide := size.x >= 1100.0
	%TitleLabel.add_theme_font_size_override("font_size", 80 if wide else 62)
	_place(%Eyebrow, Vector2(0, size.y * 0.16), Vector2(size.x, 24))
	_place(%TitleLabel, Vector2(0, size.y * 0.19), Vector2(size.x, 100))
	_place(%SummaryLabel, Vector2(0, size.y * 0.19 + 106), Vector2(size.x, 32))
	_place(%ResultDetails, Vector2(margin, size.y - 196), Vector2(380 if wide else 320, 80))
	_place(%RewardsPanel, Vector2(size.x - margin - 290, size.y - 196), Vector2(290, 72))
	_place(%ProgressLabel, Vector2(margin, size.y - 102), Vector2(size.x - margin * 2, 22))
	var buttons: Array[Button] = [%RestartButton, %LevelSelectButton, %MainMenuButton]
	if offer_next_level:
		buttons.push_front(next_level_button)
	var count := buttons.size()
	var button_width := minf(210, (size.x - margin * 2 - 12 * (count - 1)) / count)
	var start_x := size.x - margin - button_width * count - 12 * (count - 1)
	for i in range(count):
		_place(buttons[i], Vector2(start_x + i * (button_width + 12), size.y - 64), Vector2(button_width, 42))
	_place($Center/Card/Padding/Content/Description, Vector2(margin, size.y - 124), Vector2(size.x - margin * 2, 22))

func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.position = at
	control.size = dimensions
