# 受击闪红与敌人头顶血量

> 本文按团队仓库内路径编写。独立验证用于检查组件行为，真实主工程联调仍需组长及各模块协作完成。

负责人：汤志豪；更新日期：2026-10-28；Godot 4.7.2。U9 / R1 已在沙盒修复并通过无预热回归；U10 独立组件通过验证，真实角色/刷怪仍待团队接入。HUD 已更新为紧凑布局，接口未变。

依据见 [任务材料](references/README.md)，各批次历史摘要见 [test_evidence.md](test_evidence.md)。目录调整后的复测结果单独登记，历史结果不冒充新运行。

## 正式组件挂载层次

```text
Player 或 Enemy（真实角色根节点）
├── Visuals（所选 MeshInstance3D 模型子树）
├── HitFlash (Node，挂 hit_flash_3d.gd，visual_root=../Visuals)
└── HealthLabel（仅敌人，实例化 enemy_health_label_3d.tscn）
```

HitFlash 不修改 HP，只负责已接受伤害后的视觉反馈。HealthLabel 跟随各自敌人；默认 Y=1.9 须按实际模型调整。原沙盒占位角色、七按钮控制台、相机平移及 HUD 演示不随包交付。

## U9：HitFlash3D 接口

实现：[hit_flash_3d.gd](../scenes/ui/hit_flash_3d.gd)、[空间着色器](../assets/shaders/hit_flash_3d.gdshader)。

| 接口 | 约定 |
| --- | --- |
| visual_root: NodePath | 相对组件的模型子树；默认 ..，建议明确指定 ../Visuals，避免误包含装备特效 |
| flash_duration: float | 默认 0.1 秒，使用游戏时间，跟随暂停和 time_scale |
| flash_color: Color | 红色 overlay，可按实际模型/灯光调整 |
| flash() -> bool | 在场景树内且 ready 后调用；找到 MeshInstance3D 则设置/刷新闪红，否则 false |
| reset() | 取消 Timer 和待执行绘制回调，恢复原 overlay |
| is_flashing() -> bool | 查询该实例状态 |
| flash_started / flash_finished | 连续闪红段的开始/结束；active 状态下主动 reset 也发结束，退出场景树只清理 |

任务标题“闪白”与正文不一致，用户要求及 MVP 验收均为红色 0.1 秒，因此按红色实现。MeshInstance3D 不使用 2D modulate 伪代码；每个组件拥有独立 ShaderMaterial，以 material_overlay 覆盖自身 Mesh 子树，不改共享基础材质。

### R1 的原因与现行时序

修复前，启动长帧约 0.148 秒的 delta 可包含受击前的加载时间。Timer 立即启动后，可能在下一渲染帧前被这段时间耗尽；初始不预热用例 8 项中 1 项失败。不能把这个现象单独归因于已证实的 shader 冷编译。

现行图形路径：

1. 立即设置本角色 overlay；取消旧 Timer 和旧的待执行绘制回调。
2. 等待一次 frame_pre_draw，确保后续绘制是在 overlay 设置之后提交。
3. 在对应 frame_post_draw 后启动默认 0.1 秒 Timer。
4. 新命中重新按该流程计时；结束恢复命中前的 overlay。
5. reset/退出取消两类绘制回调及 Timer，避免过期回调或全局信号残留。

无界面路径没有可等待的绘制帧，直接使用 Timer。0.1 秒是游戏时间配置，实际测量受帧调度影响；验证按约定容差检查，原始样本留在原沙盒历史日志中，本包只提供摘要。

R1 修复批次：不预热的 **9 个独立进程均通过**（4 次玩家、4 次敌人、1 次等待对照，每次 8 项）；新增 **39 项时序边界通过**。原 3D 图形验证器中的显式预热已移除。见 [历史验收摘要](test_evidence.md)。

### 伤害接入与材质边界

只在实际接受并扣血后触发。初始化、回血、无敌/冷却拒绝不能触发；仅监听 hp_changed 无法区分这些情况。沙盒 damage_received(amount) 是示例新增契约，原团队表没有承诺存在：

```gdscript
# 真实 Player/Enemy 先完成存活、冷却/无敌和正伤害检查，再扣血。
hp_changed.emit(hp, max_hp)
$HitFlash.flash()
# 也可在成功扣血后发 damage_received(applied_amount)，由连接触发。
# 两种方式选一种，避免同一击调用两遍。
```

组件保存原 overlay，结束精确恢复；若其他系统中途换入新 overlay，清理不会覆盖新值。旧 overlay 在闪红期间被暂时替换，不是自动混合。透明裁切、多模型动态替换、其他描边效果、真实死亡释放与红色占位敌人的反馈对比度，须用团队实际模型验证。

## U10：EnemyHealthLabel3D

实现：[场景](../scenes/ui/enemy_health_label_3d.tscn)、[脚本](../scenes/ui/enemy_health_label_3d.gd)。采用任务允许的数字 Label3D：HP 3/3 → HP 2/3 → HP 1/3。初始 Y=1.9，面向相机、深色描边，保留深度测试；默认不透墙显示。

| 接口 | 约定 |
| --- | --- |
| update_hp(current: int, maximum: int) | 只更新显示；限制数值到 0..maximum |
| bind_health_source(source, initial_hp, maximum) -> bool | 解绑旧来源，显式显示初值，再连接 hp_changed(current, maximum)；无此信号返回 false |
| unbind_health_source() | 解除 HP 与来源退出通知 |
| hide_when_empty: bool | 默认 true，0 HP 隐藏；false 可保留 HP 0/最大值 |

40% 及以下改暖铜色；maximum <= 0 显示 HP --/--。作为敌人根节点子节点自动随角色移动，不放入屏幕 HUD。重复绑定不会累积连接；来源退出时解绑并隐藏，复用时重新绑定初始值。

```gdscript
# 示例契约，不表示团队 Enemy 已提供这些接口；在敌人 ready 后接入。
var initial: Vector2i = Vector2i(initial_hp, maximum_hp) # 由真实生成流程提供
var ok: bool = enemy.get_node("HealthLabel").bind_health_source(
    enemy, initial.x, initial.y
)
assert(ok)
```

原 Enemy 只约定 take_damage 和 enemy_died，没有 hp_changed/get_health_snapshot。字远可增加公开初始化与变更接口，或在扣血/治疗处主动 update_hp；不得猜测队友私有字段。初值须主动传入，每个动态敌人都绑定自身。

## 历史回归与本包边界

既有最终验收：3D 逻辑 **64 项**、图形 **101 项**、时序 **39 项**、补充边界 **48 项**均 0 失败；9 个无预热首击独立进程各 8 项通过。覆盖连续受击、共享材质隔离、原 overlay 与外部新 overlay、重置、解绑、归零、来源释放，以及绘制阶段取消、暂停/速度、移出/重进和全局回调清理。摘要见 [test_evidence.md](test_evidence.md)。

图形按钮与截图由 AI 工具验证，不是汤志豪本人的验收。原测试宿主、验证脚本、截图和输出不进入团队仓库；目录调整后的新一轮检查在仓库外独立副本中执行，结果见测试摘要。当前尚不能运行真实团队玩法。

## 必须由团队主工程补测

1. 与俞吉依、字远确认成功伤害通知，补测真实无敌、攻击冷却、同帧命中、回血和死亡时序。
2. 确认 Enemy 初值/变更接口，在 spawner 的每个实例上挂载并绑定 Label，补测切房、清敌、重开与对象池（若使用）。
3. 用真实 Visuals、相机、灯光和房间校验闪红对比、Label 高度/字体、远近与墙体遮挡。当前布局测试检查投影点，不能替代整行文字和真实墙体可读性验收。
4. 验证真实拾取、房间索引、死亡/三房胜利、随机世界重建和旧信号清理。

本模块的正式组件现位于 scenes/ui，两个 Shader 位于 assets/shaders；保留对应 UID 及 [dungeon_font.tres](../scenes/ui/dungeon_font.tres)。测试宿主、占位角色和沙盒 project.godot 不进入团队仓库。真实角色挂载、伤害通知与动态敌人绑定仍待接入，详见 [职责状态](task_audit.md)。
