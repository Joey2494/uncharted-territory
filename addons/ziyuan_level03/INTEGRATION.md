# 第三关敌人模块整合说明

2026-11-23：直接攻击版本见 [DIRECT_COMBAT.md](DIRECT_COMBAT.md)。五类敌人取消所有攻击前提示/范围网格，`attack_telegraphed`仅保留兼容声明且不再发射；UI/音效请监听新增`attack_started(enemy_id,mode)`。沙王沙印改为可阻挡的飞行沙咒，半血只加速不召唤；旧说明中的预警和半血召唤条目已失效。

版本 1.0 · 2026-11-17 · 提交人 字远

2026-11-18 主工程整合：正式第三关及独立潮汐预览已通过 `scenes/dungeon/level03/level03_preview.gd` 使用本模块工厂；C/E/F/G 各两名敌人，G 为双链执刑官和沙缚王。`tide_enemy_encounter.gd` 接入原战斗房唤醒/停止，宿主读取 `get_campaign_boss()` 绑定血条；沙王半血援军由地图创建、死亡或终局回收，不加入静态门锁名单。奖励请求转为实体金币掉落，正式玩家实现沙咒减速接口，地图的泄压及出口条件继续生效。下文保留模块交付时的接口说明；模型以 `MODEL_UPDATE.md` 的 V3 为准。

本模块是四类敌人及一个 Boss 的可运行原型。地图、机关与主线解锁继续由小组对应成员负责；不覆盖第一二关，也不改共享 Player.gd、Main.gd、project.godot 或永久钱包。

## 文件与依赖

将整个 addons/ziyuan_level03 复制到 Godot 项目的同一路径。
正式敌人入口：BoneAxe.tscn、BoneSpike.tscn、TombSword.tscn、ChainJailer.tscn、SandKing.tscn。
工厂 factory.gd 用稳定 ID 创建实例，catalog.gd 保存名称、HP、基础伤害、移速、攻击前摇和恢复时间。
Prototype.tscn、prototype.gd、prototype_player.gd、capture.gd、tests.gd 是实验室和验证用文件；正式地图无需运行实验室。

本模块沿用现有项目以下资源：
- res://scenes/player/Player.tscn 及其现有依赖，仅供实验室使用；正式敌人只需要传入兼容目标。
- res://scenes/ui/enemy_health_label_3d.tscn
- res://scenes/ui/hit_flash_3d.gd 及 assets/shaders/hit_flash_3d.gdshader
- res://scenes/ui/BossHealthBar.tscn 与其主题、材质依赖（实验室 UI）
- res://scenes/ui/dungeon_font.tres（实验室 UI）

不需要 Autoload、外部插件或网络。Godot 4.7.2，GL Compatibility。

## 场景生成示例

```gdscript
const Factory = preload("res://addons/ziyuan_level03/factory.gd")
var enemy = Factory.create("tomb_sword", player)
enemy.reward_source_id = run_uuid + ":room3:sword1"
room.add_child(enemy)
enemy.global_position = spawn_point.global_position
# 必须先加入树，等待 ready 完成，再登记清场和奖励。
room_progress.register_enemy(room_id, enemy)
enemy.reward_requested.connect(func(source_id, coins):
    inventory.grant_reward(source_id, {}, coins))
# 清敌名单封存、玩家进入后再激活。
enemy.set_encounter_active(true)
```

默认 start_active=false。NodePath target_path 默认为 ../Player，可在场景里改路径，或通过 bind_target(player) 显式绑定。
碰撞层保持项目约定：世界=1，玩家=2，敌人=4。敌人查询射线只检测世界层，投射物扫掠检测世界及玩家。camera_targets 组和 camera_radius/camera_height 元数据可直接供现有镜头使用。

## 战斗接口

- bind_target(target: Node3D) -> bool：目标必须实现 take_damage(int) -> bool 和 is_dead() -> bool；可选 take_direct_damage(int, Vector3) -> bool。
- set_encounter_active(bool)：房间唤醒/停止；停止会清理该敌人的预警和腐质投射物。暂停由 SceneTree.paused 控制，不设置敌人为 ALWAYS。
- take_damage(int) -> bool：法术等通用伤害；长剑和双链在 RECOVER 状态承受双倍伤害。
- take_direct_damage(int, source_position: Vector3) -> bool：有方向的直接伤害；墓卫非收招/受控时正面减半，至少 1 点，背面正常。
- apply_control(seconds)、apply_slow(seconds)：普通怪支持打断与减速，Boss 免疫硬控，支持减速。
- hp_changed(current, maximum)、damage_received(amount)、died：适配现有 HUD、击杀与房间进度。
- battle_started、state_changed(message)：接 Boss 血条和状态提示。
- attack_telegraphed(enemy_id, mode, duration)、attack_resolved(enemy_id, mode)：可接 UI/音效，不改变伤害时机。
- reward_requested(source_id, coins)：只发送一次奖励请求，不直接写钱包。宿主使用唯一局 ID 前缀并调用现有背包奖励接口；通关结算继续交给现有主机。
- summon_requested(enemy_id, position)：半血时只请求两名斥候一次，由宿主决定是否生成、计入清场或随 Boss 死亡回收。
- status_requested(target, status_id, duration, strength)：目前仅 slow；若目标实现 apply_level03_slow(duration, factor)，敌人会调用它，信号仅用于通知；未实现时可由宿主接信号施加状态，避免重复处理。

## 与地图组对接

1. 四种普通/精英怪可直接放入房间静态名单，封存名单后再激活。
2. Boss 援军是动态请求，不能直接塞进已封存的 RoomProgress 名单。正式关建议把援军视为召唤物，Boss 死亡由宿主统一回收，不把它们作为额外门锁条件。实验室为了验证组合，清场会检查 Boss 与已生成援军。
3. 房间停止时对所有存活敌人调用 set_encounter_active(false)，并由房间回收所属召唤物和 l3_transient 临时特效。不要删除其他房间/玩家的节点。
4. Visuals 是程序化原型，最终可替换 visual.gd/模型，并保留 pose(state, progress, moving, delta, strike) 的适配入口。伤害逻辑和模型不要互相调用计时器。
5. 生成援军、奖励和延迟回调必须携带本局/本房 generation 标识，防止重开后旧回调落入新房间。实验室已示范该保护。

## 试运行与验证

F6 运行 res://addons/ziyuan_level03/Prototype.tscn，或运行交付的独立 EXE。数字 1–5 切组合，按钮进入五敌图鉴，Esc 暂停。J/K/Space/R/I 沿用现有操作。实验室玩家生命 24、每组药剂 3、手炮弹药 18；全部只在沙盒内生效，永久钱包不变。

```text
Godot --headless --path 项目目录 --script res://addons/ziyuan_level03/tests.gd --quit-after 2000
Godot --headless --path 项目目录 res://addons/ziyuan_level03/Prototype.tscn -- --l3-smoke
```

45 项检查已通过，涵盖逐级伤害、接口、休眠、真实近远程伤害、正背面护甲、收招弱点、墙体阻挡、扫链内圈、沙咒躲避、减速、半血召唤、死亡奖励幂等、图鉴切回、暂停、旧回调拦截、失败后原组重试。测试使用定点移动与真实物理判定，不等同于人工通关或最终难度验收。

造型按用户五张图片提炼，原型网格由程序构建，未将参考图片作为贴图或成品模型打包。本版提供机制与低多边形造型验证，最终布料、美术贴图、专业骨骼动画和角色成长仍可由组员继续制作。
