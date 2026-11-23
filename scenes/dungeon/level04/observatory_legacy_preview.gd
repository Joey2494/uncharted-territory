extends "res://scenes/dungeon/level04/mirror_observatory.gd"
## 保留原地图工具和白盒测试的直跑入口，正式战役与独立试玩包共用 Main。
@onready var commerce := $CommerceLayer

func _enter_tree() -> void:
	$Player.character_id = CHARACTERS.selected_id
	completed.connect($CommerceLayer.finish_run)
	failed.connect($CommerceLayer.finish_run)

func _ready() -> void:
	super._ready()
	var music := get_node_or_null("/root/MusicManager")
	if music: music.play_level(4)
	player.feedback.connect(note)
	inventory.feedback.connect(note)
	commerce.bind_inventory(inventory, func() -> bool: return not finished and not puzzles.modal_open())
	commerce.external_pause_state = func() -> bool: return $HUD/Overlay.visible and not finished
	commerce.set_run_active(true)
	_record_location()
