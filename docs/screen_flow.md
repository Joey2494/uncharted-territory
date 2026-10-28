# 开始、死亡与胜利界面：独立验证与接入

> 本文按团队仓库内路径编写。独立验证用于检查组件行为，真实主工程联调仍需组长及各模块协作完成。

负责人：汤志豪；更新日期：2026-10-28；引擎：Godot 4.7.2。当前说明按紧凑 HUD 版本核对；三个菜单本身未因 HUD 改版修改功能。

三个界面保留暗色石面、旧金属角饰、暖灰衬线文字与暗金按钮，见 [dungeon_style.md](dungeon_style.md)。[screen_layout.md](screen_layout.md) 使用相同的结算层创建规则。

## 已实现的界面行为

| 任务 | 组件与接口 | 组件行为 |
| --- | --- | --- |
| U6 | StartScreen / start_requested | 显示“未至之境”、开始按钮；请求宿主启动已配置场景 |
| U7 | DeathScreen / set_room_index(index) / restart_requested | 显示 Game Over、到达房间数和重开按钮 |
| U8 | WinScreen / restart_requested | 显示 You Win、清房摘要和重开按钮 |
| 结算接入 | HUD.show_death_screen(index)、show_win_screen()、restart_requested | HUD 显示结果并转发重开，实际重建由宿主负责 |

按钮支持鼠标和 ui_accept，显示后自动获得焦点。菜单根节点 PROCESS_MODE_ALWAYS，使暂停 SceneTree 时仍可操作结果按钮。菜单不会自行暂停游戏，也不自行选择团队入口路径。

## ResultLayer 的唯一创建方式

调用 HUD.show_death_screen() 或 HUD.show_win_screen() 时，首次需要的 ResultLayer（CanvasLayer，layer=20）由 HUD 创建，并作为 HUD 的子节点。后续复用该层，一次只展示一个结算界面；旧界面先隐藏再 queue_free。宿主不在 Main 下另建一套 ResultLayer，也不向当前 HUD 注入额外结果层。

创建代码位于 [hud.gd](../scenes/ui/hud.gd) 的 `_show_result_screen()`。宿主调用原方法即可：

```gdscript
hud.show_death_screen(current_room_index)
# 或在真实清完所有房间时：
hud.show_win_screen()
# 在宿主初始化时连接一次：
hud.restart_requested.connect(_on_restart_requested)
```

首次结算前 `get_result_screen()` 返回 null；结算后可查询当前界面。释放旧一局的 HUD 时，其 ResultLayer 一并释放。切换 Death/Win 时复用结果层并替换界面，不积累多套可见结果。

## 正式宿主与层次

```text
Main（团队真实游戏宿主，名称仅示意）
├── World（真实玩家、敌人、房间）
├── HUDLayer (CanvasLayer，layer=10)
│   └── HUD
│       ├── Panel（透明定位组，紧凑 HUD）
│       └── ResultLayer (CanvasLayer，layer=20，HUD 动态创建)
│           └── DeathScreen 或 WinScreen
└── StartLayer (CanvasLayer，宿主自行管理)
    └── StartScreen（开始后隐藏或释放）
```

每个菜单内部：Full Rect Control → Backdrop + Center → Card → 石面/角饰/Padding/Content → 标题、摘要和按钮。Card 宽 520；开始背景不透明，结算遮罩保留后方世界/HUD 的可见轮廓。静态装饰忽略鼠标，菜单根节点阻挡背景点击；真实玩法输入必须由宿主另外停止。

“探索到房间 2”表示进入第二房，即便只清完第一房；死亡摘要不使用清房数冒充到达深度。

## 注入入口与重开责任

StartScreen 自身只发出 start_requested。宿主可通过自有的导出 PackedScene 注入真实入口；未配置时应保持开始界面并给出提示。新一局重建和同帧重复重开请求保护属于宿主责任，正式界面脚本不实现世界替换。

三个可复用界面及 HUD 不引用任何测试场景，也不硬编码假定团队主场景路径。团队宿主按实际工程选择 PackedScene：

```gdscript
@export var gameplay_scene: PackedScene

func _on_start_requested() -> void:
    if gameplay_scene != null:
        get_tree().change_scene_to_packed(gameplay_scene)

func _on_restart_requested() -> void:
    get_tree().paused = false
    # 由真实主流程重载/新建游戏，清理旧世界并初始化状态。
```

这个重开示意不包含团队玩法实现；真实地牢、敌人、装备、旧信号、随机生成和暂停恢复必须由宿主管理。

## 接口与参数

```gdscript
# StartScreen
signal start_requested

# DeathScreen / WinScreen
signal restart_requested

# DeathScreen，可在进入场景树前设置
func set_room_index(room_index: int) -> void

# HUD，ready 后调用
func show_death_screen(room_index: int) -> void
func show_win_screen() -> void
signal restart_requested
```

room_index 为 0 基索引，负数/越界显示“探索到房间 --”。DeathScreen.total_rooms 与 WinScreen.completed_rooms 在创建时由 HUD.total_rooms 传入。真实 Player.player_died 无参数，宿主须从主流程取得当前索引。HUD 不从测试事件获取数据，也不根据房间分段自行判断胜利。

## 历史验证与移交

既有最终验收：界面流程 **88 项逻辑 / 193 项图形检查全部通过**，包括鼠标/键盘、暂停下按钮、重复请求、死亡深度和模拟重开清理。重建保护是在原测试宿主中验证，接收方必须自行实现并重测真实主流程；详见 [test_evidence.md](test_evidence.md)。

组件保持原接口；场景与脚本在 scenes/ui，图标在 assets/ui，着色器在 assets/shaders，见 [风格依赖](dungeon_style.md)。开始/死亡/胜利的场景选择、暂停恢复、真实清敌通知、旧世界/旧信号清理和随机地牢重建见 [task_audit.md](task_audit.md)。当前团队检出尚无 project.godot 和真实主场景，不能直接 F5；由组长补齐骨架并选择实际入口。
