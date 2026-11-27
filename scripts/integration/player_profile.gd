extends RefCounted
class WalletEvents:
	extends RefCounted
	signal changed(balance: int)
static var events := WalletEvents.new()
## Shared persistent wallet, character ownership and confirmed selection.
static var override_path := ""
static var _loaded_path := ""
static var coins: int = 0
static var inventory: Dictionary = {}
static var unlocked: Array[String] = ["knight"]
static var discovered_enemies: Array[String] = []
static var bestiary_unsaved := false
static var _selected_character: String = "knight"
static var settled_runs: Array = []
static var message := ""
const PRICES := {"lan": 100, "iron": 150, "astra": 180}
const MAX_COINS := 100000000
const Catalog = preload("res://data/item_catalog.gd")
const EnemyCodex = preload("res://data/enemy_codex.gd")
const BAG_IDS := [Catalog.HEALTH_POTION,Catalog.ATTACK_RUNE,Catalog.GUARD_RUNE,Catalog.ENERGY_POTION,Catalog.PISTOL_AMMO,Catalog.COIL_AMMO,Catalog.REVIVAL_CARD]

static func ensure_loaded() -> void:
	var path := override_path if not override_path.is_empty() else "user://player_profile.cfg"
	if _loaded_path == path: return
	_loaded_path = path
	coins = 0
	inventory = {}
	unlocked = ["knight"]
	discovered_enemies = []
	bestiary_unsaved = false
	_selected_character = "knight"
	settled_runs = []
	message = ""
	var config := ConfigFile.new()
	if config.load(path) != OK:
		# An interrupted write must not turn a valid wallet into an empty profile.
		if config.load(path + ".bak") != OK: return
	var saved: Variant = config.get_value("profile", "coins", 0)
	if saved is int: coins = clampi(saved, 0, 100000000)
	var saved_bag: Variant = config.get_value("profile","inventory",{})
	if saved_bag is Dictionary:
		for id in BAG_IDS:
			var count: Variant = saved_bag.get(id,0)
			if count is int: inventory[id] = clampi(count,0,Catalog.MAX_STACK)
	var settled: Variant = config.get_value("profile", "settled_runs", [])
	if settled is Array: settled_runs = settled
	var owned: Variant = config.get_value("profile", "characters", [])
	if owned is Array:
		for id in owned:
			if id is String and PRICES.has(id) and id not in unlocked: unlocked.append(id)
	var selected: Variant = config.get_value("profile", "selected_character", "knight")
	if (selected is String or selected is StringName) and String(selected) in unlocked:
		_selected_character = String(selected)
	var discoveries: Variant = config.get_value("profile", "discovered_enemies", [])
	if discoveries is Array:
		for id in discoveries:
			if id is String and id in EnemyCodex.IDS and id not in discovered_enemies: discovered_enemies.append(id)

static func discover_enemy(id: String) -> bool:
	ensure_loaded()
	if id not in EnemyCodex.IDS or id in discovered_enemies: return false
	discovered_enemies.append(id)
	# A failed save retains session discoveries and exposes a retry in the codex.
	if not save(): bestiary_unsaved = true
	return true

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
	if config.load(_loaded_path) != OK: config.load(_loaded_path + ".bak")
	config.set_value("profile", "coins", coins)
	config.set_value("profile", "inventory", inventory)
	config.set_value("profile", "settled_runs", settled_runs)
	config.set_value("profile", "characters", unlocked)
	config.set_value("profile", "discovered_enemies", discovered_enemies)
	config.set_value("profile", "selected_character", get_selected_character())
	# Write beside the destination, then replace it only after the complete file
	# is closed. Keep the last valid profile as a recovery copy.
	var temporary := _loaded_path + ".tmp"
	var ok := config.save(temporary) == OK
	if ok and FileAccess.file_exists(_loaded_path):
		var previous := ConfigFile.new()
		if previous.load(_loaded_path) == OK:
			ok = DirAccess.copy_absolute(_loaded_path, _loaded_path + ".bak") == OK
	if ok:
		ok = DirAccess.rename_absolute(temporary, _loaded_path) == OK
	if not ok and FileAccess.file_exists(temporary):
		DirAccess.remove_absolute(temporary)
	message = "" if ok else "存档失败，请检查存储权限后重试"
	if ok: bestiary_unsaved = false
	return ok

static func set_coins(amount: int) -> bool:
	ensure_loaded()
	if amount == coins: return true
	var previous := coins
	coins = clampi(amount, 0, 100000000)
	if save():
		events.changed.emit(coins)
		return true
	coins = previous
	return false

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
	events.changed.emit(coins)
	return true

## 通关结算入账：同一局（run_id）只结算一次；保存失败回滚。
static func settle_run(run_id: String, pending: int) -> bool:
	ensure_loaded()
	if pending < 0: return false
	return commit_run(run_id,pending,inventory.duplicate())

## Final defeat forfeits the complete carried wallet/bag, including prior clears.
## Character ownership and campaign progress are independent of run assets.
static func forfeit_run(run_id: String) -> bool:
	ensure_loaded()
	return commit_run("defeat:" + run_id, -coins, {}) if not run_id.is_empty() else false

## Commit wallet delta and the complete surviving backpack in one atomic save.
static func commit_run(run_id: String, delta: int, bag: Dictionary) -> bool:
	ensure_loaded()
	if run_id.is_empty(): return false
	if run_id in settled_runs: return true
	if coins+delta < 0 or coins+delta > MAX_COINS: return false
	for id in bag:
		if id not in BAG_IDS or not bag[id] is int or bag[id] < 0 or bag[id] > Catalog.MAX_STACK: return false
	var previous := coins
	var previous_bag := inventory.duplicate()
	coins += delta
	inventory = bag.duplicate()
	settled_runs.append(run_id)
	if not save():
		coins = previous
		inventory = previous_bag
		settled_runs.erase(run_id)
		return false
	events.changed.emit(coins)
	return true
