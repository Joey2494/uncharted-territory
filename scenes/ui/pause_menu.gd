extends Control

signal shop_requested
signal backpack_requested

signal resume_requested
signal restart_requested
signal main_menu_requested
signal settings_requested


func _ready() -> void:
	%ShopButton.pressed.connect(func() -> void: shop_requested.emit())
	%BackpackButton.pressed.connect(func() -> void: backpack_requested.emit())
	%ResumeButton.pressed.connect(func() -> void: resume_requested.emit())
	%RestartButton.pressed.connect(func() -> void: restart_requested.emit())
	%MainMenuButton.pressed.connect(func() -> void: main_menu_requested.emit())
	%SettingsButton.pressed.connect(func() -> void: settings_requested.emit())


func show_pause(elapsed_seconds: float) -> void:
	var seconds := floori(maxf(elapsed_seconds, 0.0))
	%TimeLabel.text = "本局用时  %02d:%02d" % [floori(seconds / 60.0), seconds % 60]
	show()
	%ResumeButton.grab_focus.call_deferred()
