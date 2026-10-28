# 暗黑地牢奇幻 UI 风格说明

> 本文按团队仓库内路径编写。独立验证用于检查组件行为，真实主工程联调仍需组长及各模块协作完成。

更新日期：2026-10-28；适用：当前紧凑 HUD 与原开始/死亡/胜利界面。参考为用户提供的 [地牢例图归档](references/dungeon_reference.png)，来源与字节校验见 [references/README.md](references/README.md)。

## 视觉方向与现行布局

HUD 使用固定左上角的三个独立组件，透明定位组为 336×108：心形与细长暗红血条、房间图标/编号/分段、64×64 武器方框。HUD 不再用整块大矩形底板；房间卡保留程序化石面，心形框和武器框使用暗金属边。

开始、死亡、胜利界面仍使用居中的石面大卡片、角饰、暖灰衬线文字与暗金按钮。紧凑 HUD 改版没有改变三个菜单的操作或接口。世界/屏幕/结算层次见 [screen_layout.md](screen_layout.md)。

| 信息 | 颜色与规则 |
| --- | --- |
| 常规 / 低 HP 血条 | #7b2428 / #a53632；低 HP 为大于 0 且不超过 40% |
| 无武器 | 图标 #5f6055、文字 #9a968b，暗框无亮边 |
| 已装备 | 图标/文字 #b99a5c、边框 #806b40，轻微暗金亮边 |
| 当前 / 已到达房间 | 分段 #b99a5c / #756442，未来空段背景 #20221c |
| 主文字 | 暖灰/象牙色，约 #ddd1b6 |
| 结果界面 | 死亡偏铜红，胜利偏暗金；按钮焦点清晰 |
| 敌人头顶 HP | 暖灰旧金；低 HP 暖铜色，保留数字与深描边 |

不只依赖颜色：保留 HP 数字、状态提示、房间编号与“无武器/已装备”。隐藏的 WeaponHint 保留字段更新，紧凑 HUD 不显示该长句。分段表示到达房间，不代表已经清完房间。

## 资源与字体

| 资源 | 实际用途 |
| --- | --- |
| [hud.tscn](../scenes/ui/hud.tscn) | 自身 Theme 和各组件 StyleBox，形状为简洁矩形 |
| [dungeon_font.tres](../scenes/ui/dungeon_font.tres) | SystemFont 优先 SimSun，衬线候选与系统回退；FontVariation 字重增加 0.4 |
| [menu_theme.tres](../scenes/ui/menu_theme.tres) | 三个正式菜单；HUD 自身 Theme 共享字体选择，不直接套用该菜单 Theme |
| [stone_material.tres](../scenes/ui/stone_material.tres) / [stone_surface.gdshader](../assets/shaders/stone_surface.gdshader) | 房间卡和菜单的程序化石面 |
| [dungeon_frame.tscn](../scenes/ui/dungeon_frame.tscn) / [stone_corner.svg](../assets/ui/stone_corner.svg) | 菜单角饰；现行 HUD 没有外层大角饰框 |
| [heart.svg](../assets/ui/heart.svg) | 心形标识 |
| [weapon_empty.svg](../assets/ui/weapon_empty.svg) / [weapon_equipped.svg](../assets/ui/weapon_equipped.svg) | 灰方框与暗金剑形 |
| [room.svg](../assets/ui/room.svg) | 房间入口图标，HUD 改版新增 |
| [hit_flash_3d.gdshader](../assets/shaders/hit_flash_3d.gdshader) | 模型受击的短暂红色，与 HUD 血条分开 |

当前 HUD 主 HP 数字字号 14、状态辅助字号 11、房间字号 16、武器文字 12；均为设计单位。三个菜单沿用原有较大标题/按钮字号。SystemFont 依赖运行设备的可用字体；当前设备已验证，跨系统/正式分发时仍需团队决定统一字体资源，不能将系统字体当成随包字体。

设计基准保持 1280×720，canvas_items + expand + fractional；窗口启动模式由团队项目决定。24 为设计单位边距。静态装饰和 HUD 忽略输入，菜单结果层阻挡背景点击。

## 历史验证

既有最终验收：HUD **213/605**、菜单 **88/193**、3D **64/101** 全通过，首击和时序回归通过。AI 执行自动验证并复核截图；仓库不提交测试截图，不表示本人人工验收或新的团队验收。详见 [test_evidence.md](test_evidence.md)。用户提供的例图作为需求材料保留，不作为游戏运行背景。

## 仓库组织与接入

- scenes/ui：HUD、三个菜单、敌人 Label3D、受击反馈脚本、主题/字体/材质和角饰场景。
- assets/ui：五个 SVG 图标及各自 .svg.import；assets/shaders：石面与受击闪红着色器及 .uid。
- docs：布局、流程、视觉反馈、风格、职责、AI 使用和测试摘要；docs/references 保留原始任务及视觉参考，通过 .gdignore 排除 Godot 资源扫描。

保留全部脚本/Shader UID 和 SVG 导入配置。SVG 配置里的 .godot/imported 路径由目标编辑器重新生成，缓存不提交。主工程配置与实际入口由组长管理，本次不在团队仓库创建 project.godot 或 main 场景。

SystemFont 未附字体二进制；其他设备须检查中文回退和视觉一致性。原始测试宿主、占位角色、截图、日志和缓存不放在团队仓库；当前独立复测摘要见 [test_evidence.md](test_evidence.md)。
