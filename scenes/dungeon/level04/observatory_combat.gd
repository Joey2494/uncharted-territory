extends Node3D
## 日晷观测站遭遇控制器。房门由宿主统一管理，此处仅在越过内线与完整清除名单时发信号。
signal battle_started(room: String)
signal battle_cleared(room: String)
signal feedback(message: String)
signal cage_landed(first_placement: bool)

const FACTORY := preload("res://addons/ziyuan_level04/factory.gd")
const PLAN := preload("res://scenes/dungeon/level04/observatory_plan.gd")
const WITCH := preload("res://scenes/dungeon/level04/observatory_witch.gd")
const CRATE := preload("res://scenes/dungeon/level04/observatory_crate.gd")
const SWEEP := preload("res://scenes/dungeon/level04/observatory_sweep.gd")
const ROSTERS := {
	"B": [["dawn_shade",Vector2(-6,1)],["dawn_shade",Vector2(6,-1)]],
	"D": [["sun_puppet",Vector2(-3.5,3.8)],["sun_puppet",Vector2(-4.8,-3.5)]],
	"F": [["iron_thistle",Vector2(-4,-3)],["iron_thistle",Vector2(4,-3)]],
	"H": [["raven_roost",Vector2(4,-3)]],
	"I": [["witch",Vector2(-4,-2)],["iron_thistle",Vector2(5,-3.5)]],
}
const REINFORCEMENTS := {"F": Vector2(3,-4.8), "H": Vector2(-3.5,-4)}
const CAGE_SIZE := Vector3(1.8,1.7,1.5)
var active_room := ""
var demo_done := false
var cage_side := 0
var cage_placed := false
var requested_cage_side := 0
var half_announced := false
var _level: Node3D
var _player: CharacterBody3D
var _layout: Node3D
var _cleared := {}
var _enemies: Array[CharacterBody3D] = []
var _sweeps := {}
var _markers := {}
var _cage: StaticBody3D
var _model_cage: MeshInstance3D
var _demo_running := false
var _window_lights := Node3D.new()
var _reinforced := false
var _warning_left := -1.0
var _spawn_serial := 0
var _stopped := false
var prepared_dome_boss: CharacterBody3D
var _jailer: CharacterBody3D
var _advance_paused_light := false
var _paths: AStarGrid2D
var _next_side := -1
var _queued_side := 0
var _minions: Array[CharacterBody3D] = []
var _generation := 0
var _blind: ColorRect
var _blind_layer: CanvasLayer
var _blind_left := 0.0
var _blind_duration := 1.0

func setup(level: Node3D) -> void:
	_level = level
	_layout = level.layout
	_player = level.get_node("Player")
	_blind_layer = CanvasLayer.new()
	_blind_layer.layer = 1 # World effect below authored combat HUD and menus.
	add_child(_blind_layer)
	_blind = ColorRect.new()
	_blind.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blind.color = Color(1.0,0.91,0.71,0.0)
	_blind_layer.add_child(_blind)
	_blind.hide()
	for spec in [["A",Vector2(-2.6,0)],["B",Vector2(-2.2,0)],["B",Vector2(0,0)]]:
		var crate := CRATE.new()
		add_child(crate)
		crate.position = _at(spec[0],spec[1],0)
		crate.build(_layout)
	_build_cage()
	_build_reinforcement_window()
	for room: String in REINFORCEMENTS:
		var marker := Node3D.new()
		add_child(marker)
		marker.position = _at(room,REINFORCEMENTS[room],0)
		_layout.block(marker,Vector3(0,0.07,0),Vector3(3.4,0.055,1.25),Color("d27d39"),true)
		for x in [-1.6,1.6]:
			_layout.block(marker,Vector3(x,0.87,-0.3),Vector3(0.15,1.7,0.15),Color("ffba52"),true)
		_layout.caption(marker,"援军将至",Vector3(0,2.2,0))
		_markers[room] = marker
		marker.hide()
	for room: String in ["H","I"]:
		var light := SWEEP.new()
		add_child(light)
		light.build(_layout,_layout.room_center(room),Vector2(9.3,7.2) if room == "H" else Vector2(11.2,9.1))
		_sweeps[room] = light

## 过横桥时，玩家能从北侧玻璃看见东北增援门的青灯。作战预警沿用独立的琥珀标记。
func _build_reinforcement_window() -> void:
	var frame := Node3D.new()
	add_child(frame)
	frame.position = _at("F",Vector2(9.0,-3.6),0)
	frame.rotation.y = -0.7
	for x: float in [-1.0,1.0]:
		_layout.block(frame,Vector3(x,0.85,0),Vector3(0.12,1.7,0.14),Color("#716957"))
	_layout.block(frame,Vector3(0,1.66,0),Vector3(2.1,0.12,0.14),Color("#a18762"))
	var glass: MeshInstance3D = _layout.block(frame,Vector3(0,1.0,0),Vector3(1.9,1.17,0.05),Color("#669792"))
	var tint := StandardMaterial3D.new()
	tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tint.albedo_color = Color(0.44,0.77,0.78,0.28)
	glass.material_override = tint
	add_child(_window_lights)
	for spot: Vector3 in [frame.position + Vector3.UP*1.75,_at("F",REINFORCEMENTS.F,0.14)]:
		_layout.block(_window_lights,spot,Vector3(1.9,0.12,0.19),Color("#87e0d8"),true)
	var placard: Label3D = _layout.caption(_window_lights,"东北增援门",_at("F",REINFORCEMENTS.F,1.85))
	placard.modulate = Color("#a9f3e5")
	_window_lights.hide()

func light_reinforcement_window() -> void:
	if not is_clear("F") and active_room != "F":
		_window_lights.show()

func _at(room: String, xz: Vector2, height: float) -> Vector3:
	var center: Vector3 = _layout.room_center(room)
	return center + Vector3(xz.x,height,xz.y)

func _build_cage() -> void:
	var neutral := _at("F",Vector2(0,2),4.4)
	_cage = _layout.solid(self,neutral,CAGE_SIZE,Color("4f666b"))
	_cage.name = "CounterweightCage"
	for x in [-0.74,-0.25,0.25,0.74]:
		for z in [-0.765,0.765]:
			_layout.block(_cage,Vector3(x,0,z),Vector3(0.10,1.62,0.07),Color("b6945f"))
	for side in [-1,1]:
		var slot := _at("F",Vector2(side*4,2),0.055)
		for edge in [-1,1]:
			_layout.block(self,slot+Vector3(0,0,edge*0.88),Vector3(2.1,0.035,0.07),Color("dcb071"))
			_layout.block(self,slot+Vector3(edge,0,0),Vector3(0.07,0.035,1.8),Color("dcb071"))
	var model := Node3D.new()
	add_child(model)
	model.position = _at("D",Vector2(5.5,-2.2),0)
	_layout.solid(model,Vector3(0,0.46,0),Vector3(2.8,0.92,1.55),Color("43545c"))
	for x in [-0.87,0,0.87]:
		_layout.block(model,Vector3(x,1.0,0),Vector3(0.76,0.09,1.35),Color("a58d69") if x!=0 else Color("4f666b"))
	_model_cage = _layout.block(model,Vector3(0,1.62,0),Vector3(0.46,0.5,0.48),Color("d7ab67"))
	_layout.caption(model,"F 双廊缩景 · 吊笼停在亮框内",Vector3(0,2.15,0))

func set_cage(side: int) -> bool:
	if _stopped or not can_process() or side not in [-1,1] or active_room == "F" or not is_clear("D"): return false
	requested_cage_side = side
	_try_place_cage()
	return true

func _try_place_cage() -> void:
	if requested_cage_side == cage_side or active_room == "F": return
	var target := _at("F",Vector2(requested_cage_side*4,2),CAGE_SIZE.y*0.5)
	var offset := _player.global_position - target
	if absf(offset.x) <= CAGE_SIZE.x*0.5+0.6 and absf(offset.z) <= CAGE_SIZE.z*0.5+0.6: return
	cage_side = requested_cage_side
	_cage.global_position = target
	_model_cage.position = Vector3(cage_side*0.87,1.29,0)
	var first_placement := not cage_placed
	cage_placed = true
	cage_landed.emit(first_placement)

func is_clear(room: String) -> bool:
	return _cleared.has(room)

func enemy_count() -> int:
	return _enemies.size()

func boss_guard() -> CharacterBody3D:
	return _jailer if is_instance_valid(_jailer) else null

func shutter_available() -> bool:
	return not _stopped and active_room == "I" and not _advance_paused_light and _sweeps.I.active

func operate_shutter() -> bool:
	if not can_process() or not shutter_available(): return false
	var light: Node3D = _sweeps.I
	if light.choose(-light.side):
		feedback.emit("已调百叶 · 本轮扫%s侧" % ("东" if light.side > 0 else "西"))
	else:
		# 锁定与实扫期间保留本轮几何，扳杆只把下一轮的预选侧翻转。
		_queued_side = light.side if _queued_side == 0 else -_queued_side
		feedback.emit("本轮已锁定 · 下一轮预选%s侧" % ("东" if _queued_side > 0 else "西"))
	return true

func update_room(room: String, delta: float) -> void:
	if _stopped or not can_process() or _player.is_dead(): return
	_tick_blind(delta)
	_try_place_cage()
	if active_room != "":
		_tick_battle(delta)
		return
	if _demo_running and room != "H":
		_sweeps.H.stop()
		_demo_running = false
	if not ROSTERS.has(room) or is_clear(room): return
	if room == "H" and not demo_done:
		if not _demo_running:
			_sweeps.H.begin(-1,true)
			_demo_running = true
			feedback.emit("百叶试车 · 青光演示不伤人，观察另一侧的暗带")
		if _sweeps.H.advance(delta,[]):
			_demo_running = false
			demo_done = true
			feedback.emit("演示完毕 · 跨过试车线迎战")
		return
	if room == "B":
		if _player.global_position.z - _layout.room_center("B").z > 4.5: return
	elif not PLAN.inside_encounter(room,Vector2(_player.global_position.x,_player.global_position.z)):
		return
	_begin_battle(room)

func _begin_battle(room: String) -> void:
	active_room = room
	if room == "F": _window_lights.hide()
	_reinforced = not REINFORCEMENTS.has(room)
	_warning_left = -1
	_paths = null
	battle_started.emit(room)
	for spec in ROSTERS[room]:
		_spawn(spec[0],spec[1])
	if room in ["H","I"]:
		_next_side = -1
		_sweeps[room].begin(_next_side,false)
		feedback.emit("百叶运行 · 琥珀光选侧，红光锁定，白光扫过")

## 战役 HUD 预先订阅女巫；封门前保持休眠，模型和碰撞均隐藏。
func prepare_dome_boss() -> void:
	for spec in ROSTERS["I"]:
		if spec[0] == "witch":
			prepared_dome_boss = _create_guard("I", spec[0], spec[1])
			prepared_dome_boss.hide()
			prepared_dome_boss.collision_layer = 0
			prepared_dome_boss.collision_mask = 0
			return

func _create_guard(room: String, kind: String, xz: Vector2) -> CharacterBody3D:
	var guard := FACTORY.create(kind)
	if kind == "witch":
		guard.set_script(WITCH)
		guard.encounter = self
		guard.add_to_group("bosses")
	guard.bind_target(_player)
	_spawn_serial += 1
	guard.name = "%s_Guard%d" % [room,_spawn_serial]
	guard.set_meta("room",room)
	guard.set_meta("combat_room_key","%d:%s" % [get_instance_id(),room])
	guard.reward_source_id = "observatory:%s:%d" % [room,_spawn_serial]
	guard.arena_center = _layout.room_center(room)
	guard.arena_size = Vector2(22,18) if room != "I" else Vector2(26,22)
	guard.position = _at(room,xz,0.06)
	add_child(guard)
	guard.died.connect(_on_guard_dead.bind(guard))
	guard.reward_requested.connect(_grant_enemy_reward)
	if kind == "witch":
		guard.summon_requested.connect(_queue_minion)
		guard.minions_dissolved.connect(_clear_minions)
	else:
		guard.status_requested.connect(_status_requested)
	return guard

func _spawn(kind: String, xz: Vector2) -> void:
	var guard: CharacterBody3D
	if kind == "witch" and is_instance_valid(prepared_dome_boss):
		guard = prepared_dome_boss
		guard.collision_layer = 4
		guard.collision_mask = 3
		guard.show()
	else:
		guard = _create_guard(active_room,kind,xz)
	_enemies.append(guard)
	guard.set_encounter_active(true)
	if kind == "witch":
		_jailer = guard
		if guard == prepared_dome_boss: guard.start_dome_encounter()

func _on_guard_dead(guard: CharacterBody3D) -> void:
	_enemies.erase(guard)
	if guard == _jailer: _jailer = null

func _tick_battle(delta: float) -> void:
	if active_room == "F" and not _reinforced and _enemies.is_empty() and _warning_left < 0:
		_warn_reinforcement(1.1)
	if active_room in ["H","I"]:
		var light: Node3D = _sweeps[active_room]
		if _handle_half_health(light): return
		if _enemies.is_empty() and _reinforced:
			_finish_battle()
			return
		if active_room == "H" and not _reinforced and _warning_left < 0 and light.elapsed+delta >= SWEEP.LOCK_END:
			_warn_reinforcement(SWEEP.ROUND_END-light.elapsed)
		var targets: Array = [_player]
		targets.append_array(_enemies)
		if light.advance(delta,targets):
			if _stopped or _player.is_dead(): return
			_next_side = _queued_side if _queued_side != 0 else -light.side
			_queued_side = 0
			light.begin(_next_side,false)
	if _stopped or _player.is_dead(): return
	if _warning_left >= 0:
		_warning_left -= delta
		if _warning_left <= 0: _release_reinforcement()
	if _enemies.is_empty() and _reinforced: _finish_battle()

func _handle_half_health(light: Node3D) -> bool:
	if active_room != "I": return false
	if _advance_paused_light:
		if is_instance_valid(_jailer) and _jailer.advancing: return true
		_advance_paused_light = false
		light.begin(_next_side,false)
	if not half_announced and is_instance_valid(_jailer) and _jailer.hp*2 <= _jailer.max_hp and light.elapsed < SWEEP.CHOOSE:
		half_announced = true
		_advance_paused_light = true
		_next_side = light.side
		light.stop()
		var target := _at("I",Vector2(5.4,2.0),0)
		_jailer.announce_advance(target)
		_jailer.state_changed.emit("移步开道")
		feedback.emit("女巫移步开道 · 百叶暂歇，绕至东侧扳杆")
		return true
	return false

func _warn_reinforcement(duration: float) -> void:
	_warning_left = duration
	_markers[active_room].show()
	feedback.emit("标记门已亮 · %s即将入场" % ("白芒尖蓟" if active_room == "F" else "群鸦归巢"))

func _release_reinforcement() -> void:
	var spawn_xz: Vector2 = REINFORCEMENTS[active_room]
	# 避免刷新在玩家身体中；门灯两侧也处于同一片预告区内。
	for dx: float in [0.0,-1.35,1.35]:
		var spot := spawn_xz + Vector2(dx,0)
		var target := _at(active_room,spot,0.06)
		if _player.global_position.distance_to(target) < 1.15: continue
		_spawn("iron_thistle" if active_room == "F" else "raven_roost",spot)
		_reinforced = true
		_warning_left = -1
		_markers[active_room].hide()
		return
	_warning_left = 0.0

func _finish_battle() -> void:
	var room := active_room
	_clear_minions()
	_clear_blind()
	if _sweeps.has(room): _sweeps[room].stop()
	_cleared[room] = true
	_player.get_node("CharacterAbility").complete_combat_room("%d:%s" % [get_instance_id(),room])
	active_room = ""
	battle_cleared.emit(room)

func stop() -> void:
	_stopped = true
	_generation += 1
	_clear_minions()
	_clear_blind()
	for light in _sweeps.values(): light.stop()
	for marker in _markers.values(): marker.hide()
	for guard in _enemies: guard.set_encounter_active(false)
	if is_instance_valid(prepared_dome_boss): prepared_dome_boss.set_encounter_active(false)

func _grant_enemy_reward(source_id: String, coins: int) -> void:
	# Enemy drops and room-completion supplies have distinct, idempotent IDs.
	if not _stopped: _level.inventory.grant_reward(source_id,{},coins)

func _queue_minion(kind: String, point: Vector3) -> void:
	_spawn_minion.call_deferred(_generation,kind,point)

func _spawn_minion(generation: int, kind: String, point: Vector3) -> void:
	if generation != _generation or _stopped or active_room != "I" or _player.is_dead(): return
	if not is_instance_valid(_jailer) or not _jailer.is_encounter_active(): return
	var minion := FACTORY.create(kind,_player)
	if minion == null: return
	minion.set_meta("is_summoned",true)
	add_child(minion)
	minion.global_position = point
	minion.set_encounter_active(true)
	_minions.append(minion)
	_jailer.register_minion(minion)

func _clear_minions() -> void:
	_generation += 1
	for minion in _minions:
		if is_instance_valid(minion):
			minion.set_encounter_active(false)
			minion.queue_free()
	_minions.clear()

func _status_requested(target: Node3D, status_id: String, duration: float, strength: float) -> void:
	if _stopped or target != _player or _player.is_dead() or status_id != "dawn_blind": return
	_blind_left = maxf(_blind_left,minf(duration,1.2))
	_blind_duration = _blind_left
	_blind.color.a = clampf(strength,0.0,0.48)
	_blind.show()

func _tick_blind(delta: float) -> void:
	_blind_left = maxf(0.0,_blind_left-delta)
	if _blind_left <= 0.0: _clear_blind()
	else: _blind.modulate.a = minf(1.0,_blind_left/maxf(0.01,_blind_duration*0.35))

func _clear_blind() -> void:
	_blind_left = 0.0
	if is_instance_valid(_blind):
		_blind.hide()
		_blind.modulate.a = 1.0

## 仅在敌人被墙挡住时生成该场地的可行走网格；按身体宽度排除窄缝，地面射线排除地板以外的格点。
func _build_paths() -> void:
	_paths = AStarGrid2D.new()
	_paths.region = Rect2i(-11,-9,23,19)
	_paths.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_paths.update()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.52
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	var space := get_world_3d().direct_space_state
	for x in range(-11,12):
		for z in range(-9,10):
			var pos := _at(active_room,Vector2(x,z),0.85)
			query.transform.origin = pos
			var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos,pos-Vector3.UP*1.4,1))
			var blocked := floor_hit.is_empty() or not space.intersect_shape(query,1).is_empty()
			_paths.set_point_solid(Vector2i(x,z),blocked)

func _nearest_cell(world: Vector3) -> Vector2i:
	var local: Vector3 = world - _layout.room_center(active_room)
	var point := Vector2(local.x,local.z)
	var cell := Vector2i(point.round())
	if _paths.is_in_boundsv(cell) and not _paths.is_point_solid(cell): return cell
	var nearest := cell
	var distance := INF
	for x in range(cell.x-3,cell.x+4):
		for z in range(cell.y-3,cell.y+4):
			var candidate := Vector2i(x,z)
			var d := point.distance_squared_to(Vector2(candidate))
			if d < distance and _paths.is_in_boundsv(candidate) and not _paths.is_point_solid(candidate):
				nearest = candidate
				distance = d
	return nearest

func next_corner(from: Vector3, to: Vector3) -> Vector3:
	if _paths == null: _build_paths()
	var a := _nearest_cell(from)
	var b := _nearest_cell(to)
	if not _paths.is_in_boundsv(a) or not _paths.is_in_boundsv(b): return from
	var path := _paths.get_id_path(a,b,true)
	if path.size() <= 1: return to
	return _at(active_room,Vector2(path[1]),from.y)
