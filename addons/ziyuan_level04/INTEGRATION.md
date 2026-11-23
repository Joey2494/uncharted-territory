# 第四关袍冠女巫 · 四人分工接入

前四房新增：曦影、赤阳傀儡、白芒尖蓟、群鸦归巢。四房试玩入口 `FourRooms.tscn`，普通房接入使用 `RoomEncounter.tscn`；详细行为、场景清单、致盲状态与清场计数接口见 [FOUR_ROOMS.md](FOUR_ROOMS.md)。下文仍为女巫Boss接口。

2026-11-23。模块在 `res://addons/ziyuan_level04/`，Godot 4.7.2 / Compatibility。无需新增 Autoload。沿用项目玩家、受击闪白、Boss 血条和地牢字体。

## 入口与职责

`Witch.tscn` 是休眠首领，`SporeGuard.tscn` 是无掉落召唤物。工厂 `factory.gd.create("witch", player)` 按稳定 ID 创建。`EnemySpawner.tscn` 是房间适配器，读取 `get_enemy_spawn_points() -> Array[Marker3D]` 的第一个出生点，管理守卫登记、延迟回调、死亡清理与奖励转发。

| 组员 | 本模块入口 | 接线职责 |
|---|---|---|
| 俞吉依：玩家与整合 | `bind_target`、`take_damage`、`take_direct_damage` | 玩家提供 `take_damage(int)` 与 `is_dead() -> bool`；玩家命中调用敌人伤害接口。连接奖励后启动遭遇 |
| 张宏伟：地图与房间 | `spawn_for_room`、`set_encounter_active`、`clear_encounter`、`enemy_died(enemy)` | 房间提供出生点、世界中心和尺寸；封门后激活，只登记首领为必要敌人，死亡后计数开门 |
| 汤志豪：HUD / 视觉音效 | `hp_changed`、`battle_started`、`damage_received`、`state_changed`、`attack_started`、`attack_resolved`、`enemy_died` | 血条、实际施法音效、受击与死亡反馈；不绘制攻击前提示 |
| 字远：敌人与掉落 | 数值表、工厂、适配器、首领、守卫、危险实体 | 稳定 ID、AI、生命周期；死亡只请求一次奖励，守卫无奖励 |

## 最少接线示例

```gdscript
const SpawnerScene = preload("res://addons/ziyuan_level04/EnemySpawner.tscn")
var spawner = SpawnerScene.instantiate()
room.add_child(spawner)
var boss = spawner.spawn_for_room(
    room, player, run_id + ":l4:witch", room_center, Vector2(26, 22))
if boss == null:
    return
spawner.enemy_died.connect(func(enemy: Node3D):
    room_progress.on_enemy_died(enemy))
spawner.reward_requested.connect(func(id: String, coins: int):
    inventory.grant_reward(id, {}, coins))
boss.battle_started.connect(func():
    boss_bar.begin_encounter(boss.boss_name, boss.hp, boss.max_hp))
boss.hp_changed.connect(boss_bar.update_hp)
boss.state_changed.connect(boss_bar.update_state)
# 地图组在此完成封门、登记首领，再激活。
spawner.set_encounter_active(true)
```

`room_progress.on_enemy_died`、`room_center` 与 `inventory` 是宿主适配点，不要求现有控制器改名。若当前清场系统监听 `died()`，可继续使用；同一敌人不要同时用 `died` 和 `enemy_died` 扣两次计数。奖励 source ID 必须对本局、本房、此首领唯一，钱包负责幂等入账。

## 公开契约

| 方法 / 信号 | 行为 |
|---|---|
| `spawn_for_room(room, player, source_id, center, size) -> Node3D` | 适配器读取第一个 Marker3D；缺失接口、空出生点或空 source_id 返回 null；创建后休眠 |
| `bind_target(Node3D) -> bool` | 验证玩家伤害与死亡查询方法，不访问玩家内部血量 |
| `set_encounter_active(bool)` | 启动 / 中止；中止清掉危险并回到 IDLE，保留血量和阶段。适配器同时清守卫 |
| `take_damage(int) -> bool` | 拒绝休眠、死亡、非正数、转换期伤害；破绽双倍 |
| `take_direct_damage(int, Vector3) -> bool` | 同上，无朝向减伤 |
| `apply_control(float)` / `apply_slow(float)` | 控制转架势；0.65 倍减速、最长 4 秒 |
| `is_boss()` / `is_dead()` / `is_encounter_active()` | 状态查询 |
| `register_minion(Node) -> bool` | 直接工厂接入时宿主须登记守卫；适配器自动完成 |
| `hp_changed(int, int)` / `damage_received(int)` | 血条 / 实际伤害 |
| `enemy_died(Node3D)` / `died()` | 各只发一次；选择其一计数 |
| `reward_requested(String, int)` | 稳定 source ID / 金币，宿主发放，不直接写钱包 |
| `summon_requested(String, Vector3)` / `minions_dissolved()` | 生成 / 解散守卫，不用适配器时宿主自行处理 |
| `attack_started(String, int)` / `attack_resolved(String, int)` | 实际施放开始 / 结束，mode：0 三点、1 脉冲、2 守卫、3 藤蔓 |
| `attack_telegraphed(String, int, float)` | 旧草稿兼容声明，本版永不发射，不用于预警 |

玩家推荐与当前项目一致让伤害方法返回 bool，表示本次伤害是否接受，毒液用它记录成功命中冷却。可选 `take_direct_damage` 额外接收来源位置，伤害仍服从玩家的护盾、翻滚和无敌规则。

## 生命周期与坐标

世界层 1、玩家层 2、敌人层 4。首领 `arena_center: Vector3` / `arena_size: Vector2` 是世界坐标场地参数，可入树前赋值。适配器 `enemy_spawned(enemy)` 包含首领与守卫；用 `is_boss()` 区分。只有首领构成门锁，守卫无掉落。

危险节点属于 `l4_hazards`，爆发属于 `l4_transient`，危险以 WeakRef 关联源首领；单个首领只清自己的危险。`clear_encounter()` 回收本次遭遇。`set_encounter_active(false)` 是中止而非撤退冻结；暂停请暂停场景树或包含整房与危险的公共父节点。

本模块不新增通用拾取系统，`item_picked(item_id)` 由现有道具模块继续提供；击杀通过 `reward_requested` 交给整合层，避免重复发钱。正式第四关地图、解锁、通关结算仍由组员接入。

## 验证

```text
Godot --headless --path 项目目录 --script res://addons/ziyuan_level04/tests.gd --quit-after 3000
Godot --headless --path 项目目录 res://addons/ziyuan_level04/Prototype.tscn -- --l4-smoke
Godot --path 项目目录 --script res://addons/ziyuan_level04/capture_reference.gd
```

覆盖无预警信号 / 范围网格、真实秒数、四招命中、池上限、召唤上限、阶段、架势、死亡幂等、暂停与非原点房间适配器。最终结果见 `evidence/VALIDATION.md`。
