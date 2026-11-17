# 第二关 · 天然蜘蛛洞窟

第二关使用独立的天然岩石可视结构，与第一关石砖地牢区分。八个功能房间和连接通道由 `level02/stone_region.gd` 接入 `cavern_geometry.gd`：替换原有砖墙、方形地砖及建筑陈设，保留蛛网、蛛丝、蛛茧、卵簇和漏斗巢。第一关的生成器与资产不变。

洞壁采用不规则分层断面、错位棱面、侵蚀凹槽与细裂缝，顶部轮廓起伏并悬挂成簇钟乳石。外围岩台、石笋和向下约 3.8 米的断层形成高低落差；后侧房间岩壁最高约 5 米，通道约 4 米。镜头前方的南侧墙顶不超过 2.85 米，保留俯视剖面，中央不放实体屋顶。地面使用连续世界坐标的泥褐色沉积岩材质，岩壁为冷灰色石灰岩，具有细颗粒法线与低反光粗糙表面。两座原有战斗掩体换成断裂岩块。

可通行地面仍使用原有稳定碰撞平面。视觉地面的浅凹始终位于该平面之下，并严格结束在区域边界；路线标记保留原高度。大幅度高差和石笋集中在不可通行的墙外岩台，钟乳石尖端保持在角色头顶之上；不向中央战斗区、机关入口或开放门洞放置岩柱。岩体与蛛丝均挂在原有墙体遮挡节点下，复用相机淡出与恢复，不修改共享材质。

地图布局、墙体与地板碰撞、门洞、敌人出生点、导能机关、支线谜题和实体出口不变。新岩体只有静态 Node3D 和单表面 MeshInstance3D，不带额外碰撞、导航、AI 或逐帧逻辑。固定区域种子保证编辑器重建与重开后形态一致，不影响战斗随机数。当前岩体与地面为 164 个批次、86,064 个三角形，另有两座岩石掩体；蛛丝保留117 个批次。

回归入口：

```text
godot --headless --path . --script res://tests/dungeon/test_cavern_environment.gd
godot --headless --path . --script res://tests/dungeon/test_spider_habitat.gd
godot --headless --path . --script res://tests/dungeon/test_level02_layout.gd
godot --headless --path . --script res://tests/dungeon/test_level02_navigation.gd
godot --headless --path . --script res://tests/dungeon/test_energy_relay.gd
godot --headless --path . --script res://tests/audio/test_background_music.gd
```

洞窟专项验证所有区域与原生成器的完整碰撞签名、战斗与通道余量、地面接缝、前景高度、相机真实射线淡出、几何有效性与预算、重建一致性及第一关隔离。其余回归覆盖玩家双向过门、守卫绕掩体、机关及两关真实出口流程。图形取证使用实际 `Level02Run.tscn`，覆盖入口、中庭、导能区、通道、Boss 洞厅、档案支线和奖励区；使用独立 APPDATA，不写玩家存档。
