# 第三关模型 V3：绷带巨像与枯筋腐尸

本次按你新提供的两张图修改两个敌人。沙缚王采用图一的宽肩、巨臂巨拳、紫黑残躯、米色宽绷带、几何织纹、封闭面罩与蓝色眼缝；原骨刺猎手替换为图二方向的枯筋腐尸，采用细长身体、灰褐残皮、扭结筋腱、凹眼和曲指，取消外伸骨刺与头角。

模型为 Godot 原生、程序几何生成的风格化实时模型。网格、材质和分件全部保存于 tscn，可在编辑器里直接查看；动作使用分件姿态接口，后续可替换为标准骨骼绑定。

## 在 Godot 中查看

用 Godot 4.7.2 导入独立工程的 project.godot，按 F5 默认进入新首领展示。
鼠标拖动旋转、滚轮缩放，左上角可切换五种怪物；“姿态动作”可查看已有动作。

独立场景以 addons/ziyuan_level03 为相对根目录：

| 怪物 | 模型场景：编辑网格、材质和分件 | 预览场景：带灯光与镜头，按 F6 运行 |
| --- | --- | --- |
| 绷带巨像／沙缚王 | models/BandagedTitanModel.tscn | previews/BandagedTitanPreview.tscn |
| 枯筋腐尸 | models/RevenantModel.tscn | previews/RevenantPreview.tscn |

这两个易读名称是继承原模型的独立入口。基础数据仍保存于 SandKingModel.tscn、BoneSpikeModel.tscn，以保留上一版合并路径和稳定 ID。
其余三种敌人保留：BoneAxeModel.tscn、TombSwordModel.tscn、ChainJailerModel.tscn。

模型场景不带游戏玩家或战斗脚本；需要单独运行查看，请运行 Preview 场景。
模型分件仍提供 Body、Head、Jaw、ArmR/Hand、ArmL/Hand、LegR、LegL，可调整姿态或实例化到其他场景。

## 战斗与合并

枯筋腐尸替代原远程怪，显示名称与提示已更新。其攻击外观改为褐色腐质团，保留三路投射物、墙体阻挡、伤害 2 和攻击节奏；不再显示骨刺弹。底层 bone_spike ID、BoneSpike.tscn 和 bone_projectile.gd 文件名仅为兼容上一版模块而保留。

首领沙缚王保留原三式技能与 6/8 伤害，模型已接回战斗场景。小组合并包覆盖 addons/ziyuan_level03；无需覆盖 Main.gd、Player.gd 或 Autoload。完整源码从 addons/ziyuan_level03/Prototype.tscn 运行试炼。

tools/build_models.gd 为离线生成器，与第二关同样采用 SurfaceTool / 分件几何 / PackedScene 保存流程。重新执行会重建基础模型；手工修改时建议另存变体或编辑继承入口场景。

## 验证和截图

独立模型工程 32 项检查通过；战斗回归 45 项检查通过。检查包括新腐尸无外伸骨刺、首领蓝眼与封闭绷带面罩、独立场景加载、预览构图、旧伤害和生命周期。
预览截图来自实际 Godot 渲染。独立工程的“预览截图”和完整模块的 evidence/models 供对照；“参考图”保存用户此次提供的两张图。
旧版设计 DOCX、旧 evidence 图鉴与 1.0/2.0 ZIP 是历史版本，本次新模型以 V3 和此说明为准。
