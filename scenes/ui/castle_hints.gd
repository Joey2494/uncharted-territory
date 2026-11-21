extends Control
## Local, non-spoiling presentation only. Does not interact, collect or change puzzle state.
signal hint_shown(kind: String, key: String)
const NEAR := 5.8
const LEAVE := 7.2
const PUZZLE_SECONDS := 5.0
const SUPPLY_SECONDS := 3.5
const GUIDE_BRIEF_SECONDS := 3.2
const SUPPLY_GROUPS := {"entrance":["EntrancePotion"],"west":["SupplyPotion","AttackRune"]}
@onready var host: Node = get_node("../../..")
@onready var world: Node3D = host.get_node("DungeonTest")
@onready var player: CharacterBody3D = world.get_node("Player")
@onready var puzzle: Node3D = world.get_node("RunePuzzle")
@onready var camera: Camera3D = world.get_node("Camera3D")
@onready var hud: Control = get_parent()
@onready var card: Panel = $HintCard
@onready var guide: Panel = $SupplyGuide
var _seen := {}
var _active := {}
var _remaining := 0.0
var _cooldown := 0.0
var _retry_pending := false
var _last_puzzle_state := -1
var _guide_key := ""
var _guide_seconds := {}

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and is_node_ready():
		card.hide()
		guide.hide()

func _process(delta: float) -> void:
	if host.get_run_state() != host.RunState.PLAYING or player.is_dead() or not player.can_process():
		card.hide()
		guide.hide()
		return
	if puzzle.state != _last_puzzle_state:
		_last_puzzle_state = puzzle.state
		if puzzle.state == puzzle.State.RESETTING: _retry_pending = true
		elif puzzle.is_solved(): _retry_pending = false
	# Existing item/room feedback has priority; the local hint does not echo it.
	if _in_combat():
		card.hide()
		guide.hide()
		return
	if hud.has_feedback_message():
		card.hide()
		_update_guide(delta)
		return
	_update_card(delta)
	_update_guide(delta)

func _update_card(delta: float) -> void:
	_cooldown = maxf(0.0,_cooldown-delta)
	if not _active.is_empty():
		var nearby_supply := _supply_candidate()
		if not _valid_active():
			_finish(0.8)
		elif _active.kind == "puzzle" and not nearby_supply.is_empty():
			_finish(0.0)
		else:
			_display(delta)
			return
	if _cooldown > 0.0: return
	var candidate := _supply_candidate()
	if candidate.is_empty(): candidate = _puzzle_candidate()
	if candidate.is_empty() or _seen.has(candidate.key): return
	_active = candidate
	_remaining = PUZZLE_SECONDS if candidate.kind == "puzzle" else SUPPLY_SECONDS
	_display(delta)

func _in_combat() -> bool:
	if host._boss_bar.is_visible_in_tree(): return true
	var progress: Node = world.get_node("RoomProgress")
	var region: Node3D = world.get_region_at(player.global_position)
	if region == null: return false
	var room: StringName = &"l1_crossroads" if region.name == &"Crossroads" else (&"l1_boss" if region.name == &"BossArena" else &"")
	return not room.is_empty() and progress.get_room_state(room) == progress.RoomState.ACTIVE

func _puzzle_candidate() -> Dictionary:
	if puzzle.is_reward_claimed(): return {}
	if puzzle.is_solved():
		var chest: Node3D = puzzle.get_node("RewardChest")
		if not _near_visible(chest,NEAR) or chest.can_interact(player): return {}
		return {"kind":"puzzle","key":"puzzle:reward","anchor":chest,"states":[puzzle.State.OPEN],
			"title":"可选密室","body":"暗门已开启，可查看门后的宝箱补给。"}
	var anchor: Node3D
	var distance := INF
	for node: Node3D in [puzzle.get_node("SunRune"),puzzle.get_node("MoonRune"),puzzle.get_node("StarRune")]:
		var gap := player.global_position.distance_squared_to(node.global_position)
		if gap < distance and _near_visible(node,NEAR):
			anchor = node
			distance = gap
	if anchor == null: return {}
	if _retry_pending and puzzle.state in [puzzle.State.READY,puzzle.State.RESETTING]:
		return {"kind":"puzzle","key":"puzzle:retry","anchor":anchor,"states":[puzzle.State.READY,puzzle.State.RESETTING],
			"title":"机关观察","body":"检查门楣石刻与符文图案的联系，再尝试操作。"}
	if puzzle.state == puzzle.State.OPENING:
		return {"kind":"puzzle","key":"puzzle:opening","anchor":anchor,"states":[puzzle.State.OPENING],
			"title":"机关响应","body":"石门正在升起，等待通路完全打开。"}
	return {"kind":"puzzle","key":"puzzle:observe","anchor":anchor,"states":[puzzle.State.READY],
		"title":"机关观察 · 可选","body":"先观察门楣上的石刻，再对照符文石上的图案。"}

func _supply_candidate() -> Dictionary:
	# Let the existing E prompt/tutorial take over at pickup range.
	if hud.has_pickup_prompt() or hud._tutorial_message in ["interact","rune_pickup"]: return {}
	var nearest: Node3D
	var distance := INF
	for group: String in SUPPLY_GROUPS:
		for name: String in SUPPLY_GROUPS[group]:
			if _seen.has("supply:"+name): continue
			var node: Node3D = world.get_node_or_null(name)
			if not _near_visible(node,NEAR) or node.can_collect(player): continue
			var gap := player.global_position.distance_squared_to(node.global_position)
			if gap < distance:
				nearest = node
				distance = gap
	if nearest == null: return {}
	return {"kind":"supply","key":"supply:"+str(nearest.name),"anchor":nearest,
		"title":"可选补给","body":"附近有%s ×%d，靠近后可选择按 E 拾取。" % [nearest.get_display_name(),nearest.quantity]}

func _remaining_supplies(group: String) -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	for name: String in SUPPLY_GROUPS[group]:
		var node: Node3D = world.get_node_or_null(name)
		if is_instance_valid(node) and not node.is_queued_for_deletion() and node.is_inside_tree() and node.is_visible_in_tree():
			nodes.append(node)
	return nodes

func _guide_candidate() -> Dictionary:
	var region: Node3D = world.get_region_at(player.global_position)
	if region == null: return {}
	var group := ""
	var phase := ""
	var message := ""
	var point := Vector3.ZERO
	match region.name:
		&"ArrivalLanding", &"EntranceHall":
			group = "entrance"
			phase = "arrival" if region.name == &"ArrivalLanding" else "hall"
			message = "大厅内有补给"
			point = world.get_node("Doorways/Entrance").global_position
		&"Crossroads":
			if not world.get_node("Gates/CourtyardWestSeal").is_open(): return {}
			group = "west"
			phase = "junction"
			message = "西侧通道有补给"
			point = world.get_node("Doorways/OptionalBranch").global_position
		&"WestPassage":
			group = "west"
			phase = "passage"
			message = "通道尽头有补给"
			var chamber: Node3D = world.get_node("Regions/SupplyChamber")
			point = chamber.global_position+Vector3(chamber.dimensions.x*0.5,0,0)
		&"SupplyChamber":
			group = "west"
			phase = "chamber"
			message = "石室内有补给"
		_:
			return {}
	var supplies := _remaining_supplies(group)
	if supplies.is_empty(): return {}
	var nearest: Node3D = supplies[0]
	for node in supplies:
		if node.global_position.distance_squared_to(player.global_position) < nearest.global_position.distance_squared_to(player.global_position): nearest = node
		# Actual nearby names/E prompts replace the route marker.
		if _near_visible(node,NEAR): return {}
	if phase in ["hall","chamber"]: point = nearest.global_position
	# The marker points at a real traversable doorway, never straight through a wall.
	if not _clear_sightline(point): return {}
	return {"key":"guide:"+group+":"+phase,"point":point,"message":message}

func _update_guide(delta: float) -> void:
	guide.hide()
	_guide_key = ""
	if card.visible or hud.has_pickup_prompt() or hud._tutorial_message in ["interact","rune_pickup"]: return
	var candidate := _guide_candidate()
	if candidate.is_empty(): return
	var remaining: float = _guide_seconds.get(candidate.key,GUIDE_BRIEF_SECONDS)
	var brief := remaining > 0.0
	%GuideText.text = _direction_arrow(candidate.point)+" "+(candidate.message if brief else "补给")
	var dimensions := Vector2(220 if brief else 110,40)
	if not _place_overlay(guide,candidate.point+Vector3.UP*1.8,dimensions,true): return
	guide.show()
	_guide_key = candidate.key
	_guide_seconds[candidate.key] = maxf(0.0,remaining-delta)
	if not _seen.has(candidate.key):
		_seen[candidate.key] = true
		hint_shown.emit("guide",candidate.key)

func _direction_arrow(point: Vector3) -> String:
	var direction := camera.unproject_position(point)-camera.unproject_position(player.global_position)
	var index: int = posmod(roundi(direction.angle()*4.0/PI),8)
	return ["→","↘","↓","↙","←","↖","↑","↗"][index]

func _clear_sightline(point: Vector3) -> bool:
	var start := player.global_position+Vector3.UP*0.8
	var end := Vector3(point.x,start.y,point.z)
	var ray := PhysicsRayQueryParameters3D.create(start,end,1,[player.get_rid()])
	return world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _near_visible(node: Node3D, radius: float) -> bool:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree() or not node.is_visible_in_tree(): return false
	var offset := node.global_position-player.global_position
	if Vector2(offset.x,offset.z).length() > radius or absf(offset.y) > 2.0: return false
	var excluded: Array[RID] = [player.get_rid()]
	if node is CollisionObject3D: excluded.append(node.get_rid())
	var end := Vector3(node.global_position.x,player.global_position.y+0.8,node.global_position.z)
	var ray := PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*0.8,end,1,excluded)
	return world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _valid_active() -> bool:
	var node: Node3D = _active.anchor
	if not _near_visible(node,LEAVE): return false
	if _active.kind == "puzzle":
		return puzzle.state in _active.states and not (node == puzzle.get_node("RewardChest") and node.can_interact(player))
	return not node.can_collect(player) and not hud.has_pickup_prompt()

func _display(delta: float) -> void:
	%HintCategory.text = _active.title
	%HintCategory.add_theme_color_override("font_color",Color("f3ce78"))
	%HintBody.text = _active.body
	%HintProgress.visible = _active.kind == "puzzle"
	if _active.kind == "puzzle":
		%HintProgress.text = "符文机关 %d/%d" % [puzzle.progress,puzzle.CORRECT_SEQUENCE.size()]
		if puzzle.is_solved(): %HintProgress.text = "机关已解开 · 宝箱未领取"
	if not _place_near(_active.anchor):
		card.hide()
		return
	card.modulate.a = minf(1.0,_remaining/0.3)
	card.show()
	if not _seen.has(_active.key):
		_seen[_active.key] = true
		if _active.key == "puzzle:retry": _retry_pending = false
		hint_shown.emit(_active.kind,_active.key)
	_remaining = maxf(0.0,_remaining-delta)
	if _remaining == 0.0: _finish(1.2)

func _finish(gap: float) -> void:
	card.hide()
	_active.clear()
	_remaining = 0.0
	_cooldown = gap

func _place_near(anchor: Node3D) -> bool:
	var dimensions := Vector2(minf(264.0,get_viewport_rect().size.x-32.0),94.0 if _active.kind == "puzzle" else 78.0)
	return _place_overlay(card,anchor.global_position+Vector3.UP*1.8,dimensions)

func _place_overlay(control: Control, _point: Vector3, dimensions: Vector2, _allow_edge: bool = false) -> bool:
	if camera.is_position_behind(_point): return false
	if control == card and hud.hint_dock.bubbles.has_keys(%HintBody.text):
		return hud.hint_dock.bubbles.place_world(control,_point)
	return hud.hint_dock.place_context(control,dimensions)
