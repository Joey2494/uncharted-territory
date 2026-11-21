extends Control

signal back_requested
var _settings: RefCounted
var _direct_guide := false
var _layout_pending := false
const RESOLUTIONS := [Vector2i(960,540),Vector2i(1280,720),Vector2i(1366,768),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160)]
const QUALITY_IDS := ["low","medium","high"]

func _ready() -> void:
	%BackButton.pressed.connect(func() -> void: back_requested.emit())
	%FullscreenButton.toggled.connect(_on_fullscreen)
	%VsyncButton.toggled.connect(_on_vsync)
	%VolumeSlider.value_changed.connect(_on_volume)
	%MusicVolumeSlider.value_changed.connect(_on_music_volume)
	%ResolutionOption.item_selected.connect(_on_resolution)
	%QualityOption.item_selected.connect(_on_quality)
	for label in ["低","中","高"]: %QualityOption.add_item(label)
	get_viewport().size_changed.connect(_queue_layout)
	%Content.minimum_size_changed.connect(_queue_layout)
	_queue_layout()
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
	if _settings != null and _settings.changed.is_connected(_refresh_controls): _settings.changed.disconnect(_refresh_controls)
	_settings = settings
	_settings.changed.connect(_refresh_controls)
	_refresh_controls()

func _refresh_controls(_keys: PackedStringArray = PackedStringArray()) -> void:
	if _settings == null: return
	%FullscreenButton.set_pressed_no_signal(_settings.fullscreen)
	%VsyncButton.set_pressed_no_signal(_settings.vsync)
	%VolumeSlider.set_value_no_signal(_settings.volume*100.0)
	%VolumeLabel.text = "主音量  %d%%" % roundi(_settings.volume*100.0)
	%MusicVolumeSlider.set_value_no_signal(_settings.music_volume*100.0)
	%MusicVolumeLabel.text = "背景音乐  %d%%" % roundi(_settings.music_volume*100.0)
	%QualityOption.select(QUALITY_IDS.find(_settings.quality))
	%ResolutionOption.clear()
	var sizes := RESOLUTIONS.duplicate()
	if not _settings.resolution in sizes: sizes.append(_settings.resolution)
	sizes.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	for dimensions: Vector2i in sizes:
		if dimensions != _settings.resolution and _settings.fit_window_resolution(dimensions,get_tree().root) != dimensions: continue
		var index: int = %ResolutionOption.item_count
		%ResolutionOption.add_item("%d × %d" % [dimensions.x,dimensions.y])
		%ResolutionOption.set_item_metadata(index,dimensions)
		if dimensions == _settings.resolution: %ResolutionOption.select(index)
	%ResolutionOption.disabled = _settings.fullscreen
	%StatusLabel.text = _settings.status_message
	_queue_layout()

func show_settings(back_label: String = "返回主菜单") -> void:
	_refresh_controls()
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
	_settings.update({"fullscreen":enabled})

func _on_vsync(enabled: bool) -> void:
	_settings.update({"vsync":enabled})

func _on_volume(value: float) -> void:
	_settings.update({"volume":value/100.0})

func _on_music_volume(value: float) -> void:
	_settings.update({"music_volume":value/100.0})

func _on_resolution(index: int) -> void:
	_settings.update({"resolution":%ResolutionOption.get_item_metadata(index)})

func _on_quality(index: int) -> void:
	_settings.update({"quality":QUALITY_IDS[index]})

func _queue_layout() -> void:
	if _layout_pending: return
	_layout_pending = true
	_layout.call_deferred()

func _layout() -> void:
	_layout_pending = false
	if not is_inside_tree(): return
	var viewport_size := get_viewport().get_visible_rect().size
	%Card.custom_minimum_size.x = minf(620.0,viewport_size.x-32.0)
	var chrome: float = %Content.get_combined_minimum_size().y-%SettingsScroll.custom_minimum_size.y+36.0
	%SettingsScroll.custom_minimum_size.y = clampf(viewport_size.y-32.0-chrome,120.0,420.0)


func _safe_focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()
