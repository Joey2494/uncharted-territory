# 第三关修复与第四关敌人原型 PR 验证

基线：GitHub main `b1ee670`，隔离分支 `codex/level03-fixes-level04-enemies`。保留主分支新镜头、墓穴美术、加载界面、任务UI和日晷观测站正式战役。原工作区未重置、未覆盖。

## 交付

- 第三关五个单一兵种战斗房、维修井清场后泄压、真实战役启动脚本、减轻初始生命/伤害基线与模型修正。
- 第三关五类敌人取消攻击前蓄力/范围提示、加强追击和连攻、远程走位、飞行沙咒替代脚下咒印；实际攻击伤害仍受翻滚/护盾/墙体规则约束。
- 取消持续回能；保留药剂与角色机制恢复。结算保存失败阻止离开、钱包临时文件替换与备份恢复、失败回滚和幂等入账。
- 第四关袍冠女巫（含压低兜帽）、曦影/赤阳傀儡/白芒尖蓟/群鸦，均含独立模型和试炼场景、无攻击预警、队员接入契约与实机截图。
- 观测站旧敌人继承行为隔离成compat脚本，避免第三关强化意外改动组员正式第四关机关战。新敌人尚未接入正式观测站地图。

## 合并后复测

Godot 4.7.2，Compatibility。存档测试使用独立路径，未使用正式档案。

| 检查 | 结果 |
|---|---|
| 第三关敌人 `addons/ziyuan_level03/tests.gd` | 70通过 / 0失败 |
| 女巫 `addons/ziyuan_level04/tests.gd` | 91通过 / 0失败 |
| 前四房 `addons/ziyuan_level04/room_tests.gd` | 62通过 / 0失败 |
| 资源与钱包 `tests/scenes/energy_wallet_regression.gd` | 40通过 / 0失败 |
| 钱包新进程回读 `-- --readback` | 2通过 / 0失败 |
| 正式第三关敌人接入 | 46通过 / 0失败 |
| 正式第三关战役 | 143通过 / 0失败 |
| 正式第四关观测站战斗 | 66通过 / 0失败 |
| 正式第四关观测站战役 | 41通过 / 0失败 |

第三关战役的`EXPECTED_LOAD_FAILURE`段故意注入无效场景，钱包测试故意使用截断文件与不可写路径；这些错误属于故障恢复检查。观测站原有测试退出仍提示2/15个ObjectDB实例泄漏，断言全部通过，本PR未扩展修复该历史清理问题。

## 复核入口

- 正式第三关：`scenes/dungeon/Level03Run.tscn`。
- 第三关敌人实验室：`addons/ziyuan_level03/Prototype.tscn`，1–5切换。
- 第四关女巫：`addons/ziyuan_level04/Prototype.tscn`。
- 第四关前四房：`addons/ziyuan_level04/FourRooms.tscn`，1–4选房、N清房后继续。
- 第四关模型：`addons/ziyuan_level04/previews/*Preview.tscn`。

数值为原型初值，测试不替代人工试玩平衡。PR不含`.godot`缓存、全项目导入记录、旧失败日志或系统编辑器设置。
