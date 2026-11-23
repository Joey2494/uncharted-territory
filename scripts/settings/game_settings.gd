extends RefCounted
## One validated model. The persistent GameSettings service owns the live instance.
signal changed(keys: PackedStringArray)
const AUDIO_BUSES = preload("res://scenes/audio/audio_buses.gd")
const DEFAULT_RESOLUTION := Vector2i(1280,720)
const QUALITIES := ["low","medium","high"]
var fullscreen := false
var vsync := true
var resolution := DEFAULT_RESOLUTION
var quality := "medium"
var volume := 0.8
var music_volume := 0.65
var path: String
var last_save_error: Error = OK
var last_load_error: Error = OK
var recovered_from_backup := false
var status_message := "设置自动保存"
var _window: WeakRef

func _init(save_path: String = "user://settings.cfg") -> void:
	path = save_path

func snapshot() -> Dictionary:
	return {"fullscreen":fullscreen,"vsync":vsync,"resolution":resolution,"quality":quality,"volume":volume,"music_volume":music_volume}

func _gain(value: Variant, fallback: float) -> float:
	return clampf(float(value),0.0,1.0) if (value is int or value is float) and is_finite(float(value)) else fallback

func _resolution(value: Variant) -> Vector2i:
	if not (value is Vector2i or value is Vector2): return DEFAULT_RESOLUTION
	if not Vector2(value).is_finite(): return DEFAULT_RESOLUTION
	if value.x < 640 or value.y < 360 or value.x > 7680 or value.y > 4320: return DEFAULT_RESOLUTION
	return Vector2i(value)

func _normalized(values: Dictionary) -> Dictionary:
	var mode: Variant = values.get("fullscreen",false)
	var sync: Variant = values.get("vsync",true)
	var detail: Variant = values.get("quality","medium")
	return {
		"fullscreen":mode if mode is bool else false,
		"vsync":sync if sync is bool else true,
		"resolution":_resolution(values.get("resolution",DEFAULT_RESOLUTION)),
		"quality":detail if detail is String and detail in QUALITIES else "medium",
		"volume":_gain(values.get("volume",0.8),0.8),
		"music_volume":_gain(values.get("music_volume",0.65),0.65)}

func _assign(values: Dictionary) -> void:
	fullscreen = values.fullscreen
	vsync = values.vsync
	resolution = values.resolution
	quality = values.quality
	volume = values.volume
	music_volume = values.music_volume

func load_settings() -> void:
	var config := ConfigFile.new()
	last_load_error = config.load(path)
	recovered_from_backup = false
	if last_load_error != OK and config.load(path+".bak") == OK:
		recovered_from_backup = true
	elif last_load_error != OK:
		config = ConfigFile.new()
	_assign(_normalized({
		"fullscreen":config.get_value("display","fullscreen",false),
		"vsync":config.get_value("display","vsync",true),
		"resolution":config.get_value("display","resolution",DEFAULT_RESOLUTION),
		"quality":config.get_value("graphics","quality","medium"),
		"volume":config.get_value("audio","volume",0.8),
		"music_volume":config.get_value("audio","music_volume",0.65)}))
	status_message = "已从备份恢复设置" if recovered_from_backup else "设置自动保存"
	var window := _bound_window()
	if window != null: apply(window)
	changed.emit(PackedStringArray(snapshot().keys()))

func update(values: Dictionary) -> bool:
	var previous := snapshot()
	var next := previous.duplicate()
	for key in values:
		if next.has(key): next[key] = values[key]
	_assign(_normalized(next))
	var requested := PackedStringArray()
	for key in values:
		if previous.has(key): requested.append(key)
	var window := _bound_window()
	# Re-selecting a size also restores it after an OS/window-manager resize.
	if window != null and not requested.is_empty(): apply(window,requested)
	var keys := PackedStringArray()
	for key in previous:
		if previous[key] != get(key): keys.append(key)
	var saved := save_settings()
	changed.emit(keys)
	return saved

func _bound_window() -> Window:
	return _window.get_ref() as Window if _window != null else null

func apply(window: Window, keys: PackedStringArray = PackedStringArray()) -> void:
	_window = weakref(window)
	_assign(_normalized(snapshot()))
	var all := keys.is_empty()
	if all or "volume" in keys:
		var master := AudioServer.get_bus_index(&"Master")
		AudioServer.set_bus_mute(master,volume == 0.0)
		AudioServer.set_bus_volume_db(master,linear_to_db(maxf(volume,0.0001)))
	if all or "music_volume" in keys:
		var bus := AUDIO_BUSES.ensure_music_bus()
		AudioServer.set_bus_mute(bus,music_volume == 0.0)
		AudioServer.set_bus_volume_db(bus,linear_to_db(maxf(music_volume,0.0001)))
	if DisplayServer.get_name() != "headless":
		if all or "fullscreen" in keys or "resolution" in keys:
			var mode := Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
			if window.mode != mode: window.mode = mode
			if not fullscreen:
				resolution = fit_window_resolution(resolution,window)
				if window.size != resolution: window.size = resolution
		if all or "vsync" in keys:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if all or "quality" in keys:
		apply_quality(window)
		for viewport in window.find_children("*","Viewport",true,false): apply_quality(viewport)
		if RenderingServer.has_method("directional_shadow_atlas_set_size"):
			var base := int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size",4096))
			RenderingServer.call("directional_shadow_atlas_set_size",mini(base,2048) if quality == "low" else (maxi(base,4096) if quality == "high" else base),true)

func fit_window_resolution(requested: Vector2i, window: Window) -> Vector2i:
	if DisplayServer.get_name() == "headless": return requested
	var available := DisplayServer.screen_get_usable_rect(window.current_screen).size
	var decoration := window.get_size_with_decorations()-window.size
	available -= Vector2i(maxi(16,decoration.x),maxi(40,decoration.y))
	if available.x <= 0 or available.y <= 0: return requested
	var scale := minf(1.0,minf(float(available.x)/requested.x,float(available.y)/requested.y))
	return Vector2i(maxi(1,floori(requested.x*scale)),maxi(1,floori(requested.y*scale)))

func apply_quality(viewport: Viewport) -> void:
	# Medium preserves each viewport's original art settings, including menu previews.
	if not viewport.has_meta("_settings_quality_base"):
		viewport.set_meta("_settings_quality_base",{"msaa":viewport.msaa_3d,"atlas":viewport.positional_shadow_atlas_size,"lod":viewport.mesh_lod_threshold})
	var base: Dictionary = viewport.get_meta("_settings_quality_base")
	viewport.msaa_3d = Viewport.MSAA_DISABLED if quality == "low" else (Viewport.MSAA_4X if quality == "high" else base.msaa)
	viewport.positional_shadow_atlas_size = mini(base.atlas,1024) if quality == "low" else (maxi(base.atlas,4096) if quality == "high" else base.atlas)
	viewport.mesh_lod_threshold = maxf(base.lod,4.0) if quality == "low" else (minf(base.lod,1.0) if quality == "high" else base.lod)

func save_settings() -> bool:
	_assign(_normalized(snapshot()))
	var config := ConfigFile.new()
	var primary_valid := config.load(path) == OK
	if not primary_valid:
		config = ConfigFile.new()
		config.load(path+".bak")
	config.set_value("display","fullscreen",fullscreen)
	config.set_value("display","vsync",vsync)
	config.set_value("display","resolution",resolution)
	config.set_value("graphics","quality",quality)
	config.set_value("audio","volume",volume)
	config.set_value("audio","music_volume",music_volume)
	var temporary := path+".tmp"
	last_save_error = config.save(temporary)
	if last_save_error == OK and primary_valid: last_save_error = DirAccess.copy_absolute(path,path+".bak")
	if last_save_error == OK: last_save_error = DirAccess.rename_absolute(temporary,path)
	if last_save_error != OK and FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
	status_message = "设置已保存" if last_save_error == OK else "设置已生效，但未能保存，请检查存储空间与权限"
	return last_save_error == OK
