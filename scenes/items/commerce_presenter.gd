extends RefCounted
## Adapts integer inventory IDs to the team's StringName-based UI contract.

const Catalog = preload("res://data/item_catalog.gd")
const ICONS := {
	Catalog.HEALTH_POTION: preload("res://assets/ui/potion.svg"),
	Catalog.ATTACK_RUNE: preload("res://assets/ui/attack_rune.svg"),
	Catalog.GUARD_RUNE: preload("res://assets/ui/guard_rune.svg"),
	Catalog.FIREARM: preload("res://assets/ui/gun.svg"),
	Catalog.AMMO: preload("res://assets/ui/ammo.svg"),
}
const TINTS := [Color("9dbd8a"), Color("d6b46b"), Color("80c9cb"), Color("d4d9df"), Color("dbab7d")]


static func item_id(key: StringName) -> int:
	for product in Catalog.get_products():
		if StringName(product.key) == key:
			return product.id
	return -2


static func description(product: Dictionary, inventory: Node3D) -> String:
	match int(product.id):
		Catalog.HEALTH_POTION:
			return "恢复 %d 点生命；满血不消耗" % inventory.potion_healing
		Catalog.ATTACK_RUNE:
			return "伤害 ×%s，持续 %s 秒" % [inventory.rune_multiplier, inventory.rune_duration]
	return product.description


static func products(inventory: Node3D, menu: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for product in Catalog.get_products():
		var error: String = inventory.get_purchase_error(product.id, 1, menu)
		result.append({
			"id": StringName(product.key), "name": product.name, "price": product.price,
			"category": "装备" if product.id == Catalog.FIREARM else "消耗品",
			"summary": description(product, inventory), "icon": ICONS[product.id],
			"tint": TINTS[product.id], "owned": inventory.get_count(product.id),
			"can_buy": error.is_empty(),
			"purchase_label": "购买" if error.is_empty() else error,
		})
	return result


static func backpack(inventory: Node3D, menu: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for product in Catalog.get_products():
		var count: int = inventory.get_count(product.id)
		if count <= 0:
			continue
		var label := "使用物品"
		var usable: bool = menu.allows_inventory_action(inventory, false)
		if not usable:
			label = "进入游戏后使用"
		elif product.id == Catalog.AMMO:
			label = "弹药已自动入库"
			usable = false
		elif product.id == Catalog.FIREARM:
			label = "切回近战" if inventory.equipped_weapon == Catalog.FIREARM else "装备手炮"
			if inventory.get_parent().is_dodging() or inventory.get_parent().get_node("MeleeAttack").is_attacking():
				label = "动作结束后装备"
				usable = false
		elif inventory.get_use_cooldown_remaining() > 0.0:
			label = "使用冷却中"
			usable = false
		elif product.id == Catalog.GUARD_RUNE and inventory.guard_active:
			label = "守护已生效"
			usable = false
		elif product.id == Catalog.HEALTH_POTION and inventory.get_parent().hp >= inventory.get_parent().max_hp:
			label = "生命值已满"
			usable = false
		result.append({
			"id": StringName(product.key), "name": product.name, "count": count,
			"category": "装备" if product.id == Catalog.FIREARM else "消耗品",
			"description": description(product, inventory), "icon": ICONS[product.id],
			"tint": TINTS[product.id], "can_use": usable, "use_label": label,
			"equipped": product.id == Catalog.FIREARM and inventory.equipped_weapon == Catalog.FIREARM,
		})
	return result
