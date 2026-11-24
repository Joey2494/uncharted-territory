extends SceneTree
## 三组机关的错误路径、离开重访、实物领取和输入隔离。
const MODULE := "res://scenes/dungeon/level04/observatory_puzzles.gd"
const PLAYER := preload("res://scenes/player/PlayerKnight.tscn")
const LAYOUT := preload("res://scenes/dungeon/level04/observatory_layout.gd")
var failures := 0
var checks := 0

class Host extends Node3D:
	var layout: Node3D
	var player: CharacterBody3D
	var inventory: Node
	var last_note := ""
	func note(message: String) -> void: last_note = message
	func add_station(id: StringName, pos: Vector3, _label: String) -> Node3D:
		var station := Node3D.new()
		station.name = id
		add_child(station)
		station.position = pos
		return station

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL ", message)

func _initialize() -> void:
	run.call_deferred()

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func run() -> void:
	check(ResourceLoader.exists(MODULE), "独立谜题模块存在")
	if failures:
		quit(1)
		return
	var host := Host.new()
	host.layout = LAYOUT.new()
	host.player = PLAYER.instantiate()
	host.add_child(host.layout)
	host.add_child(host.player)
	root.add_child(host)
	host.inventory = host.player.get_node("ItemInventory")
	var puzzles = load(MODULE).new()
	host.add_child(puzzles)
	puzzles.setup(host)
	check(not puzzles.available(&"p_alpha"), "校准前没有入射光")
	check(puzzles.interact(&"p_dial") and paused and not host.player.can_process(), "读片时角色和战斗冻结")
	await key(KEY_ENTER)
	check(puzzles.exposure == 2, "逆转到暮片")
	check(puzzles.has_method("restore_comparison_lamp"), "F 清场可以给 E 的读片台供电")
	if puzzles.has_method("restore_comparison_lamp"):
		check(puzzles.comparison_phases().is_empty(), "供电前不能并排查看试片")
		puzzles.restore_comparison_lamp()
		check(puzzles.comparison_phases() == [0, 2], "只保留亲自看过的晨、暮两片")
		puzzles.operate(&"turn", 0, -1)
		check(puzzles.comparison_phases() == [0, 2, 1], "新读过的午片入册，保留查看次序")
	await key(KEY_ESCAPE)
	check(not paused and puzzles.interact(&"p_safe"), "离台后恢复并可开柜")
	puzzles.operate(&"digit", 0, 4)
	puzzles.operate(&"submit")
	check(not puzzles.calibrated, "错误密码不放行")
	puzzles.operate(&"hint")
	puzzles.operate(&"hint")
	check(puzzles.hint_depth == 2, "两级主动提示")
	puzzles.operate(&"close")
	puzzles.interact(&"p_safe")
	check(puzzles.digits == [4, 0, 0], "重访保留拨轮")
	puzzles.operate(&"digit", 1, 2)
	puzzles.operate(&"digit", 2, 5)
	puzzles.operate(&"submit")
	check(puzzles.calibrated and not paused and puzzles.available(&"p_alpha"), "425 开柜通电")
	puzzles.interact(&"p_beta")
	check(not puzzles.mirror_solved, "光落在尚未移开的遮罩上")
	for i in 2: puzzles.interact(&"p_alpha")
	check(not puzzles.inscription_lit, "镜背吸光")
	puzzles.interact(&"p_alpha")
	check(puzzles.inscription_lit and not puzzles.mirror_solved, "照向南壁后移开遮罩")
	puzzles.interact(&"p_alpha")
	check(puzzles.mirror_solved and puzzles.available(&"p_chart"), "完整的反射光路展开星图")
	host.inventory.rune_count = host.inventory.Catalog.MAX_STACK
	check(not puzzles.interact(&"p_chart") and not puzzles.mirror_claimed, "满包保留符文")
	host.inventory.rune_count = 0
	check(puzzles.interact(&"p_chart") and not puzzles.interact(&"p_chart") and host.inventory.rune_count == 1 and host.inventory.guard_count == 1, "星图两枚不同符文仅发一次")
	check(puzzles.interact(&"p_lightbox"), "打开冲洗灯台")
	puzzles.bench.rails[1].grab_focus()
	await key(KEY_RIGHT)
	check(puzzles.plates[1] == 1 and puzzles.bench.rails[1].has_focus(), "键盘移动遮片后保留滑轨焦点")
	puzzles.operate(&"undo")
	check(puzzles.plates == [1, 0, 0], "可撤销一次试片操作")
	puzzles.operate(&"plate", 0, -1)
	puzzles.operate(&"plate", 1, 1)
	check(not puzzles.film_developed and not puzzles.available(&"p_print"), "缺侧光时冲洗未完成")
	puzzles.operate(&"close")
	puzzles.interact(&"p_lightbox")
	await process_frame
	# 点击最后一道实体滑轨最右边的刻度，松开鼠标时面板已转入显影状态。
	var final_rail: Rect2 = puzzles.bench.rails[2].get_global_rect()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = Vector2(final_rail.end.x - 3, final_rail.get_center().y)
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click, true)
		await process_frame
	check(puzzles.film_developed and not puzzles.film_claimed, "对齐人像、镜面和手后才出现成片")
	puzzles.operate(&"close")
	check(puzzles.interact(&"p_print") and not puzzles.interact(&"p_print"), "从台边单次取片")
	check(puzzles.window_photo.frame == 3, "升降台窗换上完整四人合影")
	var drops := get_nodes_in_group("item_pickups")
	check(drops.size() == 2, "两次取片仅在显影盘旁留下一对药剂")
	for drop in drops:
		host.player.global_position = drop.global_position + Vector3.BACK * 0.6
		check(drop.try_collect(host.player) and not drop.try_collect(host.player), "值班补给实际入包且不可重复拾取")
	check(host.inventory.potion_count == 1 and host.inventory.energy_potion_count == 1, "成片保留，生命和能量补给分别领取")
	print("level04 puzzle instruments: %d checks / %d failed" % [checks, failures])
	quit(1 if failures else 0)
