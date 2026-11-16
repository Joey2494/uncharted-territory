extends Control
## A failed scene keeps its original navigation underneath this retry panel.
signal retry_requested
signal back_requested

func _ready() -> void:
	%RetryButton.pressed.connect(func() -> void: retry_requested.emit())
	%BackButton.pressed.connect(func() -> void: back_requested.emit())

func show_failure(message: String, back_label: String) -> void:
	%ErrorMessage.text = message
	%BackButton.text = back_label
	show()
	_focus_retry.call_deferred()

func _focus_retry() -> void:
	if is_visible_in_tree(): %RetryButton.grab_focus()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		back_requested.emit()
	elif event.is_action("pause") or event.is_action("open_shop"):
		get_viewport().set_input_as_handled()
