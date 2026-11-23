# 第四关前四房 · 敌人设计与运行

2026-11-23。按本次用户描述新增四类普通房敌人，延续已有袍冠女巫作为后续首领。所有敌人攻击直接发生，没有攻击预警、落点圆、条带、范围轮廓。原型使用风格化程序网格，数值为首轮试玩初值。

## 四房设计

| 房间 | 敌人与造型 | 行为 | 初值 / 房间配置 |
|---|---|---|---|
| 1 薄光回廊 | 曦影：清晨暖白光纱、多层透明朦胧边缘、漂浮光尘，无实体材质 | 非致死受击分出两只同形假身并换位；假身一击消失，6 秒自然消散；本体接近时造成接触伤害。每 3.6 秒尝试在 7 单位可见范围内释放晨光致盲，持续 0.85 秒 | 本体 HP8、伤害1、金币16；2 本体，最多各2假身 |
| 2 赤阳木庭 | 赤阳傀儡：烧黑木躯、沿木纹流动的金红熔光、头顶摇晃日斑 | 缓慢逼近；每 3.8 秒发出真实火舌热浪，速度4.5向外扩散至9单位，波前经过造成1伤害；每波只判一次，墙柱阻挡 | HP12、接触伤害1、金币20；2只 |
| 3 暴晒刺径 | 白芒尖蓟：铁绿粗茎、扎地根刺、白亮尖刺花冠 | 扎根不移动且与玩家实体碰撞；每2.7秒交替发射7发扇状实体飞刺、长出6簇实际生效尖刺。刺丛只在近身约2单位处分布，不在玩家远处脚下偷生成 | HP14、伤害1、金币22；3只错位封路，留侧路 |
| 4 暮鸦巢台 | 群鸦归巢：7只黑蓝乌鸦，每只可受击、持续扇翼 | 每4.2秒交替：四散，从不同方位逐只穿过锁定点，起飞错开0.12秒；聚拢为小群共同向锁定位置压进。使用鸟运动线段判定接触，群内共享生命 | 整群HP12、伤害1、金币24；1群，算1个必要敌人 |

曦影的假身与本体外观相同，不用本体专属血条标记。玩家现有手动近战 / 法术可命中二者；没有改写玩家瞄准系统或添加永久失锁。相同本体已有假身时不继续增殖，避免分身数量失控。本体死亡后假身全部消散，不掉钱、不阻碍清房。

晨光致盲是短暂暖白遮罩，透明度上限0.48，保留操作和HUD；不全屏强白、不反转方向。停止、死亡、换房会清掉状态。该视觉由实验室玩家脚本提供，正式接入的公开状态请求见下文。

热浪是当前生效的移动攻击实体，不是地面范围提示。刺丛同样是实际伤害物。群鸦聚拢属于实际攻击运动，没有攻击前停顿。单次近战同时击中多只鸟用0.15秒共享受击保护避免多倍扣血；群鸦内部不是7个独立掉落敌人。

## 运行与单独查看

打开 `res://addons/ziyuan_level04/FourRooms.tscn` 按F6，或双击根目录 `PLAY_LEVEL04_ROOMS.cmd`。WASD移动，J近战、K法术、空格翻滚、R药剂；1–4选房、F5重试、Esc暂停。清房后按N主动前往下一房，末房提示四房完成；实验室每次换房恢复24HP和3瓶药，奖励只演示不写永久钱包。这是敌人测试场，不是正式第四关地图或主战役流程。

| 敌人 | 战斗场景 | 模型预览（F6旋转缩放） |
|---|---|---|
| 曦影 | `DawnShade.tscn` | `previews/DawnShadePreview.tscn` |
| 赤阳傀儡 | `SunPuppet.tscn` | `previews/SunPuppetPreview.tscn` |
| 白芒尖蓟 | `IronThistle.tscn` | `previews/IronThistlePreview.tscn` |
| 群鸦归巢 | `RavenRoost.tscn` | `previews/RavenRoostPreview.tscn` |

`models/` 中同名 `*Model.tscn` 带 `@tool`，可在3D编辑器直接查看。模型复用 `room_visual.gd`，战斗复用 `room_enemy.gd`，集中数值在 `room_catalog.gd`。女巫入口保持 `Prototype.tscn` / `previews/WitchPreview.tscn`。

## 按四人分工接入

俞吉依：通过工厂 `factory.gd.create(id, player)` 创建，玩家继续提供 `take_damage(int)`、`is_dead()`，可选 `take_direct_damage(int, Vector3)`；敌人同样提供这些受击入口。共享玩家脚本未修改。晨光可用玩家可选方法 `apply_dawn_blind(duration, strength)` 接收；若玩家不提供该方法，使用 `status_requested(target, "dawn_blind", duration, strength)` 交给玩家状态/UI模块处理。两种路径只接一种，避免重复视觉；效果需跟随暂停、死亡、换房清理。

张宏伟：使用 `RoomEncounter.tscn` 的 `spawn_for_room(room, player, index, source_prefix, center, size)`，index为0–3；房间提供 `get_enemy_spawn_points() -> Array[Marker3D]`。每个出生点生成对应房间的一只敌人/一群鸦。传入真实房间中心和尺寸，适配器支持非原点房间。完成房间条件后调用 `set_encounter_active(true)`。监听 `room_cleared(index)`，该信号一次；若自行统计，则使用正式演员的 `enemy_died(enemy)`，不要把假身、鸟群子碰撞体计入门锁。

汤志豪：监听 `hp_changed(current,max)`、`damage_received(amount)`、`attack_started(id,mode)`、`attack_resolved(id,mode)`、`enemy_died(enemy)`。曦影本体和假身不显示区别血条；可自行做统一受击视觉。`status_requested`可渲染晨光遮罩，但不得添加范围提示。群鸦的攻击结束信号在整轮实际俯冲完成后发出，其余技能在实体发射完成后发出，危险实体可继续运动。

字远：维护敌人、假身、群鸦共享受击体和危险生命周期。`reward_requested(source_id,coins)`只为正式敌人死亡发射一次，由整合层沿用现有奖励/拾取系统。`source_prefix`必须本局本房唯一；宿主钱包幂等处理，避免与现有掉落重复计钱。

```gdscript
var encounter = preload("res://addons/ziyuan_level04/RoomEncounter.tscn").instantiate()
room.add_child(encounter)
if encounter.spawn_for_room(room, player, 0, run_id + ":l4:room1", room_center, Vector2(26,22)):
    encounter.room_cleared.connect(func(index): room.on_combat_cleared(index))
    encounter.reward_requested.connect(func(id, coins): inventory.grant_reward(id, {}, coins))
    encounter.set_encounter_active(true)
```

上面的宿主方法名为示例，不强制已有房间控制器改名。

额外查询：`is_required_enemy()`、`is_decoy()`、`is_boss()`、`is_dead()`、`is_encounter_active()`；`RoomEncounter.living_count()`仅统计正式演员；`enemy_spawned(enemy)`也会报告假身，使用查询过滤。暂停用场景树或包含所有敌人与危险的公共父节点；`set_encounter_active(false)`是中止，会清理假身与危险，不是撤退快照冻结。适配器 `clear_encounter()`完整回收，generation防止旧房回调误开新门。

## 验证

`room_tests.gd`检查基础契约、分身上限/无掉落、致盲恢复、墙柱遮挡、热浪单次命中、飞刺和刺丛、群鸦共享血量、四房清场、暂停、推进和死亡重试。结果见 `evidence/FOUR_ROOMS_VALIDATION.md`。实机模型及战斗截图由 `capture_rooms.gd`输出。数值仍需团队试玩；未宣称已接入正式地图。
