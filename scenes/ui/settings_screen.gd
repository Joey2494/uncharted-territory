extends Control

signal back_requested
var _settings: RefCounted
var _direct_guide := false

func _ready() -> void:
	%BackButton.pressed.connect(func() -> void: back_requested.emit())
	%FullscreenButton.toggled.connect(_on_fullscreen)
	%VsyncButton.toggled.connect(_on_vsync)
	%VolumeSlider.value_changed.connect(_on_volume)
	%MusicVolumeSlider.value_changed.connect(_on_music_volume)
	%ControlsGuideButton.pressed.connect(func() -> void:
		$Center.hide()
		$ControlsGuide.open_guide())
	$ControlsGuide.closed.connect(func() -> void:
		if _direct_guide:
			_direct_guide = false
			back_requested.emit()
		else:
			$Center.show()
			_safe_focus.call_deferred(%ControlsGuideButton))

func configure(settings: RefCounted) -> void:
	_settings = settings
	%FullscreenButton.set_pressed_no_signal(settings.fullscreen)
	%VsyncButton.set_pressed_no_signal(settings.vsync)
	%VolumeSlider.set_value_no_signal(settings.volume * 100.0)
	%VolumeLabel.text = "主音量  %d%%" % roundi(settings.volume * 100.0)
	%MusicVolumeSlider.set_value_no_signal(settings.music_volume * 100.0)
	%MusicVolumeLabel.text = "背景音乐  %d%%" % roundi(settings.music_volume * 100.0)

func show_settings(back_label: String = "返回主菜单") -> void:
	_direct_guide = false
	%BackButton.text = back_label
	$ControlsGuide.hide()
	$Center.show()
	show()
	_safe_focus.call_deferred(%FullscreenButton)

func show_controls_guide(back_label: String = "返回暂停菜单") -> void:
	_direct_guide = true
	$Center.hide()
	show()
	$ControlsGuide.open_guide(back_label)

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		go_back()

func go_back() -> void:
	if $ControlsGuide.visible:
		$ControlsGuide.close_guide()
	else:
		back_requested.emit()

func _on_fullscreen(enabled: bool) -> void:
	_settings.fullscreen = enabled
	_apply()

func _on_vsync(enabled: bool) -> void:
	_settings.vsync = enabled
	_apply()

func _on_volume(value: float) -> void:
	_settings.volume = value / 100.0
	%VolumeLabel.text = "主音量  %d%%" % roundi(value)
	_apply()

func _apply() -> void:
	_settings.apply(get_tree().root)
	%StatusLabel.text = "设置已保存" if _settings.save_settings() else "设置未能保存，请检查存储空间与权限"

func _on_music_volume(value: float) -> void:
	_settings.music_volume = value / 100.0
	%MusicVolumeLabel.text = "背景音乐  %d%%" % roundi(value)
	_apply()


func _safe_focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()
