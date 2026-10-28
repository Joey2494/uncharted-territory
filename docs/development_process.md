# 开发过程文档：uncharted-territory（未至之境）

> 记录人：张宏伟（组员 · 地牢生成 / 房间系统 / Git 管理）
> 时间：2026-10-28 起
> 协作方式：全程与 AI 协作开发，Git 管理版本
> 关联文档：[命名规范](naming_convention.md) · [README](../README.md) · 飞书项目准备文档

---

## 0. 文档说明

本文件记录我（张宏伟）在本次团队游戏作业中，从接收任务、规划、开发、测试到版本管理的**完整执行过程**，以"我 → AI → 执行 → 验证"的对话式步骤呈现，供团队了解我的模块进度与接口，也供我后续复盘复用。

---

## 1. 任务背景与我的分工

### 1.1 项目概况

- 项目名：uncharted-territory（未至之境）
- 引擎：Godot 4.7.2 stable（本机路径 `D:\software\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64.exe`）
- 玩法：3D 俯视角 Roguelike 地牢（类似元气骑士），固定俯视相机
- 远程仓库：`https://github.com/Joey2494/uncharted-territory.git`（origin 已配置，分支 main）

### 1.2 团队分工（飞书项目准备文档固化）

| 成员 | 职责 |
|------|------|
| 俞吉依（组长） | 玩家系统 + main.tscn 整合 |
| 张宏伟（我） | 地牢生成 + 房间系统 + Git 管理 |
| 字远 | 敌人 + 道具 + 数值表 |
| 汤志豪 | UI / HUD / 视觉音效 |

### 1.3 我的任务来源

组长提供两份 MVP 规划文档：《作业 5 最小 MVP 工作分解（完整版）》与《MVP范围.md》，
其中明确了我需要实现的 R1–R11 任务清单（R9 审查他人 PR、R11 导出配置需等其他成员整合后进行）。

---

## 2. 规划阶段

### 2.1 第一步：读文档，拆任务清单

**我说**：按这两份 MVP 规划，整理出我需要做的内容并完成，用 git 管理版本开发。

**AI 执行**：
1. 通读两份 md，逐条提取属于我的任务；
2. 输出任务清单 R1–R11 及状态表（下表为规划时的原始清单，最终全部完成情况见第 6 节）。

| 编号 | 任务内容 | 说明 |
|------|----------|------|
| R1 | room_template_01.tscn | BoxMesh 地板(10×10) + 4 面墙 + 门洞，简单几何体 |
| R2 | EnemySpawnPoint1/2/3 + PlayerSpawnPoint | Marker3D 出生点，玩家在房间 z=-3 |
| R3 | WeaponSpawnPoint | 武器出生点，在玩家出生点附近 |
| R4 | room.gd | get_enemy_spawn_points / get_player_spawn_point / get_weapon_spawn_point / enemy_count / on_enemy_died |
| R5 | room_template_02/03.tscn | 同结构不同配色与敌人数 |
| R6 | dungeon_generator.gd | generate(room_count) 沿 Z 轴线性拼接 |
| R7 | door.gd | 清敌开门 + door_entered 信号 |
| R8 | 门视觉反馈 | 红门隐藏 = 可通行 |
| R9 | 审查他人 PR | 待整合后进行 |
| R10 | docs/naming_convention.md | 命名规范 |
| R11 | 导出配置 | 待整合后进行 |

### 2.2 第二步：确定技术方案（降级策略）

**我**：组长倾向做 3D Roguelike，和元气骑士类似，担心开发难度。
**我们**（组内 + AI）敲定降级策略，控制复杂度：

- 相机：固定俯视角（不做自由旋转相机）；
- 美术：全部用 Godot 内置几何体（BoxMesh / CapsuleMesh / Marker3D），不用外部模型；
- 敌人 AI：直线追击（暂不引入 NavigationRegion3D / 导航烘焙）；
- 房间结构：预制房间模板 + 程序化拼接，不在地牢内做复杂寻路。

### 2.3 第三步：Git 工作流约定

按上一轮已推送的目录结构与 `docs/naming_convention.md`：

- 功能开发走分支：`feature/dungeon-mvp`；
- 提交信息前缀五类：`feat:` / `fix:` / `docs:` / `chore:` / `merge:`；
- 完成后 `--no-ff` 合并回 `main`；
- `.gitignore` 忽略 `.godot/`、`export/` 等。

### 2.4 第四步：接口契约（给其他成员的约定）

我在 README 与命名规范中锁定的对外接口：

- 信号：`room_cleared`（房间清空）、`door_entered(next_room_index)`（玩家进门）；
- 查询方法：`get_enemy_spawn_points()` / `get_player_spawn_point()` / `get_weapon_spawn_point()`；
- 敌人通知：敌人死亡调用 `room.on_enemy_died(enemy)`。

> 供字远（敌人）接入：敌人死亡务必回调 `on_enemy_died`，房间才能清敌开门；
> 供俞吉依（玩家）接入：`door_entered` 信号携带下一房间索引，玩家场景据此传送。

---

## 3. 开发阶段（分步执行记录）

开发在分支 `feature/dungeon-mvp` 上完成，共 5 次逻辑提交。每一步的节奏都是：
**我说需求 → AI 写代码并说明 → 我确认 → 提交 git**。

### Step 1：工程初始化（commit `1fd610e`）

- 创建 `project.godot`（config_version=5，viewport 1280×720，Forward Plus，主场景指向 test_dungeon）；
- 重写 `README.md`（运行方式 / 目录结构 / 接口契约）；
- `.gitignore` 使用 Godot 完整版。

### Step 2：R1–R5 房间模板与 room.gd（commit `56fe87a`）

文件：`scenes/dungeon/room_template_01/02/03.tscn`、`scenes/dungeon/room.gd`

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

### Step 3：R6–R8 地牢生成器与门逻辑（commit `6f3a5ab`）

文件：`scenes/dungeon/dungeon_generator.gd`、`scenes/dungeon/door.gd`

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

### Step 4：独立测试场景（commit `cac6d42`）

文件：`scenes/dungeon/test_dungeon.tscn/.gd`、`test_player.tscn/.gd`

- 场景内放一个 DungeonGenerator 节点，`_ready` 时 `generate(3)` 并打印各房间信息；
- 简易玩家：CharacterBody3D 胶囊体，WASD 移动，SPEED=6；
- 交互验证：按 T 模拟击杀 1 只敌人，看门是否打开、走入是否传送；
- 相机：俯视全景 `(0, 28, 20)`，`look_at(0, 0, 14)`。

### Step 5：R10 命名规范（commit `f460584`）

文件：`docs/naming_convention.md` —— 文件/节点/脚本命名规则、接口契约命名锁定表、Git 约定。

### Step 6：合并入 main（commit `eebe9fb`）

`git merge --no-ff feature/dungeon-mvp`，合并 5 个提交，13 个文件 +778 行。

---

## 4. 测试与验证阶段

### 4.1 静态校验（开发中）

**AI 执行**：写临时 Python 校验脚本，对全部 `.tscn/.gd/project.godot` 做 load_steps、资源引用、父链、脚本缩进/括号闭合检查 → 全部通过。

### 4.2 Godot headless 导入验证

**我**：提供本机 Godot 路径后，**AI 执行**：

```
Godot_v4.7.2...exe --headless --path <仓库根> --import
```

结果：全局类 Door / DungeonGenerator / Room 注册成功，无脚本编译错误。

### 4.3 设计自动化自检（--selftest）

为保证"本地先做好"，**AI 在 test_dungeon.gd 中增加命令行自检模式**：

```
Godot_v4.7.2...exe --headless --path <仓库根> -- --selftest
```

自检断言（通过退出码 0/1 判定）：
1. 房间数 = 3；
2. 每房敌人点 ≥ 2、玩家/武器出生点非空；
3. 房间 Z 间距 = 12（0 / 12 / 24）；
4. 清敌后门 `_is_open` 且 `room_cleared` 发出；
5. 模拟玩家进门后 `door_entered(1)` 信号正确。

### 4.4 Bug 1：GDScript lambda 按值捕获（测试脚本自身问题）

- **现象**：自检断言 `room_cleared=false`，但运行时日志明明打了"房间1 已清空 → 门打开"；
- **根因**：GDScript 的匿名函数按**值**捕获局部变量，lambda 里改的是副本，外层标志位不变；
- **修复**：改用数组（引用类型）共享状态，`flags[0] = true`；
- **教训**：GDScript 闭包共享状态要用数组 / 成员变量，别用局部布尔。

### 4.5 Bug 2：next_room_index 时序（真实逻辑 Bug）

- **现象**：`door_entered fired=true next=-1 期望 1`；
- **根因**：生成器在 `add_child(room)` **之前**调用 `set_next_room_index`，此时房间 `_ready` 未执行、`_door` 还是空引用，索引静默丢失（保留默认 -1）；
- **修复**：调整生成顺序——先 `add_child(room)` 触发 `_ready` 绑定门，再 `set_next_room_index(i+1)`；
- **教训**：`@onready` 依赖 `_ready` 时序，节点加入场景树前调用会被静默吞掉。

### 4.6 最终验证输出（真实日志）

```
[TestDungeon] Room1 pos=(0.0, 0.0, 0.0) 敌人点=3 武器点=(0.0, 0.5, -1.0) 玩家点=(0.0, 0.5, -3.0)
[TestDungeon] Room2 pos=(0.0, 0.0, 12.0) 敌人点=3 武器点=(0.0, 0.5, 11.0) 玩家点=(0.0, 0.5, 9.0)
[TestDungeon] Room3 pos=(0.0, 0.0, 24.0) 敌人点=3 武器点=(0.0, 0.5, 23.0) 玩家点=(0.0, 0.5, 21.0)
[SelfTest] OK: 3 房间排列与生成点齐全
[TestDungeon] 房间1 已清空 → 门打开
[SelfTest] OK: 清敌后门打开，room_cleared 已发出
[TestDungeon] door_entered → 下一房间 1
[SelfTest] OK: door_entered(1) 信号正常
[SelfTest] === 全部通过 ===
（退出码 0）
```

### 4.7 收尾

- 提交 `fix: 房间索引绑定时机 + 测试场景自检（headless 验证通过）`（`6222038`）；
- 提交 Godot 4.4+ 生成的脚本 `.uid` 文件（`63b5950`，官方建议纳入版本管理）；
- 删除临时日志与校验脚本，工作区干净。

---

## 5. 版本管理记录

### 5.1 提交链（自新到旧）

| Commit | 类型 | 内容 |
|--------|------|------|
| `63b5950` | chore | 提交脚本 .uid 文件（Godot 4.4+ 稳定标识） |
| `6222038` | fix | 房间索引绑定时机 + 测试场景自检（headless 验证通过） |
| `eebe9fb` | merge | 张宏伟地牢模块（R1-R8+R10）合入 main |
| `f460584` | docs | 命名规范 naming_convention（R10） |
| `cac6d42` | feat | 地牢独立测试场景（test_dungeon） |
| `6f3a5ab` | feat | 地牢生成器与门逻辑（R6-R8） |
| `56fe87a` | feat | 3 个房间模板与 room.gd（R1-R5） |
| `1fd610e` | feat | 初始化 Godot 工程（project.godot + README） |
| `945cb5b` | chore | 创建项目目录结构（10 个目录占位，上一轮） |

### 5.2 分支示意

```
945cb5b ──→ 1fd610e ──→ 56fe87a ──→ 6f3a5ab ──→ cac6d42 ──→ f460584   (feature/dungeon-mvp)
                                                                    ↘
                                                        eebe9fb ──→ 6222038 ──→ 63b5950   (main)
```

---

## 6. 当前状态与下一步

### 6.1 已完成（我的模块）

- R1–R8：3 个房间模板、room.gd、dungeon_generator.gd、door.gd（含门视觉反馈）；
- R10：命名规范文档；
- 独立测试场景 + headless 自检（退出码 0 通过）；
- 本地 main 完整，待推送远程（推送由我本人执行）。

### 6.2 待办

| 事项 | 触发条件 |
|------|----------|
| R9 审查其他成员 PR | 等俞吉依/字远/汤志豪提 PR |
| R11 导出配置（export.bat + export_guide） | 组长整合 main.tscn 后 |
| 与俞吉依联调 door_entered → 玩家传送 | 玩家系统完成 |
| 与字远联调 on_enemy_died | 敌人系统完成 |

### 6.3 给组员的接口提醒

- **字远（敌人）**：敌人死亡必须调用 `room.on_enemy_died(enemy)`，否则房间不会清敌开门；
- **俞吉依（玩家）**：监听 `door_entered(next_room_index)` 做房间传送；玩家出生点取 `get_player_spawn_point()`；
- **汤志豪（UI）**：`room_cleared` 信号可驱动"房间已清除"的 HUD 提示。
