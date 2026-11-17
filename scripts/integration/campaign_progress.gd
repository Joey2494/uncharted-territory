extends RefCounted
## Scene-local facades share one authoritative in-memory state per save file.
static var override_path: String = ""
const LEVEL_IDS := ["level1", "level2", "level3"]

class SessionState:
	var message: String = ""
	var completed: Array = []
	var played: Array = []
	var last_played: StringName = &""

static var _sessions: Dictionary = {}
var _state: SessionState
var message: String:
	get: return _state.message
	set(value): _state.message = value
var completed: Array:
	get: return _state.completed
	set(value): _state.completed = value
var played: Array:
	get: return _state.played
	set(value): _state.played = value
var _last_played: StringName:
	get: return _state.last_played
	set(value): _state.last_played = value
var path := "user://campaign_progress.cfg"

func _init(save_path: String = "user://campaign_progress.cfg") -> void:
	path = override_path if not override_path.is_empty() else save_path
	var key := ProjectSettings.globalize_path(path).simplify_path()
	if _sessions.has(key):
		_state = _sessions[key]
		return
	_state = SessionState.new()
	_sessions[key] = _state
	# Load only on the first access in this process. A scene replacement must not
	# replace unsaved completions, visits or the warning with an older disk snapshot.
	var config := ConfigFile.new()
	if config.load(path) == OK:
		var stored: Variant = config.get_value("campaign", "completed", [])
		if stored is Array: completed = stored.filter(func(v: Variant) -> bool: return str(v) in LEVEL_IDS)
		stored = config.get_value("campaign", "played", [])
		if stored is Array: played = stored.filter(func(v: Variant) -> bool: return str(v) in LEVEL_IDS)
		stored = config.get_value("campaign", "last_played", "")
		if (stored is String or stored is StringName) and str(stored) in played:
			_last_played = StringName(stored)
		elif not played.is_empty():
			# Older saves only have first-visit history. Preserve their previous continue target
			# until the next actual run writes an explicit recent level.
			_last_played = StringName(played.back())

func is_unlocked(id: StringName) -> bool:
	var index := LEVEL_IDS.find(String(id))
	# 已游玩记录兼容旧档；新关卡必须有前一关完成记录。
	return index == 0 or (index > 0 and (LEVEL_IDS[index - 1] in completed or String(id) in played))
func has_played(id: StringName) -> bool: return String(id) in played
func is_completed(id: StringName) -> bool: return String(id) in completed
func recommended_level() -> StringName:
	for index in range(LEVEL_IDS.size() - 1, -1, -1):
		if is_unlocked(StringName(LEVEL_IDS[index])): return StringName(LEVEL_IDS[index])
	return &"level1"
func get_last_played_level() -> StringName: return _last_played
func mark_played(level: int) -> void:
	var id := "level%d" % level
	if id not in LEVEL_IDS: return
	if id not in played: played.append(id)
	# Main calls this only after starting gameplay, including re-entered levels.
	_last_played = StringName(id)
	_save()
func complete(level: int) -> void:
	var id := "level%d" % level
	if id not in LEVEL_IDS: return
	if id not in completed: completed.append(id)
	_save()
func _save() -> void:
	var config := ConfigFile.new()
	# Retain unrelated fields already present in the save.
	config.load(path)
	config.set_value("campaign", "completed", completed)
	config.set_value("campaign", "played", played)
	config.set_value("campaign", "last_played", String(_last_played))
	message = "" if config.save(path) == OK else "进度保存失败，当前会话仍可继续"
