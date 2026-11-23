# 第四关前四房验证

2026-11-23，Godot 4.7.2 / Windows / GL Compatibility，Intel Iris Xe。

最终四房结果：**62 passed / 0 failed**。女巫回归：**91 passed / 0 failed**。

- 四房自动检查：`room_tests.gd`，最终结果见 `room_tests.log`。涵盖四种场景契约、假身数量/生命/奖励、致盲限时与恢复、墙柱遮挡、热浪单次伤害、七发飞刺实际碰撞、六簇刺丛、鸟群七受击体共享生命及实际冲击伤害、暂停、主动推进、清场、死亡重试和非原点房间。
- 原有女巫回归：`tests.gd` **91 passed / 0 failed**，见 `tests.log`。新增工厂条目未破坏女巫和守卫。
- 四种模型预览及四房战斗由 `capture_rooms.gd` 在图形渲染器输出并查看。曦影已使用透明柔边着色器；傀儡熔纹已沿木躯表面贴合；尖蓟尖刺和乌鸦扇翼可见。输出包括 `four_rooms_roster.png`、四张 `*_model.png`、四张 `room_*_combat.png`，日志 `rooms_capture.log`。
- 四房首次直接加载：`four_rooms_smoke.log`，无脚本错误。

原型场地复用实验室，演示生命与补给不影响正式角色，不写永久钱包。未声称已完成正式第四关地图、人工连续通关或最终数值平衡。
