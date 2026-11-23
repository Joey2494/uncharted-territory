# Uncharted Territory · 未知之境

Godot 4.7.2 项目。本周三关整合版已合入队友交付和俞的角色机制，提交到 `codex/week10-integrated-baseline` 分支供审查；合并后下一轮统一从最新 `main` 创建开发分支。下周分工与已知问题见 [第十一周计划](docs/week11-plan.md)，整合变更见 [修改记录](docs/change/change-week9.md)。

用 Godot 导入根目录 `project.godot`，按 F5 启动 `Main.tscn`。第二关可通过第一关胜利页面进入，也可直接运行 `scenes/dungeon/Level02Run.tscn`。

测试版三关全部开放，确认角色后可直接选择第一、第二或第三关，无需先通关。第三关「潮汐回流工坊」正式入口为 `scenes/dungeon/Level03Run.tscn`；暂用第一关的石砖、苔墙和石台素材，保留张宏伟的路线、潮汐与充能机关，已接入字远的四类敌人及首领沙缚王。靠近设备按 E，Esc 暂停后选择「操作与路线」查阅路线说明。独立调试入口 `scenes/dungeon/level03/Level03Preview.tscn` 保留，打开后按 F6；独立预览使用 Tab 查看路线。

保留免费初始旅人 Knight，新增 Lan、Iron、Astra 三名金币解锁角色；三关共用 HUD、暂停、商城、背包和操作设置。第二关采用天然蜘蛛洞窟外观；档案室使用固定全房间取景，能源归属常驻目标卡，靠近设备显示操作提示。

主要操作：WASD / 方向键移动、J 使用当前武器、K 法术、L 角色技能、Space 闪避、E 交互、R 药剂、F 强化符文、G 守护符文、I 切换手炮与近战、P 商城、Esc 暂停。

商城新增「星蓝药剂」：15 金币，恢复 20 点能量，满蓝不消耗；可在背包使用或按快捷键 6。拾取金币属于本局余额，剩余金币仅在本关通关后存入永久钱包，失败和退出不入账。

2026-11-22 修订：取消角色随时间自动回能，保留药剂和角色机制的单次恢复；第三关 C/E/F/I/G 分别配置骨斧×2、腐尸×2、墓卫×2、执刑官×1、沙王×1，每室只有一种敌人，维修井清场后方可泄压。`PLAY_LEVEL03.cmd` 现在进入正式战役；敌人实验室仍可单独运行 `addons/ziyuan_level03/Prototype.tscn`。通关钱包使用临时文件替换和备份恢复，保存失败时需重试成功后再离开结算页。详细数值、review 和验证见 [本次修复记录](docs/review/level03-energy-wallet-2026-11-22.md)。

当前模块、角色和接线说明见 [项目开发说明](docs/current_project.md)，本次修改见 [第九周变更记录](docs/change/change-week9.md)。素材来源及授权保留在各素材目录的 README 和 License 文件中。
