extends RefCounted
## Shared persistent wallet and character ownership. Tests use a separate path.
static var override_path := ""
static var _loaded_path := ""
static var coins: int = 0
static var unlocked: Array[String] = ["knight"]
static var message := ""
const PRICES := {"lan": 100, "iron": 150, "astra": 180}

static func ensure_loaded() -> void:
	var path := override_path if not override_path.is_empty() else "user://player_profile.cfg"
	if _loaded_path == path: return
	_loaded_path = path
	coins = 0
	unlocked = ["knight"]
	message = ""
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	var saved: Variant = config.get_value("profile", "coins", 0)
	if saved is int: coins = clampi(saved, 0, 100000000)
	var owned: Variant = config.get_value("profile", "characters", [])
	if owned is Array:
		for id in owned:
			if id is String and PRICES.has(id) and id not in unlocked: unlocked.append(id)

static func owns(id: String) -> bool:
	ensure_loaded()
	return id in unlocked

static func save() -> bool:
	var config := ConfigFile.new()
	config.set_value("profile", "coins", coins)
	config.set_value("profile", "characters", unlocked)
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
