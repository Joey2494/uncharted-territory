extends "res://scenes/dungeon/components/combat_room_encounter.gd"
## 字远的敌人还具有显式唤醒开关；与共享封场生命周期一起启停。
func try_activate() -> bool:
	var activated := super.try_activate()
	if activated and _active and not _completed and not _stopped:
		for enemy in _enemy_modes:
			if is_instance_valid(enemy) and not enemy.is_dead():
				enemy.set_encounter_active(true)
	return activated

func stop() -> void:
	for enemy in _enemy_modes:
		if is_instance_valid(enemy) and not enemy.is_dead():
			enemy.set_encounter_active(false)
	super.stop()
