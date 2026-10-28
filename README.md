# uncharted-territory（未至之境）

3D 俯视角 Roguelike 地牢探索 —— 四人小组课程作业（Godot 4，GDScript）。

## 运行方式

1. 用 Godot 4.x 打开本目录（仓库根目录即 `res://` 根）
2. 按 F5 运行

> **当前入口**：`scenes/dungeon/test_dungeon.tscn`（张宏伟地牢模块独立测试场景）
> - T：模拟击杀当前房间一只敌人（验证清敌开门）
> - WASD：移动测试玩家（验证走进门触发传送）
> - 俞吉依整合完成后，入口切换为 `scenes/main.tscn`

## 目录结构（各目录放本人文件，Git 冲突概率最低）

```
res://
├── scenes/
│   ├── main.tscn            ← 俞吉依（整合）
│   ├── player/              ← 俞吉依
│   ├── dungeon/             ← 张宏伟
│   ├── enemies/             ← 字远
│   ├── items/               ← 字远
│   └── ui/                  ← 汤志豪
├── assets/
│   ├── audio/               ← 汤志豪
│   ├── particles/           ← 汤志豪
│   └── shaders/             ← 汤志豪
├── data/                    ← 字远
└── docs/                    ← 文档（命名规范、提案、接口契约等）
```

## 接口契约（张宏伟提供 / 消费部分）

| 方向 | 信号 / 方法 | 消费方 |
|---|---|---|
| 提供 | `DungeonGenerator.generate(room_count: int) → Array[Node3D]` | 俞吉依（main） |
| 提供 | `Room.get_enemy_spawn_points() → Array[Marker3D]` | 字远（EnemySpawner） |
| 提供 | `Room.get_player_spawn_point() → Marker3D` | 俞吉依（main） |
| 提供 | `Room.get_weapon_spawn_point() → Marker3D` | 俞吉依（main） |
| 提供 | `signal door_entered(next_room_index: int)` | 俞吉依（main 传送） |
| 提供 | `signal room_cleared` | 俞吉依（main 进度） |
| 消费 | `signal enemy_died(enemy: Node3D)`（字远） | 张宏伟（计数开门） |

完整契约见飞书项目文档与 `docs/naming_convention.md`。
