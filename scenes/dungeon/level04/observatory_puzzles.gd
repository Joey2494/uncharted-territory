extends Node3D
## 曝光盘、双镜和暗房共享本局状态。面板只发操作，世界中的读数与光路取自同一份数据。
const PANEL := preload("res://scenes/dungeon/level04/observatory_bench.gd")
const PHOTO := preload("res://scenes/dungeon/level04/night_shift_plates.png")
const REWARD := "level04_starlight_register"
const GOLD := Color("#ffc76a")
const CYAN := Color("#84e9db")
const BRASS := Color("#8d7150")
const BLUE := Color("#253d4d")
const PHASES := ["晨", "午", "暮"]
const STARS := [
	[Vector2(-0.61, -0.32), Vector2(-0.22, 0.29), Vector2(0.31, -0.27), Vector2(0.63, 0.22)],
	[Vector2(-0.53, 0.24), Vector2(0.48, -0.26)],
	[Vector2(-0.69, 0.26), Vector2(-0.39, -0.32), Vector2(0, 0.27), Vector2(0.32, -0.15), Vector2(0.68, 0.16)]
]
const MIRRORS := [Vector2(-1.8, 2.35), Vector2(-1.8, -2.6)]
const SOURCE := Vector2(-6.5, 2.35)
const TABLET := Vector2(-1.8, 5.6)
const RECEIVER := Vector2(6.1, -2.6)
const BOUNDS := Rect2(-7.1, -6.1, 14.2, 12.2)

var level
var layout
var calibrated := false
var mirror_solved := false
var mirror_claimed := false
var film_developed := false
var film_claimed := false
var inscription_lit := false
var exposure := 0
var digits := [0, 0, 0]
var hint_depth := 0
var plates := [1, 0, 0]
var previous_plates: Array = []
var plate_zoom := -1
var display := &""
var status := ""
var bench
var phase_displays: Array[Node3D] = []
var turns := [2, 0]
var heads: Array[Node3D] = []
var beams := Node3D.new()
var tablet_label: Label3D
var iris: Node3D
var chart: Node3D
var print_sprite: Sprite3D
var window_photo: Sprite3D
var hood: Node3D
var slide_knobs: Array[Node3D] = []

func setup(host: Node3D) -> void:
	level = host
	layout = host.layout
	_build_exposure()
	_build_mirrors()
	_build_darkroom()
	bench = PANEL.new()
	bench.instrument = self
	bench.name = "InstrumentView"
	add_child(bench)
	_refresh_optics()

func _center(room: StringName) -> Vector3:
	return layout.room_center(room)

func _station(id: StringName, room: StringName, x: float, z: float, label: String) -> Node3D:
	return level.add_station(id, _center(room) + Vector3(x, 0, z), label)

func _build_exposure() -> void:
	var dial := _station(&"p_dial", &"E", -2.5, 2.6, "转动曝光轮")
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.56
	wheel.bottom_radius = 0.56
	wheel.height = 0.19
	var hub := MeshInstance3D.new()
	hub.mesh = wheel
	hub.material_override = layout.material(BRASS)
	dial.add_child(hub)
	hub.position.y = 0.81
	for i in 3:
		var grip: MeshInstance3D = layout.block(hub, Vector3(sin(i*TAU/3)*0.47, 0.12, cos(i*TAU/3)*0.47), Vector3(0.14, 0.18, 0.14), GOLD)
		grip.rotation.y = i * TAU/3
	# 三块试片实际摆成暮、午、晨。刻十字的是定位标，不参加数数。
	var locations := [Vector3(-5.5, 0.95, -3.1), Vector3(-0.3, 0.95, -5.3), Vector3(5.2, 0.95, -4.6)]
	for slot in 3:
		var phase := 2 - slot
		var board := Node3D.new()
		add_child(board)
		board.position = _center(&"E") + locations[slot]
		board.rotation.x = -0.42
		layout.block(board, Vector3.ZERO, Vector3(2.1, 1.14, 0.15), BLUE)
		layout.block(board, Vector3(0, 0, 0.09), Vector3(0.34, 0.025, 0.02), BRASS)
		layout.block(board, Vector3(0, 0, 0.09), Vector3(0.025, 0.34, 0.02), BRASS)
		var constellation := Node3D.new()
		board.add_child(constellation)
		for p: Vector2 in STARS[phase]:
			var bulb: MeshInstance3D = layout.block(constellation, Vector3(p.x, -p.y, 0.11), Vector3(0.12, 0.12, 0.05), GOLD, true)
			bulb.rotation.z = PI/4
		phase_displays.push_front(constellation)
		constellation.visible = phase == exposure
		layout.caption(board, PHASES[phase], Vector3(0, 0.84, 0))
	var safe := _station(&"p_safe", &"E", 2.7, -2, "校准密码柜")
	hood = layout.block(safe, Vector3(0, 0.96, 0), Vector3(1.22, 0.68, 0.8), BRASS)
	for i in 3:
		layout.block(hood, Vector3((i-1)*0.29, 0, 0.43), Vector3(0.17, 0.29, 0.06), GOLD)

func _build_mirrors() -> void:
	add_child(beams)
	beams.position = _center(&"K")
	for i in 2:
		var station := _station(&"p_alpha" if i == 0 else &"p_beta", &"K", MIRRORS[i].x, MIRRORS[i].y, "转动甲镜" if i == 0 else "转动乙镜")
		var head := Node3D.new()
		station.add_child(head)
		head.position.y = 1.16
		layout.block(head, Vector3.ZERO, Vector3(1.2, 0.85, 0.16), BRASS)
		layout.block(head, Vector3(0, 0, 0.1), Vector3(1.03, 0.65, 0.04), CYAN, true)
		heads.append(head)
	var center := _center(&"K")
	layout.block(self, center + Vector3(SOURCE.x, 1.15, SOURCE.y), Vector3(0.55, 0.7, 0.6), GOLD, true)
	layout.block(self, center + Vector3(TABLET.x, 0.8, TABLET.y), Vector3(2, 1.5, 0.22), BLUE)
	tablet_label = layout.caption(self, "南壁 · 无字星盘", center + Vector3(TABLET.x, 1.72, TABLET.y))
	layout.block(self, center + Vector3(RECEIVER.x, 1.05, RECEIVER.y), Vector3(0.64, 0.85, 0.9), CYAN, true)
	iris = layout.block(self, center + Vector3(RECEIVER.x - 0.35, 1.05, RECEIVER.y), Vector3(0.16, 1, 1.02), BRASS)
	var rack := _station(&"p_chart", &"K", 4.4, 2.9, "观测星图架")
	chart = Node3D.new()
	rack.add_child(chart)
	chart.position.y = 0.91
	layout.block(chart, Vector3.ZERO, Vector3(1.5, 0.09, 0.94), BLUE)
	var seals := [GOLD, CYAN, Color("#d48e85"), Color("#bb9ce1")]
	for i in 4:
		layout.block(chart, Vector3((i-1.5)*0.29, 0.07, 0.28), Vector3(0.19, 0.06, 0.19), seals[i], true)
	for p: Vector2 in STARS[0]:
		layout.block(chart, Vector3(p.x, 0.07, p.y-0.15), Vector3(0.09, 0.03, 0.09), GOLD, true)
	chart.hide()

func _framed_photo(parent: Node3D, offset: Vector3, frame: int, width: float) -> Sprite3D:
	var picture := Sprite3D.new()
	picture.texture = PHOTO
	picture.hframes = 4
	picture.frame = frame
	picture.pixel_size = width / (PHOTO.get_width()/4.0)
	picture.position = offset + Vector3(0, 0, 0.09)
	picture.rotation.x = -0.38
	picture.shaded = false
	parent.add_child(picture)
	var frame_mesh: MeshInstance3D = layout.block(parent, offset, Vector3(width+0.16, width*206/440+0.16, 0.09), BRASS)
	frame_mesh.rotation.x = picture.rotation.x
	return picture

func _build_darkroom() -> void:
	var entry := _station(&"p_photo", &"A", -3.3, -2, "查看值班合影")
	_framed_photo(entry, Vector3(0, 1.34, 0), 0, 2.25)
	for i in 4:
		layout.block(entry, Vector3((i-1.5)*0.36, 0.76, 0.28), Vector3(0.21, 0.26, 0.06), [GOLD, CYAN, Color("#d48e85"), Color("#bb9ce1")][i])
	var box := _station(&"p_lightbox", &"L", 0.4, 0.6, "操作冲洗灯台")
	layout.block(box, Vector3(0, 0.76, 0), Vector3(2.1, 0.18, 1.2), Color("#a5786e"))
	for i in 3:
		layout.block(box, Vector3(0, 0.87, (i-1)*0.32), Vector3(1.62, 0.04, 0.07), BLUE)
		slide_knobs.append(layout.block(box, Vector3((plates[i]-1)*0.64, 0.93, (i-1)*0.32), Vector3(0.21, 0.11, 0.15), GOLD))
	for i in 3:
		var pos := _center(&"L") + Vector3((i-1)*3.35, 1.23, -4.5)
		_framed_photo(self, pos, i, 2.76)
		layout.caption(self, ["欠曝片", "长曝片", "侧光片"][i], pos + Vector3(0, 0.97, 0))
	var reprint := _station(&"p_negative", &"L", -4.2, -1.6, "翻看交班合影")
	_framed_photo(reprint, Vector3(0, 1.22, 0), 0, 1.68)
	var tray := _station(&"p_print", &"L", 4, 1.6, "从显影盘取成片")
	print_sprite = _framed_photo(tray, Vector3(0, 0.96, 0), 3, 1.3)
	print_sprite.hide()
	var window := _station(&"p_window", &"J", -3, -1, "看照相窗")
	window_photo = _framed_photo(window, Vector3(0, 1.34, 0), 0, 2.3)

func modal_open() -> bool:
	return display != &""

func available(id: StringName) -> bool:
	if modal_open(): return false
	match id:
		&"p_dial", &"p_photo", &"p_lightbox", &"p_negative", &"p_window": return true
		&"p_safe": return not calibrated
		&"p_alpha", &"p_beta": return calibrated and not mirror_solved
		&"p_chart": return mirror_solved and not mirror_claimed
		&"p_print": return film_developed and not film_claimed
	return false

func interact(id: StringName) -> bool:
	if not available(id): return false
	match id:
		&"p_alpha", &"p_beta":
			var i := 0 if id == &"p_alpha" else 1
			turns[i] = (turns[i]+1)%4
			_refresh_optics()
		&"p_chart":
			if not level.inventory.grant_reward(REWARD, {level.inventory.ATTACK_RUNE: 1, level.inventory.GUARD_RUNE: 1}):
				level.note("背包空间不足。星图架会为你保留奖励。")
				return false
			mirror_claimed = true
			level.note("取得强化符文与守护符文各一枚。星图边缘盖着夜班四人的印记。")
		&"p_print":
			film_claimed = true
			print_sprite.hide()
			window_photo.frame = 3
			# 成片先更新结局；留下的值班补给可分别拾取，满包也能完成合影。
			var medicine := preload("res://scenes/items/HealthPotion.tscn").instantiate() as Node3D
			medicine.position = _center(&"L") + Vector3(2, 0, 3.7)
			add_child(medicine)
			var reserve := preload("res://scenes/items/EnergyPotion.tscn").instantiate() as Node3D
			reserve.position = _center(&"L") + Vector3(4.2, 0, 3.7)
			add_child(reserve)
			level.note("完整合影已送往照相窗。显影盘旁的生命药剂和星蓝药剂可按 E 拾取。")
		_:
			display = id
			status = ""
			plate_zoom = -1
			get_tree().paused = true
			bench.present()
	return true

## 面板键鼠操作及实物控件都调用此入口，状态随离台保留。
func operate(action: StringName, index := 0, delta := 1) -> void:
	if not modal_open(): return
	if action == &"close":
		display = &""
		bench.dismiss()
		get_tree().paused = false
		return
	match display:
		&"p_dial":
			if action == &"turn":
				exposure = posmod(exposure + delta, 3)
				for i in 3: phase_displays[i].visible = exposure == i
		&"p_safe":
			match action:
				&"digit":
					if index >= 0 and index < 3: digits[index] = posmod(digits[index] + delta, 10)
					status = ""
				&"hint": hint_depth = mini(2, hint_depth+1)
				&"submit":
					if digits == [4, 2, 5]:
						calibrated = true
						operate(&"close")
						hood.create_tween().tween_property(hood, "rotation:y", -1.1, 0.42)
						_refresh_optics()
						level.note("百叶已开启。北门通往栈道，东侧旧镜室也收到了日光。")
						return
					status = "锁舌没有松动。可离台复看墙片。"
		&"p_lightbox":
			if action == &"zoom":
				plate_zoom = -1 if plate_zoom == index else clampi(index, -1, 2)
			elif action == &"undo" and not film_developed and not previous_plates.is_empty():
				plates = previous_plates.pop_back()
				status = ""
			elif action == &"plate" and not film_developed and index >= 0 and index < 3:
				previous_plates.append(plates.duplicate())
				plates[index] = posmod(plates[index]+delta, 3)
				plate_zoom = -1
				film_developed = plates == [0, 1, 2]
				status = "显影完成。到台边取下成片。" if film_developed else ""
				if film_developed: print_sprite.show()
			for i in 3: slide_knobs[i].position.x = (plates[i]-1)*0.64
			if action in [&"plate",&"undo"] and not film_developed:
				bench.update_rails()
				return
	bench.refresh()

## 单面镜反射。可见光束、铭文显影和解锁共用最近交点。
func _refresh_optics() -> void:
	for child in beams.get_children():
		beams.remove_child(child)
		child.queue_free()
	var normals: Array[Vector2] = []
	for i in 2:
		var basis_normal := Vector2(1, 1) if i == 0 else Vector2(1, -1)
		var normal := basis_normal.normalized().rotated(turns[i]*PI/2)
		normals.append(normal)
		heads[i].rotation.y = atan2(normal.x, normal.y)
	if not calibrated: return
	var origin := SOURCE
	var direction := Vector2.RIGHT
	var targets := [MIRRORS[0], MIRRORS[1], TABLET, RECEIVER]
	for bounce in 3:
		var edge := BOUNDS.end if direction.x+direction.y > 0 else BOUNDS.position
		var nearest := absf(edge.x-origin.x) if absf(direction.x)>0.5 else absf(edge.y-origin.y)
		var hit := -1
		for i in targets.size():
			var diff: Vector2 = targets[i]-origin
			var distance := diff.dot(direction)
			if distance > 0.01 and distance < nearest and absf(diff.cross(direction)) < 0.01:
				nearest = distance
				hit = i
		var end := origin + direction*nearest
		layout.beam(beams, origin, end, GOLD if bounce == 0 else CYAN)
		match hit:
			0, 1:
				if direction.dot(normals[hit]) >= 0: break
				direction = direction.bounce(normals[hit]).round()
				origin = end
			2:
				if not inscription_lit:
					inscription_lit = true
					tablet_label.text = "北星折向日出 →"
					iris.create_tween().tween_property(iris, "position:y", 0.16, 0.4)
					level.note("南壁显影「北星折向日出」。东侧透镜的铜罩移开了。")
				break
			3:
				if inscription_lit and not mirror_solved:
					mirror_solved = true
					chart.show()
					chart.scale.z = 0.08
					chart.create_tween().tween_property(chart, "scale:z", 1, 0.55)
					level.note("星图展开。室内星图架上可领取强化与守护两枚符文。")
				elif not inscription_lit:
					level.note("光落在遮罩上。南壁空白的星盘仍待显影。")
				break
			_: break
