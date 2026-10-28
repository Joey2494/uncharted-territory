# 命名规范（naming convention）

> 维护人：张宏伟｜适用范围：全组所有新增文件与节点
> 目的：接口契约稳定、Git 冲突最小、验收时一看就懂

## 一、目录结构（谁的文件放谁目录，不跨目录）

| 目录 | 归属 | 说明 |
|---|---|---|
| `scenes/main.tscn` | 俞吉依 | 整合入口（整合后设为项目主场景） |
| `scenes/player/` | 俞吉依 | 玩家场景与脚本 |
| `scenes/dungeon/` | 张宏伟 | 房间模板、生成器、门、测试场景 |
| `scenes/enemies/` | 字远 | 敌人场景、AI、生成器 |
| `scenes/items/` | 字远 | 拾取物（武器/血药）、pickup 脚本 |
| `scenes/ui/` | 汤志豪 | HUD、开始/结算/胜利界面 |
| `assets/audio|particles|shaders/` | 汤志豪 | 视觉与音效素材 |
| `data/` | 字远 | 数值表（敌人属性、掉落概率等） |
| `docs/` | 全组 | 文档（提案、契约、命名规范、导出指南等） |

## 二、命名规则

### 文件与场景

| 类型 | 规则 | 示例 |
|---|---|---|
| 场景文件 | 小写 snake_case + 类型后缀 | `room_template_01.tscn`、`player.tscn`、`heal_pickup.tscn` |
| 脚本文件 | 与场景同名 | `room.gd` 对应房间脚本、`player.gd` 对应 `player.tscn` |
| 数值表 | 语义名 | `enemy_stats.gd`、`item_table.gd` |

### 节点命名（场景树内）

| 类型 | 规则 | 示例 |
|---|---|---|
| 房间内静态物 | 语义名 + 方位后缀 | `WallE / WallW / WallZFrontL` |
| 生成点 | **固定后缀规则**，代码按名前缀查找 | `EnemySpawnPoint1/2/3`、`PlayerSpawnPoint`、`WeaponSpawnPoint` |
| 门 | 统一叫 `Door`（房间脚本固定查找） | `Door` |

> 生成点命名是接口约定的一部分：`get_enemy_spawn_points()` 按 `EnemySpawnPoint` 前缀收集，
> 新加敌人点只需继续编号 `EnemySpawnPoint4`，无需改代码。

### 脚本命名（代码内）

| 类型 | 规则 | 示例 |
|---|---|---|
| 信号 | 过去式/事件式 snake_case | `door_entered`、`room_cleared`、`enemy_died`、`hp_changed` |
| 方法 | 动词开头 snake_case | `generate()`、`open()`、`on_enemy_died()`、`take_damage()` |
| 常量 | 全大写 + 下划线 | `ROOM_SPACING`、`SPEED` |
| 导出变量 | 小写 snake_case | `enemy_count`、`next_room_index` |
| 私有变量 | 下划线前缀 | `_door`、`_is_open` |

## 三、接口契约命名（全组锁定，改动需开会确认）

| 提供方 | 名称 | 消费方 |
|---|---|---|
| 张宏伟 | `DungeonGenerator.generate(room_count) → Array[Node3D]` | 俞吉依 |
| 张宏伟 | `Room.get_enemy_spawn_points() → Array[Marker3D]` | 字远 |
| 张宏伟 | `Room.get_player_spawn_point() → Marker3D` | 俞吉依 |
| 张宏伟 | `Room.get_weapon_spawn_point() → Marker3D` | 俞吉依 |
| 张宏伟 | `signal door_entered(next_room_index)` | 俞吉依 |
| 张宏伟 | `signal room_cleared` | 俞吉依 |
| 俞吉依 | `Player.take_damage(amount)` / `heal(amount)` / `equip_weapon()` | 字远 / 俞吉依 |
| 字远 | `signal enemy_died(enemy)` / `Enemy.take_damage(amount)` / `signal item_picked(item_id)` | 张宏伟 / 俞吉依 |
| 汤志豪 | `HUD.update_hp_bar(current, maximum)` 等 | 俞吉依 |

## 四、Git 约定

- 每人只改自己目录下的文件
- commit message 用 `type: 简述`（如 `feat: 房间模板`、`chore: 建目录`、`docs: 命名规范`）
- 每完成一个可验证的小功能就提交一次，方便回滚与审查
- 分支：开发用 `feature/<模块名>`，稳定后合并到 `main`
