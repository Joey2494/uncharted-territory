extends Node3D
## 孢冠女巫试炼实验室。这不是第四关正式地图或战役入口，
## 只验证首领四式、毒池上限、召唤与二阶段；金币奖励仅作接口演示，不写永久钱包。
const Factory = preload("factory.gd")
const Catalog = preload("catalog.gd")
const FX = preload("effects.gd")
static var retry_wave := 0
var player: CharacterBody3D
var arena: Node3D
var camera: Camera3D
var wave := 0
var _generation := 0
var _pending := 0
var _claimed: Dictionary = {}
var _clock := 0.0
var _message_time := 0.0
var _banner: Label
var _stats: Label
var _message: Label
var _boss_bar: Control
var _actors: Array[Node] = []
var _guards: Array[Node] = []
var _content: Control
var _pause: PanelContainer
var _ended := false
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	arena = Node3D.new()
	arena.name = "Arena"
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(arena)
	_build_arena()
	player = preload("res://scenes/player/Player.tscn").instantiate()
	player.set_script(preload("prototype_player.gd"))
	arena.add_child(player)
	player.global_position = Vector3(0, 0.05, 7)
	player.died.connect(_on_player_died)
	player.feedback.connect(show_message)
	player.get_node("ItemInventory").feedback.connect(show_message)
	player.get_node("CharacterAbility").feedback.connect(show_message)
	_build_ui()
	if OS.get_cmdline_user_args().has("--l4-smoke"):
		for id in Catalog.ENEMIES:
			var enemy := Factory.create(id, player)
			arena.add_child(enemy)
			enemy.set_encounter_active(true)
			enemy.queue_free()
		print("LEVEL04_PACKAGE_SMOKE PASS witch + spore guard + shared player + UI")
		get_tree().quit()
		return
	var initial := retry_wave
	retry_wave = 0
	load_wave(initial)
func _build_arena() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("141b2b")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c4cee8")
	settings.ambient_light_energy = 0.65
	env.environment = settings
	arena.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -32, 0)
	sun.light_color = Color("dddafa")
	sun.light_energy = 1.15
	arena.add_child(sun)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	arena.add_child(floor_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(26, 0.5, 22)
	shape.shape = box
	shape.position.y = -0.25
	floor_body.add_child(shape)
	var tiles := MultiMeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.98, 0.1, 0.98)
	mesh.material = FX.mat(Color("505c6c"))
	tiles.multimesh = MultiMesh.new()
	tiles.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	tiles.multimesh.use_colors = true
	tiles.multimesh.mesh = mesh
	tiles.multimesh.instance_count = 26 * 22
	for x in 26:
		for z in 22:
			var i := x * 22 + z
			tiles.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x - 12.5, -0.05, z - 10.5)))
			tiles.multimesh.set_instance_color(i, Color(0.86, 0.96, 0.8) * (0.86 + ((x + z) % 3) * 0.05))
	arena.add_child(tiles)
	# 中心小型实心柱（§12.4）；外围保持至少 3 单位宽的连续通行环道。
	_obstacle(Vector3(0, 1.25, 0), Vector3(2, 2.5, 2), Color("465063"))
	# 真实边界与场地尺寸一致，避免玩家走出镜头或危险区在场外出现。
	for wall in [[Vector3(-13.25, 1, 0), Vector3(0.5, 2, 23)], [Vector3(13.25, 1, 0), Vector3(0.5, 2, 23)], [Vector3(0, 1, -11.25), Vector3(26, 2, 0.5)], [Vector3(0, 1, 11.25), Vector3(26, 2, 0.5)]]:
		_obstacle(wall[0], wall[1], Color("303a4b"))
	# 四角低矮菌柱：装饰与少量掩体，不压缩环道。
	for corner in [Vector3(-11.5, 0.4, -8.5), Vector3(11.5, 0.4, -8.5), Vector3(-11.5, 0.4, 8.5), Vector3(11.5, 0.4, 8.5)]:
		_obstacle(corner, Vector3(1.2, 0.8, 1.2), Color("7d8a6a"))
	camera = Camera3D.new()
	camera.current = true
	camera.position = Vector3(0, 19, 20)
	camera.fov = 58
	arena.add_child(camera)
	camera.look_at(Vector3(0, 0, -1))
func _obstacle(at: Vector3, dims: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	arena.add_child(body)
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dims
	shape.shape = box
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dims
	mesh.material = FX.mat(color)
	visual.mesh = mesh
	body.add_child(visual)
func _label(parent: Node, text: String, size: int = 18) -> Label:
	var n := Label.new()
	n.text = text
	n.add_theme_font_override("font", preload("res://scenes/ui/dungeon_font.tres"))
	n.add_theme_font_size_override("font_size", size)
	parent.add_child(n)
	return n
func _panel(at: Vector2, dims: Vector2) -> PanelContainer:
	var n := PanelContainer.new()
	_content.add_child(n)
	n.position = at
	n.size = dims
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.08, 0.93)
	style.border_color = Color("af9665")
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	n.add_theme_stylebox_override("panel", style)
	return n
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_content)
	var top := _panel(Vector2(20, 16), Vector2(560, 100))
	var col := VBoxContainer.new()
	top.add_child(col)
	_banner = _label(col, "第四关 袍冠女巫 试炼原型", 22)
	_stats = _label(col, "", 15)
	_label(col, "演示体力 24  原型不写入永久钱包", 13)
	var buttons := HBoxContainer.new()
	_content.add_child(buttons)
	buttons.position = Vector2(20, 126)
	for data in [["上一组", -1], ["重试本组", 0], ["下一组", 1]]:
		var b := Button.new()
		b.text = data[0]
		b.custom_minimum_size = Vector2(104, 34)
		buttons.add_child(b)
		var action: int = data[1]
		b.pressed.connect(func() -> void: load_wave(clampi(wave + action, 0, 2)))
	_boss_bar = preload("res://scenes/ui/BossHealthBar.tscn").instantiate()
	_content.add_child(_boss_bar)
	var bottom := _panel(Vector2(20, 606), Vector2(760, 94))
	var info := VBoxContainer.new()
	bottom.add_child(info)
	_message = _label(info, "", 17)
	_label(info, "WASD 移动  J 普攻  K 法术  Space 翻滚  R 药剂", 14)
	_label(info, "1–3 切换试炼   Esc 暂停   每组开始重置演示体力与补给", 13)
	_pause = _panel(Vector2(470, 270), Vector2(340, 130))
	var pause_col := VBoxContainer.new()
	_pause.add_child(pause_col)
	_label(pause_col, "已暂停", 24)
	_label(pause_col, "Esc 继续  或选择一组重试", 16)
	_pause.hide()
	get_viewport().size_changed.connect(_layout)
	_layout.call_deferred()
func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	_boss_bar.position = Vector2(maxf(20, screen.x - 540), 18)
	_boss_bar.size = Vector2(minf(520, screen.x - 40), 88)
	var bottom := _message.get_parent().get_parent() as Control
	bottom.position.y = screen.y - 112
	bottom.size.x = maxf(320, screen.x - 40)
	# 窄窗口将 Boss 栏移到第二行，避免压住试炼按钮。
	if screen.x < 1120:
		_boss_bar.position = Vector2(20, 170)
	_pause.position = Vector2((screen.x - 340) / 2, (screen.y - 130) / 2)
func _clear_wave() -> void:
	get_tree().paused = false
	_pause.hide()
	_generation += 1
	_ended = false
	_boss_bar.hide()
	for actor in _actors:
		if is_instance_valid(actor): actor.set_encounter_active(false)
	for guard in _guards:
		if is_instance_valid(guard): guard.queue_free()
	_guards.clear()
	for actor in _actors:
		if is_instance_valid(actor): actor.queue_free()
	_actors.clear()
	for group in ["l4_hazards", "l4_transient", "player_projectiles"]:
		for node in get_tree().get_nodes_in_group(group):
			if arena.is_ancestor_of(node): node.queue_free()
	_pending = 0
	_claimed.clear()
func load_wave(index: int) -> void:
	if is_instance_valid(player) and player.is_dead():
		retry_wave = index
		get_tree().reload_current_scene()
		return
	_clear_wave()
	camera.position = Vector3(0, 19, 20)
	camera.look_at(Vector3(0, 0, -1))
	player.show()
	wave = clampi(index, 0, 2)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.global_position = Vector3(0, 0.05, 7)
	player.hp = player.max_hp
	player.energy = player.max_energy
	player.web_remaining = 0
	player._invulnerability_remaining = 0
	player._dodge_invulnerability_remaining = 0
	var items := player.get_node("ItemInventory")
	items.potion_count = 3
	items.gold = 0
	items._publish_state()
	_banner.text = "第四关 %d/3  %s" % [wave + 1, Catalog.WAVES[wave].name]
	show_message(Catalog.WAVES[wave].tip, 99)
	var ids: Array = Catalog.WAVES[wave].ids
	var witch_spawned := false
	for i in ids.size():
		var at := Vector3((i - 1) * 4.0, 0.05, -6)
		var actor := spawn_enemy(ids[i], at, i > 0)
		if ids[i] == "witch" and not witch_spawned:
			witch_spawned = true
			if wave == 2:
				# 第三组从半血开始，完整演示二阶段转换与固定首次藤蔓横扫。
				actor.take_damage(actor.max_hp / 2 + 1)
func spawn_enemy(id: String, at: Vector3, is_guard := false) -> Node:
	if _ended or not is_instance_valid(player) or player.is_dead(): return null
	# Death animations free guards while the witch can still summon another batch.
	_actors = _actors.filter(func(entry): return is_instance_valid(entry) and not entry.is_queued_for_deletion())
	_guards = _guards.filter(func(entry): return is_instance_valid(entry) and not entry.is_queued_for_deletion())
	var summoner: Node = null
	if is_guard:
		for boss in _actors:
			if boss.enemy_id != "witch" or boss.is_dead(): continue
			summoner = boss
			var slot: Dictionary = boss.find_minion_spawn(at)
			if slot.is_empty(): return null
			at = slot.position
			break
		if summoner == null: return null
	var actor := Factory.create(id, player)
	if actor == null: return null
	if id == "witch": actor.reward_source_id = "lab:%d:witch" % _generation
	arena.add_child(actor)
	actor.global_position = at
	actor.set_encounter_active(true)
	_actors.append(actor)
	if is_guard:
		_guards.append(actor)
		summoner.register_minion(actor)
		FX.burst(arena, actor.global_position + Vector3.UP * 0.2, Color("9ac77a"), 0.4)
	var generation := _generation
	actor.died.connect(func() -> void: _check_cleared.call_deferred(generation))
	if id == "witch":
		actor.reward_requested.connect(func(source_id: String, coins: int) -> void:
			if generation == _generation and not _claimed.has(source_id):
				_claimed[source_id] = true
				_pending += coins)
		actor.summon_requested.connect(func(kind: String, point: Vector3) -> void:
			if generation == _generation and not _ended: _spawn_for_generation.call_deferred(generation, kind, point))
		actor.minions_dissolved.connect(func() -> void: _dissolve_guards())
		actor.battle_started.connect(func() -> void: _boss_bar.begin_encounter(actor.boss_name, actor.hp, actor.max_hp))
		actor.hp_changed.connect(_boss_bar.update_hp)
		actor.state_changed.connect(_boss_bar.update_state)
		actor.died.connect(_boss_bar.show_defeated)
	return actor
func _dissolve_guards() -> void:
	## 首领死亡后召唤物解体（§12.4）：不再造成伤害，不要求玩家打完尾怪。
	for guard in _guards:
		if is_instance_valid(guard) and not guard.is_dead():
			guard.set_encounter_active(false)
			FX.burst(arena, guard.global_position + Vector3.UP * 0.3, Color("a8c47e"), 0.7)
			guard.queue_free()
	_guards.clear()
func _check_cleared(generation: int) -> void:
	if generation != _generation or _ended: return
	for actor in _actors:
		if is_instance_valid(actor) and not actor.is_dead(): return
	_ended = true
	show_message("本组完成  1–3 或上方按钮选择下一组  奖励仅作接口演示", 99)
func _on_player_died() -> void:
	_ended = true
	for actor in _actors:
		if is_instance_valid(actor): actor.set_encounter_active(false)
	_boss_bar.hide()
	show_message("本次试炼失败  点击重试本组重新开始", 99)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_3: load_wave(event.keycode - KEY_1)
		elif event.keycode == KEY_ESCAPE:
			get_tree().paused = not get_tree().paused
			_pause.visible = get_tree().paused
			get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	if not get_tree().paused:
		_clock += delta
		_message_time = maxf(0, _message_time - delta)
	_stats.text = "HP %d/%d   能量 %d/%d   演示待结算 %d" % [player.hp, player.max_hp, player.energy, player.max_energy, _pending]
func show_message(message: String, duration := 4.0) -> void:
	if is_instance_valid(_message):
		_message.text = message
		_message_time = duration
func _spawn_for_generation(generation: int, id: String, point: Vector3) -> void:
	if generation == _generation and not _ended: spawn_enemy(id, point, true)
