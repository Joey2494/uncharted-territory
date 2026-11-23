extends "res://scenes/player/Player.gd"
## 仅独立实验室使用；正式玩家数值不受影响。演示生命 24，便于观察多次受击。
func _ready() -> void:
	super._ready()
	max_hp = 24
	hp = max_hp
	max_shield = 0
	shield = 0
