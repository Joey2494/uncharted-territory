extends SceneTree
## 在正式第三关验证房间唤醒、真实 J/K、奖励、暂停和首领召唤生命周期。
const Profile = preload("res://scripts/integration/player_profile.gd")
const Progress = preload("res://scripts/integration/campaign_progress.gd")
const Catalog = preload("res://addons/ziyuan_level03/catalog.gd")
var host: Node3D
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func frames(n := 8) -> void:
	for i in n: await physics_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", message)
func go(point: Vector3) -> void:
	host._player.global_position = point
	host._player.velocity = Vector3.ZERO
	await frames()

func run() -> void:
	if "--capture" in OS.get_cmdline_user_args():
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
	var token := "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	Profile.override_path = "user://tide-enemy-profile-" + token + ".cfg"
	Progress.override_path = "user://tide-enemy-progress-" + token + ".cfg"
	change_scene_to_file("res://scenes/dungeon/Level03Run.tscn")
	await frames()
	host = current_scene
	var map: Node3D = host._dungeon
	check(host._player.max_hp == 5 and host._player.max_energy == 50, "正式入口保持俞的角色属性，不采用原型实验室属性")
	check(map.get_node("Enemies").get_child_count() == 8, "四个战斗房登记八名正式敌人")
	var ids: Array = []
	for enemy in map.get_node("Enemies").get_children():
		ids.append(enemy.enemy_id)
		check(enemy.hp == Catalog.definition(enemy.enemy_id).hp and not enemy.is_encounter_active() and not enemy.take_damage(1), "原始数值与休眠保护：" + enemy.name)
		var shape: CollisionShape3D = enemy.get_node("CollisionShape3D")
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape.shape
		query.transform = shape.global_transform
		query.collision_mask = 1
		check(enemy.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "出生不嵌入墙、掩体或交互台：" + enemy.name)
	check(Catalog.ENEMIES.keys().all(func(id: String) -> bool: return id in ids), "五种字远敌人均已接入正式地图")
	host._on_run_started()
	host._player._invulnerability_remaining = 1000
	await go(map.get_node("Rooms/C").global_position + Vector3(0, 0.05, 3))
	var axe: Node3D = map.get_node("Enemies/C_Guard1")
	var second: Node3D = map.get_node("Enemies/C_Guard2")
	check(axe.is_encounter_active() and second.is_encounter_active() and not map.get_node("Enemies/E_Guard1").is_encounter_active(), "入 C 只唤醒 C 名单，E 继续休眠")
	axe.apply_control(2.5)
	second.apply_control(2.5)
	await go(axe.global_position + Vector3(0, 0, 1.5))
	host._player.visuals.rotation.y = 0
	var before: int = axe.hp
	check(host._player.get_node("MeleeAttack").try_attack(), "真实 J 接受攻击")
	await frames(15)
	check(axe.hp < before, "真实 J 命中字远敌人")
	before = axe.hp
	var energy: float = host._player.energy
	check(host._player.get_node("EnergyShock").try_cast() and host._player.energy == energy - 5, "真实 K 保持每次五点能量")
	await frames(12)
	check(axe.hp < before, "真实 K 投射物命中字远敌人")
	check(axe.take_damage(999) and not map.get_node("Progress").is_complete(&"C"), "只击败一名守卫不能提前清场")
	var coins := map.get_node("EnemyRewards").get_child_count()
	check(not axe.take_damage(999) and map.get_node("EnemyRewards").get_child_count() == coins, "重复伤害不会重复生成金币")
	var pickup: Node3D = map.get_node("EnemyRewards").get_child(0)
	await go(pickup.global_position + Vector3(0, 0, 0.8))
	var wallet: int = Profile.coins
	check(pickup.try_collect(host._player) and host._items.gold == 12 and Profile.coins == wallet, "拾取按字远数值进入本局金币，永久钱包保持到出口再结算")
	check(second.take_damage(999) and map.get_node("Progress").is_complete(&"C"), "全部静态守卫死亡后 C 才完成")
	await go(map.get_node("Rooms/E").global_position + Vector3(0, 0.05, 3))
	var spike: Node3D = map.get_node("Enemies/E_Guard2")
	spike.apply_control(1)
	var frozen: Vector3 = spike.global_position
	var control: float = spike._control
	host.set_paused(true)
	await create_timer(0.15).timeout
	check(spike.global_position == frozen and spike._control == control and not spike.take_damage(1), "共享暂停冻结敌人、状态计时并拒绝伤害")
	host.set_paused(false)
	await go(map.get_node("Rooms/G").global_position + Vector3(0, 0.05, 3))
	var boss: Node3D = host._boss
	check(boss.is_encounter_active() and host._boss_bar.visible and host._boss_bar.title_label.text == "沙缚王", "G 入场显示真实沙缚王血条")
	check(boss.take_damage(45) and map._summons.size() == 2 and map.get_node("Progress").get_total_enemies(&"G") == 2, "半血召唤两名斥候，不破坏封存的静态清场名单")
	check(map._summons.all(func(enemy: Node3D) -> bool: return enemy.is_encounter_active() and enemy.get_meta("room") == &"G"), "援军绑定本局玩家和 G 房间并立即参战")
	if "--capture" in OS.get_cmdline_user_args():
		# 测试刚从 E 定点移动到 G；截图从稳定构图开始。
		map.get_node("Camera3D").reset_follow()
		await frames(12)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/ziyuan_level03_boss.png")
	host._player.apply_level03_slow(0.3, 0.6)
	Input.action_press("move_right")
	await frames(2)
	check(is_equal_approx(host._player.velocity.x, host._player.walk_speed * 0.6), "正式角色沙咒减速使用六成移速")
	Input.action_release("move_right")
	var slow: float = host._player._sand_slow_remaining
	host.set_paused(true)
	await create_timer(0.15).timeout
	check(host._player._sand_slow_remaining == slow, "沙咒持续时间随暂停冻结")
	host.set_paused(false)
	await frames(24)
	check(host._player._sand_slow_remaining == 0 and host._player.walk_speed == 5, "减速结束恢复正常属性")
	var reward_count: int = map.get_node("EnemyRewards").get_child_count()
	check(boss.take_damage(999), "正式首领可死亡")
	await frames(3)
	check(map._summons.is_empty() and map.get_node("Enemies").get_children().filter(func(n: Node) -> bool: return n.get_meta("summoned", false)).is_empty(), "Boss 死亡回收两名援军")
	check(map.get_node("EnemyRewards").get_child_count() == reward_count + 1, "回收援军不额外掉钱，Boss 仅生成一次奖励")
	check(host._boss_defeated and not map.get_node("Progress").is_complete(&"G") and not map.is_exit_open(), "仅 Boss 死亡不能绕过存活执刑官或打开出口")
	check(map.get_node("Enemies/G_Guard1").take_damage(999), "击败剩余执刑官")
	await frames(24)
	await go(map.get_node("Rooms/J").global_position)
	host._on_exit_reached()
	check(host.get_run_state() == host.RunState.PLAYING and not map.is_completion_ready(), "Boss 和守卫均死亡仍不能绕过 I 泄压")
	map.stop_run()
	await frames(3)
	check(get_nodes_in_group("l3_hazards").is_empty() and get_nodes_in_group("l3_transient").is_empty(), "停止本局清理该关投射物与临时特效")
	check(map.get_node("Enemies").get_children().filter(func(n: Node) -> bool: return n.has_method("is_encounter_active") and n.is_encounter_active()).is_empty(), "停止本局停用全部存活敌人")
	host.queue_free()
	await frames(3)
	root.get_node("MusicManager").stop_music()
	await create_timer(0.15).timeout
	print("LEVEL03_ENEMY_INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
