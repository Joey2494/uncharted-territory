# 规划文档（张宏伟）

> 记录我的任务规划，只涉及我负责的地牢生成 / 房间系统 / 仓库与目录管理。

## 1. 我的任务清单（来自作业 5 MVP 分解）

| 编号 | 任务 | 交付物 |
|---|---|---|
| R1 | 房间模板 01 | `room_template_01.tscn`：BoxMesh 地板(10×10) + 4 面墙 + 门洞 |
| R2 | 出生点 | `EnemySpawnPoint1/2/3` + `PlayerSpawnPoint`（Marker3D） |
| R3 | 武器出生点 | `WeaponSpawnPoint`（玩家出生点附近） |
| R4 | 房间脚本 | `room.gd`：查询方法 + enemy_count + on_enemy_died |
| R5 | 房间模板 02/03 | `room_template_02/03.tscn`（同结构不同配色与敌人数） |
| R6 | 地牢生成器 | `dungeon_generator.gd`：generate(room_count) 沿 Z 拼接 |
| R7 | 门逻辑 | `door.gd`：清敌开门 + door_entered 信号 |
| R8 | 门视觉反馈 | 红门隐藏 = 可通行 |
| R9 | 审查他人 PR | 待组员提 PR 后进行 |
| R10 | 命名规范 | `docs/naming_convention.md` |
| R11 | 导出配置 | 待组长整合后进行 |

## 2. 我模块的技术方案（降级策略）

为控制复杂度，我负责的地牢模块采用：

- 固定俯视角相机（不做自由旋转相机）；
- 房间全部用 Godot 内置几何体（BoxMesh / Marker3D），不依赖外部模型；
- 房间 = 预制模板 + 程序化沿 Z 轴线性拼接，不做复杂寻路；
- 敌人直线追击由字远处理，我不引入 NavigationRegion3D / 导航烘焙。

## 3. 我的 Git 工作流

- 开发分支：`feature/dungeon-mvp`；
- 提交前缀：`feat` / `fix` / `docs` / `chore`；
- 每个可验证小功能一次提交，完成后 `--no-ff` 合并 `main`；
- 我同时负责仓库与目录管理：为每位成员划出 `scenes/` 与 `docs/` 目录。

## 4. 我要产出的接口（概览）

- 信号：`room_cleared`、`door_entered(next_room_index)`；
- 方法：`get_enemy_spawn_points()` / `get_player_spawn_point()` / `get_weapon_spawn_point()`；
- 生成：`DungeonGenerator.generate(room_count)`。

调用方式与接入细节见 [interface_notes.md](interface_notes.md)。
