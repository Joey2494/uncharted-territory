## 😀 默认助手

# 作业 5 最小 MVP 工作分解（完整版，含武器拾取）

---

## 验收时要演示什么

```
老师打开你们的工程 → F5 运行 →

开始界面 → 点"开始" → 进入房间1
→ 看到地上蓝色武器 + 2个红色敌人
→ 按左键没反应（还没捡武器）→ HUD 显示"无武器"
→ 走到武器上 → 自动捡起 → 手上出现武器 → HUD 变"已装备"
→ WASD移动 + 鼠标左键砍敌人 → 敌人追玩家、碰到扣血
→ 左上角血条在变 → 杀完敌人 → 概率掉血药 → 门打开
→ 走进门 → 传送到房间2（已有武器直接打）→ 房间3 → 清完弹 "You Win"
→ 中途死了弹 "Game Over" + 显示到了第几个房间
→ 点"重新开始" → 重新生成 → 再来一局

全程 HUD 血条+武器状态固定在屏幕左上角不动
```

---

## 四人任务总表

```
                    第1-2天          第3-4天          第5天        第6天
俞吉依(组长)    玩家移动+攻击    整合所有模块     试玩修bug    验收
张宏伟          3个房间+门       生成器拼接       审PR+导出    验收
字远            敌人AI+战斗      掉落+武器拾取    配合整合     验收
汤志豪          HUD血条+武器状态 开始/结算界面    闪白特效     验收
```

---

## 一、俞吉依（组长）— 玩家系统 + 整合

### 第 1-2 天：玩家能动、捡了武器才能打

| 编号 | 任务 | 怎么验证做完了 |
|---|---|---|
| P1 | 建 `player.tscn`：CharacterBody3D + CapsuleMesh + CollisionShape3D | 编辑器里能看到胶囊体 |
| P2 | `player.gd`：WASD 移动（`move_and_slide()`） | F5 运行，WASD 能跑 |
| P3 | 固定斜俯视相机：Camera3D 作为玩家子节点，rotation_degrees(-55,0,0)，高度 10 | 运行后视角稳定，看得清地面 |
| P4 | 武器模型（BoxMesh 小长条）挂在玩家子节点，**默认 visible = false** | 运行后看不到武器 |
| P5 | `var has_weapon: bool = false`，鼠标左键攻击时 `if has_weapon:` 才执行挥砍 | 没捡武器时按左键无反应 |
| P6 | `func equip_weapon()`：`has_weapon = true` + 武器 `visible = true` | 调用后武器出现，按左键能砍了 |
| P7 | 近战攻击：Area3D 扫描 + Tween 旋转武器 | 捡到武器后按左键看到武器转一圈 |
| P8 | 暴露接口：`signal hp_changed(current, max)`、`signal player_died`、`func take_damage(amount)`、`func heal(amount)` | print 测试信号发出 |

**产出文件：**
```
scenes/player/player.tscn
scenes/player/player.gd
```

### 第 3-4 天：整合所有模块

| 编号 | 任务 | 怎么验证做完了 |
|---|---|---|
| P9 | 建 `main.tscn` + `main.gd`：调用张宏伟的 `generate(3)` 拿到 3 个房间 | 运行看到 3 个房间排列 |
| P10 | 把玩家放到房间 1 的出生点 | 玩家出现在第一个房间中央 |
| P11 | 遍历 spawn_points → 调字远的 spawner 生成敌人 + 把 player_ref 传给敌人 | 每个房间出现红色方块敌人 |
| P12 | **在第 1 个房间的 WeaponSpawnPoint 放置武器拾取物** | 房间 1 地上能看到蓝色武器 |
| P13 | 连接所有信号：hp_changed→HUD、enemy_died→房间计数→开门、**item_picked→判断 heal/weapon** | 打怪掉血、捡武器、捡血药全部联动 |
| P14 | **item_picked 回调：`"weapon"` → `player.equip_weapon()` + `hud.update_weapon_status(true)`；`"heal"` → `player.heal(1)`** | 捡武器后能打，捡绿球回血 |
| P15 | 通关判定：清完 3 个房间 → 调汤志豪的 `show_win_screen()` | 连续清 3 房间弹 You Win |
| P16 | 死亡判定：player_died → `show_death_screen(current_room_index)` | HP 归零弹 Game Over |

**产出文件：**
```
scenes/main.tscn
scenes/main.gd
```

### 文档任务

| 编号 | 任务 | 产出 |
|---|---|---|
| P17 | 写修订版一页提案 | `docs/proposal.md` |
| P18 | 写接口契约表（含武器相关接口） | `docs/interface_contract.md` |
| P19 | 画核心循环草图（手绘拍照或工具画） | `docs/core_loop.png` |

---

## 二、张宏伟 — 地牢房间 + 门 + Git

### 第 1-2 天：3 个房间能看到

| 编号 | 任务 | 怎么验证做完了 |
|---|---|---|
| R1 | `room_template_01.tscn`：BoxMesh 地板(10x10) + 4 面墙(StaticBody3D) + 留 1 个门洞 | 编辑器里看到一个有墙有门洞的方形房间 |
| R2 | 在房间里放 2-3 个 Marker3D 叫 `EnemySpawnPoint1/2/3`，放 1 个 `PlayerSpawnPoint` | 编辑器里能看到标记点 |
| R3 | **在房间入口附近显眼位置放 1 个 Marker3D 叫 `WeaponSpawnPoint`** | 编辑器里看到武器刷新点标记 |
| R4 | `room.gd`：`get_enemy_spawn_points()`、`get_player_spawn_point()`、**`get_weapon_spawn_point()`**、`var enemy_count`、`func on_enemy_died()` | 代码里调这些方法不报错 |
| R5 | 复制改两个变体 `room_template_02.tscn`、`room_template_03.tscn`（墙壁布局/颜色稍不同，同样带所有 Marker3D） | 3 个房间长得不一样 |

**产出文件：**
```
scenes/dungeon/room_template_01.tscn
scenes/dungeon/room_template_02.tscn
scenes/dungeon/room_template_03.tscn
scenes/dungeon/room.gd
```

### 第 3-4 天：拼接 + 门逻辑

| 编号 | 任务 | 怎么验证做完了 |
|---|---|---|
| R6 | `dungeon_generator.gd`：`func generate(room_count) -> Array[Node3D]`，随机选模板实例化，沿 Z 轴线性排列（房间间距=房间宽度） | 单独测试场景里跑一下，看到 3 个房间排成一排 |
| R7 | `door.gd`：门的 Area3D → 玩家进入时检查 `enemy_count == 0` → 发 `signal door_entered(next_room_index)` | 有敌人时走到门口没反应，敌人清完走到门口触发信号 |
| R8 | 门视觉反馈：未开=红色 BoxMesh 挡住门洞 / 已开=隐藏或变绿 | 清完敌人后门的颜色变了或消失了 |

**产出文件：**
```
scenes/dungeon/dungeon_generator.gd
scenes/dungeon/door.gd
```

### Git + 文档任务

| 编号 | 任务 | 产出 |
|---|---|---|
| R9 | 审查其他三人的 PR（每个 PR 检查文件位置+F5 能跑） | GitHub PR 页面的 Approve 记录 |
| R10 | 写命名规范文档 | `docs/naming_convention.md` |
| R11 | 整合完成后配置导出 + 写导出文档 | `export.bat` + `docs/export_guide.md` |

---

## 三、字远 — 敌人 + 掉落 + 武器拾取

### 第 1-2 天：敌人能追能打

| 编号 | 任务 | 怎么验证做完了 |
|---|---|---|
| E1 | `enemy_base.tscn`：CharacterBody3D + 红色 BoxMesh + CollisionShape3D + Area3D（检测半径 8） | 编辑器里看到红色方块 |
| E2 | `enemy_base.gd`：`var hp = 3`、`func take_damage(amount)`、`signal enemy_died(enemy)` | 调 `take_damage(3)` 后敌人消失且信号发出 |
| E3 | 直线追击 AI：Area3D 检测到玩家 → `(player.position - position).normalized() * speed` → `move_and_slide()` | 把玩家和敌人放同一场景，敌人会朝玩家跑 |
| E4 | 接触攻击：碰到玩家 → `player_ref.take_damage(1)` + Timer 1 秒冷却 | 碰到扣 1 血，不会每帧扣 |
| E5 | `var player_ref: CharacterBody3D`：等 main.gd 赋值 | 不报 null 错 |

**产出文件：**
```
scenes/enemies/enemy_base.tscn
scenes/enemies/enemy_base.gd
```

### 第 3-4 天：生成器 + 掉落 + 武器拾取物

| 编号 | 任务 | 怎么验证做完了 |
|---|---|---|
| E6 | `enemy_spawner.gd`：接收 spawn_points 数组 → 每个点实例化一个 enemy_base | 给 3 个 Marker3D 就生成 3 个敌人 |
| E7 | 数值表 `enemy_stats.gd`：字典 `{hp=3, speed=3.0, damage=1, drop_chance=0.5}` | 敌人属性从表里读而不是硬编码 |
| E8 | `pickup.gd`：通用拾取脚本，`@export var item_type: String = "heal"`，碰到玩家 → `signal item_picked(item_type)` → `queue_free()` | 碰到后信号发出，物品消失 |
| E9 | `heal_pickup.tscn`：绿色小球，`item_type = "heal"` | 碰到绿球，item_picked 发出 "heal" |
| E10 | **`weapon_pickup.tscn`：蓝色小长条（像剑），`item_type = "weapon"`** | **碰到蓝色物体，item_picked 发出 "weapon"** |
| E11 | 敌人死亡时 50% 概率在原地生成 heal_pickup | 杀敌后有时掉绿球有时不掉 |

**产出文件：**
```
scenes/enemies/enemy_spawner.gd
data/enemy_stats.gd
scenes/items/pickup.gd
scenes/items/heal_pickup.tscn
scenes/items/weapon_pickup.tscn        ← 新增
```

---

## 四、汤志豪 — UI / HUD + 视觉反馈

### 第 1-2 天：HUD 能显示

| 编号 | 任务 | 怎么验证做完了 |
|---|---|---|
| U1 | `hud.tscn`：CanvasLayer → Control → ProgressBar（血条）+ Label（房间编号）+ **Label（武器状态）** | 运行后屏幕左上角有血条、房间编号、武器状态 |
| U2 | `hud.gd`：`func update_hp_bar(current, maximum)` → 更新 ProgressBar | 手动调用，血条在变 |
| U3 | `func update_room_label(index)` → Label 显示 "房间 1/3" | 手动调用，文字在变 |
| U4 | **`func update_weapon_status(has_weapon: bool)` → 没武器显示灰色"🔲 无武器"，有武器显示黄色"⚔ 已装备"** | **手动调用 true/false，文字和颜色在切换** |
| U5 | 验证 HUD 固定：相机跟玩家移动时，血条和武器状态始终在屏幕左上角不动 | 移动玩家，HUD 位置不变 |

**产出文件：**
```
scenes/ui/hud.tscn
scenes/ui/hud.gd
```

### 第 3-4 天：界面 + 视觉反馈

| 编号 | 任务 | 怎么验证做完了 |
|---|---|---|
| U6 | `start_screen.tscn`：Label "未至之境" + Button "开始游戏" → `get_tree().change_scene_to_file("res://scenes/main.tscn")` | 点按钮进入游戏 |
| U7 | `death_screen.tscn`：Label "Game Over" + Label "探索到房间 X" + Button "重新开始" → 重新加载 main | player_died 信号触发后弹出 |
| U8 | `win_screen.tscn`：Label "You Win" + Button "重新开始" | 清完 3 房间后弹出 |
| U9 | 受击闪白：被打时 `modulate = Color.RED` → 0.1 秒后恢复白色 | 受击瞬间角色/敌人变红再恢复 |
| U10 | 敌人头顶血量：Label3D 显示 hp 数字（最简方案） | 能看到敌人头上的数字在减少 |

**产出文件：**
```
scenes/ui/start_screen.tscn
scenes/ui/death_screen.tscn
scenes/ui/win_screen.tscn
```

### 文档任务

| 编号 | 任务 | 产出 |
|---|---|---|
| U11 | 画面组织草图：世界画面 + HUD（血条+武器状态+房间编号）+ 界面层次关系 | `docs/screen_layout.md` 或手绘拍照 |

---

## 五、任务依赖关系图

```
第 1-2 天（各自独立开发，互不依赖）
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ P1-P8        │ │ R1-R5        │ │ E1-E5        │ │ U1-U5        │
│ 玩家移动     │ │ 3个房间模板   │ │ 敌人能追能打 │ │ HUD 血条     │
│ 捡武器才能打 │ │ +武器刷新点   │ │              │ │ +武器状态    │
│              │ │              │ │              │ │              │
│ 自己建测试场景│ │ 自己建测试场景│ │ 自己建测试场景│ │ 自己建测试场景│
│ 单独 F5 验证 │ │ 单独 F5 验证 │ │ 单独 F5 验证 │ │ 单独 F5 验证 │
└──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
       │                │                │                │
       │   各自提 PR → 张宏伟审 / 组长审   │                │
       │                │                │                │
       ▼                ▼                ▼                ▼

第 3-4 天（有部分依赖）
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ R6-R8        │ │ E6-E11       │ │ U6-U10       │
│ 生成器+门    │ │ Spawner+掉落 │ │ 界面+特效    │
│ 不依赖别人   │ │ +武器拾取物  │ │ 不依赖别人   │
└──────┬───────┘ └──────┬───────┘ └──────┬───────┘
       │                │                │
       │   全部提 PR 合入 main            │
       │                │                │
       ▼                ▼                ▼
┌──────────────────────────────────────────────────────────┐
│ P9-P16 俞吉依整合（第 5 天）                               │
│                                                           │
│ main.gd:                                                  │
│   generate(3) → 放玩家 → 生敌人                           │
│   → 在房间1放武器拾取物（读 WeaponSpawnPoint）              │
│   → 连信号 → 连UI                                         │
│   → item_picked: "weapon"→装备, "heal"→回血               │
│                                                           │
│ 依赖：张的房间 + 字远的敌人和拾取物 + 汤的HUD 全部合入后做  │
└──────────────────────────────────────────────────────────┘
                           │
                           ▼
                    第 6 天：试玩 + 修 bug
                           │
                           ▼
                    第 6 周实验课验收
```

---

## 六、每人独立测试怎么做

**不用等别人做完，每个人自己建一个临时测试场景：**

### 俞吉依的测试场景

```
建一个 test_player.tscn：
- 一块大平面（StaticBody3D + MeshInstance3D 地板）
- 放一个 player.tscn 实例
- 地上放一个临时的 Area3D 模拟武器拾取
  → 碰到后调 player.equip_weapon()
- F5 测试：开始打不了 → 走到 Area3D 上 → 能打了
```

### 张宏伟的测试场景

```
建一个 test_dungeon.tscn：
- 空的 Node3D
- 脚本里调 generate(3) 看房间能不能排好
- 放一个 Camera3D 俯视看全景
- 检查每个房间有 EnemySpawnPoints + WeaponSpawnPoint
```

### 字远的测试场景

```
建一个 test_enemy.tscn：
- 一块地板
- 放一个假的 CharacterBody3D 当玩家
- 放一个 enemy_base.tscn → 看敌人追不追
- 放一个 weapon_pickup.tscn → 走过去看信号发不发
- 放一个 heal_pickup.tscn → 走过去看信号发不发
```

### 汤志豪的测试场景

```
建一个 test_ui.tscn：
- 放 hud.tscn
- 脚本里每秒调一次 update_hp_bar(hp, 5) 其中 hp 递减
- 2 秒后调 update_weapon_status(true) 看文字变化
- 看血条动不动，武器状态切不切换
```

---

## 七、作业 5 额外要求对照

| 要求 | 谁做 | 怎么做 |
|---|---|---|
| **修订一页提案** | 俞吉依 | `docs/proposal.md`，内容与实际实现一致（含武器拾取玩法） |
| **核心循环草图** | 俞吉依 | 手绘拍照或在线画图，放 `docs/`（循环里加"捡武器"节点） |
| **画面组织草图** | 汤志豪 | 画世界画面 + HUD（血条+武器状态+房间编号）层次关系 |
| **同伴试玩** | 全组 | 第 6 天找外组同学试"进房间找到武器捡起来杀一个敌人"，记录操作和问题 |
| **用观察支持一次决策** | 全组 | 比如"武器放房间中央还是入口？"→ 两种都试 → 看试玩者多久找到 → 选入口 |
| **核对 AI 贡献** | 每人自己 | 每人写"我用 AI 做了什么，我自己改了什么，怎么验证的" |

### 试玩记录模板（放 `docs/playtest_log.md`）

```markdown
# 试玩记录

## 试玩信息
- 日期：2025-xx-xx
- 试玩者：xxx（非本组）
- 运行版本：main 分支 commit xxxxxx
- 任务目标：进入房间，找到武器捡起来，杀死一个敌人，观察血条变化

## 操作过程
1. 试玩者进入房间，按左键尝试攻击 → 发现没反应
2. 试玩者四处走动 → 看到蓝色物体 → 走过去自动捡起
3. HUD 从"无武器"变成"已装备"
4. 再按左键 → 能攻击了 → 砍到敌人
5. ...

## 遇到的问题
- 一开始不知道蓝色东西是武器
- 敌人速度太快来不及捡武器就被打死了

## 修改决策
- 问题：来不及捡武器就被打
- 方案A：武器放在离玩家出生点更近的地方
- 方案B：敌人检测范围从 8 缩小到 5，给玩家捡武器的时间
- 观察：方案B 后试玩者有 3 秒空档捡武器
- 最终取舍：采用方案 B，detect_range = 5
```

---

## 八、更新后的完整接口契约

| 提供方 | 信号 / 方法 | 参数 | 消费方 |
|---|---|---|---|
| **张宏伟** | `DungeonGenerator.generate(room_count: int) → Array[Node3D]` | 返回房间列表 | 俞吉依（main） |
| **张宏伟** | `Room.get_enemy_spawn_points() → Array[Marker3D]` | — | 字远 |
| **张宏伟** | `Room.get_player_spawn_point() → Marker3D` | — | 俞吉依（main） |
| **张宏伟** | **`Room.get_weapon_spawn_point() → Marker3D`** | — | **俞吉依（main）** |
| **张宏伟** | `signal door_entered(next_room_index: int)` | 玩家踏入门触发 | 俞吉依（main） |
| **俞吉依** | `Player.take_damage(amount: int)` | — | 字远（敌人攻击） |
| **俞吉依** | `Player.heal(amount: int)` | — | 俞吉依（main 回调） |
| **俞吉依** | **`Player.equip_weapon()`** | — | **俞吉依（main 回调）** |
| **俞吉依** | **`Player.has_weapon: bool`** | — | **player.gd 内部判断** |
| **俞吉依** | `signal hp_changed(current: int, max: int)` | — | 汤志豪（HUD） |
| **俞吉依** | `signal player_died` | — | 汤志豪（结算界面） |
| **字远** | `Enemy.take_damage(amount: int)` | — | 俞吉依（玩家攻击） |
| **字远** | `signal enemy_died(enemy: Node3D)` | — | 张宏伟（开门）、汤志豪（特效） |
| **字远** | `signal item_picked(item_id: String)` | `"heal"` 或 `"weapon"` | 俞吉依（main 回调） |
| **汤志豪** | `HUD.update_hp_bar(current: int, maximum: int)` | — | 俞吉依（main 连信号） |
| **汤志豪** | `HUD.update_room_label(index: int)` | — | 俞吉依（main） |
| **汤志豪** | **`HUD.update_weapon_status(has_weapon: bool)`** | — | **俞吉依（main）** |
| **汤志豪** | `HUD.show_death_screen(room_index: int)` | — | 俞吉依（main） |
| **汤志豪** | `HUD.show_win_screen()` | — | 俞吉依（main） |

---

## 九、最终交付物清单

| 类别 | 文件 | 负责人 |
|---|---|---|
| **工程代码** | scenes/main.tscn + main.gd | 俞吉依 |
| | scenes/player/player.tscn + player.gd | 俞吉依 |
| | scenes/dungeon/（3 个模板 + generator + room + door） | 张宏伟 |
| | scenes/enemies/（enemy_base + spawner） | 字远 |
| | scenes/items/pickup.gd | 字远 |
| | scenes/items/heal_pickup.tscn | 字远 |
| | **scenes/items/weapon_pickup.tscn** | **字远** |
| | data/enemy_stats.gd | 字远 |
| | scenes/ui/（hud + 3 个界面） | 汤志豪 |
| **文档** | docs/proposal.md（一页提案） | 俞吉依 |
| | docs/interface_contract.md（接口契约） | 俞吉依 |
| | docs/core_loop.png（循环草图） | 俞吉依 |
| | docs/screen_layout.md（画面组织） | 汤志豪 |
| | docs/naming_convention.md（命名规范） | 张宏伟 |
| | docs/export_guide.md（导出文档） | 张宏伟 |
| | docs/playtest_log.md（试玩记录） | 全组 |
| | docs/ai_usage.md（AI 使用说明） | 每人写自己的 |
| **Git 记录** | 每人至少 2-3 个 PR + 审查记录 | GitHub 自动有 |
