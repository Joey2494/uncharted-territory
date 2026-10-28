# 开发文档（张宏伟）

> 以"我 → AI 协作 → 提交"的步骤，记录我在 `feature/dungeon-mvp`、`feature/dungeon-door-fix` 分支上的开发过程。

## Step 1：工程初始化（commit `1fd610e`）

- `project.godot`：config_version=5，viewport 1280×720，Forward Plus，主场景指向 test_dungeon；
- `README.md`：运行方式 / 目录结构 / 接口契约；
- `.gitignore`：Godot 完整版（忽略 `.godot/`、`export/` 等）。

## Step 2：R1–R5 房间模板与 room.gd（commit `56fe87a`）

文件：`room_template_01/02/03.tscn`、`room.gd`

每个房间模板同一结构（112 行 .tscn）：

```
Room (Node3D)
├── Floor            StaticBody3D + BoxMesh(10×10×0.2)
├── WallE / WallW    X 向两侧墙
├── WallZFrontL/R    Z 向前墙（中间留门洞）
├── WallZBackL/R     Z 向后墙
├── Door             Area3D + door.gd（门板 BoxMesh 2×2.4×0.3，红色）
├── PlayerSpawnPoint Marker3D（z=-3）
├── EnemySpawnPoint1/2/3 Marker3D（z=1/1/2.5）
└── WeaponSpawnPoint Marker3D（z=-1）
```

room.gd 关键实现：

```gdscript
class_name Room extends Node3D
signal room_cleared
signal door_entered(next_room_index: int)
@export var enemy_count: int = 2

func get_enemy_spawn_points() -> Array[Marker3D]:
    # 按 "EnemySpawnPoint" 前缀收集全部敌人出生点
func on_enemy_died(_enemy) -> void:
    enemy_count -= 1
    if enemy_count <= 0:
        enemy_count = 0
        open_door()          # 隐藏门板 + 发 room_cleared
func set_next_room_index(index: int) -> void:
    _door.next_room_index = index
```

## Step 3：R6–R8 地牢生成器与门（commit `6f3a5ab`）

文件：`dungeon_generator.gd`、`door.gd`

dungeon_generator.gd：

```gdscript
class_name DungeonGenerator extends Node3D
const ROOM_TEMPLATES: Array[String] = [三个模板路径]
const ROOM_SPACING := 12.0

func generate(room_count: int) -> Array[Node3D]:
    for i in room_count:
        var room = 随机选模板.instantiate()
        room.position = Vector3(0, 0, i * ROOM_SPACING)   # 沿 Z 线性拼接
        room.name = "Room%d" % (i + 1)
        add_child(room)                                    # 先入场景树
        room.set_next_room_index(i + 1)                    # 再设门的目标房间
        rooms.append(room)
```

door.gd：

```gdscript
class_name Door extends Area3D
@export var next_room_index := -1
@onready var _mesh := $Mesh
@onready var _room := get_parent() as Room

func open() -> void:  _mesh.hide()          # 红门隐藏 = 可通行（R8）

func _on_body_entered(body) -> void:
    if _is_open and _room.enemy_count == 0:
        door_entered.emit(next_room_index)  # 仅清敌后允许传送
```

## Step 4：独立测试场景（commit `cac6d42`）

文件：`test_dungeon.tscn/.gd`、`test_player.tscn/.gd`

- 场景内放 DungeonGenerator，`_ready` 时 `generate(3)` 并打印各房间信息；
- 简易玩家：CharacterBody3D 胶囊体，WASD 移动，SPEED=6；
- 按 T 模拟击杀一只敌人，验证开门；走入验证 door_entered 传送；
- 相机：俯视全景 `(0, 28, 20)`，`look_at(0, 0, 14)`。

## Step 5：R10 命名规范（commit `f460584`）

`docs/naming_convention.md`：文件/节点/脚本命名规则、接口契约锁定表、Git 约定。

## Step 6：合并 main（commit `eebe9fb`）

`git merge --no-ff feature/dungeon-mvp`，合并 5 个提交，13 个文件 +778 行。

## 后续修复（commit `6222038` / `63b5950`）

- 修复 next_room_index 绑定时机（见 [testing.md](testing.md) Bug 2）；
- 提交 Godot 4.4+ 生成的脚本 `.uid` 文件。

## Step 7：元气骑士式门机制（本轮修复）

我在 Godot 里实跑发现 3 个问题，对照元气骑士重写了门与房间：

| 问题 | 根因 | 修复 |
|---|---|---|
| 玩家从第一个房间后门直接跑出地图 | 后墙留了门洞，但门洞处没有门 | 每房加 `BackDoor`，首房 `BackDoor` 调 `seal()` 永久封死 |
| 门一开始畅通无阻、门板是白色 | 门板 `Area3D` 不产生物理阻挡；材质定义了却没被 Mesh 引用，全用默认白色 | 门内加 `Blocker`（StaticBody 碰撞）；给所有 BoxMesh 补 `material` 引用（红色门板） |
| 进下一房间后无法返回 | 只有前门，没有后门 | 每房加前后两门 + `RoomArea`，清敌前关门、清敌开门，可自由往返 |
| 进 R2 后被关、T 清不了 R2（状态卡在 R1） | 门方向按身体位置判定，**帧卡顿一次穿越**时身体已在门另一侧，R2 后门误发 `door_entered(0)` 把当前房间拉回 R1 | 门方向改用**移动速度 velocity** 判定；新增 `player_entered_room` 信号，由 RoomArea 确定当前房间索引 |

新房间结构：

```
Room (Node3D, room.gd)
├── Floor / WallE / WallW / WallZFrontL,R / WallZBackL,R
├── FrontDoor (Area3D, door.gd, direction=1)
│   ├── Mesh（红色门板）  AreaCollision（薄检测）
│   └── Blocker (StaticBody3D) → BlockerCollision（关闭时阻挡）
├── BackDoor (Area3D, door.gd, direction=-1)  同上
├── RoomArea (Area3D)  检测玩家进入房间（9×3×9）
└── PlayerSpawnPoint / EnemySpawnPoint1-3 / WeaponSpawnPoint
```

状态机（room.gd，初版"困住"）：

- 玩家进入未清房间（`RoomArea.body_entered`）→ 前后门全关（困住）；
- 敌人死亡回调 `on_enemy_died` 计数到 0 → 前后门全开 + 发 `room_cleared`，并联动下一房间打开其后门；
- 门按**玩家移动速度 velocity** 判定方向：前门只在前进时触发，后门只在后退时触发。

生成器（dungeon_generator.gd）：所有房间就位后再 `setup()` 链接，相邻房间之间补 `Corridor` 走廊地板（地板 10 深、间距 12，留 2 的缝）。

接口变更已同步到 [interface_notes.md](interface_notes.md)：`next_room_index` 改名 `target_room_index`，玩家**自然行走不再传送**。

## Step 8：软门机制（按反馈调整，commit `9e7f50a`）

实跑反馈：进入第二、三房间后，中间的门"经过就关、要全部通关才开"，体验不好。我和组长确认改为**软门**（不困住，只挡前进）：

| 门 | 行为 |
|---|---|
| **前门 FrontDoor（前进）** | 初始关闭，**清敌才打开**——清敌前无法前往下一房间 |
| **后门 BackDoor（后退）** | 前一房间清空后打开并**一直保持**——已探索房间随时可退回 |
| 首房 BackDoor | 永久封死（地牢入口） |

实现改动（room.gd）：

- `RoomArea.body_entered` 只发 `player_entered_room`（确定当前房间），**不再关门**；
- `on_previous_room_cleared()` 打开后门并保持（去掉"未清才开"的条件，避免被任何逻辑重新关上）；
- 清敌 `_on_cleared()` 打开前门（后门此时已开）。

> 说明：元气骑士原版是"进房间全关、清敌全开"（硬门困住）。我们按课程难度和反馈改成软门，核心规则"清敌前不能前进、之后可自由往返"不变。
