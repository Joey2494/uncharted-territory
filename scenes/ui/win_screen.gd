extends Control

signal restart_requested
signal next_level_requested

@export_range(1, 99, 1) var completed_rooms: int = 3

var offer_next_level := false

@onready var next_level_button: Button = %NextLevelButton
@onready var restart_button: Button = %RestartButton
@onready var summary_label: Label = %SummaryLabel

var _run_result: Dictionary = {}


func _ready() -> void:
	next_level_button.visible = offer_next_level
	if offer_next_level:
		$Center/Card/Padding/Content/Description.text = "进入新关卡会重新整备生命和道具。"
	next_level_button.pressed.connect(func() -> void: next_level_requested.emit())
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	visibility_changed.connect(_focus_action)
	_refresh_result()
	_focus_action()


func set_run_result(result: Dictionary) -> void:
	_run_result = result.duplicate(true)
	if is_node_ready():
		_refresh_result()


func _refresh_result() -> void:
	$Center/Card/Padding/Content/ResultDetails.visible = not _run_result.is_empty()
	if _run_result.is_empty():
		summary_label.text = "已清完全部 %d 个房间" % completed_rooms
		return
	summary_label.text = "%s已击败 · 成功离开地牢" % _run_result.get("boss_name", "最终Boss")
	var seconds := floori(maxf(0.0, float(_run_result.get("elapsed_seconds", 0.0))))
	%TimeLabel.text = "通关用时：%02d:%02d" % [floori(seconds / 60.0), seconds % 60]
	%ExplorationLabel.text = "探索区域：%d/%d" % [_run_result.get("rooms_visited", 0), _run_result.get("rooms_total", completed_rooms)]
	%HealthLabel.text = "剩余生命：%d/%d" % [_run_result.get("player_hp", 0), _run_result.get("player_max_hp", 0)]
	var second_level: bool = _run_result.get("level_id", 1) == 2
	if second_level:
		$Center/Card/Padding/Content/Description.text = "导能遗迹的出口已经开启，本次探索完成。"
	%PuzzleLabel.text = "%s：%s" % ["档案机关" if second_level else "符文机关", "已解开" if _run_result.get("puzzle_solved", false) else "未解开"]
	%RewardLabel.text = "密室奖励：%s" % ("已领取" if _run_result.get("reward_claimed", false) else "未领取")


func _focus_action() -> void:
	if is_node_ready() and is_visible_in_tree():
		var action := next_level_button if offer_next_level else restart_button
		_safe_focus.call_deferred(action)


func _safe_focus(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree() and button.is_visible_in_tree():
		button.grab_focus()
