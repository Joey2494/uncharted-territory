extends Node3D
## 日晷观测站。主遮光闸供给北出口和支线光源；镜面方向决定真实的可视光路。
const CHARACTERS := preload("res://scenes/player/character_catalog.gd")
const STATION := preload("res://scenes/dungeon/level03/tide_station.gd")
const GATE := preload("res://scenes/dungeon/components/ProgressionGate.tscn")
const REWARD := "level04_starlight_register"
const MIRRORS := [Vector2(15, 2), Vector2(15, -4)]
const SOURCE := Vector2(10, 2)
const TABLET := Vector2(15, 6.55)
const RECEIVER := Vector2(23.4, -4)
const MIRROR_BOUNDS := Rect2(9, -7, 16, 14)
const GOLD := Color("#feb84e")
const CYAN := Color("#7ff1e4")

signal feedback(message: String)
signal completed

var powered := false
var inscription_lit := false
var finished := false
var _solved := false
var _turns := [2, 0]  # 接通电源时北向光抵达乙镜背面。
var _mirror_heads: Array[Node3D] = []
var _main_gate: StaticBody3D
var _vault_gate: StaticBody3D
var _tablet: Label3D
var _iris: MeshInstance3D
var _receiver: MeshInstance3D
var _reward_mesh: MeshInstance3D
var _reward_label: Label3D

@onready var layout := $Layout
@onready var beams := $Beams
@onready var inventory := $Player/ItemInventory

func _enter_tree() -> void:
	# 读取菜单已选择的角色；独立预览进程默认为骑士，不触发档案读写。
	$Player.character_id = CHARACTERS.selected_id

func _ready() -> void:
	$Camera3D.set_safe_frame(Rect2(0.05, 0.15, 0.9, 0.75))
	layout.build()
	_main_gate = _gate("SolarGate", Vector3(0, 0, -8), "开启前厅遮光闸")
	_vault_gate = _gate("VaultGate", Vector3(20, 0, -7), "双镜供能")
	var shutter := _station(&"power", Vector2(-2.5, 4), "升起遮光闸")
	layout.block(shutter, Vector3(0, 0.8, 0), Vector3(0.26, 0.85, 0.24), GOLD).rotation.z = -0.48
	for i in MIRRORS.size():
		var name_id := "alpha" if i == 0 else "beta"
		var station := _station(StringName(name_id), MIRRORS[i], "转动甲镜" if i == 0 else "转动乙镜")
		var head := Node3D.new()
		station.add_child(head)
		head.position.y = 1.16
		layout.block(head, Vector3.ZERO, Vector3(1.12, 0.74, 0.1), Color("#34556c"))
		# 单面镜以薄亮面区分背板；局部 +Z 为受光面。
		layout.block(head, Vector3(0, 0, 0.07), Vector3(1.03, 0.65, 0.03), CYAN, true)
		_mirror_heads.append(head)
	var reward := _station(&"claim", Vector2(20, -10), "领取星图符文")
	_reward_mesh = layout.block(reward, Vector3(0, 0.92, 0), Vector3(0.52, 0.52, 0.52), GOLD, true)
	_reward_mesh.rotation_degrees.z = 45
	layout.block(layout, Vector3(SOURCE.x, 1, SOURCE.y), Vector3(0.48, 0.55, 0.55), GOLD, true)
	layout.block(layout, Vector3(TABLET.x, 0.74, TABLET.y), Vector3(1.55, 1.45, 0.28), Color("#284356"))
	_tablet = layout.caption(layout, "南壁 · 无字星盘", Vector3(TABLET.x, 1.65, TABLET.y))
	_receiver = layout.block(layout, Vector3(RECEIVER.x, 0.94, RECEIVER.y), Vector3(0.52, 0.8, 0.82), Color("#41536d"))
	_iris = layout.block(layout, Vector3(RECEIVER.x - 0.32, 0.95, RECEIVER.y), Vector3(0.13, 0.95, 0.96), Color("#a88654"))
	layout.caption(layout, "封印透镜", Vector3(RECEIVER.x, 1.75, RECEIVER.y))
	_refresh_optics()

func _gate(title: String, point: Vector3, hint: String) -> StaticBody3D:
	var gate := GATE.instantiate() as StaticBody3D
	gate.name = title
	gate.position = point
	gate.locked_message = hint
	add_child(gate)
	return gate

func _station(id: StringName, point: Vector2, hint: String) -> Node3D:
	var station := STATION.new()
	station.name = id
	station.action = id
	station.level = self
	station.caption = hint
	station.position = Vector3(point.x, 0, point.y)
	$Stations.add_child(station)
	layout.solid(station, Vector3(0, 0.34, 0), Vector3(1.12, 0.68, 1.12), Color("#3e5566")).name = "Body"
	var caption: Label3D = layout.caption(station, hint, Vector3(0, 1.93, 0))
	if id == &"claim":
		_reward_label = caption
		caption.hide()
		_vault_gate.opened.connect(func(_id: StringName): caption.show())
	return station

func station_available(id: StringName) -> bool:
	if finished or not can_process(): return false
	match id:
		&"power": return not powered
		&"alpha", &"beta": return powered and not _solved
		&"claim": return vault_open() and not reward_claimed()
	return false

func use_station(id: StringName) -> bool:
	if not station_available(id): return false
	match id:
		&"power":
			powered = true
			_main_gate.open_gate()
			feedback.emit("遮光闸已升起。北行可离站；东侧镜室的日光也已接通。")
		&"alpha", &"beta":
			var index := 0 if id == &"alpha" else 1
			_turns[index] = (_turns[index] + 1) % 4
		&"claim":
			if not inventory.grant_reward(REWARD, {inventory.ATTACK_RUNE: 1}): return false
			_reward_mesh.hide()
			_reward_label.text = "星图已归档"
			feedback.emit("获得星图符文。沿西廊返回，北行离站。")
	_refresh_optics()
	return true

func reward_claimed() -> bool:
	return inventory.has_claimed(REWARD)

func vault_open() -> bool:
	return _vault_gate != null and _vault_gate.is_open()

## 计算镜面的实际法线。第一面将东向入射光导向南壁或乙镜，第二面可将光导向接收器。
func _normal(index: int) -> Vector2:
	var initial := Vector2(1, 1) if index == 0 else Vector2(1, -1)
	return initial.normalized().rotated(_turns[index] * PI / 2.0)

func _refresh_optics() -> void:
	for child in beams.get_children():
		beams.remove_child(child)
		child.queue_free()
	for i in MIRRORS.size():
		var normal := _normal(i)
		_mirror_heads[i].rotation.y = atan2(normal.x, normal.y)
	if not powered: return
	var origin := SOURCE
	var direction := Vector2.RIGHT
	# 两面平面镜至多需要三段光。用同一交点驱动可见光束与受光判定。
	for _bounce in 3:
		var edge := MIRROR_BOUNDS.end if direction.x + direction.y > 0 else MIRROR_BOUNDS.position
		var nearest := absf(edge.x - origin.x) if absf(direction.x) > 0.5 else absf(edge.y - origin.y)
		var hit := -1
		var targets := [MIRRORS[0], MIRRORS[1], TABLET, RECEIVER]
		for i in targets.size():
			var diff: Vector2 = targets[i] - origin
			var distance := diff.dot(direction)
			if distance > 0.01 and distance < nearest and absf(diff.cross(direction)) < 0.01:
				nearest = distance
				hit = i
		var end := origin + direction * nearest
		layout.beam(beams, origin, end, GOLD if _bounce == 0 else CYAN)
		if hit == 2:
			if not inscription_lit:
				inscription_lit = true
				_tablet.text = "北星折向日出 →"
				_receiver.material_override = layout.material(CYAN, true)
				create_tween().tween_property(_iris, "position:y", 0.15, 0.4)
				feedback.emit("南壁显影「先引北星，再照日出」。封印透镜已露出。")
			break
		if hit == 3:
			if inscription_lit and not _solved:
				_solved = true
				_vault_gate.open_gate()
				feedback.emit("透镜聚光。镜室北壁的星图柜已解封。")
			elif not inscription_lit:
				feedback.emit("透镜仍有遮罩。先让光线照亮南壁的无字星盘。")
			break
		if hit < 0: break
		var normal := _normal(hit)
		if direction.dot(normal) >= 0: break
		direction = direction.bounce(normal).round()
		origin = end

func _physics_process(_delta: float) -> void:
	if finished or not powered or not _main_gate.is_open(): return
	var p: Vector3 = $Player.position
	if absf(p.x) <= 4.5 and p.z <= -13.25 and p.z >= -16.9 and absf(p.y) <= 1.3:
		finished = true
		completed.emit()
