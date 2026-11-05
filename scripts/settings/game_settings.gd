extends RefCounted

var fullscreen: bool = false
var vsync: bool = true
var volume: float = 0.8
var path: String

func _init(save_path: String = "user://settings.cfg") -> void:
	path = save_path

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	var saved_fullscreen: Variant = config.get_value("display", "fullscreen", false)
	var saved_vsync: Variant = config.get_value("display", "vsync", true)
	var saved_volume: Variant = config.get_value("audio", "volume", 0.8)
	fullscreen = saved_fullscreen if saved_fullscreen is bool else false
	vsync = saved_vsync if saved_vsync is bool else true
	if (saved_volume is float or saved_volume is int) and is_finite(float(saved_volume)):
		volume = clampf(float(saved_volume), 0.0, 1.0)

func apply(window: Window) -> void:
	AudioServer.set_bus_mute(0, volume == 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	if DisplayServer.get_name() != "headless":
		if fullscreen:
			window.mode = Window.MODE_FULLSCREEN
		elif window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
			window.mode = Window.MODE_WINDOWED
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

func save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	config.set_value("audio", "volume", volume)
	return config.save(path) == OK
