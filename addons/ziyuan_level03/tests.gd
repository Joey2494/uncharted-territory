extends SceneTree
const Factory=preload("factory.gd")
const Catalog=preload("catalog.gd")
var passed:=0
var failed:=0
var reward_count:=0
var summon_count:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	passed+=int(ok)
	failed+=int(not ok)
	print("PASS " if ok else "FAIL ",message)
func frames(n:=4) -> void:
	for i in n: await physics_frame
	await process_frame
func actor(lab: Node, id: String, point: Vector3) -> Node:
	var a:=Factory.create(id,lab.player)
	lab.arena.add_child(a)
	a.global_position=point
	a.set_encounter_active(true)
	a.set_physics_process(false)
	return a
func reset_player(player: Node3D, point: Vector3) -> void:
	player.global_position=point
	player.hp=24
	player._invulnerability_remaining=0
	player._dodge_invulnerability_remaining=0
	player._l3_slow=0
	player.get_node("ItemInventory").guard_active=false
func strike(a: Node) -> void:
	a._remaining=0
	a._physics_process(0.02)
	a._tick_strike(0.26)
func run() -> void:
	change_scene_to_file("res://addons/ziyuan_level03/Prototype.tscn")
	for i in 6: await process_frame
	var lab:=current_scene
	var player: Node=lab.player
	player.set_physics_process(false)
	for a in lab._actors: a.set_encounter_active(false); a.queue_free()
	lab._actors.clear()
	await frames()
	check(Catalog.ENEMIES.size()==5,"four enemy types and one boss registered")
	var last:=0
	for id in Catalog.ENEMIES:
		check(Catalog.ENEMIES[id].damage>last,"damage increases at "+id)
		last=Catalog.ENEMIES[id].damage
		var sample:=Factory.create(id,player)
		lab.arena.add_child(sample)
		check(sample.has_signal("died") and sample.has_signal("reward_requested") and sample.has_method("apply_control"),id+" exposes merge contract")
		check(not sample.is_encounter_active() and not sample.take_damage(1),id+" starts dormant")
		sample.queue_free()
	await frames()
	var axe:=actor(lab,"bone_axe",Vector3(0,0.05,-3))
	reset_player(player,Vector3(0,0.05,-1.5))
	check(axe.begin_attack(),"axe windup accepted")
	check(player.hp==24,"telegraph does not apply damage")
	strike(axe)
	check(player.hp==23,"axe cleave deals one actual damage")
	axe._tick_strike(0.1)
	check(player.hp==23,"one axe strike cannot hit twice")
	axe.state=axe.State.CHASE
	axe.begin_attack()
	player._dodge_invulnerability_remaining=1
	strike(axe)
	check(player.hp==23,"roll blocks direct strike")
	axe.state=axe.State.CHASE
	axe.begin_attack()
	axe.apply_control(1)
	check(axe.state==axe.State.HURT,"control interrupts ordinary attack")
	axe._physics_process(0.6)
	axe._physics_process(0.41)
	check(axe._control==0 and axe.state==axe.State.CHASE,"control duration does not run a second hurt countdown")
	axe.queue_free()
	await frames()
	var sword:=actor(lab,"tomb_sword",Vector3(0,0.05,-5))
	sword._visual.rotation.y=0
	check(sword.take_direct_damage(4,sword.global_position+Vector3.FORWARD*2) and sword.hp==12,"front sword armor halves direct damage")
	check(sword.take_direct_damage(4,sword.global_position+Vector3.BACK*2) and sword.hp==8,"rear strike bypasses armor")
	sword.state=sword.State.RECOVER
	sword.take_damage(2)
	check(sword.hp==4,"sword recovery doubles received damage")
	reset_player(player,Vector3(0,0.05,-1.5))
	sword.state=sword.State.CHASE
	sword.begin_attack()
	sword._begin_strike()
	for i in 30:
		sword._tick_strike(1.0/60.0)
		if sword.state==sword.State.RECOVER: break
	check(player.hp==21,"sword physical thrust deals three damage")
	sword.queue_free()
	await frames()
	var chain:=actor(lab,"chain_jailer",Vector3(0,0.05,-4))
	reset_player(player,chain.global_position+Vector3.FORWARD*0.6)
	chain._direction=Vector3.FORWARD
	chain._zone(chain.global_position,4.8,4,360,0.95)
	check(player.hp==24,"chain inner pocket is safe")
	reset_player(player,chain.global_position+Vector3.FORWARD*3)
	chain._zone(chain.global_position,4.8,4,360,0.95)
	check(player.hp==20,"chain outer ring deals four damage")
	chain.queue_free()
	await frames()
	var spike:=actor(lab,"bone_spike",Vector3(0,0.05,-5))
	reset_player(player,Vector3(0,0.05,1))
	spike.begin_attack()
	strike(spike)
	check(get_nodes_in_group("l3_hazards").size()==3,"bone hunter fires three real projectiles")
	await frames(40)
	check(player.hp==22,"bone projectile swept collision deals two damage")
	spike.set_encounter_active(false)
	await frames()
	check(get_nodes_in_group("l3_hazards").is_empty(),"dormant source cleans its projectiles")
	spike.queue_free()
	await frames()
	var wall_hunter:=actor(lab,"bone_spike",Vector3(-8,0.05,-5))
	reset_player(player,Vector3(-8,0.05,3))
	wall_hunter.begin_attack()
	strike(wall_hunter)
	var center_bolt: Node=get_nodes_in_group("l3_hazards")[1]
	await frames(34)
	check(not is_instance_valid(center_bolt) and player.hp==24,"stone pillar blocks the central bone projectile")
	wall_hunter.set_encounter_active(false)
	wall_hunter.queue_free()
	await frames()
	var boss:=actor(lab,"sand_king",Vector3(0,0.05,-5))
	reset_player(player,Vector3(0,0.05,0))
	boss.begin_attack(0)
	strike(boss)
	check(player.hp==18,"mummy bandage cone deals six damage")
	boss.state=boss.State.CHASE
	reset_player(player,Vector3(0,0.05,0))
	boss.begin_attack(1)
	var old: Vector3=player.global_position
	player.global_position+=Vector3.RIGHT*6
	strike(boss)
	check(player.hp==24,"leaving committed curse circles avoids damage")
	boss.state=boss.State.CHASE
	reset_player(player,old)
	boss.begin_attack(1)
	strike(boss)
	check(player.hp==16 and player._l3_slow>0,"curse circle deals eight damage and slow on accepted hit")
	boss.summon_requested.connect(func(_id: String,_point: Vector3) -> void: summon_count+=1)
	boss.take_damage(45)
	boss.take_damage(1)
	check(summon_count==2 and boss._phase_two,"boss half-health transition summons exactly two helpers once")
	boss.reward_requested.connect(func(_source: String,_coins: int) -> void: reward_count+=1)
	check(boss.take_damage(999) and not boss.take_damage(999) and reward_count==1,"death and reward request are idempotent")
	await frames(45)
	check(not is_instance_valid(boss),"death animation releases boss actor")
	lab.show_gallery()
	await frames()
	check(lab._actors.size()==5 and lab.gallery,"gallery contains all five silhouettes")
	lab.load_wave(2)
	await frames()
	check(not lab.gallery and player.visible and lab._actors.size()==2,"returning from gallery resets a real encounter")
	paused=true
	var at: Vector3=player.global_position
	await create_timer(0.1).timeout
	check(player.global_position==at and not lab._actors[0].can_process(),"pause freezes player and enemies")
	paused=false
	var count: int=lab._actors.size()
	lab._spawn_for_generation(lab._generation-1,"bone_axe",Vector3.ZERO)
	check(lab._actors.size()==count,"stale summon request cannot enter another encounter")
	player.take_damage(999)
	check(lab._ended and not lab._actors[0].is_encounter_active(),"player death stops enemy combat immediately")
	lab.load_wave(3)
	for i in 8: await process_frame
	check(current_scene.wave==3 and current_scene.player.hp==24,"retry after death recreates the requested encounter")
	print("LEVEL03_TEST_RESULT passed=%d failed=%d" % [passed,failed])
	quit(1 if failed else 0)

