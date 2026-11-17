extends "res://scenes/player/Player.gd"
## Only the standalone laboratory uses this subclass; campaign player stats remain untouched.
var _l3_slow := 0.0
var _l3_factor := 1.0
func _ready() -> void:
	super._ready()
	max_hp=24
	hp=max_hp
	max_shield=0
	shield=0
func apply_level03_slow(duration: float, factor: float) -> void:
	if is_dead(): return
	_l3_slow=maxf(_l3_slow,duration)
	_l3_factor=clampf(factor,0.25,1)
	feedback.emit("沙咒迟缓 可翻滚脱离危险区域")
func _physics_process(delta: float) -> void:
	_l3_slow=maxf(0,_l3_slow-delta)
	var old_run:=move_speed
	var old_walk:=walk_speed
	if _l3_slow>0:
		move_speed*=_l3_factor
		walk_speed*=_l3_factor
	super._physics_process(delta)
	move_speed=old_run
	walk_speed=old_walk
