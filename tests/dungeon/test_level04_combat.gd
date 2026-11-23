extends SceneTree
## 以正式预览场景、角色、敌人和物理空间验收战斗。房间时钟手动推进，角色动作照常逐帧执行。
const LEVEL := preload("res://scenes/dungeon/level04/Level04Preview.tscn")
const SPORE := preload("res://addons/ziyuan_level03/bone_projectile.gd")
var level: Node3D
var combat: Node3D
var player: CharacterBody3D
var checks := 0
var failures := 0
var clears: Array[String] = []

func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ",message)
func at(room: String,x: float,z: float) -> Vector3:
	return level.layout.room_center(room)+Vector3(x,0.065,z)
func enter(room: String,x: float,z: float) -> void:
	player.global_position = at(room,x,z)
	player.velocity = Vector3.ZERO
	combat.update_room(room,0.016)
func kill_guards() -> void:
	for guard in combat._enemies.duplicate(): guard.take_damage(999)
func names() -> Array:
	return combat._enemies.map(func(g): return g.enemy_id)
func verify_spawn() -> void:
	for guard: CharacterBody3D in combat._enemies:
		var hitbox: CollisionShape3D = guard.get_node("CollisionShape3D")
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = hitbox.shape
		query.transform = hitbox.global_transform
		query.collision_mask = 1
		check(guard.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"生成点与真实地形、设施分离 "+guard.name)

func run() -> void:
	level = LEVEL.instantiate()
	root.add_child(level)
	combat = level.combat
	player = level.player
	level.set_physics_process(false)
	combat.battle_cleared.connect(func(room: String): clears.append(room))
	await frames(4)
	var boxes := get_nodes_in_group("breakable_cover")
	check(boxes.size()==3,"A 一只练习箱，B 两只内线箱")
	var box: StaticBody3D = boxes[0]
	player.global_position = box.global_position+Vector3(0,0.06,1.61)
	player.visuals.rotation.y = 0.0
	await frames(3)
	check(player.get_node("MeleeAttack").try_attack(),"真实近战起手")
	await frames(29)
	check(box.hits_left==2,"木箱既遮挡又可被近战剑击一次")
	check(player.get_node("EnergyShock").try_cast(),"真实能量弹起手")
	await frames(28)
	check(box.hits_left==1,"玩家弹丸能伤害掩体")
	check(box.take_damage(999) and box.collision_layer==0 and not box.visible,"第三次命中同时移去木箱碰撞与模型")
	check(not box.take_damage(1),"同帧第四次命中无效")
	var permanent: Node = level.layout.get_node("A").get_children().filter(func(n): return n is StaticBody3D and n.position.x < -3 and absf(n.position.z-1.6)<0.2).back()
	check(not permanent.has_method("take_damage"),"练习箱旁的石基永久保留")
	enter("B",0,6)
	check(combat.active_room=="","在装卸场门内可站稳后再封场")
	enter("B",-3.8,3.3)
	check(names()==["bone_axe","bone_axe","bone_spike"],"B 两斥候一腐尸")
	verify_spawn()
	player._invulnerability_remaining = 300
	var crate: StaticBody3D = boxes[1]
	var shooter: CharacterBody3D = combat._enemies.back()
	shooter.global_position = crate.global_position+Vector3(0,0.06,-2.5)
	await frames(1)
	var bolt := SPORE.new()
	combat.add_child(bolt)
	bolt.global_position = shooter.global_position+Vector3.UP*1.25
	bolt.launch(shooter,player,Vector3.BACK,20)
	await frames(15)
	check(crate.hits_left==2,"腐尸弹丸在箱面消失并算一次有效命中")
	kill_guards()
	combat.update_room("B",0.016)
	check(combat.is_clear("B") and clears==["B"],"B 完整清场仅一次")
	enter("B",-3.8,3.3)
	check(combat.enemy_count()==0,"重访不再生成 B 守卫")
	enter("D",6,0)
	check(combat.active_room=="","D 观察窗与退路在封场线外")
	enter("D",3.2,0)
	check(names()==["tomb_sword","bone_spike"],"跨线启动 D 墓卫和射手")
	verify_spawn()
	kill_guards()
	combat.update_room("D",0.016)
	player.global_position = at("F",-4,2)
	check(combat.set_cage(-1) and combat.cage_side==0,"目标被玩家占用时悬停等待")
	player.global_position = at("D",4.0,0.0)
	combat.update_room("D",0.016)
	check(combat.cage_side==-1 and combat._cage.position.distance_to(at("F",-4,2))<1.1,"腾空后左侧实体到位")
	check(combat.set_cage(1) and combat.cage_side==1,"开战前可改换侧别")
	enter("F",-3,3.9)
	check(names()==["bone_spike","bone_spike"] and not combat.set_cage(-1),"F 双廊射手和战时锁定")
	verify_spawn()
	check(not combat._enemies[0]._can_see(combat._enemies[1].global_position),"双廊分隔石墙阻断射线")
	kill_guards()
	combat.update_room("F",0.016)
	check(not combat.is_clear("F") and combat.enemy_count()==0 and combat._markers.F.visible,"F 清首波时先点亮援军门")
	combat.update_room("F",1.2)
	check(names()==["tomb_sword"],"F 标记门后补入墓卫")
	verify_spawn()
	kill_guards()
	combat.update_room("F",0.016)
	check(combat.is_clear("F") and combat.set_cage(-1),"已清 F 可回 D 检修")
	enter("H",0,5.8)
	combat.update_room("H",3.0)
	combat.update_room("",0.016)
	check(not combat.demo_done and not combat._sweeps.H.active,"离开试车房可折返，回来仍能观看完整演示")
	enter("H",-3,0)
	player._invulnerability_remaining = 0
	var before: int = player.hp+player.shield
	combat.update_room("H",5.8)
	check(not combat.demo_done and combat.enemy_count()==0 and player.hp+player.shield==before,"演示期间跨线也不伤人不开战")
	enter("H",0,5.8)
	combat.update_room("H",0.3)
	combat.update_room("H",0.02)
	check(combat.demo_done and combat.active_room=="" and combat._demo_threshold.visible,"看完演示仍可停在安全台")
	enter("H",-3,0)
	check(names()==["bone_spike","bone_axe"],"H 内侧阈值才启用两名首波敌人")
	verify_spawn()
	var lure: CharacterBody3D = combat._enemies[0]
	lure.global_position = at("H",-5,0)
	combat._enemies[1].global_position = at("H",4,1)
	var other_hp: int = combat._enemies[1].hp
	var lure_hp: int = lure.hp
	combat.update_room("H",4.51)
	check(player.hp+player.shield==before and lure.hp==lure_hp and combat._markers.H.visible,"首轮锁定预警不造成身侧未扫到的伤害")
	combat.update_room("H",0.75)
	check(player.hp+player.shield==before-1 and lure.hp<lure_hp and combat._enemies[1].hp==other_hp,"同一亮带命中玩家和追兵，暗侧无伤")
	before = player.hp+player.shield
	player._invulnerability_remaining = 0
	combat.update_room("H",0.015)
	check(player.hp+player.shield==before,"同一轮穿过亮带不会二次伤人")
	kill_guards()
	check(not combat.is_clear("H"),"实扫完成前必须保留待入场守卫")
	combat.update_room("H",0.8)
	check(names()==["tomb_sword"],"H 第一次实扫后补入墓卫")
	verify_spawn()
	kill_guards()
	combat.update_room("H",0.016)
	check(combat.is_clear("H") and not combat._sweeps.H.active,"H 全名单清除后停光放行")
	enter("I",2.5,7.2)
	check(combat.active_room=="","终战门廊仍可回头")
	enter("I",2.5,5.2)
	check(names()==["chain_jailer","bone_spike"],"终战执刑官及一名远程近卫")
	verify_spawn()
	var jailer: CharacterBody3D = combat._jailer
	check(jailer.max_hp == 28,"穹顶执刑官限定耐久")
	check(combat.boss_guard()==jailer and combat._enemies[1].max_hp==9,"血条仅绑定主敌，远程近卫保留旧数值")
	check(jailer.begin_attack(),"执刑官进入重击预告")
	var telegraph: Node3D = jailer._warning.get_child(-1)
	var windup_time: float = jailer._remaining
	jailer.take_direct_damage(2,player.global_position)
	check(jailer.hp==jailer.max_hp-2 and jailer.state==jailer.State.WINDUP and jailer._remaining==windup_time and not telegraph.is_queued_for_deletion(),"正常命中扣血，已亮起的重击预警与时钟保持")
	await frames(62)
	check(jailer.state==jailer.State.STRIKE,"受击的预告仍兑现重击")
	var cover_ray := PhysicsRayQueryParameters3D.create(at("I",-3,0)+Vector3.UP,at("I",3,0)+Vector3.UP,1)
	check(not level.get_world_3d().direct_space_state.intersect_ray(cover_ray).is_empty(),"穹顶中央仪器真实阻断弹道")
	check(combat.operate_shutter() and combat._sweeps.I.side==1,"选择期可以切换至东侧")
	combat.update_room("I",3.02)
	check(combat.operate_shutter() and combat._sweeps.I.side==1,"锁定后扳杆仅预约，不能改本轮")
	player._invulnerability_remaining=300
	jailer.take_damage(ceili(jailer.max_hp*0.5)-2)
	combat.update_room("I",0.05)
	check(not combat.half_announced,"半血推进等待锁定扫光结束")
	combat.update_room("I",3.1)
	check(combat._sweeps.I.side==1 and combat._queued_side==0,"扳杆预约只在下一轮开始时兑现")
	# 采自基础骑士持续进攻时的实跑位置：玩家占住石岛北沿第一个绕行点。
	jailer.global_position = at("I",-1.269,-2.444)
	player.global_position = at("I",-0.448,-2.664)
	var blocked_at := Vector2(player.position.x,player.position.z)
	combat.update_room("I",0.016)
	check(combat.half_announced and jailer.advancing and not combat._sweeps.I.active,"半血预告与扫光互斥")
	var marked: Node = jailer._warning.get_child(-1)
	var half_hp: int = jailer.hp
	jailer.take_direct_damage(2,player.position)
	check(jailer.hp==half_hp-1 and not marked.is_queued_for_deletion(),"举链承受部分直击伤害，推进路线仍可见")
	var start := jailer.global_position
	await frames(55)
	check(jailer.global_position.distance_to(start)<0.25,"半血预告留出反应窗口")
	for i in 455:
		if not jailer.advancing: break
		await physics_frame
	check(jailer.global_position.distance_to(at("I",5.4,2.0))<1.1 and not jailer.advancing,"执刑官实际绕岛推进至扳杆侧 %s · 玩家 %s" % [jailer.position,player.position])
	check(blocked_at.distance_to(Vector2(player.position.x,player.position.z))>0.12,"堵路角色在真实碰撞范围内让出举链行进线")
	combat.update_room("I",0.016)
	check(combat._sweeps.I.active and not jailer.advancing,"推进后恢复选侧阶段且不重复推进")
	jailer.take_damage(999)
	combat.update_room("I",0.016)
	check(not combat.is_clear("I") and combat.enemy_count()==1 and combat.boss_guard()==null,"击败主敌收回血条且不能跳过存活近卫")
	kill_guards()
	combat.update_room("I",0.016)
	check(clears==["B","D","F","H","I"] and not combat._sweeps.I.active,"终战完整名单清除后停光")
	level.queue_free()
	await frames(3)
	root.get_node("MusicManager").stop_music()
	print("LEVEL04_COMBAT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
