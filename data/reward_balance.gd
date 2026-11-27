extends RefCounted
## Authored task rewards are separate from per-enemy coins and cheap random finds.
const Items = preload("res://data/item_catalog.gd")
const Coins = preload("res://scenes/items/coin_pickup.gd")
const TASKS := {
	"l1_crossroads": {"gold":0,"items":{}},
	"l1_boss": {"gold":10,"items":{Items.GUARD_RUNE:1}},
	"l1_puzzle": {"gold":12,"items":{Items.ATTACK_RUNE:1}},
	"l2_hub": {"gold":0,"items":{}},
	"l2_relay": {"gold":8,"items":{}},
	"l2_antechamber": {"gold":12,"items":{Items.GUARD_RUNE:1}},
	"l2_boss": {"gold":20,"items":{Items.ATTACK_RUNE:1}},
	"l2_archive": {"gold":20,"items":{Items.HEALTH_POTION:1,Items.GUARD_RUNE:1}},
	"l3_C": {"gold":0,"items":{}},
	"l3_E": {"gold":10,"items":{}},
	"l3_F": {"gold":14,"items":{}},
	"l3_I": {"gold":20,"items":{Items.GUARD_RUNE:1}},
	"l3_G": {"gold":30,"items":{Items.ATTACK_RUNE:1}},
	"l3_garden": {"gold":10,"items":{Items.GUARD_RUNE:1}},
	"l3_release": {"gold":25,"items":{}},
	"l4_B": {"gold":0,"items":{}},
	"l4_D": {"gold":12,"items":{}},
	"l4_F": {"gold":20,"items":{Items.HEALTH_POTION:1}},
	"l4_H": {"gold":50,"items":{}},
	"l4_I": {"gold":45,"items":{Items.GUARD_RUNE:1}},
	"l4_calibration": {"gold":15,"items":{}},
	"l4_mirror": {"gold":25,"items":{Items.ATTACK_RUNE:1,Items.GUARD_RUNE:1}},
	"l4_film": {"gold":20,"items":{Items.ENERGY_POTION:1}},
	"l4_mail_take": {"gold":0,"items":{Items.HEALTH_POTION:2,Items.ENERGY_POTION:2,Items.ATTACK_RUNE:10,Items.GUARD_RUNE:10}},
	"l4_mail": {"gold":0,"items":{Items.REVIVAL_CARD:1}},
}
const PICKUPS := {
	Items.HEALTH_POTION:"res://scenes/items/HealthPotion.tscn",
	Items.ENERGY_POTION:"res://scenes/items/EnergyPotion.tscn",
	Items.ATTACK_RUNE:"res://scenes/items/AttackRune.tscn",
	Items.GUARD_RUNE:"res://scenes/items/GuardRune.tscn",
	Items.PISTOL_AMMO:"res://scenes/items/PistolAmmo.tscn",
	Items.COIL_AMMO:"res://scenes/items/CoilAmmo.tscn",
	Items.REVIVAL_CARD:"res://scenes/items/RevivalCard.tscn",
}

static func task(id: String) -> Dictionary:
	return TASKS.get(id, {"gold":0,"items":{}}).duplicate(true)

static func grant(inventory: Node, source: String, task_id: String) -> bool:
	var bundle := task(task_id)
	return inventory.grant_reward(source, bundle.items, bundle.gold)

## Random exploration is always worth less than a completed combat/puzzle task.
## 80% empty; a whole level may generate at most one non-empty random find.
static func random_find(level: int, roll: int) -> Dictionary:
	var tier := clampi(level, 1, 4)
	if roll < 10: return {"gold":2 + tier,"items":{}}
	if roll < 15: return {"gold":0,"items":{Items.PISTOL_AMMO:2 + tier}}
	if roll < 20: return {"gold":0,"items":{Items.COIL_AMMO:1 + tier}}
	return {"gold":0,"items":{}}

static func value(bundle: Dictionary) -> float:
	var total := float(bundle.get("gold", 0))
	for id in bundle.get("items", {}):
		var product := Items.get_item(id)
		total += float(product.price) / float(product.quantity) * int(bundle.items[id])
	return total

## World-owned once ledger survives puzzle resets, switching handles and reentry.
static func spawn(world: Node3D, source: String, bundle: Dictionary, point: Vector3) -> bool:
	var generated: Dictionary = world.get_meta("generated_task_rewards", {})
	if generated.has(source): return false
	generated[source] = true
	world.set_meta("generated_task_rewards", generated)
	var entries: Dictionary = bundle.get("items", {})
	var index := 0
	for id in entries:
		var pickup: Node3D = load(PICKUPS[id]).instantiate()
		pickup.quantity = entries[id]
		pickup.set_meta("reward_source", source)
		pickup.show_prompt_quantity = true
		pickup.position = world.to_local(point + Vector3((index % 3) * 1.6, 0, (index / 3) * 1.6))
		world.add_child(pickup)
		var label := pickup.get_node("NameLabel") as Label3D
		label.font_size = 32
		label.pixel_size = 0.0065
		label.outline_size = 5
		if pickup.quantity > 1: label.text += " ×%d" % pickup.quantity
		index += 1
	if int(bundle.get("gold", 0)) > 0:
		Coins.spawn(world, point + Vector3(-1.6, 0, 0), bundle.gold, source + ":coins")
	return true

static func spawn_task(world: Node3D, source: String, task_id: String, point: Vector3) -> bool:
	return spawn(world, source, task(task_id), point)

static func scatter(world: Node3D, source: String, level: int, point: Vector3) -> bool:
	if int(world.get_meta("random_supply_count", 0)) >= 1:
		return spawn(world, source, {"gold":0,"items":{}}, point)
	# Keep both the item position and the offset coin position outside station
	# approach ranges, so E at a puzzle control cannot collect a random find instead.
	for station in world.get_tree().get_nodes_in_group("world_interactables"):
		if station is Node3D and world.is_ancestor_of(station) \
			and Vector2(point.x - station.global_position.x, point.z - station.global_position.z).length() < 4.7:
			return spawn(world, source, {"gold":0,"items":{}}, point)
	var bundle := random_find(level, randi_range(0, 99))
	var spawned := spawn(world, source, bundle, point)
	if spawned and (bundle.gold > 0 or not bundle.items.is_empty()):
		world.set_meta("random_supply_count", 1)
	return spawned
