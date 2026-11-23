extends "prototype_player.gd"
## 致盲只在实验室显示；正式接入通过 status_requested 交给玩家/UI组。
var blind_remaining := 0.0
var blind_strength := 0.0
func apply_dawn_blind(duration: float, strength: float) -> void:
	if is_dead(): return
	blind_remaining = maxf(blind_remaining, minf(duration, 1.2))
	blind_strength = clampf(strength, 0, 0.55)
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	blind_remaining = maxf(0, blind_remaining - delta)
func clear_room_status() -> void:
	blind_remaining = 0
	blind_strength = 0
