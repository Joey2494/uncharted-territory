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
	_camera.position = Vector3(0, 28, 16)
	_camera.look_at(Vector3(0, 0, 16), Vector3.UP)
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
		print("[TestDungeon] Room%d pos=%v 敌人点=%d 武器点=%s 玩家点=%s" % [
			i + 1,
			room.global_position,
			room.get_enemy_spawn_points().size(),
			str(weapon.global_position) if weapon else "<缺失>",
			str(player_spawn.global_position) if player_spawn else "<缺失>",
		])

	var player_scene: PackedScene = load("res://scenes/dungeon/test_player.tscn")
	_player = player_scene.instantiate()
	add_child(_player)
	_place_player(0)

	print("[TestDungeon] 提示：T=模拟击杀 1 只敌人；WASD=移动；清敌后门消失，走入门测试传送")


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
