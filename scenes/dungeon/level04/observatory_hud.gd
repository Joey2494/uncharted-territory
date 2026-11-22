extends CanvasLayer
const NAV := preload("res://scripts/integration/menu_navigation.gd")
const MAP := preload("res://scenes/dungeon/level04/observatory_map.gd")
@onready var level := get_parent()
@onready var overlay := $Overlay
@onready var message := $Readout/Rows/Message
@onready var goal := $Readout/Rows/Goal
var remaining := 0.0
var switching := false
var map: Control

func _ready() -> void:
	level.feedback.connect(_notice)
	level.completed.connect(_finish)
	level.failed.connect(func(): _show_overlay("观测中断","角色已倒下。重新进入可从到达台再次出发。",false))
	level.get_node("Player/ItemInventory").pickup_prompt_changed.connect(func(s: String):
		$Readout/Rows/Prompt.text = s
		$Readout/Rows/Prompt.visible = s != "")
	$Overlay/Card/Resume.pressed.connect(_resume)
	$Overlay/Card/Restart.pressed.connect(_restart)
	$Overlay/Card/Return.pressed.connect(_return_to_levels)
	$MapButton.pressed.connect(_open_map)
	$Overlay/Card/Backpack.pressed.connect(func(): level.commerce.open_backpack())
	map = MAP.new()
	map.level = level
	map.custom_minimum_size.y = 300
	$Overlay/Card.add_child(map)
	$Overlay/Card.move_child(map,2)
	map.hide()

func _notice(s: String) -> void:
	message.text = s
	message.show()
	remaining = 4.5

func _process(delta: float) -> void:
	if not level.is_node_ready(): return
	var panel_open: bool = overlay.visible or level.puzzles.modal_open() or level.commerce.view != level.commerce.View.NONE
	$Readout.visible = not panel_open
	$Keys.visible = not panel_open
	$MapButton.visible = not panel_open
	level.commerce.shortcut.visible = not panel_open and not level.finished
	if panel_open:
		$Boss.hide()
		return
	var id: String = level.current_room
	var location := id + " " + str(level.NAMES[id]) if level.NAMES.has(id) else "连接通廊"
	$Readout/Rows/Title.text = "日晷观测站   /   %s     %d/12" % [location,level.visited.size()]
	$Readout/Rows/Vitals.text = "生命 %d/%d   护盾 %d   能量 %d/%d   药 %d" % [level.player.hp,level.player.max_hp,level.player.shield,level.player.energy,level.player.max_energy,level.inventory.potion_count]
	goal.text = level.objective()
	var hint: String = level.side_hint()
	$Readout/Rows/Side.visible = hint != "" and not level.optional_done(level.current_room) and level.combat.active_room == ""
	$Readout/Rows/Side.text = hint
	var boss = level.combat.boss_guard()
	$Boss.visible = is_instance_valid(boss) and not boss.is_dead()
	if $Boss.visible:
		$Boss/Rows/Name.text = "执刑官　 %d / %d" % [boss.hp,boss.max_hp]
		$Boss/Rows/Health.max_value = boss.max_hp
		$Boss/Rows/Health.value = boss.hp
	if remaining > 0:
		remaining -= delta
		if remaining <= 0: message.hide()

func _input(event: InputEvent) -> void:
	if level.finished or event.is_echo() or level.puzzles.modal_open() or level.commerce.view != level.commerce.View.NONE: return
	var tab: bool = event is InputEventKey and event.keycode == KEY_TAB and event.pressed
	if not event.is_action_pressed("pause") and not tab: return
	get_viewport().set_input_as_handled()
	if overlay.visible: _resume()
	elif tab: _open_map()
	else: _show_overlay("观测暂停","J 普攻   K 法术   L 角色技能   空格闪避\nR 回血   F 强化   G 守护   I 换武器   P 商店",true)

func _open_map() -> void:
	if level.finished or get_tree().paused: return
	_show_overlay("观测站路线","金线为主路　青线为支路　● 当前位置　✓ 支线完成",true)
	map.show()
	map.queue_redraw()

func _finish() -> void:
	var photo := "照相窗亮起，快门线后的人也回到了合影里。" if level.puzzles.film_claimed else "升降台掠过照相窗。三个人站在镜头前，窗边挂着四枚工牌。"
	_show_overlay("升降台已抵达地面","探索 %d/12　支线完成 %d/4\n%s" % [level.visited.size(),level.optional_count(),photo],false)

func _show_overlay(title: String, body: String, can_resume: bool) -> void:
	$Overlay/Card/Title.text = title
	$Overlay/Card/Body.text = body
	$Overlay/Card/Resume.visible = can_resume
	$Overlay/Card/Backpack.visible = can_resume
	map.hide()
	overlay.show()
	get_tree().paused = true
	if can_resume: $Overlay/Card/Resume.grab_focus()
	else: $Overlay/Card/Return.grab_focus()

func _resume() -> void:
	if level.finished or switching: return
	overlay.hide()
	get_tree().paused = false

func _restart() -> void:
	if switching: return
	switching = true
	var tree := get_tree()
	tree.paused = false
	var err := tree.reload_current_scene()
	if err != OK:
		switching = false
		tree.paused = true
		$Overlay/Card/Body.text = "重开失败：" + error_string(err)

func _return_to_levels() -> void:
	if switching: return
	switching = true
	var tree := get_tree()
	var previous := NAV.pending_level_select
	NAV.pending_level_select = true
	tree.paused = false
	var err := tree.change_scene_to_file("res://Main.tscn")
	if err != OK:
		NAV.pending_level_select = previous
		switching = false
		tree.paused = true
		$Overlay/Card/Body.text = "返回选关失败：" + error_string(err)
