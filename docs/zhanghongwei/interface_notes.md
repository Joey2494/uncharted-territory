# 接口与集成说明（给其他同学）

> 维护人：张宏伟
> 这是我地牢模块需要其他同学关注 / 接入的内容，单独成文，避免与个人进度文档混在一起。

## 1. 给字远（敌人）

**敌人出生点**：在每个房间的敌人出生点生成敌人：

```gdscript
var points: Array[Marker3D] = room.get_enemy_spawn_points()
for p in points:
    var enemy = load("res://scenes/enemies/enemy.tscn").instantiate()
    add_child(enemy)
    enemy.global_position = p.global_position
```

**敌人死亡必须回调**（否则房间不会清敌开门）：

```gdscript
# 敌人死亡时
room.on_enemy_died(self)
```

## 2. 给俞吉依（玩家 / 整合）

**生成地牢**：

```gdscript
var rooms: Array[Node3D] = $DungeonGenerator.generate(3)
```

**玩家出生点**：

```gdscript
var spawn: Marker3D = rooms[0].get_player_spawn_point()
player.global_position = spawn.global_position
```

**武器出生点**：`room.get_weapon_spawn_point() → Marker3D`。

**房间传送**：监听门的 `door_entered`，把玩家移到下一房间的玩家出生点：

```gdscript
func _on_door_entered(next_room_index: int) -> void:
    var next_room = rooms[next_room_index]
    player.global_position = next_room.get_player_spawn_point().global_position
```

**房间进度**：`room_cleared` 表示该房间已清空，可用于推进流程。

## 3. 给汤志豪（UI）

- `room_cleared` 信号可驱动"房间已清除"的 HUD 提示；
- 房间切换（`door_entered`）可用于更新楼层/房间号显示。

## 4. 信号与方法速查

| 名称 | 类型 | 说明 | 接入方 |
|---|---|---|---|
| `DungeonGenerator.generate(room_count)` | 方法 | 生成并返回房间数组 | 俞吉依 |
| `Room.get_enemy_spawn_points()` | 方法 | 敌人出生点数组 | 字远 |
| `Room.get_player_spawn_point()` | 方法 | 玩家出生点 | 俞吉依 |
| `Room.get_weapon_spawn_point()` | 方法 | 武器出生点 | 俞吉依 |
| `Room.on_enemy_died(enemy)` | 方法 | 敌人死亡回调（计数开门） | 字远 |
| `signal door_entered(next_room_index)` | 信号 | 玩家进门，携带下一房间索引 | 俞吉依 |
| `signal room_cleared` | 信号 | 房间敌人已清空 | 俞吉依 / 汤志豪 |

> 接口命名为全组锁定项，改动需开会确认，见 `docs/naming_convention.md`。
