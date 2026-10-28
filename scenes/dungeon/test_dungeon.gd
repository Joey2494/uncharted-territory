extends Node3D

## 张宏伟独立测试场景：验证「3 房间拼接 + 元气骑士式门机制」
## 操作：
##   T     = 模拟击杀当前房间 1 只敌人
##   WASD  = 移动
##   清敌前：前后门关闭（红门 + 碰撞），无法通过
##   清敌后：门打开，可前进、也可回已探索房间

var _rooms: Array[Node3D] = []
var _player: CharacterBody3D = null
var _current_room_index: int = 0

@onready var _camera: Camera3D = $Camera3D
@onready var _light: DirectionalLight3D = $DirectionalLight3D


func _ready() -> void:
	_camera.position = Vector3(0, 28, 20)
	_camera.look_at(Vector3(0, 0, 14), Vector3.UP)
	_light.rotation_degrees = Vector3(-58, -35, 0)

	var generator := DungeonGenerator.new()
	add_child(generator)
	_rooms = generator.generate(3)

	for i in _rooms.size():
		var room: Room = _rooms[i]
		room.room_cleared.connect(_on_room_cleared.bind(i))
		room.door_entered.connect(_on_door_entered)
		room.player_entered_room.connect(_on_player_entered_room)
		var weapon: Marker3D = room.get_weapon_spawn_point()
		var player_spawn: Marker3D = room.get_player_spawn_point()
		print("[TestDungeon] Room%d pos=%s 敌人点=%d 武器点=%s 玩家点=%s" % [
			i + 1,
			str(room.global_position),
			room.get_enemy_spawn_points().size(),
			str(weapon.global_position) if weapon else "<缺失>",
			str(player_spawn.global_position) if player_spawn else "<缺失>",
		])

	var player_scene: PackedScene = load("res://scenes/dungeon/test_player.tscn")
	_player = player_scene.instantiate()
	add_child(_player)
	_place_player(0)

	print("[TestDungeon] 提示：T=模拟击杀；WASD=移动；清敌前门关闭，清敌后可前进/后退")

	if OS.get_cmdline_user_args().has("--selftest"):
		call_deferred("_selftest")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			_simulate_kill()


func _simulate_kill() -> void:
	var room: Room = _rooms[_current_room_index]
	if room.enemy_count > 0:
		room.on_enemy_died(null)
		print("[TestDungeon] 模拟击杀：房间%d 剩余敌人 %d" % [_current_room_index + 1, room.enemy_count])
	else:
		print("[TestDungeon] 当前房间已清空（门已开）")


func _on_room_cleared(room_index: int) -> void:
	print("[TestDungeon] 房间%d 已清空 → 门打开" % (room_index + 1))


## 玩家身体进入房间（RoomArea）：以此确定当前房间（最可靠，不依赖门信号）
func _on_player_entered_room(room_index: int) -> void:
	_current_room_index = room_index
	print("[TestDungeon] 进入房间 %d" % (room_index + 1))


## 门信号只作"穿过门"通知：显示去向；越界（最后房间）= 通关
func _on_door_entered(target: int) -> void:
	if target < _rooms.size():
		print("[TestDungeon] door_entered → 房间 %d" % target)
	else:
		print("[TestDungeon] 已通关（You Win 由俞吉依 main 场景处理）")


func _place_player(index: int) -> void:
	_current_room_index = index
	var room: Room = _rooms[index]
	var spawn: Marker3D = room.get_player_spawn_point()
	if spawn and _player:
		_player.global_position = spawn.global_position


## 自动验证（headless）：初始封闭 → 清 R1 开门 → 进入 R2 关门 → 清 R2 → 门方向信号
func _selftest() -> void:
	print("[SelfTest] === 自动验证开始 ===")
	var r1: Room = _rooms[0]
	var r2: Room = _rooms[1]
	var r3: Room = _rooms[2]

	# 1) 拼接与生成点
	if _rooms.size() != 3:
		_fail("房间数=%d 期望 3" % _rooms.size())
		return
	for i in _rooms.size():
		var room: Room = _rooms[i]
		if room.get_enemy_spawn_points().size() < 2:
			_fail("Room%d 敌人点不足" % (i + 1)); return
		if room.get_player_spawn_point() == null or room.get_weapon_spawn_point() == null:
			_fail("Room%d 缺玩家/武器点" % (i + 1)); return
		if abs(room.position.z - i * 12.0) > 0.001:
			_fail("Room%d 位置未按间距 12" % (i + 1)); return
	print("[SelfTest] OK: 3 房间排列与生成点齐全")

	# 2) 初始：所有门关闭，R1 后门封死
	if r1._front_door._is_open or r1._back_door._is_open:
		_fail("初始门应关闭"); return
	if not r1._back_door._sealed:
		_fail("R1 后门应封死"); return
	if r2._back_door._sealed:
		_fail("R2 后门不应封死"); return
	print("[SelfTest] OK: 初始门关闭，R1 入口封死")

	# 3) 清 R1：前门开 + R2 后门开 + room_cleared
	var flags := [false]
	r1.room_cleared.connect(func() -> void: flags[0] = true)
	while r1.enemy_count > 0:
		r1.on_enemy_died(null)
	if not r1._front_door._is_open or not flags[0] or not r2._back_door._is_open:
		_fail("清 R1 后通道应打开"); return
	print("[SelfTest] OK: 清 R1 后前门开、R2 后门开")

	# 4) 玩家进入 R2（有敌人）：后门保持开（可退回），前门仍关（清敌才能前进）
	r2._on_room_area_body_entered(_player)
	if not r2._back_door._is_open:
		_fail("进入 R2 后门应保持开（可退回）"); return
	if r2._front_door._is_open:
		_fail("R2 前门应仍关（清敌才能前进）"); return
	print("[SelfTest] OK: 进入 R2 后后门开（可退）、前门关（不可前进）")

	# 5) 清 R2：前门开 + R3 后门开
	while r2.enemy_count > 0:
		r2.on_enemy_died(null)
	if not r2._front_door._is_open or not r3._back_door._is_open:
		_fail("清 R2 后前门应开、R3 后门应开"); return
	print("[SelfTest] OK: 清 R2 后前门开、R3 后门开")

	# 6) 清 R3：前门开，target=3（越界 = 胜利）
	while r3.enemy_count > 0:
		r3.on_enemy_died(null)
	if not r3._front_door._is_open or r3._front_door.target_room_index != 3:
		_fail("清 R3 后前门应开且 target=3"); return
	print("[SelfTest] OK: 清 R3 后前门开（出口）")

	# 7) 门按「移动方向 velocity」触发
	# 前门：前进触发，后退不触发
	var fwd_count := [0]
	r1._front_door.door_entered.connect(func(_v: int) -> void: fwd_count[0] += 1)
	_player.velocity = Vector3(0, 0, 6)
	r1._front_door._on_body_entered(_player)
	_player.velocity = Vector3(0, 0, -6)
	r1._front_door._on_body_entered(_player)
	if fwd_count[0] != 1:
		_fail("前门应只在前进时触发"); return

	# 后门：后退触发，前进不触发（即使身体已在门的另一侧——模拟帧卡顿的情况）
	var bwd_count := [0]
	r2._back_door.door_entered.connect(func(_v: int) -> void: bwd_count[0] += 1)
	_player.velocity = Vector3(0, 0, 6)
	_player.global_position = r2._back_door.global_position + Vector3(0, 0, 0.5)
	r2._back_door._on_body_entered(_player)
	_player.velocity = Vector3(0, 0, -6)
	r2._back_door._on_body_entered(_player)
	if bwd_count[0] != 1:
		_fail("后门应只在后退时触发"); return
	print("[SelfTest] OK: 门按移动方向触发（帧卡顿也不误判）")

	# 8) 房间区域（RoomArea）确定当前房间索引
	_player.velocity = Vector3.ZERO
	r2._on_room_area_body_entered(_player)
	if _current_room_index != 1:
		_fail("进入 R2 后当前房间索引应为 1"); return
	print("[SelfTest] OK: 进入房间后当前房间索引正确")

	print("[SelfTest] === 全部通过 ===")
	get_tree().quit(0)


func _fail(msg: String) -> void:
	printerr("[SelfTest] FAIL: " + msg)
	get_tree().quit(1)
