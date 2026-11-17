extends Node3D
## Enemy laboratory and combination encounters. This is not the final third-level map or campaign unlock flow.
const Factory=preload("factory.gd")
const Catalog=preload("catalog.gd")
const FX=preload("effects.gd")
static var retry_wave := 0
var player: CharacterBody3D
var arena: Node3D
var camera: Camera3D
var wave := 0
var gallery := false
var _generation := 0
var _pending := 0
var _claimed: Dictionary={}
var _clock := 0.0
var _message_time := 0.0
var _banner: Label
var _stats: Label
var _message: Label
var _boss_bar: Control
var _actors: Array[Node]=[]
var _content: Control
var _pause: PanelContainer
var _ended := false
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	arena=Node3D.new()
	arena.name="Arena"
	arena.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(arena)
	_build_arena()
	player=preload("res://scenes/player/Player.tscn").instantiate()
	player.set_script(preload("prototype_player.gd"))
	arena.add_child(player)
	player.global_position=Vector3(0,0.05,6)
	player.died.connect(_on_player_died)
	player.feedback.connect(show_message)
	player.get_node("ItemInventory").feedback.connect(show_message)
	player.get_node("CharacterAbility").feedback.connect(show_message)
	_build_ui()
	if OS.get_cmdline_user_args().has("--l3-smoke"):
		for id in Catalog.ENEMIES:
			var enemy:=Factory.create(id,player)
			arena.add_child(enemy)
			enemy.set_encounter_active(true)
			enemy.queue_free()
		print("LEVEL03_PACKAGE_SMOKE PASS five enemies + shared player + UI")
		get_tree().quit()
		return
	var initial:=retry_wave
	retry_wave=0
	load_wave(initial)
	if OS.get_cmdline_user_args().has("--showcase"): show_gallery()
func _build_arena() -> void:
	var env:=WorldEnvironment.new()
	var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("131c20")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("d7cbaa")
	settings.ambient_light_energy=0.65
	env.environment=settings
	arena.add_child(env)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-58,-32,0)
	sun.light_color=Color("ffe4b7")
	sun.light_energy=1.15
	arena.add_child(sun)
	var floor_body:=StaticBody3D.new()
	floor_body.collision_layer=1
	floor_body.collision_mask=0
	arena.add_child(floor_body)
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(32,0.5,28)
	shape.shape=box
	shape.position.y=-0.25
	floor_body.add_child(shape)
	var tiles:=MultiMeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=Vector3(0.98,0.1,0.98)
	mesh.material=FX.mat(Color("7e7363"))
	tiles.multimesh=MultiMesh.new()
	tiles.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	tiles.multimesh.use_colors=true
	tiles.multimesh.mesh=mesh
	tiles.multimesh.instance_count=32*28
	for x in 32:
		for z in 28:
			var i:=x*28+z
			tiles.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(x-15.5,-0.05,z-13.5)))
			tiles.multimesh.set_instance_color(i,Color(1,0.94,0.83)*(0.86+((x+z)%3)*0.05))
	arena.add_child(tiles)
	for item in [[Vector3(-16,0.65,0),Vector3(0.5,1.3,28)],[Vector3(16,0.65,0),Vector3(0.5,1.3,28)],[Vector3(0,0.65,-14),Vector3(32,1.3,0.5)],[Vector3(0,0.65,14),Vector3(32,1.3,0.5)]]:
		_obstacle(item[0],item[1])
	for point in [Vector3(-8,1.25,0),Vector3(8,1.25,0)]: _obstacle(point,Vector3(1.3,2.5,1.3))
	for i in 6:
		var slab:=MeshInstance3D.new()
		var stone:=BoxMesh.new()
		stone.size=Vector3(0.6,0.12,1.8)
		stone.material=FX.mat(Color("c0b08a"))
		slab.mesh=stone
		arena.add_child(slab)
		slab.position=Vector3((i-2.5)*1.6,0.04,-11)
	camera=Camera3D.new()
	camera.current=true
	camera.position=Vector3(0,19,20)
	camera.fov=58
	arena.add_child(camera)
	camera.look_at(Vector3(0,0,-1))
func _obstacle(at: Vector3, dims: Vector3) -> void:
	var body:=StaticBody3D.new()
	body.collision_layer=1
	body.collision_mask=0
	arena.add_child(body)
	body.position=at
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=dims
	shape.shape=box
	body.add_child(shape)
	var visual:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=dims
	mesh.material=FX.mat(Color("817b70"))
	visual.mesh=mesh
	body.add_child(visual)
func _label(parent: Node, text: String, size: int=18) -> Label:
	var n:=Label.new()
	n.text=text
	n.add_theme_font_override("font",preload("res://scenes/ui/dungeon_font.tres"))
	n.add_theme_font_size_override("font_size",size)
	parent.add_child(n)
	return n
func _panel(at: Vector2, dims: Vector2) -> PanelContainer:
	var n:=PanelContainer.new()
	_content.add_child(n)
	n.position=at
	n.size=dims
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(0.04,0.07,0.08,0.93)
	style.border_color=Color("af9665")
	style.set_border_width_all(1)
	style.content_margin_left=12
	style.content_margin_right=12
	style.content_margin_top=10
	style.content_margin_bottom=10
	n.add_theme_stylebox_override("panel",style)
	return n
func _build_ui() -> void:
	var layer:=CanvasLayer.new()
	layer.layer=10
	add_child(layer)
	_content=Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(_content)
	var top:=_panel(Vector2(20,16),Vector2(500,100))
	var col:=VBoxContainer.new()
	top.add_child(col)
	_banner=_label(col,"第三关 敌人试炼原型",22)
	_stats=_label(col,"",15)
	_label(col,"演示体力 24  原型不写入永久钱包",13)
	var buttons:=HBoxContainer.new()
	_content.add_child(buttons)
	buttons.position=Vector2(20,126)
	for data in [["上一组",-1],["重试本组",0],["下一组",1],["五敌图鉴",2]]:
		var b:=Button.new()
		b.text=data[0]
		b.custom_minimum_size=Vector2(104,34)
		buttons.add_child(b)
		var action: int=data[1]
		b.pressed.connect(func() -> void:
			if action==2: show_gallery()
			else: load_wave(clampi(wave+action,0,4)))
	_boss_bar=preload("res://scenes/ui/BossHealthBar.tscn").instantiate()
	_content.add_child(_boss_bar)
	var bottom:=_panel(Vector2(20,606),Vector2(760,94))
	var info:=VBoxContainer.new()
	bottom.add_child(info)
	_message=_label(info,"",17)
	_label(info,"WASD 移动  J 普攻  K 法术  Space 翻滚  R 药剂  I 切手炮",14)
	_label(info,"1–5 切换组合   Esc 暂停   每组开始重置演示体力与补给",13)
	_pause=_panel(Vector2(470,270),Vector2(340,130))
	var pause_col:=VBoxContainer.new()
	_pause.add_child(pause_col)
	_label(pause_col,"已暂停",24)
	_label(pause_col,"Esc 继续  或选择一组重试",16)
	_pause.hide()
	get_viewport().size_changed.connect(_layout)
	_layout.call_deferred()
func _layout() -> void:
	var screen:=get_viewport().get_visible_rect().size
	_boss_bar.position=Vector2(maxf(20,screen.x-540),18)
	_boss_bar.size=Vector2(minf(520,screen.x-40),88)
	var bottom:=_message.get_parent().get_parent() as Control
	bottom.position.y=screen.y-112
	_pause.position=Vector2((screen.x-340)/2,(screen.y-130)/2)
func _clear_wave() -> void:
	get_tree().paused=false
	_pause.hide()
	_generation+=1
	_ended=false
	_boss_bar.hide()
	for actor in _actors:
		if is_instance_valid(actor): actor.set_encounter_active(false); actor.queue_free()
	_actors.clear()
	for group in ["l3_hazards","l3_transient","l3_gallery","player_projectiles"]:
		for node in get_tree().get_nodes_in_group(group):
			if arena.is_ancestor_of(node): node.queue_free()
	_pending=0
	_claimed.clear()
func load_wave(index: int) -> void:
	if is_instance_valid(player) and player.is_dead():
		# Recreate the sandbox so the shared death animation/input locks cannot leak.
		retry_wave=index
		get_tree().reload_current_scene()
		return
	_clear_wave()
	gallery=false
	camera.position=Vector3(0,19,20)
	camera.look_at(Vector3(0,0,-1))
	player.show()
	wave=clampi(index,0,4)
	player.process_mode=Node.PROCESS_MODE_PAUSABLE
	player.global_position=Vector3(0,0.05,6)
	player.hp=player.max_hp
	player.energy=player.max_energy
	player.web_remaining=0
	player._l3_slow=0
	player._invulnerability_remaining=0
	var items:=player.get_node("ItemInventory")
	items.potion_count=3
	items.rune_count=1
	items.guard_count=1
	items.gold=0
	items.owns_firearm=true
	items.ammo=18
	items.equipped_weapon=-1
	items.guard_active=false
	items._publish_state()
	_banner.text="第三关 %d/5  %s" % [wave+1,Catalog.WAVES[wave].name]
	show_message(Catalog.WAVES[wave].tip,99)
	var ids: Array=Catalog.WAVES[wave].ids
	for i in ids.size():
		spawn_enemy(ids[i],Vector3((i-(ids.size()-1)*0.5)*6,0.05,-5))
func spawn_enemy(id: String, at: Vector3) -> Node:
	if _ended or not is_instance_valid(player) or player.is_dead(): return null
	var actor:=Factory.create(id,player)
	if actor==null: return null
	actor.reward_source_id="lab:%d:%d" % [_generation,_actors.size()]
	arena.add_child(actor)
	actor.global_position=at
	actor.set_encounter_active(true)
	_actors.append(actor)
	var generation:=_generation
	actor.died.connect(func() -> void: _check_cleared.call_deferred(generation))
	actor.reward_requested.connect(func(source_id: String, coins: int) -> void:
		if generation==_generation and not _claimed.has(source_id): _claimed[source_id]=true; _pending+=coins)
	actor.summon_requested.connect(func(kind: String, point: Vector3) -> void:
		if generation==_generation and not _ended: _spawn_for_generation.call_deferred(generation,kind,point))
	if actor.is_boss():
		actor.battle_started.connect(func() -> void: _boss_bar.begin_encounter(actor.boss_name,actor.hp,actor.max_hp))
		actor.hp_changed.connect(_boss_bar.update_hp)
		actor.state_changed.connect(_boss_bar.update_state)
		actor.died.connect(_boss_bar.show_defeated)
	return actor
func _check_cleared(generation: int) -> void:
	if generation!=_generation or _ended: return
	for actor in _actors:
		if is_instance_valid(actor) and not actor.is_dead(): return
	_ended=true
	show_message("本组完成  1–5 或上方按钮选择下一组  奖励仅作接口演示",99)
func show_gallery() -> void:
	_clear_wave()
	gallery=true
	camera.position=Vector3(0,10,16)
	camera.look_at(Vector3(0,1,-1))
	player.process_mode=Node.PROCESS_MODE_DISABLED
	player.hide()
	_banner.text="第三关 五敌图鉴  参考轮廓与伤害递进"
	var i:=0
	for id in Catalog.ENEMIES:
		var actor:=Factory.create(id,player)
		arena.add_child(actor)
		actor.global_position=Vector3((i-2)*5.2,0.05,-1)
		actor.get_node("Visuals").rotation.y=PI-0.16
		actor.get_node("Visuals").pose(0,0,0,0.01)
		_actors.append(actor)
		var label:=Label3D.new()
		label.add_to_group("l3_gallery")
		label.font=preload("res://scenes/ui/dungeon_font.tres")
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size=56
		label.pixel_size=0.008
		label.text="%s\n伤害 %d  HP %d" % [Catalog.ENEMIES[id].name,Catalog.ENEMIES[id].damage,Catalog.ENEMIES[id].hp]
		arena.add_child(label)
		label.global_position=actor.global_position+Vector3.UP*(4.4 if id=="sand_king" else 3.1)
		i+=1
	show_message("四类敌人与木乃伊首领  点击上一组或下一组回到实战",99)
func _on_player_died() -> void:
	_ended=true
	for actor in _actors:
		if is_instance_valid(actor): actor.set_encounter_active(false)
	_boss_bar.hide()
	show_message("本次试炼失败  点击重试本组重新开始",99)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode>=KEY_1 and event.keycode<=KEY_5: load_wave(event.keycode-KEY_1)
		elif event.keycode==KEY_ESCAPE:
			get_tree().paused=not get_tree().paused
			_pause.visible=get_tree().paused
			get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	if not get_tree().paused:
		_clock+=delta
		_message_time=maxf(0,_message_time-delta)
	_stats.text="HP %d/%d   能量 %d/%d   演示待结算 %d" % [player.hp,player.max_hp,player.energy,player.max_energy,_pending]
func show_message(message: String, duration := 4.0) -> void:
	if is_instance_valid(_message): _message.text=message; _message_time=duration

func _spawn_for_generation(generation: int, id: String, point: Vector3) -> void:
	if generation==_generation and not _ended: spawn_enemy(id,point)
