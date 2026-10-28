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

**门是物理阻挡，玩家自然行走，不要传送**（重要变更）：

- 每个房间有前后两个门：`FrontDoor`（+z，前进）、`BackDoor`（-z，后退）；
- 门关闭时是**红色门板 + 碰撞体**，玩家撞不过去；打开后门板隐藏、碰撞关闭，玩家直接走过去；
- **前门（前进）**：初始关闭，**清敌才打开**——清敌前无法前往下一房间；
- **后门（后退）**：前一房间清空后打开并**一直保持**——已探索房间随时可退回；
- 进入房间**不再关门困住**（打不过可退回已探索房间）；第一个房间的 `BackDoor` 已永久封死（地牢入口）。

**`player_entered_room` 用来确定"当前房间"（最可靠）**：

```gdscript
func _on_player_entered_room(room_index: int) -> void:
    current_room_index = room_index   # 玩家身体进入房间时触发，不要用 door_entered 来算当前房间
```

**`door_entered` 只表示"穿过了一扇门"**：

```gdscript
func _on_door_entered(target_room_index: int) -> void:
    if target_room_index < rooms.size():
        pass                           # 仅作穿过门通知（可用于相机/音效）
    else:
        show_victory()                 # 最后房间 target 越界（=3）→ 通关
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
| `signal player_entered_room(room_index)` | 信号 | 玩家身体进入房间，携带房间索引（确定当前房间） | 俞吉依 |
| `signal door_entered(target_room_index)` | 信号 | 玩家穿过门，携带目标房间索引（仅通知，不传送） | 俞吉依 / 汤志豪 |
| `signal room_cleared` | 信号 | 房间敌人已清空（门自动开） | 俞吉依 / 汤志豪 |

> 接口命名为全组锁定项，改动需开会确认，见 `docs/naming_convention.md`。
