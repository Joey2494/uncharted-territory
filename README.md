# uncharted-territory（未至之境）

3D 俯视角 Roguelike 地牢探索 —— 四人小组课程作业（Godot 4，GDScript）。

## 运行方式

1. 用 Godot 4.x 打开本目录（仓库根目录即 `res://` 根）
2. 按 F5 运行主场景；**测自己的场景请打开该 `.tscn` 后按 F6（运行当前场景）**

> **当前主场景（临时）**：`scenes/dungeon/test_dungeon.tscn`（张宏伟地牢模块开发专用测试场景）
> - T：模拟击杀当前房间一只敌人（验证清敌开门）
> - WASD：移动测试玩家（玩家自然行走，不传送）
> - 俞吉依整合完成后，主场景切换为 `scenes/main.tscn`
>
> 分支与协作流程见 [docs/git_workflow.md](docs/git_workflow.md)。

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
└── docs/
    ├── naming_convention.md ← 全组命名规范（张宏伟维护）
    ├── git_workflow.md     ← 全组 Git 分支 / PR 流程（张宏伟维护）
    ├── zhanghongwei/        ← 张宏伟（个人规划/开发/测试/接口）
    ├── yujiyi/              ← 俞吉依
    ├── ziyuan/              ← 字远
    └── tangzhihao/          ← 汤志豪
```

## 文档导航（每人的文档在自己目录下）

| 成员 | 文档目录 |
|---|---|
| 张宏伟 | [docs/zhanghongwei/](docs/zhanghongwei/README.md)（含规划/开发/测试/接口） |
| 俞吉依 | [docs/yujiyi/](docs/yujiyi/README.md) |
| 字远 | [docs/ziyuan/](docs/ziyuan/README.md) |
| 汤志豪 | [docs/tangzhihao/](docs/tangzhihao/README.md) |

## 张宏伟当前开发进度

- R1–R8（房间模板 / room.gd / 生成器 / 门）：✅ 完成，headless 自检通过
- R10 命名规范：✅ 完成
- R9 审查他人 PR / R11 导出配置：⏳ 待整合

详见 [docs/zhanghongwei/](docs/zhanghongwei/README.md)。

## 接口契约（张宏伟提供 / 消费部分）

| 方向 | 信号 / 方法 | 消费方 |
|---|---|---|
| 提供 | `DungeonGenerator.generate(room_count: int) → Array[Node3D]` | 俞吉依（main） |
| 提供 | `Room.get_enemy_spawn_points() → Array[Marker3D]` | 字远（EnemySpawner） |
| 提供 | `Room.get_player_spawn_point() → Marker3D` | 俞吉依（main） |
| 提供 | `Room.get_weapon_spawn_point() → Marker3D` | 俞吉依（main） |
| 提供 | `signal player_entered_room(room_index)` | 俞吉依（确定当前房间） |
| 提供 | `signal door_entered(target_room_index)` | 俞吉依 / 汤志豪（仅穿过门通知，不传送） |
| 提供 | `signal room_cleared` | 俞吉依（main 进度）/ 汤志豪（HUD） |
| 消费 | `signal enemy_died(enemy: Node3D)`（字远） | 张宏伟（计数开门） |

**接入方式与调用示例**见 [docs/zhanghongwei/interface_notes.md](docs/zhanghongwei/interface_notes.md)；
命名锁定见 [docs/naming_convention.md](docs/naming_convention.md)。
