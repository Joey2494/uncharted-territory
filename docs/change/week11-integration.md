# 第十一周整合记录

整合时间：2026-11-23 至 2026-11-24（北京时间）。工作分支：`codex/week11-integration`。

## 来源与选择规则

按俞吉依本次请求整合。第十周开发文档只作为成员分工与既有功能的参考；其中旧的 K 法术、旧耗蓝和旧界面说明不覆盖本次聊天确认的规则。

| 模块 | 主来源 | 整合处理 |
| --- | --- | --- |
| 角色、人物机制、专属武器 | 俞吉依，本地恢复点 `1f7ed15` | 保留四角色专属双武器、八套独立模型、两类弹药、R/I/J/K/L 机制及角色被动 |
| 地图和机关 | 张宏伟，PR #17 / `a587ede`，含 `e22521b`、`3abc6eb` | 保留三关潮汐/维修井、四关十二房及四支线、实体门锁、吊笼、增援、百叶扫光、地图镜头与战役结算 |
| 敌人 | 字远，PR #18 / `a0cebc7`，含 `8c9cacb`、`25781d9` | 接入第三关直接攻击和单敌种房间；将第四关新敌人从独立测试场接到正式观测站 |
| 美术和通用 UI | 汤志豪，PR #16 / `b1ee670` | 接入加载画面、设置服务、洞穴/古墓美术、任务日志、地图、交互气泡与提示队列 |
| 俞吉依新增或改过的 UI | `1f7ed15` 及本聊天最终要求 | 优先保留角色详情、透明武器介绍、暖金正文/灰色属性值、五格快捷栏、右上武器资源栏、原右下 J 与四键圆弧布局 |

仓库来源：[Joey2494/uncharted-territory](https://github.com/Joey2494/uncharted-territory)。以获取时的最新 `origin/main = a0cebc715f30b1f79ab352710fdc2ffd4b2314a8` 为来源，已包括 PR #16、#17、#18。

## Git 恢复与冲突处理

1. 原工作分支为 `codex/week10-integrated-baseline` / `7bd1e4b`。先保存全部已有角色和武器工作到 `1f7ed15`，包括模型、图标、代码、测试和历史修改记录。
2. 在 `codex/week11-integration` 整合 `b1ee670`，产生中间提交 `e7feb8a`，再整合 `a0cebc7`。未改动其他已存在的工作树。
3. `character_catalog.gd`、`character_dossiers.gd`、`character_select.gd/.tscn` 优先保留俞吉依版本。人物页继续直接展示详细 L 技能/被动及两把专属武器，不恢复旧的独立机制弹窗。
4. `item_pickup.gd` 保留专用子弹枚举，同时接入汤志豪的数量显示。`run_bindings.gd` 保留五格快捷栏及真实 I/K 点击调用，接入第四关试玩返回与战役生命周期；不恢复全局“弹药 ∞”。
5. `Player.gd` 合入字远的“取消自然回蓝”，保留俞吉依的武器行为、护盾、法力和动作约束。K 消耗现有星蓝药剂恢复 20 蓝，枪械从对应库存换弹；生命药剂仍为 R。

## 第四关正式敌人接线

原正式观测站仍使用第三关旧敌人；本轮已改成字远第四关模块，正式战役与观测站预览共用配置：

| 实际房间 | 正式敌人 | 地图机制 |
| --- | --- | --- |
| B 折尺装卸场 | 曦影 ×2 | 完整进入后封门；分身不计门锁、不掉钱、不触发守卫回盾 |
| D 配重井（可选） | 赤阳傀儡 ×2 | 清场后允许设置 F 吊笼；保持配重支线 |
| F 折光栈道 | 白芒尖蓟 ×2，随后增援 ×1 | 保留双廊、可移动掩体、增援灯与完整名单清场 |
| H 百叶试车场 | 群鸦归巢 ×1，随后增援 ×1 | 保留无伤演示、跨线开战与真实百叶扫光 |
| I 主穹顶 | 袍冠女巫 ×1、白芒尖蓟近卫 ×1 | 女巫原生招式/二阶段/孢子守卫；半血让出东侧扳杆路线；近卫未清除时不放行 |

- `observatory_witch.gd` 继承字远女巫，不复制招式实现，只适配张宏伟的石岛绕行和半血移步。半血时暂停百叶，移步完成恢复扫光；不恢复旧执刑官预警或减伤。
- 奖励使用独立且幂等的敌人来源 ID；原房间完成补给奖励保留。孢子守卫注册到女巫原生召唤列表，女巫死亡/停止本局会清理，延迟回调受 generation 检查约束。
- 曦影致盲接入场景内低层暖色遮罩，最大透明度 0.48，HUD 仍在上层；暂停冻结，持续结束/清场/死亡/停止后回收。
- 正式敌人带 `combat_room_key`，接入 Iron 近距击杀回盾；Astra 正式清场只回 5 蓝一次。三关沙王召唤物补上相同的 `is_summoned` 排除标记。
- 群鸦七个碰撞体通过 `get_combat_actor()` 返回同一整群演员。近战、引力、冰杖减速与引火余烬都落在真实共享生命上，避免多只鸟重复计目标。第四关普通敌人的减速比例与现有冰杖 30% 保持一致。
- 旧观测站兼容脚本留作历史资源，不再用于正式第四关出怪。

## 界面与入口

- 保留人物页透明武器卡、暖金正文 `#e5c17c`、关键属性灰色 `#b3b3a6`；`÷ 1.3` 等计算系数仍为正文色。
- 保留右上当前武器栏：枪显示当前弹数/弹匣容量，耗蓝法杖显示实际单次耗蓝，近战和练习魔杖显示 ∞。
- 保留五格快捷栏和 J 右下锚点；Space/L/I/K 等大、围绕 J 均匀排在左上圆弧，文字与图标分区，圆形点击区域不重叠。
- 更新整合后帮助和交互文案中的旧“K 法术 / I 手炮”。修复 `Tab` 被截成 `T` 而显示“操作”的问题。
- 新增 `PLAY_INTEGRATED.cmd`，使用 `GODOT_EXE` 或检测到的 Godot 4.7，从项目实际加载页进入主菜单，再选四个正式关卡。`PLAY_LEVEL04.cmd` 仍是字远女巫独立测试场，不能据此判断正式战役是否整合。
- 根目录旧 exe 没有重新导出，本轮运行和验证使用项目源码。

## 验证

使用 Godot `4.7.2.stable.official.ed1daf0bf`。存档类检查使用隔离文件；设置检查使用 `.review/integration-appdata`。以下均有完整结果行，未把 `--quit-after` 提前退出视为通过：

| 检查入口 | 结果 |
| --- | --- |
| `tests/weapon_week11_test.gd` | 119 项通过 |
| `tests/weapon_campaign_test.gd` | 四个正式关卡，92 项通过 |
| `tests/action_badge_layout_test.gd` | 1056 项布局/字界/圆形点击检查通过 |
| `tests/dungeon/test_level04_combat.gd` → `test_level04_enemy_integration.gd` | 78 项正式敌人、专属武器破箱、门锁、召唤、致盲、角色被动和扫光接线检查通过 |
| `tests/dungeon/test_level04_campaign.gd` | 41 项正式选关、通关、继续、失败和结算检查通过 |
| `tests/dungeon/test_level04_campaign_routes.gd` | 42 项通过，十二房/四支线完成；该次为快速路线枚举，非手动战斗试玩 |
| `tests/dungeon/test_level04_camera_run.gd` | 持续真实 WASD 输入通过；女巫半血移动 9.43m，H/I 战斗镜头距离漂移 0，最大缩放变化速度 12.00 |
| `tests/dungeon/test_level04_geometry.gd` / `test_level04_instruments.gd` | 130 / 23 项通过 |
| `tests/dungeon/test_level03_campaign.gd` | 143 项通过，包括预期的载入失败恢复 |
| `tests/dungeon/test_level03_maintenance_camera.gd` | 75 项通过 |
| `tests/scenes/pr18_review_regression.gd` | 757 项第三关实际任务、地图与交互检查通过 |
| `tests/scenes/energy_wallet_regression.gd` / `--readback` | 40 + 跨进程 2 项通过，覆盖无自然回复、备份恢复、原子保存与重复结算 |
| `tests/scenes/settings_sync_tests.gd` | 正常帧率 78 项通过，包含故意损坏配置的恢复用例 |
| `tests/scenes/loading_screen_tests.gd` | 190 项通过 |
| `tests/scenes/castle_quest_tests.gd` | 146 项通过；异步重开改为等待真正场景交接 |
| `tests/scenes/right_hint_dock_tests.gd` | 297 项通过；断言同步到已存在的世界气泡展示，不再要求旧固定按键面板 |
| `tests/scenes/interaction_bubble_tests.gd` | 508 项通过 |
| `addons/ziyuan_level04/tests.gd` / `room_tests.gd` | 女巫 91 项、四类敌人 62 项通过 |

测试适配说明：旧 `test_level04_combat.gd` 的 K 能量弹、第三关旧出怪和执刑官预警断言已退役，入口转向当前正式敌人整合测试；破箱、扫光、吊笼和门锁仍在新测试及原机关/战役路线测试中验证。镜头测试按当前 H 房名单识别增援；鸟群碰撞使角色侧移后，使用真实横移输入对齐桥口再继续北行。退出阶段少量 `ObjectDB/resources still in use` 提示保留在日志中，不当作无警告通过；未宣称完整历史测试目录全部通过。

加速执行设置测试时出现过异步加载时序失败；恢复正常帧率后设置完整流程 78 项通过。初次专项测试发现的是旧碰撞节点名称、鸟群受击保护时间和实体门开启等待的测试假设，已按当前真实节点和时序修正并重跑。

完整最终日志和实拍位于 [week11-integration-evidence](week11-integration-evidence)。截图由 `tests/integration_week11_capture.gd` 在真实渲染下生成，视觉摆位使用隔离场景，不作为手动通关证明。前次角色和武器的全部历史记录继续保留在 [week10.md](week10.md)。
