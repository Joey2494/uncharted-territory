extends Node3D

## 张宏伟独立测试场景：验证「3 房间拼接 + 门逻辑」
## 操作提示：
##   T     = 模拟击杀当前房间 1 只敌人（验证清敌开门）
##   WASD  = 移动测试玩家
##   （门打开后）走进门 = 触发 door_entered 传送，打印日志

var _rooms: Array[Node3D] = []
var _player: CharacterBody3D = null
var _current_room_index: int = 0

@onready var _camera: Camera3D = $Camera3D
@onready var _light: DirectionalLight3D = $DirectionalLight3D


func _ready() -> void:
	# 俯视全景：3 个房间沿 Z 轴排列，视野覆盖 -6..30
	_camera.position = Vector3(0, 28, 20)
	_camera.look_at(Vector3(0, 0, 14), Vector3.UP)
	_light.rotation_degrees = Vector3(-58, -35, 0)

	var generator := DungeonGenerator.new()
	add_child(generator)
	_rooms = generator.generate(3)

	for i in _rooms.size():
		var room = _rooms[i]
		room.room_cleared.connect(_on_room_cleared.bind(i))
		var door: Node = room.get_node_or_null("Door")
		if door and door.has_signal("door_entered"):
			door.door_entered.connect(_on_door_entered)
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

	print("[TestDungeon] 提示：T=模拟击杀 1 只敌人；WASD=移动；清敌后门消失，走入门测试传送")

	# 命令行自检：godot --headless --path . -- --selftest
	if OS.get_cmdline_user_args().has("--selftest"):
		call_deferred("_selftest")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			_simulate_kill()


func _simulate_kill() -> void:
	var room = _rooms[_current_room_index]
	if room.enemy_count > 0:
		room.on_enemy_died(null)
		print("[TestDungeon] 模拟击杀：房间%d 剩余敌人 %d" % [_current_room_index + 1, room.enemy_count])
	else:
		print("[TestDungeon] 当前房间已清空（门已开）")


func _on_room_cleared(room_index: int) -> void:
	print("[TestDungeon] 房间%d 已清空 → 门打开" % (room_index + 1))


func _on_door_entered(next_room_index: int) -> void:
	print("[TestDungeon] door_entered → 下一房间 %d" % next_room_index)
	if next_room_index < _rooms.size():
		_place_player(next_room_index)
	else:
		print("[TestDungeon] 已超过最后一间房（You Win 由俞吉依 main 场景处理）")


func _place_player(index: int) -> void:
	_current_room_index = index
	var room = _rooms[index]
	var spawn: Marker3D = room.get_player_spawn_point()
	if spawn and _player:
		_player.global_position = spawn.global_position


## 自动验证（headless 用）：拼接 → 生成点 → 清敌开门 → door_entered 信号
func _selftest() -> void:
	print("[SelfTest] === 自动验证开始 ===")

	# 1) 拼接与生成点
	if _rooms.size() != 3:
		printerr("[SelfTest] FAIL: 房间数=%d 期望 3" % _rooms.size())
		get_tree().quit(1)
		return
	for i in _rooms.size():
		var room = _rooms[i]
		if room.get_enemy_spawn_points().size() < 2:
			printerr("[SelfTest] FAIL: Room%d 敌人点不足" % (i + 1))
			get_tree().quit(1)
			return
		if room.get_player_spawn_point() == null or room.get_weapon_spawn_point() == null:
			printerr("[SelfTest] FAIL: Room%d 缺少玩家/武器出生点" % (i + 1))
			get_tree().quit(1)
			return
		# 房间沿 Z 轴等距排列（间距 12）
		if abs(room.position.z - i * 12.0) > 0.001:
			printerr("[SelfTest] FAIL: Room%d 位置 %s 未按间距 12 排列" % [i + 1, str(room.position)])
			get_tree().quit(1)
			return
	print("[SelfTest] OK: 3 房间排列与生成点齐全")

	# 2) 清敌开门 + room_cleared
	# 注：GDScript lambda 按值捕获局部变量，共享状态需用数组（引用类型）
	var room0 = _rooms[0]
	var door0: Node = room0.get_node_or_null("Door")
	var flags := [false]
	room0.room_cleared.connect(func() -> void: flags[0] = true)
	while room0.enemy_count > 0:
		room0.on_enemy_died(null)
	if door0 == null or not door0._is_open or not flags[0]:
		printerr("[SelfTest] FAIL: 清敌后 door_open=%s room_cleared=%s" % [str(door0._is_open if door0 else "<无门>"), str(flags[0])])
		get_tree().quit(1)
		return
	print("[SelfTest] OK: 清敌后门打开，room_cleared 已发出")

	# 3) door_entered 信号（模拟玩家走入）
	var door_flags := [false, -1]
	door0.door_entered.connect(func(v: int) -> void:
		door_flags[0] = true
		door_flags[1] = v
	)
	door0._on_body_entered(_player)
	if not door_flags[0] or door_flags[1] != 1:
		printerr("[SelfTest] FAIL: door_entered fired=%s next=%d 期望 1" % [str(door_flags[0]), door_flags[1]])
		get_tree().quit(1)
		return
	print("[SelfTest] OK: door_entered(1) 信号正常")

	print("[SelfTest] === 全部通过 ===")
	get_tree().quit(0)
