extends "res://scenes/items/item_pickup.gd"
## 教学版拾取物只增加成功通知，继续使用原库存、距离和遮挡规则。

signal collected(player: CharacterBody3D)


func try_collect(player: CharacterBody3D) -> bool:
	if not super.try_collect(player):
		return false
	collected.emit(player)
	return true
