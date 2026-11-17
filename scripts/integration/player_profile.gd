extends RefCounted
## Shared persistent wallet, character ownership and confirmed selection.
static var override_path := ""
static var _loaded_path := ""
static var coins: int = 0
static var unlocked: Array[String] = ["knight"]
static var _selected_character: String = "knight"
static var settled_runs: Array = []
static var message := ""
const PRICES := {"lan": 100, "iron": 150, "astra": 180}

static func ensure_loaded() -> void:
	var path := override_path if not override_path.is_empty() else "user://player_profile.cfg"
	if _loaded_path == path: return
	_loaded_path = path
	coins = 0
	unlocked = ["knight"]
	_selected_character = "knight"
	settled_runs = []
	message = ""
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	var saved: Variant = config.get_value("profile", "coins", 0)
	if saved is int: coins = clampi(saved, 0, 100000000)
	var settled: Variant = config.get_value("profile", "settled_runs", [])
	if settled is Array: settled_runs = settled
	var owned: Variant = config.get_value("profile", "characters", [])
	if owned is Array:
		for id in owned:
			if id is String and PRICES.has(id) and id not in unlocked: unlocked.append(id)
	var selected: Variant = config.get_value("profile", "selected_character", "knight")
	if (selected is String or selected is StringName) and String(selected) in unlocked:
		_selected_character = String(selected)

static func owns(id: String) -> bool:
	ensure_loaded()
	return id in unlocked

static func get_selected_character() -> String:
	ensure_loaded()
	return _selected_character if _selected_character in unlocked else "knight"

static func set_selected_character(id: String) -> bool:
	ensure_loaded()
	if id != "knight" and not PRICES.has(id):
		message = "无效角色"
		return false
	if not owns(id):
		message = "请先解锁该角色"
		return false
	var previous := _selected_character
	_selected_character = id
	if not save():
		_selected_character = previous
		return false
	return true

static func save() -> bool:
	ensure_loaded()
	var config := ConfigFile.new()
	config.load(_loaded_path)
	config.set_value("profile", "coins", coins)
	config.set_value("profile", "settled_runs", settled_runs)
	config.set_value("profile", "characters", unlocked)
	config.set_value("profile", "selected_character", get_selected_character())
	var ok := config.save(_loaded_path) == OK
	message = "" if ok else "存档失败，请检查存储权限后重试"
	return ok

static func set_coins(amount: int) -> bool:
	ensure_loaded()
	if amount == coins: return true
	coins = clampi(amount, 0, 100000000)
	return save()

static func unlock_character(id: String) -> bool:
	ensure_loaded()
	if owns(id):
		message = "角色已解锁，不会重复扣费"
		return false
	if not PRICES.has(id):
		message = "无效角色"
		return false
	if coins < PRICES[id]:
		message = "金币不足，需要 %d 金币" % PRICES[id]
		return false
	var previous := coins
	coins -= PRICES[id]
	unlocked.append(id)
	if not save():
		coins = previous
		unlocked.erase(id)
		return false
	message = "角色已解锁，可选择进入游戏"
	return true

## 通关结算入账：同一局（run_id）只结算一次；保存失败回滚。
static func settle_run(run_id: String, pending: int) -> bool:
	ensure_loaded()
	if run_id.is_empty() or pending < 0: return false
	if run_id in settled_runs: return true
	var previous := coins
	coins = clampi(coins + pending, 0, 100000000)
	settled_runs.append(run_id)
	if not save():
		coins = previous
		settled_runs.erase(run_id)
		return false
	return true
