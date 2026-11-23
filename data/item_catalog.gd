extends RefCounted
## Stable IDs shared by loot, shops, inventory and UI.

const HEALTH_POTION := 0
const ATTACK_RUNE := 1
const GUARD_RUNE := 2
const FIREARM := 3
const AMMO := 4
const ENERGY_POTION := 5
const PISTOL_AMMO := 6
const COIL_AMMO := 7
const MELEE := -1
const MAX_STACK := 999
const MAX_GOLD := 999999
const INITIAL_AMMO := 12

const ITEMS := {
	PISTOL_AMMO: {"id":PISTOL_AMMO,"key":"pistol_ammo","name":"黄铜手枪弹","price":12,"quantity":16,"effect":"ammo","description":"16发黄铜弹；仅供制式手枪使用，K 从备用弹药装填。"},
	COIL_AMMO: {"id":COIL_AMMO,"key":"coil_ammo","name":"线圈磁芯弹","price":18,"quantity":12,"effect":"ammo","description":"12发磁芯弹；仅供线圈卡宾枪使用，K 从备用弹药装填，不消耗蓝条。"},

	HEALTH_POTION: {"id": HEALTH_POTION, "key": "health_potion", "name": "生命药剂", "price": 10, "quantity": 1, "effect": "heal", "description": "恢复 2 点生命；满血不消耗"},
	ATTACK_RUNE: {"id": ATTACK_RUNE, "key": "attack_rune", "name": "强化符文", "price": 20, "quantity": 1, "effect": "attack_buff", "description": "伤害翻倍，持续 10 秒"},
	GUARD_RUNE: {"id": GUARD_RUNE, "key": "guard_rune", "name": "守护符文", "price": 25, "quantity": 1, "effect": "guard", "description": "使用后抵挡一次有效伤害"},
	FIREARM: {"id": FIREARM, "key": "firearm", "name": "遗迹手炮", "price": 40, "quantity": 1, "effect": "weapon", "description": "附带 12 发弹药；装备后使用普攻射击"},
	AMMO: {"id": AMMO, "key": "ammo", "name": "弹药包", "price": 12, "quantity": 6, "effect": "ammo", "description": "补充 6 发手炮弹药"},
	ENERGY_POTION: {"id": ENERGY_POTION, "key": "energy_potion", "name": "星蓝药剂", "price": 15, "quantity": 1, "effect": "energy", "description": "恢复20点能量；满能量不消耗"},
}


static func get_item(item_id: int) -> Dictionary:
	return ITEMS.get(item_id, {}).duplicate(true)


static func get_products() -> Array[Dictionary]:
	var products: Array[Dictionary] = []
	for item_id in ITEMS:
		if item_id in [FIREARM,AMMO]: continue
		products.append(get_item(item_id))
	return products
