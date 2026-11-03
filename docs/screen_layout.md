# 未至之境：画面组织与 HUD 接入

> 本文按团队仓库内路径编写。独立验证用于检查组件行为，真实主工程联调仍需组长及各模块协作完成。

负责人：汤志豪；更新日期：2026-10-28；引擎：Godot 4.7.2。现行版本为紧凑 HUD；本次只调整文件组织、资源引用和说明，公开接口与视觉布局保持不变。

范围依据见 [归档任务材料](references/README.md)，职责状态见 [task_audit.md](task_audit.md)，测试批次见 [test_evidence.md](test_evidence.md)。风格见 [dungeon_style.md](dungeon_style.md)。

## 现行左上角布局

1280×720 为设计基准。HUD 内容组固定在 (24,24)，大小 336×108 个设计单位；`Panel` 现在是透明 Control，只用于定位，没有包住整个 HUD 的大矩形背景。

```text
左上角 (24,24)
[心形框] 生命 / 状态提示                 5/5 HP
         [──────────细长暗红血条──────────]
[房间图标  房间 X/3                 ] [武器图标]
[          ▰▰▰  ▰▰▰  ▱▱▱          ] [无武器/已装备]
```

- 血量组高 36：独立 36×36 心形框、文字读数和约 290×12 的长方形血条。
- 下排距上排 8：房间卡 264×64，武器框 64×64，中间间隔 8。
- 房间卡显示入口图标、房间编号和分段长方形进度条；当前房间暗金高亮，已到达房间较暗，未来房间为空段。
- 武器框用灰暗方框表达无武器，用暗金剑形、边框和轻微亮边表达已装备，保留状态文字。
- HUD 外部区域透明，静态显示 Control 全部忽略鼠标事件。旧 `WeaponHint` 字段仍保留并更新，但当前紧凑布局中隐藏；可见的“无武器/已装备”仍保留。
- HP、武器框和房间分段的变化样式按实例隔离，避免一个 HUD 改色影响另一个。

## 实际 HUD 节点

场景：[hud.tscn](../scenes/ui/hud.tscn)；脚本：[hud.gd](../scenes/ui/hud.gd)。

```text
HUD (Control，Full Rect；外部提供 CanvasLayer)
├── Panel (Control，透明定位组，336×108)
│   ├── HealthGroup (HBoxContainer)
│   │   ├── HeartFrame → Padding → HeartIcon
│   │   └── Vitals
│   │       ├── Readout → Caption / HPStateLabel / HPText
│   │       └── HPBar (ProgressBar，细长矩形)
│   ├── LowerRow (HBoxContainer)
│   │   ├── RoomBadge (独立石面卡)
│   │   │   ├── StoneSurface
│   │   │   └── Padding → Row
│   │   │       ├── RoomIcon
│   │   │       └── Details → RoomLabel / RoomSegments
│   │   │                    └── 每房一个 ProgressBar
│   │   └── WeaponBadge (独立方框)
│   │       └── Padding → Content → WeaponIcon / WeaponLabel
│   └── WeaponHint (隐藏的兼容字段)
└── ResultLayer (CanvasLayer，layer=20；首次结算时动态创建)
    └── DeathScreen 或 WinScreen（一次仅一个）
```

## 世界、HUD 与结算层的接入结构

调用 HUD.show_death_screen() 或 HUD.show_win_screen() 时，首次需要的 ResultLayer（CanvasLayer，layer=20）由 HUD 创建，并作为 HUD 的子节点。后续复用该层，一次只展示一个结算界面；旧界面先隐藏再 queue_free。宿主不在 Main 下另建一套 ResultLayer，也不向当前 HUD 注入额外结果层。

```text
Main（团队真实游戏宿主，待接入）
├── DungeonContainer（房间、门、墙与地板）
├── Player（Visuals / HitFlash / 跟随 Camera3D）
├── Enemy 实例（Visuals / HitFlash / HealthLabel: Label3D）
├── Pickup 实例
└── HUDLayer (CanvasLayer，layer=10，关闭跟随视口)
    └── HUD
        ├── Panel（透明定位组及三个独立组件）
        └── ResultLayer (CanvasLayer，layer=20，HUD 动态创建)
            └── DeathScreen 或 WinScreen
```

ResultLayer 的生命周期跟随 HUD，释放旧 HUD 会一并释放结果层。暂停/恢复、实际世界重建和新一局初始化由宿主负责；HUD 不自行决定通关、暂停或游戏目标场景。详细流程见 [screen_flow.md](screen_flow.md)。

3D 世界由 Camera3D 渲染；HealthLabel 是每个敌人的世界子节点，面向相机并保留深度测试，不能放到屏幕 CanvasLayer。受击 overlay 仅覆盖各角色选定的 Mesh 子树，见 [feedback_3d.md](feedback_3d.md)。

## 数据来源与公开接口

| 信息 | 独立验证来源（不随仓库提交） | 团队接线点 |
| --- | --- | --- |
| HPBar / HPText / HPStateLabel | TestUI.hp_changed、FlowRun 或反馈占位角色 | 真实 Player.hp_changed，首次 HP 主动初始化 |
| RoomLabel / RoomSegments | 调用 update_room_label(index) | 门事件/主流程传入 0 基房间索引 |
| WeaponIcon / WeaponLabel / 武器框 | 调用 update_weapon_status(bool) | item_picked("weapon") 后由主流程同步装备与 HUD |
| 角色闪红 | 占位角色成功扣血后的通知 | 真实成功伤害事件或主动调用 HitFlash.flash |
| 敌人头顶 HP | 显式初始值 + hp_changed | 字远确认真实 Enemy 的初始化和变更契约 |

HUD 的原五个团队方法与重开信号保持不变：

```gdscript
func update_hp_bar(current: int, maximum: int) -> void
func update_room_label(index: int) -> void
func update_weapon_status(has_weapon: bool) -> void
func show_death_screen(room_index: int) -> void
func show_win_screen() -> void
signal restart_requested
```

`get_result_screen() -> Control` 是现有查询辅助方法，未结算时返回 null。HUD ready 后再调用更新方法：

```gdscript
player.hp_changed.connect(hud.update_hp_bar)
hud.update_hp_bar(initial_hp, initial_max_hp)
hud.update_room_label(current_room_index)
hud.update_weapon_status(initial_has_weapon)
```

上述初始值由实际宿主提供，不假定队友的私有变量或快照方法名。

- 房间索引从 0 开始：0 → 房间 1/3，2 → 房间 3/3。分段表示“已到达当前房间”的进度，不是清敌完成数，也不触发胜利。
- total_rooms 默认 3；分段数量随配置变化。已有测试覆盖 5/99 房配置；无效总数/索引显示占位并清空进度。
- HP 限制在 0..maximum；maximum <= 0 时显示 HP --/--。生命为 0 或低于等于 40% 时保留对应文字提示。
- HUD 只展示数据，不承担扣血、回血、装备、传送或通关判定。Enemy HP/成功受伤事件的新增契约仍需团队确认。

## 缩放与输入

当前团队检出尚无 project.godot。组长提供主工程后，在项目设置中使用以下设计基准和缩放项；本模块不覆盖项目设置：

```ini
window/size/viewport_width=1280
window/size/viewport_height=720
window/size/resizable=true
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/stretch/scale=1.0
window/stretch/scale_mode="fractional"
```

原沙盒最小窗口验证基准为 960×540；团队可按目标设备设置最小窗口及初始窗口模式。内容等比缩放，expand 扩展可用区域；24 是设计单位边距，物理像素边距随 UI 缩放。静态 HUD 忽略鼠标，结果界面阻挡背景点击；仍由宿主停止真实玩法输入。

## 验证范围与团队接入步骤

既有最终验收中，紧凑 HUD **213 项逻辑 / 605 项图形检查，均 0 失败**。覆盖模拟受伤/回血/换房/武器/重置/自动演示、边界与实例隔离，以及多种窗口尺寸。测试控制台和自动演示属于被排除的测试宿主，不是 HUD 的正式功能接口。历史结果与本次目录整理复测记录见 [test_evidence.md](test_evidence.md)。

接收方须在自己的可运行主工程中执行：

1. 在组长提供的项目中等待 Godot 完成 SVG 导入，将 scenes/ui/hud.tscn 挂到 layer=10 的屏幕 CanvasLayer。
2. HUD ready 后连接真实 Player.hp_changed，主动传入初始 HP、房间索引、武器状态。
3. 真实受伤、血药、拾武器、进门时核对数值与界面；分段只代表到达进度。
4. 用实际 WASD 玩家及跟随相机、多种窗口尺寸核对 HUD 固定左上角、文本清晰无裁切。
5. 验证真实死亡/通关、重开世界和结果层；停止背景玩法输入由宿主负责。

这些是接收后的待执行步骤。未提供真实主场景路径，不以原沙盒相机平移替代 U5 的完整验收。
