extends Control
## The host decides which gameplay scene to launch; this view has no scene path.

signal start_requested

@onready var start_button: Button = %StartButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	start_button.pressed.connect(func() -> void: start_requested.emit())
	visibility_changed.connect(_focus_action)
	_focus_action()


func show_status(message: String) -> void:
	status_label.text = message


func _focus_action() -> void:
	if is_node_ready() and is_visible_in_tree():
		start_button.grab_focus.call_deferred()
