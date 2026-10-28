# 汤志豪职责核对与团队接入待办

> 本文按团队仓库内路径编写。独立验证用于检查组件行为，真实主工程联调仍需组长及各模块协作完成。

更新日期：2026-10-28；范围：团队 feature/hud-ui 的 UI/HUD 与视觉反馈；Godot 4.7.2。依据为 [MVP 原文](references/mvp_scope.md)、[作业 5 分工](references/assignment_5_mvp_tasks.md)，归档说明见 [references/README.md](references/README.md)。原文中的示例、试玩和 AI 模板不是完成记录。

## U1–U11 状态

“独立通过”指组件及测试宿主中的行为，不等于真实团队游戏验收。正式界面不承担测试宿主的玩法模拟、世界重建或重复请求保护。

| 编号 | 当前实现或独立验证范围 | 必须由团队补验 |
| --- | --- | --- |
| U1 | 左上角 336×108 紧凑 HUD：细血条、独立武器框、房间图标及分段 | 真实主工程 CanvasLayer 挂载与世界同屏 |
| U2 | update_hp_bar、边界、低 HP、归零与回血显示 | Player.hp_changed 与主动初始化 HP |
| U3 | 0 基 update_room_label、编号/到达分段、无效输入 | 真实进门与房间索引约定 |
| U4 | 空武器暗框、装备暗金高亮及状态文字 | 实际拾武器、玩家装备与 HUD 同步 |
| U5 | 独立相机平移与多窗口缩放验证 | 真实 WASD 玩家、跟随相机和游戏输入 |
| U6 | StartScreen.start_requested；测试宿主注入 PackedScene | 组长提供真实入口，不能猜主场景路径 |
| U7 | 死亡界面、到达房间数、restart_requested；测试宿主验证新实例 | player_died、真实死亡索引、旧世界/信号清理 |
| U8 | 胜利界面与重开请求；测试宿主验证三房胜利及重复请求保护 | 真正清敌/开门/胜利、随机生成及宿主重开保护 |
| U9 | 独立 overlay、R1 首击修复、约 0.1 秒、连续受击、恢复与隔离 | 成功伤害通知、真实模型与死亡材质时序 |
| U10 | Label3D 初值、HP 绑定/解绑、低 HP 和归零隐藏 | Enemy 初值/变更契约，每个动态敌人绑定自身 |
| U11 | [画面组织](screen_layout.md)、HUD 子级 ResultLayer、数据与缩放说明 | 团队真实主场景图与完整运行证据 |

房间分段表示“到达当前房间”，不表示清敌或胜利。五个 HUD 方法与 restart_requested 保持原签名。ResultLayer 由 HUD 动态创建/复用为 layer=20 子节点，宿主不另建一套结果层，见 [screen_flow.md](screen_flow.md)。

## 目录与独立验证

正式场景及脚本统一放 scenes/ui，SVG 在 assets/ui，两个 Shader 在 assets/shaders。路径调整保留原 UID 与 SVG 导入配置，未修改角色生命逻辑或 UI 功能。

R1 已修复为包含 overlay 的绘制帧之后开始计时；不以预热掩盖首击。R2–R4 的结果层、人工/AI 身份及路径说明继续遵循当前实现。历史与本次独立复测分开登记，详见 [test_evidence.md](test_evidence.md) 和 [feedback_3d.md](feedback_3d.md)。

本次整理与复测状态：Godot 4.7.2 导入及 18 项运行进程检查全部通过，所有检查零失败，详见 [test_evidence.md](test_evidence.md)。当前团队检出尚无 project.godot 或真实主场景；验证使用仓库外独立副本，不把测试工程设置带入团队仓库。

## 必须接入团队主工程

| 优先级 | 协作方 | 约定及验收动作 |
| --- | --- | --- |
| P0 | 俞吉依 + 字远 | 成功扣血后主动 flash 或发伤害事件，二选一；初始化/回血/无敌拒绝不闪，同一击不重复触发 |
| P0 | 字远 | 明确 Enemy 初始 HP/最大值和 hp_changed，或主动 update_hp；每个刷出实例单独绑定，释放/切房不残留 |
| P1 | 俞吉依 | Player 初始状态、hp_changed、item_picked、房间索引，实测伤害/血药/武器/跨门 |
| P1 | 俞吉依 + 张宏伟 | 真实开始入口、player_died、清三房判定、暂停与玩法输入、重开清理及随机世界重建 |
| P1 | 模型/相机/房间成员 | 实际 Visuals 路径、overlay 使用权、Label 高度/字体/墙体遮挡、相机跟随及 HUD 固定 |
| P2 | 全组 | 外组试玩、真实观察与决策、最终导出及其他平台字体/渲染后端 |

原契约没有保证 damage_received、Enemy.hp_changed 或 get_health_snapshot；这些是协商接线点，不得假定队友已实现。原 enemy_died(enemy)/player_died 与测试宿主信号不能混用。

## 个人与全组交付

个人 AI 使用说明见 [ai_usage.md](ai_usage.md)，汤志豪本人复核与实际手改记录仍待补充。外组试玩、观察支持决策、每人 2–3 个 PR/审查以及完整游戏导出尚未完成，不用任务模板代替事实。

本次只在 feature/hud-ui 整理正式文件和文档；原沙盒、原交付包及团队 main 不修改，不暂存、不提交、不推送、不创建 PR。音效/BGM、多武器/敌人、Boss、分支房间等按当前 MVP 暂缓；粒子/装饰也不作为本轮漏做项。
