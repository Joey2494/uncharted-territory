extends Control

signal restart_requested

@export_range(1, 99, 1) var completed_rooms: int = 3

@onready var restart_button: Button = %RestartButton
@onready var summary_label: Label = %SummaryLabel


func _ready() -> void:
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	visibility_changed.connect(_focus_action)
	summary_label.text = "已清完全部 %d 个房间" % completed_rooms
	_focus_action()


func _focus_action() -> void:
	if is_node_ready() and is_visible_in_tree():
		restart_button.grab_focus.call_deferred()
