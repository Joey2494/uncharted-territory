# 当前整合版开发说明

## 开发基准与入口

使用 Godot 4.7.2，根目录 `project.godot` 指定 `Main.tscn` 为启动场景。`main` 保存当前整合结果；队友继续开发前先拉取最新主分支，再创建各自的功能分支。

第一关实际出口胜利后可进入第二关；第二关正式入口为 `scenes/dungeon/Level02Run.tscn`。需要单独调试第二关时直接运行该场景。正常关卡选择根据玩家存档中的通关进度解锁。

## 角色与操作

| 角色 | 初始状态 | 解锁金币 | 生命 / 角色护盾 / 能量 |
| --- | --- | ---: | --- |
| Knight 初始旅人 | 免费解锁 | 0 | 5 / 0 / 50 |
| Lan 游侠 | 锁定 | 100 | 5 / 1 / 50 |
| Iron 守卫 | 锁定 | 150 | 6 / 2 / 40 |
| Astra 术士 | 锁定 | 180 | 4 / 1 / 60 |

角色场景位于 `scenes/player/`，共享 `Player.tscn`。`character_catalog.gd` 负责角色配置，`character_ability.gd` 负责独特技能。金币及角色所有权由 `scripts/integration/player_profile.gd` 存入 `user://player_profile.cfg`。新玩家只有 Knight，开发者本机的金币、解锁与关卡存档不随源码共享。

Iron 使用原第一关 Boss 的 Barbarian 身体及独立圆盾、盔甲；第一关 Boss 使用 `BronzeGatekeeper.tscn` 的独立铜甲形象。Knight 的原始外形保留。菜单和战斗引用相同角色资源。

WASD / 方向键移动，J 使用当前武器，K 法术，L 角色技能，Space 闪避，E 拾取或操作机关，R 使用生命药剂，F 使用强化符文，G 使用守护，I 切换已拥有的手炮与近战，P 打开商城，Esc 暂停。I 不会自动获得手炮；手炮需要先获取并具有实际弹药。

第一关入口有实体药剂；强化符文教学等到玩家遇到支线房间内的真实符文后出现。教程控制器位于 `scenes/tutorial/`，音效连接位于 `scenes/audio/`。

## 两关与地图

`Main.gd` 管理两关的菜单、运行、暂停、死亡和胜利；`scripts/integration/run_bindings.gd` 连接玩家、经济、教程、音效和 HUD；`menu_navigation.gd` 负责关卡选择和设置。`campaign_progress.gd` 负责跨关进度。

第一关地图为 `scenes/dungeon/DungeonTest.tscn`。第二关地图在 `scenes/dungeon/level02/Level02.tscn`，通过 `Level02Campaign.tscn` 和 `campaign_level02.gd` 接入共享宿主。第二关 Boss 为灾厄巨蝎；清敌、导能、回环和档案室双阶段机关仍由原地图系统负责，击败 Boss 后必须实际进入出口才结算。

第二关全部房间与通道使用第一关同系列的 AlmsyONE 石砖、墙体及陈设。`stone_region.gd` 负责可视层，继承第一关入口的石材处理和遮挡淡出；`stone_cover.gd` 负责中庭掩体的石砌外观。基础 `dungeon_region.gd` 继续生成碰撞，新增陈设不添加碰撞，不改变门洞和原有通行范围。地砖按房间边界铺设并使用 MultiMesh，避免相邻区域重叠闪烁。

## UI 与后续接入

界面以汤的 `scenes/ui/menu_theme.tres`、石纹与暗金风格为准。两关共用血量、能量、资源、快捷栏、冷却、暂停、商城、背包及设置界面。

第二关 `LevelObjective.tscn` 从真实地图读取房间、当前目标、探索、导能与回环状态；窄窗口 Boss 战期间让位给 Boss 血条，战后恢复。修改地图目标时更新地图的 `get_objective()`，不要另建 UI 进度状态。

机关结算区分门升起中、门已开和奖励已领取；后续模块继续使用现有真实状态与信号。暂停、死亡或结算时不得独立继续推进资源、门动画或机关。

美术文件的来源及授权保留在各素材目录。保持现有模型和动画兼容节点路径，避免只替换外观后破坏骨骼动画、武器挂点或 Boss 接口。
