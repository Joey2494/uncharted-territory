# 第九周本地整合与人物机制变更记录

日期：2026-11-17。设计依据：[`../character-week10.md`](../character-week10.md)。按本次任务约定，本次实现记录归入 **week9**，设计文档文件名保持 week10。

## 基础属性

| 人物 | 生命 | 护盾 | 能量 | 步行 / 奔跑 | L 技能与冷却起点 |
| --- | ---: | ---: | ---: | --- | --- |
| Knight | 5 | **2（原为 0）** | 50 | 5 / 8 | 新增战斗补给：恢复 10 能量，成功使用后冷却 12 秒 |
| Lan | 5 | 1 | 50 | **5.2 / 8.5（原为 5 / 8）** | 专注 4 秒，结束后冷却 10 秒 |
| Iron | 6 | 2 | 40 | 4.6 / 7.4 | 举盾反击结束后冷却 **8 秒（原为 10）** |
| Astra | 4 | 1 | 60 | 5 / 8 | 成功生成法阵后冷却 14 秒 |

共享 J 近战基础伤害 1、间隔 0.5 秒；K 基础伤害 2、冷却 0.8 秒，通常消耗 10 能量，Astra 实际消耗 8。保留项目已整合的可装备手炮功能：装备手炮时 J 沿用原有武器路由，不在此次人物更新中移除武器系统；默认近战仍是零能量兜底。

## 人物机制

### Knight：战斗补给

- L 立即恢复最多 10 能量，不超过上限；满能量拒绝使用且不进入冷却。
- 不修改 J/K 动作、不重置 K 冷却、不提供伤害或无敌。
- 在发出资源更新信号前占用技能冷却，避免监听方重入导致一次使用重复补给。

### Lan：整备射击与专注

- 新增连续 1.5 秒未成功发动 J/K 的整备计时，最多存一发，持续 5 秒；两次获得至少间隔 6 秒。
- 成功释放 K 后消耗整备，基础直接伤害由 2 增至 3；未命中也消耗，能量不足或动作拒绝时保留。
- J 中断尚未完成的整备，不消耗已经获得的整备；移动、闪避和开启 L 不重置整备。
- HUD 点亮 K 图标并显示“法术 · 整备”，角色附近短暂显示“整备完成”。
- 保留专注 4 秒、J/K 间隔除以 1.3、结束后冷却 10 秒，不清除已有冷却，闪避不取消。
- 兼容现有装备手炮：成功 J 射击同样重置停火整备计时，手炮不消耗 K 专属强化。

### Iron：稳固阵地与举盾反击

- 新增 J 直接最后一击回 1 护盾：敌人死亡时距玩家不超过 2.5 米，且属于正式战斗房的非召唤普通/精英敌人。
- 每房最多实际恢复 2 点；满盾不扣额度，同一击杀不能重复结算。房间键包含本局房间控制器实例，不会因撤退、重进刷新，也不会把不同关卡同名房间混在一起。
- K、反击、法阵、环境击杀不走 J 命中结算，不能触发回盾；Boss 本体不提供该恢复来源。
- 精准格挡窗口由前 0.2 秒改为前 **0.6 秒**；反击基础伤害 2，每次格挡 +1，上限 5，精准反击对普通敌人眩晕 0.5 秒。
- 保留举盾上限 1.2 秒、锁定面向、50% 移速、正面 120 度和 2.5 米反击半径、隔墙检查。闪避取消举盾且不反击，进入 8 秒冷却。
- 直接伤害接口增加可选攻击标识和可格挡开关；同一近战攻击重复接触只计一次格挡。现有普通敌方直射弹丸沿用单次碰撞销毁流程，不反弹；地面持续伤害继续走普通伤害接口。

### Astra：节能回路与引力印记

- 保留 K 的浮点 20% 减耗；新增正式战斗房清理奖励 5 能量，包括 Boss 房。
- 奖励由战斗房组件收到正式完成事件后结算，非战斗房无奖励；每房只结算一次，满能量不储存，清房回复不受自然回复等待限制。
- 保留 0.25 秒移动施法前摇、6 米放置距离、2.5 米半径和 3 秒法阵；伤害依次为 **1 + 1 + 1 + 2**。
- 普通敌人牵引速度保留 0.6 米/秒，精英新增 0.3 米/秒；两者减速均为 30%，牵引通过碰撞移动处理，Boss 不受控制。
- 加入放置点碰撞空间检查，射线从墙体内部出发也会拒绝穿墙放置；无合法位置进入 1 秒防误触冷却。
- 闪避取消前摇只进入 1 秒冷却；已生成法阵保留，暂停/地牢冻结时停止计时，死亡立即请求清除自己生成的法阵。

## 共享与界面

- 沿用浮点能量、K 成功释放后等待 1 秒再每秒回 5、护盾先吸收且溢出扣生命、药剂只恢复生命及资源上限。
- 沿用 J 前摇/有效阶段不可被 K 覆盖、恢复期可接 K、K 后 0.18 秒限制 J、失败输入不排队和闪避取消动作。
- 所有计时依赖物理游戏时间，继续服从场景暂停与地牢冻结。死亡时停止角色光环、举盾、整备提示、施法特效和持续区域。
- 更新菜单人物属性/被动说明；Knight 显示 L 技能卡。永久解锁、两模式共用存档和本局不换人的原有流程继续保留。

## 文件位置

| 文件 | 修改内容 |
| --- | --- |
| `scenes/player/character_catalog.gd` | 人物属性、技能名称、菜单说明 |
| `scenes/player/character_ability.gd` | 补给、整备、回盾/回能、格挡、放置与死亡清理 |
| `scenes/player/Player.gd` | 通用能量回复接口、浮点消耗与可选直接伤害参数 |
| `scenes/player/melee_attack.gd` | 为一次挥击提供稳定攻击标识 |
| `scenes/skills/energy_shock.gd` | 成功 K 消耗整备并快照伤害、死亡停止施法特效 |
| `scenes/skills/gravity_field.gd` | 精英牵引速度、目标去重与死亡过滤 |
| `scenes/dungeon/components/combat_room_encounter.gd` | 战斗房归属、正式清房奖励 |
| `scenes/items/firearm_attack.gd` | 兼容已有 J 手炮的停火计时 |
| `scenes/ui/hud.gd`、`scripts/integration/run_bindings.gd` | Knight 技能卡、整备显示 |
| `tests/character_week9_rules_test.gd` | 新增机制与边界回归 |
| `tests/character_combat_test.gd`、`tests/character_unlock_test.gd` | 更新守卫 8 秒冷却、Knight 2 护盾断言 |

扩展约定：召唤单位标记 `is_summoned` 元数据或加入 `summoned_units` 组；精英标记 `is_elite` 元数据或加入 `elite_enemies` 组。现有普通敌人、射手和 Boss 无需修改数值。

## 验证

Godot 4.7.2，以下六组自动检查共 **577 项，0 失败**，各进程退出码均为 0：

| 检查脚本 | 检查数 |
| --- | ---: |
| `tests/character_week9_rules_test.gd` | 70 |
| `tests/character_combat_test.gd` | 111 |
| `tests/character_unlock_test.gd` | 31 |
| `tests/integration_modules_test.gd` | 206 |
| `tests/integration_campaign_flow_test.gd` | 17 |
| `tests/scenes/week9_tests.gd` | 142 |

覆盖补给上限与动作保持、整备获得/中断/消耗/过期、精准窗口、重复格挡、实际 J 最后一击与每房回盾限额、召唤排除、清房去重、Boss/非战斗房奖励、精英牵引、无合法位置、死亡清理与冻结。原有角色物理场景检查继续覆盖法阵总伤害、隔墙限制和普通敌人/Boss 控制差异。

日志：`.godot/character_week9_rules.log`、`.godot/character_week9_character_combat_test.log`、`.godot/character_week9_character_unlock_test.log`、`.godot/character_week9_integration_modules_test.log`、`.godot/character_week9_integration_campaign_flow_test.log`、`.godot/character_week9_system.log`。`git diff --check` 通过。

使用 GL Compatibility 实际渲染四角色菜单与独立地图/HUD，复核菜单文字换行、Knight 战斗补给技能卡、Lan 金色 K 图标和角色旁整备提示。截图缓存为 `.godot/week9_menu_*.png` 与 `.godot/week9_hud_*.png`；渲染日志 `.godot/character_week9_hud.log` 无脚本或引擎错误。独立地图截图用于机制表现检查，不代替完整主流程的人工试玩。

复测示例（工程根目录 PowerShell）：

```powershell
# 测试数据写入工程缓存，避免覆盖用户正式存档。
$env:APPDATA = Join-Path $PWD '.godot/test-appdata'
& 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/character_week9_rules_test.gd
```

自动回归用于验证机制和兼容性，最终操作手感与四角色平衡仍需实际试玩。

---

## 2026-11-18：最终本地整合

本次直接修改 `D:/uncharted-territory` 现有工作区，**未提交、未推送、未创建 PR**。下一周以俞最终发布的整合版为基准。

### 来源与取舍

- 阅读第九组第九周开发文档（11.04–11.11），将其作为模块、交付和路线设计的参考；具体整合优先级遵循俞本次明确指定的分工。
- 本地原基准 `669e3bb`；已获取并将远端 `origin/main` 的 `6041cf4` 工作文件整合到本地。包括汤的 UI、美术、背景音乐与技能展示，张宏伟的第二关修订、第三关潮汐路线，以及字远的敌人表现和通关金币结算。
- **角色以俞为准**：保留本文件上半部分及 `docs/character-week10.md` 的属性和机制，未被上游旧角色数值覆盖。为汤的技能 UI 补齐 `ability_definition()` 和 `get_configuration()` 接口，Knight 显示战斗补给，Iron 冷却显示 8 秒，Lan 整备继续使用金色 K 图标与状态提示。
- **美术以汤为准**：保留石纹暗金菜单、人物展示、HUD 技能圆盘、结算和商城背包；角色页只展示当前角色属性，去掉「较旅人」「与旅人相同」、基准竖线及悬停比较文案。
- **金币以字远为准**：每关本局金币从 0 开始，拾取不写永久钱包；局内商店消费本局金币，仅实际通关后将剩余金币入账一次。死亡、退出或重开不入账；跨关是新的一局。角色解锁消费永久钱包，旧档案与角色所有权继续兼容。
- **路线与关卡以张宏伟为准**：保留第二关主支线、能源档案室和取景修订；第三关保留 A–J 房间、高潮/低潮通路、导体方向、F 蓄能、I 泄压、G 清场及 J 实际出口判定。

### 星蓝药剂与临时第三关美术

新增「星蓝药剂」，商品 ID 为 **5**，原 0–4 号商品兼容。单价 **15 金币**，每瓶立即恢复 **20 点能量**，不超过角色上限；满蓝不消耗，也不进入使用冷却。图标为带闪电标记的蓝色药瓶 `assets/ui/energy_potion.svg`，延续商城图标风格。

商品接入真实商店购买按钮、背包和第六快捷栏，按 **6** 或点击第六槽使用。使用遵守现有共享道具冷却；只恢复能量，不改变生命、护盾、J/K 动作或自然回能等待。暂停背包通过授权入口使用；死亡、冻结世界下的普通快捷使用被拒绝。

第三关新增 `scenes/dungeon/level03/tide_stone_visuals.gd`，复用第一关 Almsyone 的 `SM_Floor_Stone.glb`、`SM_Wall_Mossy.glb`、`SM_Altar.glb`，替换地板、边墙、交互台基座与掩体的白盒外观。可视结构按原碰撞包围盒缩放，未新增碰撞或改变路线；保留水面、浮栈、线路和状态灯的功能辨识色。房间地面标签移到边侧，避免与检修台名称重叠。此处为正式第三关美术完成前的临时方案。

新增精英怪补上统一 `is_elite` 元数据，使 Astra 对普通/精英敌人的牵引分别保持 0.6/0.3 米每秒；支持新敌人的 `is_boss()` 接口，Boss 不受牵引和减速，也不计入 Iron 回盾奖励。

### 本次验证

Godot 4.7.2，以下 **17 组共 1973 项，0 失败**。资源导入完成，退出码 0；最后一次导入及实际 OpenGL 渲染日志无脚本或引擎错误。所有测试通过隔离路径保存数据，不覆盖正式玩家档案。

| 脚本 | 检查数 |
| --- | ---: |
| `tests/character_week9_rules_test.gd` | 70 |
| `tests/character_combat_test.gd` | 111 |
| `tests/character_unlock_test.gd` | 29 |
| `tests/scenes/character_skill_consistency_tests.gd` | 134 |
| `tests/scenes/character_stats_tests.gd` | 143 |
| `tests/integration_modules_test.gd` | 206 |
| `tests/integration_campaign_flow_test.gd` | 50 |
| `tests/dungeon/test_level03_campaign.gd` | 134 |
| `tests/dungeon/test_level03_tide.gd` | 99 |
| `tests/dungeon/test_level02_integration.gd` | 85 |
| `tests/scenes/level02_revision_tests.gd` | 45 |
| `tests/scenes/settlement_layout_tests.gd` | 8 |
| `tests/scenes/commerce_tests.gd` | 115 |
| `tests/scenes/hud_compact_layout_tests.gd` | 558 |
| `tests/scenes/continue_progress_tests.gd`（unit） | 16 |
| `tests/scenes/week9_tests.gd` | 143 |
| `tests/local_integration_test.gd`（实际渲染） | 27 |

新增蓝药回归覆盖：真实购买按钮、价格和扣款、永久钱包不变、暂停背包恢复 20 能量、满蓝不消耗、临近上限钳制、共享冷却、第六快捷栏、死亡与冻结拒绝使用，以及第三关复用第一关素材。更新过期回归中的旧怪物攻击、旧金币行为、旧角色选择控件和旅人比较断言，使用当前真实菜单及敌人接口。

第三关正式流程测试中的 `EXPECTED_LOAD_FAILURE_BEGIN/END` 是主动注入的场景载入失败检查，验证失败后的恢复流程。部分快速 headless 测试在退出时有 MP3 播放引用清理警告；实际渲染测试等待音频释放后正常退出。资源导入最初在受限沙箱中遇到 Windows 安全保存权限提示，沙箱外复核正常。

日志为 `.godot/integrated_<脚本名>.log`、`.godot/integration_final_import.log` 与 `.godot/integration_render.log`。截图为 `.godot/integration_character.png`、`.godot/integration_shop.png`、`.godot/integration_level03.png`。`git diff --check` 通过。

整合前的本地修改已备份为 `.godot/integration-20261118/local-before.zip`，来源与人工冲突取舍在同目录 `merge-report.json`。这些缓存不随源码上传。README、`docs/current_project.md`、`docs/character_stats.md` 和 `docs/character_skill_presentation.md` 已同步当前行为；本文件按俞的约定继续记录在 **week9**。

## 2026-11-18：K 法术统一消耗 5 点能量

按俞的新要求，四名角色每次成功释放 K 均消耗 **5 点能量**，替代此前普通角色 10 点、Astra 8 点的规则。`Player.gd::get_spell_cost()` 统一返回 5；Astra 不再额外应用 20% 减耗，清理战斗房恢复 5 能量的被动保留。Lan 的强化 K 同样只消耗 5 点。基础伤害、冷却、动作衔接、自然回能等待和回能速度保持原规则。

工作区此前仅有 `docs/character-week10.md`，本次补齐用户指定的 **`docs/character-week9.md`** 完整角色文档，并同步原 week10 文件、Astra 游戏内技能说明和当前项目说明。四名角色配置表、Lan 强化说明及可施放次数同步更新：不计回复和补给时，50 点能量可释放 10 次 K。上方旧变更条目作为历史记录保留，以本条和最新角色文档为当前规则。

验证：`tests/character_week9_rules_test.gd` **90 项通过**，`tests/character_combat_test.gd` **111 项通过**，合计 **201 项，0 失败**。新增四名角色的实际施法边界检查：4.99 能量拒绝且不扣费/不进入冷却、恰好 5 点可释放并归零、冷却中重复输入不扣费、5.5 点释放后保留 0.5 点。更新 Knight 补给与 Lan 整备后的能量预期，验证 Astra 实际扣费也是 5 点。日志为 `.godot/k_spell_cost_rules.log`、`.godot/k_spell_cost_combat.log`；`git diff --check` 通过。本次仍只修改本地，未提交或上传。

## 2026-11-18：测试版取消关卡锁

按俞的要求，测试版第一、第二、第三关全部开放。`scripts/integration/campaign_progress.gd::is_unlocked()` 改为仅判断关卡 ID 是否有效，新存档和旧存档均无需先通关即可直接选第三关；不存在的关卡仍不能进入。选关页提示改为「测试版全关卡开放」，三个关卡按钮均可点击且无锁图标。README、当前项目说明和进度文档同步更新。

开放权限不写入虚假的通关或游玩记录；实际进入第三关后才记录最近游玩目标，返回菜单可通过「继续游戏」重新进入。结算页的「下一关」同样不再依赖前关通关记录，第三关结算仍不提供不存在的第四关。角色购买、金币、关内机关和路线规则保持原有行为。

Godot 4.7.2 验证共 **456 项，0 失败**：

| 脚本 | 检查数 |
| --- | ---: |
| `tests/test_unlocked_levels.gd`（新增：新档直接选第三关及继续游戏） | 15 |
| `tests/scenes/continue_progress_tests.gd`（unit） | 16 |
| `tests/scenes/session_unlock_tests.gd`（unit） | 15 |
| `tests/dungeon/test_level03_campaign.gd` | 134 |
| `tests/scenes/victory_continuation_tests.gd` | 70 |
| `tests/integration_modules_test.gd` | 206 |

日志为 `.godot/unlocked_<脚本名>.log`。场景载入失败检查仍以 `EXPECTED_LOAD_FAILURE_BEGIN/END` 标记主动注入错误；模块测试退出仍有既有的 2 个对象清理警告。`git diff --check` 通过。本次仅修改本地，未提交或上传。

## 2026-11-18：字远第三关敌人接入潮汐地图

将现有 `addons/ziyuan_level03/` 的五种敌人、V3 模型和战斗机制接入正式第三关及独立潮汐预览，替换四个房间的基础近战占位怪。按原目录数值保留生命、伤害、移动、前摇、收招、精英弱点及奖励，不采用原型实验室的 24 生命玩家。

| 房间 | 静态敌人配置 | 单个敌人生命 / 金币 |
| --- | --- | --- |
| C 沉沙库 | 两名骨斧斥候 | 6 / 12 |
| E 浮栈战区 | 骨斧斥候、枯筋腐尸 | 6 / 12；9 / 18 |
| F 蓄能工房 | 枯筋腐尸、长剑墓卫 | 9 / 18；14 / 25 |
| G 中心闸庭 | 双链执刑官、沙缚王 | 22 / 34；90 / 120 |

`level03_preview.gd` 使用字远的工厂创建八名静态敌人并登记原清场名单，出生点避开碰撞、门洞和交互台。新增 `tide_enemy_encounter.gd`，将敌人的显式激活接口接到共享封场组件：进入房间后唤醒，其他房间继续休眠；必须清除整份名单才开门。原潮位、导体、蓄能、泄压、支线奖励及路线规则继续生效。

沙缚王通过地图的 `get_campaign_boss()` 接入共享宿主，展示真实血条和攻击状态。半血仅召唤两名骨斧斥候一次；援军在 G 房边界内出生，不加入已封存的静态门锁名单。首领死亡或本局停止时回收援军，回收不产生金币；玩家实际击败援军仍按原斥候奖励掉落。地图停止时禁用存活敌人并清理所属投射物和临时特效，重开重新建立整局归属。

敌人的奖励请求转换成实体金币，拾取后只增加本局余额，死亡、退出及通关结算遵循现有字远金币规则；唯一奖励 ID 防止重复生成。正式 `Player.gd` 补上沙咒减速接口：命中后 1.4 秒六成常规移速，暂停冻结持续时间，翻滚不缩短。俞的原生命、护盾、能量和每次 K 消耗 5 点保持生效。

共享宿主同时复核地图的完成权限；沙缚王死亡仍不能绕过存活执刑官或 I 泄压。必须 G 完整清场、泄压、门完全打开并实际进入 J 才结算。完成摘要显示沙缚王与最终守卫。README、当前项目说明和模块整合说明同步更新。

Godot 4.7.2 验证 **9 组 headless 共 822 项，0 失败**，另在实际 OpenGL 渲染下通过同一接线测试 **43 项，0 失败**：

| 脚本 | 检查数 |
| --- | ---: |
| `tests/dungeon/test_level03_enemy_integration.gd`（新增） | 43 |
| `tests/dungeon/test_level03_campaign.gd` | 138 |
| `tests/dungeon/test_level03_tide.gd` | 107 |
| `addons/ziyuan_level03/tests.gd` | 45 |
| `addons/ziyuan_level03/tools/model_tests.gd` | 32 |
| `tests/character_week9_rules_test.gd` | 90 |
| `tests/character_combat_test.gd` | 111 |
| `tests/integration_campaign_flow_test.gd` | 50 |
| `tests/integration_modules_test.gd` | 206 |

新增接线测试覆盖所有出生点的实体碰撞检查、休眠保护、真实 J/K 命中、K 扣费、逐敌清场、金币拾取及去重、暂停、Boss 血条、半血召唤、援军回收、沙咒恢复和终局清理。独立潮汐测试仍用常规移动连续跑通原路线；战役测试覆盖真实机关、出口、金币保存失败重试、四角色暂停/死亡/重开与继续游戏。测试使用隔离存档。

日志为 `.godot/ziyuan_*.log`，其中主线日志为 `.godot/ziyuan_campaign.log`，实际渲染日志为 `.godot/ziyuan_enemy_render.log`；截图 `.godot/ziyuan_level03_boss.png` 已人工查看，包含沙缚王、执刑官、半血援军、攻击预警和共享 HUD。载入失败注入仍有显式标记；部分快速 headless 退出仍有既有 2 个对象清理警告，实际渲染退出无此警告。`git diff --check` 通过。仅修改本地，未提交或上传。

## 2026-11-18：第三关改为固定视角，消除镜头升降

按俞的反馈，第三关原通用跟随镜头会随角色与敌人的分布自动缩放，HUD 反馈显隐也会重新计算取景，导致视角忽上忽下。本次新增 `scenes/dungeon/level03/level03_camera.gd`，正式战役和独立预览均切换到与第二关一致的 **44° 固定俯角**。

同一画幅下，全关统一镜头高度和距离，预先按最大房间、沙缚王体积及角色高度预留可见范围。房间内固定中心构图，通道中只做水平缓动；跨房平移最高 10 米/秒，避免从房间中心突然追到门口。门槛保留 0.7 米退出缓冲，小步往返不反复切换构图。玩家移动或高度变化、敌人移动、清场、半血召唤、Boss 血条出现与隐藏均不推动相机升降或缩放。窗口尺寸变化时重新适配。

第三关正式入口启用已有的紧凑 HUD 布局，并固定预留目标卡、首领栏及交互带，避免长反馈出现/消失改变取景。商店快捷按钮由该布局统一定位。前景墙体仍按房间地面及角色采样淡出，碰撞、机关、敌人和路线规则继续生效。第二关与第一关保持原布局配置。

Godot 4.7.2，**5 组 headless 共 777 项，0 失败**；另在实际 OpenGL 渲染下通过相机测试 **302 项，0 失败**：

| 脚本 | 检查数 |
| --- | ---: |
| `tests/dungeon/test_level03_camera.gd`（新增） | 302 |
| `tests/dungeon/test_level03_enemy_integration.gd` | 43 |
| `tests/dungeon/test_level03_campaign.gd` | 138 |
| `tests/dungeon/test_level03_tide.gd` | 107 |
| `tests/dungeon/test_level02_camera.gd` | 187 |

新增测试覆盖 1280×720、1920×1080、720×720 三种画幅、十个房间的完整地面和 4.8 米高角色轮廓、固定高度/视距、房内移动、真实首领索敌触发血条、半血召唤、清场、长提示显隐、门口往返、逐帧通道移动和暂停。主线、连续步行路线、敌人实战与第二关相机回归均通过。

日志为 `.godot/camera3_fixed.log`、`.godot/camera3_enemy.log`、`.godot/camera3_test_level03_campaign.log`、`.godot/camera3_test_level03_tide.log`、`.godot/camera3_test_level02_camera.log`、`.godot/camera3_render.log`。实际截图 `.godot/camera3_boss.png` 已查看，Boss、援军与共享 HUD 显示正常。正式流程测试中的载入失败仍为显式标记的故障注入；最终相机及渲染日志无脚本错误。`git diff --check` 通过。仅修改本地，未提交或上传。

## 2026-11-18：第三关视角进一步调低

按俞的最新反馈，将第三关固定俯角从 **44° 降低到 36°**，降低俯视程度。`level03_camera.gd` 与预览场景配置同步更新，保留全关固定高度/视距、水平缓动和门槛缓冲，第二关配置保持原值。当前项目说明同步为 36°，上一条 44° 作为调整历史保留。

实际 OpenGL 渲染回归 **302 项，0 失败**，覆盖三个画幅、十个房间、角色及首领轮廓、血条显隐、召唤、清场、提示变化、通道移动与暂停。日志 `.godot/camera3_lower_render.log`；已查看更新后的 `.godot/camera3_boss.png`，模型及 HUD 正常。`git diff --check` 通过。仅修改本地，未提交或上传。

## 2026-11-18：第三关镜头统一为第一关设计

按俞的最新要求，第三关正式入口和独立预览直接使用第一关的 **`scenes/dungeon/follow_camera.gd`**，相机参数完全对齐第一关：俯角 52°、视野 50°、最小视距 18、跟随速度 8、缩放速度 5、角色留白 0.45、近/远裁剪 0.1/120。跟随玩家及当前战斗房角色、轮廓适配和前景遮挡淡出由同一脚本实现，不再为第三关单独设计固定取景。

移除 `level03_camera.gd` 及对应 UID，撤下 44°/36° 固定俯角、最大房间统一拉远、房间中心锁定和第三关独有安全取景覆盖。正式入口的 HUD 和商城快捷按钮布局也恢复第一关配置；撤销仅为第三关固定镜头增加的 HUD 预留逻辑。第一关与第二关的镜头参数未修改。当前项目说明同步；此前两条镜头调整作为历史保留，当前以本条为准。

`tests/dungeon/test_level03_camera.gd` 更新为读取真实第一关场景作对照，核对正式第三关及预览使用相同脚本与八项参数，覆盖三种画幅的缓动跟随、当前战斗房角色取景、首领/援军轮廓和暂停。**105 项通过**；正式第三关全流程 **138 项通过**，敌人实战接线 **43 项通过**，合计 headless **286 项，0 失败**。另通过实际 OpenGL 实战渲染 **43 项，0 失败**，并查看 `.godot/camera3_first_style.png`，确认第一关风格下 Boss、援军、预警及 HUD 显示正常。

有效验证日志为 `.godot/camera3_first_style.log`、`.godot/camera3_first_test_level03_campaign.log`、`.godot/camera3_first_test_level03_enemy_integration.log` 和 `.godot/camera3_first_gameplay_render.log`。首次多场景渲染尝试未完成并产生退出清理警告，未计入通过项；最终画面复核采用已完成的实战渲染测试，退出正常，无脚本或引擎错误。`git diff --check` 通过。仅修改本地，未提交或上传。

## 2026-11-18：紧急修复导出程序第二关开局持续下坠

俞确认问题发生在导出的游戏程序。复现旧 `week10.exe` 内的第二关时，人物出生位置仍为 `(0, 0.05, 2)`，而到达平台 Z 范围为 `[-11, 1]`；出生点下方射线检测不到地板，八种角色/入口组合在两秒内持续下坠。源码场景中的人物位置已为 `(0, 0.05, -3)`，因此只运行编辑器会漏掉此问题。

`scenes/dungeon/level02/level02.gd::_ready()` 现在按 `Regions/Arrival` 的局部偏移 `(0, 0.05, 2)` 定位人物并清零速度，当前落点为 `(0, 0.05, -3)`，位于平台内部。这样开局位置直接与到达平台关联。新增 `tests/dungeon/test_level02_spawn.gd`，覆盖四名角色的菜单开局及跨场景直接开局，检查平台边界、连续两秒落地、角色身份及满生命，并输出地板射线证据。

同时查出 `.godot/exported/133200997` 中 `Level02Campaign.scn` 仍是 11 月 11 日的继承场景缓存，普通重新导出未更新它；旧缓存也保留了错误的到达药剂位置。已将整个生成缓存目录可逆备份为 `.godot/exported-before-spawnfix-20261118-141142` 后重新导出，确保人物和补给的实际资源都与源码一致。现已生成根目录 **`week10-fixed.exe`**（Windows x64 调试版，资源嵌入 EXE，无需另带 PCK），旧 `week10.exe` 保留供对照，实际试玩请使用修复版。

`Main.gd` 增加一次性的 `--week09-test` 转交入口，复用既有 `PackageEntry.tscn` 白名单自检；`tools/export/package_entry.gd` 将开局回归加入白名单。该入口用于在导出模板不接受外部 `--script` 的情况下直接验证游戏程序，常规双击仍进入正式菜单。当前项目说明同步记录出生规则、修复程序和重新生成导出缓存的方法。

Godot 4.7.2：源码开局回归 **24 项、0 失败**，源码第二关流程 **85 项、0 失败**；最终修复版 EXE 内同样通过 **24 项开局检查及 85 项流程检查，合计 109 项、0 失败**，覆盖到达药剂真实 E 拾取、主线机关、战斗清场与出口。导出程序测试使用独立存档，正常存储权限下运行；首次沙箱执行因禁止写游戏用户目录导致其他角色无法解锁，已在允许隔离存档写入后重新验证通过，未修改角色解锁规则。

最终日志：`.godot/level02_spawn_actual_exe.log`、`.godot/level02_spawn_actual_exe_campaign.log`，对应 `.err` 仅有快速 headless 退出时既有的 2 个 ObjectDB 清理警告，无脚本错误；源码日志为 `.godot/level02_spawn_fixed.log`、`.godot/level02_spawn_campaign.log`，导出日志为 `.godot/level02_spawn_export_build.log`。本次为 headless 物理与流程验证，未计作人工画面验收。该阶段仅在本地整合，未提交或上传。

## 2026-11-18 本周整合基准发布

按俞的新指示，将当前本地整合工程作为下周共同开发基准，发布到 `codex/week10-integrated-baseline`，以最新主分支 `6041cf4` 为父提交。发布内容以本地现有文件集为准，不重新合入其他组员分支。提交审查人为 HongWei Zhang（GitHub `True-my-world-eye`）；审查合并后，各组员从最新 `main` 创建下周开发分支。README、当前项目说明及 `docs/week11-plan.md` 同步该流程和完整分工。导出 EXE、PCK、压缩包和本机缓存不入源码仓库。

发布前从暂存源码树生成不含原 `.godot` 的副本，Godot 4.7.2 导入成功；人物规则 90、模块组合 206、三关流程 50、第三关正式流程 138、第三关相机 105、第二关开局 24、自由选关 15，合计 **628 项、0 失败**。日志保存在 `.godot/publish-week10/`。测试中标记的载入失败属于预期故障注入，快速退出的既有对象清理警告保留说明。该验证不代表“持续回蓝”和“每局金币无法保存”的新反馈已修复，二者仍由字远在下周复现与处理。
