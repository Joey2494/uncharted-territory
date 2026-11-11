extends "res://scenes/dungeon/level02/level02.gd"
## Adapt the teammate's map to the shared campaign host and Tang HUD.
signal room_changed(room_name: String, visited_count: int)
signal progression_feedback(message: String)
signal exit_unlocked
signal exit_opening_started
var _last_room: StringName = &""

func _ready() -> void:
	super._ready()
	feedback.connect(func(message: String) -> void: progression_feedback.emit(message))
	$Gates/BossNorth.opening_started.connect(func(_id: StringName) -> void: exit_opening_started.emit())
	$Gates/BossNorth.opened.connect(func(_id: StringName) -> void: exit_unlocked.emit())

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var room := get_current_room_id()
	if room != _last_room:
		_last_room = room
		var region := get_region_at(player.global_position)
		room_changed.emit(region.display_name if region != null else "连接通道", get_visited_count())

func get_objective() -> String:
	if get_current_room_id() == BOSS and not progress.is_complete(BOSS):
		return "击败灾厄巨蝎 · 留意蓄力与毒液区域"
	return super.get_objective().replace("遗迹守门者", "灾厄巨蝎")

func unlock_exit() -> bool:
	return true # RoomProgress remains the authority for the Boss gate.

func is_exit_open() -> bool:
	return $Gates/BossNorth.is_open()

func is_exit_opening() -> bool:
	return not is_exit_open()

func is_player_in_exit_area() -> bool:
	# The base map latches physical overlap before freezing CollisionObject3Ds.
	return _exit_recorded or $ExitArea.overlaps_body(player)

func stop_run() -> void:
	super.stop_run()
	if is_instance_valid(player) and player.is_dead():
		# Allow the shared death animation to finish while the rest of the map freezes.
		process_mode = Node.PROCESS_MODE_PAUSABLE
		for child in get_children():
			if child != player: child.process_mode = Node.PROCESS_MODE_DISABLED
