extends Node
## Discovery follows real encounter activation; the UI owns no combat state.
const Catalog = preload("res://data/enemy_codex.gd")
const Profile = preload("res://scripts/integration/player_profile.gd")
const SCREEN = preload("res://scenes/ui/EnemyCodex.tscn")
@onready var host := get_parent()
var screen: Control
var _world: Node3D
var _pending: Array[String] = []
var _practice_known: Array[String] = []
var _snapshots: Dictionary = {}
var _return_state: Variant
var _previous_pause := false
var _previous_focus: WeakRef
var _spawn_candidates: Array[WeakRef] = []
var _auto_popup := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_world = host._dungeon
	_practice_known = Profile.discovered_enemies.duplicate()
	_auto_popup = "--no-bestiary-popup" not in OS.get_cmdline_user_args()
	var layer := CanvasLayer.new()
	layer.name = "EnemyCodexLayer"
	layer.layer = 50
	add_child(layer)
	screen = SCREEN.instantiate()
	layer.add_child(screen)
	screen.back_requested.connect(close)
	screen.next_discovery_requested.connect(next_discovery)
	screen.retry_save_requested.connect(retry_save)
	host._start_screen.get_node("%EnemyCodexButton").pressed.connect(open_library)
	host._commerce.pause_menu.get_node("%EnemyCodexButton").pressed.connect(open_library)
	for node in _world.get_children():
		if node.has_method("get_encounter_enemies") and node.has_signal("battle_started"):
			node.battle_started.connect(_on_room_started.bind(node))
	get_tree().node_added.connect(_on_node_added)

func get_known() -> Array[String]:
	return _practice_known.duplicate() if host.practice_run else Profile.discovered_enemies.duplicate()

func is_open() -> bool:
	return is_instance_valid(screen) and screen.visible

func _can_record() -> bool:
	return not host._transition_queued and host._run_state == host.RunState.PLAYING and not host._player.is_dead()

func _on_room_started(_room: Variant, source: Node) -> void:
	# Third-level actors finish their explicit wake-up after battle_started.
	# Record after activation completes, including already-created dormant rosters.
	_capture_roster.call_deferred(source)

func _capture_roster(source: Node) -> void:
	if not is_instance_valid(source) or not _can_record(): return
	for actor in source.get_encounter_enemies(): record_actor(actor)

func record_actor(actor: Node) -> void:
	if not _can_record() or not is_instance_valid(actor) or not _world.is_ancestor_of(actor): return
	if not actor.is_node_ready() or not actor.can_process() or actor.is_queued_for_deletion(): return
	if actor is Node3D and not actor.is_visible_in_tree(): return
	if actor.has_method("is_dead") and actor.is_dead(): return
	var id := Catalog.identify(actor)
	if id.is_empty(): return
	var numbers := Catalog.stats(id).duplicate()
	if actor.get("max_hp") != null: numbers.hp = actor.max_hp
	if actor.get("move_speed") != null: numbers.speed = actor.move_speed
	if id == "broodling" and actor.get("_speed") != null: numbers.speed = actor._speed
	_snapshots[id] = numbers
	if id in get_known(): return
	if host.practice_run: _practice_known.append(id)
	else: Profile.discover_enemy(id)
	if _auto_popup and id not in _pending: _pending.append(id)

func _on_node_added(node: Node) -> void:
	if node is CharacterBody3D and _world.is_ancestor_of(node):
		_spawn_candidates.append(weakref(node))

func _record_spawn(actor: Node) -> void:
	var id := Catalog.identify(actor)
	if id.is_empty(): return
	if id == "broodling":
		var source_ref: WeakRef = actor.get("_source")
		var source: Node = source_ref.get_ref() if source_ref != null else null
		if is_instance_valid(source) and source.can_process() and source.has_meta("combat_room_key"): record_actor(actor)
	elif actor.has_method("is_encounter_active") and actor.is_encounter_active(): record_actor(actor)

func _process(_delta: float) -> void:
	if not _can_record() or get_tree().paused: return
	var candidates := _spawn_candidates.duplicate()
	_spawn_candidates.clear()
	for candidate: WeakRef in candidates:
		var actor: Node = candidate.get_ref()
		if is_instance_valid(actor) and actor.is_node_ready() and not actor.is_queued_for_deletion(): _record_spawn(actor)
	if _pending.is_empty() or is_open(): return
	if host._is_dungeon_modal_open() or host._commerce.view != host._commerce.View.NONE: return
	var navigation := host.get_node("MenuNavigation")
	if navigation.settings_screen.visible or navigation.load_error.visible: return
	_open(true)

func open_library() -> bool:
	if is_open() or host._transition_queued or host._player.is_dead(): return false
	if host._run_state not in [host.RunState.MENU, host.RunState.PLAYING, host.RunState.PAUSED]: return false
	if host._is_dungeon_modal_open() or host._commerce.view not in [host._commerce.View.NONE, host._commerce.View.PAUSE]: return false
	var navigation := host.get_node("MenuNavigation")
	if navigation.settings_screen.visible or navigation.load_error.visible: return false
	if host._run_state == host.RunState.MENU and not host._start_screen.visible: return false
	return _open(false)

func _open(fresh: bool) -> bool:
	if is_open(): return false
	_return_state = host._run_state
	_previous_pause = get_tree().paused
	var focus := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	host._run_state = host.RunState.CODEX
	get_tree().paused = true
	host._refresh_overlay()
	var known := get_known()
	var id: String = _pending.pop_front() if fresh else (known[0] if not known.is_empty() else Catalog.IDS[0])
	screen.present(known, id, fresh, _pending.size() if fresh else 0, Profile.bestiary_unsaved and not host.practice_run, _snapshots)
	return true

func next_discovery() -> void:
	if not is_open() or not screen.encounter_mode: return
	if _pending.is_empty(): close()
	else:
		var id: String = _pending.pop_front()
		screen.present(get_known(), id, true, _pending.size(), Profile.bestiary_unsaved and not host.practice_run, _snapshots)

func close() -> void:
	if not is_open(): return
	screen.hide()
	# "Read later" dismisses the current batch; every entry is already unlocked.
	_pending.clear()
	host._run_state = _return_state
	get_tree().paused = _previous_pause
	host._refresh_overlay()
	var focus: Control = _previous_focus.get_ref() if _previous_focus != null else null
	if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus.call_deferred()

func retry_save() -> void:
	if host.practice_run or not is_open(): return
	Profile.save()
	screen.present(get_known(), screen.selected_id, screen.encounter_mode, _pending.size(), Profile.bestiary_unsaved, _snapshots)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo() \
		and (event.physical_keycode if event.physical_keycode != 0 else event.keycode) == KEY_B:
		if open_library(): get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if is_open(): get_tree().paused = _previous_pause
