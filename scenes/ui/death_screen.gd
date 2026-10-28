extends Control
## Receives a zero-based room index, and presents the number of rooms reached.

signal restart_requested

@export_range(1, 99, 1) var total_rooms: int = 3

var _room_index: int = 0

@onready var restart_button: Button = %RestartButton
@onready var depth_label: Label = %DepthLabel
@onready var room_reached_label: Label = %RoomReachedLabel


func _ready() -> void:
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	visibility_changed.connect(_focus_action)
	_refresh_depth()
	_focus_action()


func set_room_index(room_index: int) -> void:
	_room_index = room_index
	if is_node_ready():
		_refresh_depth()


func _refresh_depth() -> void:
	if _room_index < 0 or _room_index >= total_rooms:
		depth_label.text = "--"
		room_reached_label.text = "探索到房间 --"
		return
	depth_label.text = "%02d" % [_room_index + 1]
	room_reached_label.text = "探索到房间 %d" % [_room_index + 1]


func _focus_action() -> void:
	if is_node_ready() and is_visible_in_tree():
		restart_button.grab_focus.call_deferred()
