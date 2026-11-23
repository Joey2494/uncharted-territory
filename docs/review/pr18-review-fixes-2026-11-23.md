# PR18 三项审查修正

针对审查提交 c0dd1ab 的三项 P2，本次保留 PR 开放，不合并。

1. 实际 `LevelObjective` 使用的 `campaign_objective_presenter._third` 增加 `i_guards`，位于回流连接与泄压之间，数量读取封存名单；活跃 I 战斗优先展示。`quest_map_data` 同步定位干涸维修井。击杀后才显示泄压，G 改为沙缚王一名，主线总计16步。真实E操作验证拒绝提前泄压，机关重置保留 I 清场记录。
2. 四角色机制窗口明确不自然回能，列出星蓝药剂20、Knight补给10、Astra首次清房5和上限；新增可见 `MechanicsText` 断言。角色代码与规则未更改。
3. `tide_camera.ARENAS` 增加 I，沿用固定整房构图、平滑过渡、墓穴脚本继承和高墙淡出。新增真实WASD走入、战斗中横移、清场后离开再进入；战斗中不调用reset_follow，检查完整轮廓、安全区、连续缩放与稳定距离。

## 验证

Godot4.7.2。固定60FPS只用于确定性界面/镜头测试。

| 测试 | 通过 / 失败 |
|---|---|
| `test_level03_camera.gd` 三种尺寸 | 94 / 0 |
| `test_level03_maintenance_camera.gd` 三尺寸连续移动 | 72 / 0 |
| `pr18_review_regression.gd` 正式第三关可见任务、真实E、地图、尺寸矩阵 | 757 / 0 |
| `campaign_quest_tests.gd` 完整二三关任务栏 | 1161 / 0 |
| `quest_map_tests.gd` 完整地图 | 1696 / 0 |
| `pr18_mechanics_tests.gd` 四角色机制窗口与切换 | 65 / 0 |
| `character_week9_rules_test.gd` 实际角色规则 | 90 / 0 |
| `test_level03_campaign.gd` 正常时间步长、独立测试存档 | 143 / 0 |

修正旧任务测试的过期双敌人/召唤假设，并按真实交互优先级先拾起更近的掉落再操作机关；不再将“拾到金币”误认为蓄能成功。遍历敌人期间可能跨帧释放，补充实例有效性检查。

`character_skill_consistency_tests` 完整角色行为链另跑未通过（角色场景异步交接/换绑及后续资源加载失败），不将其记为通过；本次65项是实际机制窗口专项，不覆盖该完整行为链。固定帧的战役扩展运行遇到二关资源加载失败，未按退出码0记为成功。镜头基础测试退出的2个ObjectDB清理警告单独保留，不等同断言失败。

## 图形证据

`pr18_review_capture.gd` 图形渲染截图使用明确主线状态夹具，真实交互由757项回归独立覆盖。截图脚本断言地图目标正确，并检测空图像/保存失败；机制页单独进程渲染，避免连续切换场景导致渲染内存不足。

- [I房战斗1280×720](pr18-evidence/maintenance-battle-1280x720.png)
- [I房战斗1920×1080](pr18-evidence/maintenance-battle-1920x1080.png)
- [I房战斗720×720](pr18-evidence/maintenance-battle-720x720.png)
- [清场前任务与地图](pr18-evidence/maintenance-combat-map.png)
- [清场后泄压任务](pr18-evidence/maintenance-release-journal.png)
- [清场后泄压地图目标](pr18-evidence/maintenance-release-map.png)
- [角色机制页](pr18-evidence/mechanics-no-passive-energy.png)

截图已逐张查看；未重新导出Windows包、未声称人工难度验收。
