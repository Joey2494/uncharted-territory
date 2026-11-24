extends Node
## One pending ember per target. Node lifetime follows the enemy and room.
var remaining: float = 1.0
func _physics_process(delta: float) -> void:
	remaining -= delta
	if remaining > 0: return
	set_physics_process(false)
	var target := get_parent()
	if target.has_method("take_damage") and not (target.has_method("is_dead") and target.is_dead()): target.take_damage(1)
	queue_free()
