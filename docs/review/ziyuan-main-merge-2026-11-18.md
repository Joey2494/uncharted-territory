# PR #13 合入最新 main 的整改记录

日期：2026-11-18。原 PR 头：`e0f0f6fd126a5c53fc60b510d7173811b038c522`；合入 main：`d7e2934e8fd4b4fa5922b5abdd030a8992aa7d0e`（PR #14 合并后）。共同基线：`1fda27147bbe1d2a9fb51431f1b4761b79ec1613`。

## 冲突解决

执行真实三方合并，仅 `scenes/ui/win_screen.gd` 发生内容冲突。按字段合并双方修改：

- 保留本 PR 的本局金币独立、成功一次入账、保存失败回滚及胜利页重试接线；`Main.gd` 中的金币状态与 main 的第三关完成快照同时保留。
- 保留 main 的 `completion_summary`、`puzzle_name`、`reward_name`，以及机关解开、奖励领取的实际状态。
- `RewardLabel` 显示关卡奖励，独立的 `SettlementLabel` 显示金币入账或保存失败信息，两者同时存在。原空白 Description 标签改为 SettlementLabel。
- 保留 `_queue_layout()` 刷新和保存失败时的重试按钮；详情与补给上移，为金币状态留出独立一行。按钮宽度按实际文字最小宽度分配，避免方形窗口内的长重试按钮挤压相邻按钮。自动换行标签最小尺寸变化时重新排版。
- 流程测试等待真实 `scene_changed` 后再读取新场景，避免高负载时固定等待物理帧仍读到空场景；原 17 项检查保留。

没有通过整段选取任一侧来覆盖冲突。main 新增的正式第三关、菜单与跨关接线均已合入。

## 合并后实际验证

引擎：Godot `4.7.2.stable.official.ed1daf0bf`，Windows。以下结果均在合并并完成冲突解决后的最终代码上取得，所有进程退出码均为 0。

| 入口 | 检查数 | 失败数 |
| --- | ---: | ---: |
| `tests/scenes/level02_revision_flow.gd` | 17 | 0 |
| `tests/scenes/objective_hud_tests.gd` | 117 | 0 |
| `tests/scenes/level02_revision_tests.gd` | 45 | 0 |
| `tests/dungeon/test_level03_campaign.gd` | 134 | 0 |
| `tests/scenes/victory_continuation_tests.gd` | 67 | 0 |
| `tests/scenes/settlement_layout_tests.gd`（headless） | 8 | 0 |
| `tests/scenes/settlement_layout_tests.gd -- --capture`（OpenGL 实际渲染） | 16 | 0 |

六组 headless 合计 388 项通过；渲染另检查 8 种组合的布局与截图保存，共 16 项。仅声明以上执行范围，不将前次快照或审查方的 456 项结果算入本次运行。

正式第三关测试增加真实流程断言：收集 37 本局金币；实际走入出口时注入钱包保存失败；检查永久余额及结算去重标记回滚、本局金币保留；恢复可写存档并点击胜利页重试按钮；验证仅入账 37、清空本局金币、更新成功文案、隐藏重试按钮；重复按钮及出口回调不重复入账。失败和成功两种状态均检查第三关摘要、潮汐机关与溢流花园奖励，以及 1280×720、720×720 下的可见性、边界、文字宽度和控件不重叠。

第三关正式流程与胜利衔接测试保留了 `EXPECTED_LOAD_FAILURE_BEGIN/END` 包围的场景载入故障注入，因此相应日志中包含预期的错误输出。这些故障均验证重试恢复，最终断言零失败，未出现 `SCRIPT ERROR` 或 `Parse Error`。导入阶段退出 0，另有本机编辑器配置 Safe save 提示；它不作为无错误导入的证明。

原始日志在 [ziyuan-main-merge/](ziyuan-main-merge/)。渲染截图用于结算 UI 组合验证，使用展示数据；实际金币保存、回滚、重试与第三关通关由上述正式第三关测试验证。

## 复跑

在仓库根目录，将 `godot` 替换为本机控制台程序路径：

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/scenes/level02_revision_flow.gd
godot --headless --path . --script res://tests/scenes/objective_hud_tests.gd
godot --headless --path . --script res://tests/scenes/level02_revision_tests.gd
godot --headless --path . --script res://tests/dungeon/test_level03_campaign.gd
godot --headless --path . --script res://tests/scenes/victory_continuation_tests.gd
godot --headless --path . --script res://tests/scenes/settlement_layout_tests.gd
godot --path . --rendering-method gl_compatibility --script res://tests/scenes/settlement_layout_tests.gd -- --capture
```

最后一条命令将截图存至 `user://settlement-layout`，也可加 `--output=绝对输出目录` 指定位置。整改完成后更新原 PR #13，最终验收由组长复审。
