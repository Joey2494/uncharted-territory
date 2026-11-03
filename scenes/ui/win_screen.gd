extends Control

signal restart_requested

@export_range(1, 99, 1) var completed_rooms: int = 3

@onready var restart_button: Button = %RestartButton
@onready var summary_label: Label = %SummaryLabel

var _run_result: Dictionary = {}


func _ready() -> void:
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
	%PuzzleLabel.text = "符文机关：%s" % ("已解开" if _run_result.get("puzzle_solved", false) else "未解开")
	%RewardLabel.text = "密室奖励：%s" % ("已领取" if _run_result.get("reward_claimed", false) else "未领取")


func _focus_action() -> void:
	if is_node_ready() and is_visible_in_tree():
		restart_button.grab_focus.call_deferred()
