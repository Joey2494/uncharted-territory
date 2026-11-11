extends RefCounted
static var override_path: String = ""
var message := ""
var completed: Array = []
var played: Array = []
var path := "user://campaign_progress.cfg"

func _init(save_path: String = "user://campaign_progress.cfg") -> void:
	path = override_path if not override_path.is_empty() else save_path
	var config := ConfigFile.new()
	if config.load(path) == OK:
		var stored: Variant = config.get_value("campaign", "completed", [])
		if stored is Array: completed = stored.filter(func(v: Variant) -> bool: return str(v) in ["level1", "level2"])
		stored = config.get_value("campaign", "played", [])
		if stored is Array: played = stored.filter(func(v: Variant) -> bool: return str(v) in ["level1", "level2"])

func is_unlocked(id: StringName) -> bool:
	return id == &"level1" or (id == &"level2" and ("level1" in completed or "level2" in played))
func has_played(id: StringName) -> bool: return String(id) in played
func is_completed(id: StringName) -> bool: return String(id) in completed
func recommended_level() -> StringName: return &"level2" if is_unlocked(&"level2") else &"level1"
func mark_played(level: int) -> void:
	var id := "level%d" % level
	if id not in played: played.append(id)
	_save()
func complete(level: int) -> void:
	var id := "level%d" % level
	if id not in completed: completed.append(id)
	_save()
func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("campaign", "completed", completed)
	config.set_value("campaign", "played", played)
	message = "" if config.save(path) == OK else "进度保存失败，当前会话仍可继续"
