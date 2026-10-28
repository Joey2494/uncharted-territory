# 开发文档（张宏伟）

> 以"我 → AI 协作 → 提交"的步骤，记录我在 `feature/dungeon-mvp` 上的开发过程。

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
