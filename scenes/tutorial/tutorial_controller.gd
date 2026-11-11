extends Node
## Seven event-driven lessons using Tang's prompt, wording and skip interface.
const STEPS = ["move", "interact", "attack", "spell", "dodge", "heal", "rune"]
@onready var bindings := get_parent()
@onready var host = bindings.host
@onready var player = bindings.player
@onready var items = bindings.items
@onready var hud = bindings.hud
var index: int = 0
var active: bool = false
var finished: bool = false
var moved: Array[String] = []
var revealed: Array[String] = ["attack", "spell", "dodge"]
var _rune_encountered := false
var _branch_rune_collected := false
var _rune_used_after_encounter := false
var _heal_prepared := false

func _ready() -> void:
	items.pickup_succeeded.connect(_on_pickup)
	player.get_node("MeleeAttack").attack_started.connect(func() -> void: complete("attack"))
	player.get_node("EnergyShock").released.connect(func(_bolt: Node3D) -> void: complete("spell"))
	player.dodge_started.connect(func() -> void: complete("dodge"))
	items.item_used.connect(_on_item_used)

func _physics_process(_delta: float) -> void:
	if finished or host._run_state != host.RunState.PLAYING or not player.can_process() or player.is_dead(): return
	if not active:
		active = true
		_show()
	if index == 0 and player.get_real_velocity().length() > 0.1:
		for pair in [["move_forward", "W"], ["move_left", "A"], ["move_backward", "S"], ["move_right", "D"]]:
			if Input.is_action_pressed(pair[0]) and pair[1] not in moved: moved.append(pair[1])
		_show()
		if moved.size() == 4: complete("move")
	if index == 5: _prepare_heal()
	if index == 6:
		_update_rune_encounter()
		if _rune_used_after_encounter:
			complete("rune")
		else:
			_show()

func complete(step: String) -> void:
	if not active or finished or STEPS[index] != step or host._run_state != host.RunState.PLAYING: return
	if step == "rune" and not _rune_encountered: return
	index += 1
	if index == STEPS.size():
		skip()
		return
	if STEPS[index] == "heal":
		_prepare_heal()
	_show()

func _show() -> void:
	var lesson: String = STEPS[index]
	if lesson == "rune":
		if not _rune_encountered:
			lesson = ""
		elif items.rune_count <= 0:
			lesson = "rune_pickup" if _is_rune_nearby() else ""
	hud.set_tutorial_guidance(lesson, revealed, moved)

func _prepare_heal() -> void:
	if _heal_prepared or items.potion_count <= 0: return
	_heal_prepared = true
	if player.hp == player.max_hp:
		player.hp = player.max_hp - 1
		player.hp_changed.emit(player.hp, player.max_hp)

func _is_rune_nearby() -> bool:
	var world = host.get_node("DungeonTest")
	var branch = world.get_node_or_null("Regions/SupplyChamber")
	var rune := world.get_node_or_null("AttackRune") as Node3D
	if branch == null or world.get_region_at(player.global_position) != branch: return false
	if rune == null or not rune.is_visible_in_tree() or player.global_position.distance_to(rune.global_position) > 6.0: return false
	var start: Vector3 = player.global_position + Vector3.UP * 0.8
	var finish: Vector3 = rune.global_position + Vector3.UP * 0.8
	var ray := PhysicsRayQueryParameters3D.create(start, finish, 1, [player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _update_rune_encounter() -> void:
	if _branch_rune_collected or _is_rune_nearby(): _rune_encountered = true

func _on_pickup(target: Node) -> void:
	if target == host.get_node("DungeonTest").get_node_or_null("AttackRune"):
		_branch_rune_collected = true
		_rune_encountered = true
	complete("interact")

func _on_item_used(id: int) -> void:
	if id == items.HEALTH_POTION:
		complete("heal")
	elif id == items.ATTACK_RUNE and _rune_encountered:
		_rune_used_after_encounter = true
		complete("rune")

func skip() -> void:
	finished = true
	active = false
	hud.set_tutorial_guidance("", revealed)
	hud.show_item_message("教学结束 · 可在设置中查看操作指南")

func _unhandled_input(event: InputEvent) -> void:
	if active and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ENTER:
		skip()
		get_viewport().set_input_as_handled()
