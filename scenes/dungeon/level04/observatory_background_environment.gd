extends WorldEnvironment
## Resource-only finish on the existing environment node. Runs after the target
## layout, puzzles, combat overlays and route indicators have finished setup.
const BACKGROUND := preload("res://scenes/dungeon/level04/observatory_background.gd")
var finish := BACKGROUND.new()
var _level: Node3D

func _ready() -> void:
	set_process(false)
	_apply_finish.call_deferred()

func _apply_finish() -> void:
	_level = get_parent() as Node3D
	finish.apply(_level)
	set_process(true)

func _process(delta: float) -> void:
	if is_instance_valid(_level): finish.update(_level.player.global_position,delta)
