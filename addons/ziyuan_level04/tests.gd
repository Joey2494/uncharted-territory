extends SceneTree
## 孢冠女巫原型自动验证：契约接口、四式招式、毒池上限与跳伤、
## 召唤规则、二阶段转换、架势破绽、死亡幂等、休眠清理与暂停冻结。
## 测试使用定点移动与真实物理判定，不等同于人工通关或最终难度验收。
const Factory = preload("factory.gd")
const Catalog = preload("catalog.gd")
const Witch = preload("witch.gd")
const Mark = preload("spore_mark.gd")
var passed := 0
var failed := 0
var reward_count := 0
var summon_points: Array[Vector3] = []
var dissolve_count := 0
var tele_count := 0
var applied_total := 0
var died_total := 0
var lab: Node
var player: Node
var witch: Node
var owned: Array[Node] = []
## 单标记测试替身：只验证爆炸伤害与生成毒池的调用，不真正生成毒池。
class MarkStub extends Node3D:
	var definition: Dictionary = {"damage": 2}
	var pool_count := 0
	func is_encounter_active() -> bool: return true
	func _spawn_pool(_at: Vector3) -> void: pool_count += 1
class RoomStub extends Node3D:
	func get_enemy_spawn_points() -> Array[Marker3D]:
		return [$Spawn as Marker3D]
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	passed += int(ok)
	failed += int(not ok)
	print("PASS " if ok else "FAIL ", message)
func frames(n := 4) -> void:
	for i in n: await physics_frame
	await process_frame
func reset_player(point: Vector3) -> void:
	player.global_position = point
	player.hp = 24
	player._invulnerability_remaining = 0
	player._dodge_invulnerability_remaining = 0
	player.get_node("ItemInventory").guard_active = false
func fresh_witch(point := Vector3(-5, 0.05, -5)) -> Node:
	await clear_lab()
	var w := Factory.create("witch", player)
	lab.arena.add_child(w)
	w.global_position = point
	w.set_encounter_active(true)
	w.set_physics_process(false)
	owned.append(w)
	return w
func clear_lab() -> void:
	for actor in lab._actors:
		if is_instance_valid(actor): actor.set_encounter_active(false)
	for guard in lab._guards:
		if is_instance_valid(guard): guard.queue_free()
	lab._guards.clear()
	for actor in lab._actors:
		if is_instance_valid(actor): actor.queue_free()
	lab._actors.clear()
	for w in owned:
		if is_instance_valid(w): w.set_encounter_active(false)
	for w in owned:
		if is_instance_valid(w): w.queue_free()
	owned.clear()
	for group in ["l4_hazards", "l4_transient"]:
		for node in get_nodes_in_group(group):
			if lab.arena.is_ancestor_of(node): node.queue_free()
	await frames()
func strike(a: Node) -> void:
	# 直接施放已在 begin_attack 完成；只推进执行时间。
	a._tick_strike(0.26)
func step_boss(delta: float) -> void:
	# 玩家移出攻击距离，避免自动出招干扰计时器推进。
	var back: Vector3 = player.global_position
	player.global_position = Vector3(13, 0.05, 9)
	witch._physics_process(delta)
	player.global_position = back
func count_kind(kind: String) -> int:
	var n := 0
	for node in get_nodes_in_group("l4_hazards"):
		match kind:
			"pool": if node.has_method("overlaps_band"): n += 1
			"mark": if node.get("_fuse") != null: n += 1
			"vine": if node.get("_travel") != null: n += 1
			"bolt": if node.get("_life") != null: n += 1
	return n
func run() -> void:
	change_scene_to_file("res://addons/ziyuan_level04/Prototype.tscn")
	for i in 6: await process_frame
	lab = current_scene
	player = lab.player
	player.set_physics_process(false)
	await clear_lab()
	# ---------- 数值表与契约 ----------
	check(Catalog.ENEMIES.size() == 2, "catalog registers witch boss and spore guard minion")
	check(Catalog.ENEMIES.witch.hp == 60 and Catalog.ENEMIES.witch.gold == 160, "witch boss stats scaled to campaign baseline")
	check(Catalog.ENEMIES.spore_guard.gold == 0, "spore guard drops no coins")
	witch = await fresh_witch()
	check(witch.has_signal("died") and witch.has_signal("reward_requested") and witch.has_signal("summon_requested") and witch.has_signal("minions_dissolved"), "witch exposes boss contract signals")
	check(witch.has_signal("hp_changed") and witch.has_signal("state_changed") and witch.has_signal("battle_started") and witch.has_signal("attack_telegraphed") and witch.has_signal("attack_resolved"), "witch exposes hud and telegraph signals")
	check(witch.has_method("bind_target") and witch.has_method("set_encounter_active") and witch.has_method("take_damage") and witch.has_method("take_direct_damage"), "witch exposes combat methods")
	check(witch.has_method("apply_control") and witch.has_method("apply_slow") and witch.has_method("register_minion") and witch.is_boss(), "witch exposes control and minion contract")
	check(not witch.bind_target(null) and witch.bind_target(player), "target binding validates the player interface")
	check(witch.is_in_group("camera_targets") and witch.get_meta("camera_radius") == 2.2, "witch joins camera group with framing metadata")
	var dormant := Factory.create("witch", player)
	lab.arena.add_child(dormant)
	check(not dormant.is_encounter_active() and not dormant.take_damage(1), "witch starts dormant and rejects damage")
	dormant.queue_free()
	await frames()
	# ---------- 单标记爆炸与三点孢弹 ----------
	var stub := MarkStub.new()
	var solo := Mark.new()
	lab.arena.add_child(solo)
	reset_player(Vector3(0, 0.05, 2))
	solo.launch(stub, player, Vector3(0, 0.05, 2), 0.9)
	await frames(60)
	check(player.hp == 22 and stub.pool_count == 1, "single spore mark explodes for two damage and leaves one pool")
	stub.free()
	witch = await fresh_witch()
	reset_player(Vector3(0, 0.05, 2))
	tele_count = 0
	witch.attack_telegraphed.connect(func(_id: String, _mode: int, _duration: float) -> void: tele_count += 1)
	check(witch.begin_attack() and witch._mode == Witch.Move.TRIPLE and tele_count == 0 and witch.state == Witch.State.STRIKE, "triple shot starts directly without any telegraph signal or windup")
	check(witch._warning.get_child_count() == 0, "direct cast creates no attack range meshes")
	check(count_kind("mark") == 1, "first physical spore launches immediately")
	witch._tick_strike(0.0)
	check(count_kind("mark") == 1, "repeated zero delta cannot duplicate the first spore")
	witch._tick_strike(0.34)
	check(count_kind("mark") == 1, "second spore waits for 0.35 real seconds")
	witch._tick_strike(0.02)
	check(count_kind("mark") == 2, "second spore launches after 0.35 seconds")
	strike(witch)
	witch._tick_strike(0.26)
	witch._tick_strike(0.26)
	witch._tick_strike(0.26)
	witch._tick_strike(0.26)
	check(count_kind("mark") == 3, "triple spore shot places three locked marks")
	witch._tick_strike(0.0)
	check(count_kind("mark") == 3, "finished triple shot never duplicates projectiles")
	# 测试同步生成的三枚标记同时爆炸，受击保护只结算一次。
	await frames(62)
	check(player.hp == 22, "locked marks explode and hit protection settles one hit")
	check(count_kind("pool") == 3, "three marks leave three poison pools")
	# ---------- 毒池上限与替换 ----------
	witch._spawn_pool(player.global_position)
	await frames(20)
	check(count_kind("pool") == 3, "fourth pool dissolves the oldest one")
	await clear_lab()
	# ---------- 毒池跳伤节奏 ----------
	witch = await fresh_witch()
	reset_player(Vector3(0, 0.05, 2))
	witch._spawn_pool(player.global_position)
	await frames(3)
	check(player.hp == 23, "pool ticks once immediately on entry")
	player._invulnerability_remaining = 0
	await frames(66)
	check(player.hp == 22, "pool ticks once per second while standing inside")
	player._invulnerability_remaining = 0
	player.global_position = Vector3(4, 0.05, 4)
	await frames(30)
	check(player.hp == 22, "leaving the pool stops damage")
	player.global_position = Vector3(0, 0.05, 2)
	await frames(3)
	check(player.hp == 22, "re-entering inside one second cannot speed up the source tick")
	await frames(30)
	check(player.hp == 21, "the pool still ticks once per second after re-entry")
	await frames(150)
	check(count_kind("pool") == 0, "pool expires after four seconds")
	# ---------- 脉冲种子 ----------
	await clear_lab()
	witch = await fresh_witch()
	reset_player(Vector3(-5, 0.05, -3))
	check(witch.begin_attack(Witch.Move.PULSE) and witch._mode == Witch.Move.PULSE, "pulse seed can be forced for verification")
	strike(witch)
	check(count_kind("bolt") == 8, "pulse seed fires eight ring bolts")
	await frames(40)
	check(player.hp == 23, "ring bolt deals one damage on swept contact")
	# ---------- 孢子守卫召唤规则 ----------
	await clear_lab()
	witch = await fresh_witch()
	reset_player(Vector3(-5, 0.05, -3))
	summon_points.clear()
	witch.summon_requested.connect(func(_id: String, p: Vector3) -> void: summon_points.append(p))
	check(witch.begin_attack(Witch.Move.GUARD) and witch._mode == Witch.Move.GUARD, "guard slot fires while no minion is alive")
	strike(witch)
	check(summon_points.size() == 2 and summon_points[0] != summon_points[1], "one batch requests two guards at distinct marked positions")
	check(witch._summon_batches == 1, "summon batch counter advances")
	var guard := Factory.create("spore_guard", player)
	lab.arena.add_child(guard)
	guard.global_position = summon_points[0]
	guard.set_encounter_active(true)
	guard.set_physics_process(false)
	check(witch.register_minion(guard) and witch._living_minions() == 1, "host registers living minions for summon decision")
	witch.state = Witch.State.CHASE
	check(witch.begin_attack(Witch.Move.GUARD) and witch._mode == Witch.Move.PULSE, "guard slot replaced by pulse while a batch is alive")
	witch.state = Witch.State.CHASE
	guard.take_damage(999)
	await frames(2)
	check(witch._living_minions() == 0, "dead batch frees the guard slot again")
	check(witch.begin_attack(Witch.Move.GUARD) and witch._mode == Witch.Move.GUARD, "second batch is allowed once the first is gone")
	strike(witch)
	check(witch._summon_batches == 2, "second batch summons and advances the counter")
	var guard2 := Factory.create("spore_guard", player)
	lab.arena.add_child(guard2)
	guard2.global_position = summon_points[2]
	guard2.set_encounter_active(true)
	guard2.set_physics_process(false)
	witch.register_minion(guard2)
	witch.state = Witch.State.CHASE
	check(witch.begin_attack(Witch.Move.GUARD) and witch._mode == Witch.Move.PULSE, "alive minion keeps replacing the guard slot")
	guard2.take_damage(999)
	await frames(2)
	witch.state = Witch.State.CHASE
	check(witch.begin_attack(Witch.Move.GUARD) and witch._mode == Witch.Move.GUARD, "third and final batch is allowed")
	strike(witch)
	check(witch._summon_batches == 3, "batch cap reached")
	witch.state = Witch.State.CHASE
	check(witch.begin_attack(Witch.Move.GUARD) and witch._mode == Witch.Move.PULSE, "fourth batch is refused and replaced by pulse")
	# ---------- 藤蔓横扫 ----------
	await clear_lab()
	witch = await fresh_witch()
	reset_player(Vector3(0, 0.05, 2))
	check(witch.begin_attack(Witch.Move.VINE) and witch._mode == Witch.Move.VINE and witch._vine_position == 0.0, "vine sweep locks its band on the player at windup start")
	strike(witch)
	check(count_kind("vine") == 1, "vine sweep hazard is live")
	await frames(110)
	check(player.hp == 22, "wave passing the player inside the band deals two damage")
	check(count_kind("vine") == 0, "vine hazard clears after one pass")
	await clear_lab()
	witch = await fresh_witch()
	reset_player(Vector3(0, 0.05, 2))
	witch.begin_attack(Witch.Move.VINE)
	player.global_position = Vector3(3, 0.05, 2)
	strike(witch)
	await frames(110)
	check(player.hp == 24, "stepping off the band avoids the sweep")
	await clear_lab()
	witch = await fresh_witch()
	reset_player(Vector3(0, 0.05, 2))
	witch.begin_attack(Witch.Move.VINE)
	strike(witch)
	player._dodge_invulnerability_remaining = 1.0
	await frames(110)
	check(player.hp == 24, "roll invulnerability crosses the sweep")
	await clear_lab()
	witch = await fresh_witch()
	reset_player(Vector3(0, 0.05, 2))
	witch._spawn_pool(Vector3(0.4, 0.05, 2))
	await frames(3)
	check(player.hp == 23, "overlapping pool ticks once before the sweep test")
	player._invulnerability_remaining = 0
	check(count_kind("pool") == 1, "one pool lies across the sweep band")
	var live_pool: Node
	for node in get_nodes_in_group("l4_hazards"):
		if node.has_method("overlaps_band"): live_pool = node
	check(live_pool.overlaps_band(0.0, 1.0) and not live_pool.overlaps_band(5.0, 1.0), "pool safe path tests the sweep x axis")
	witch.begin_attack(Witch.Move.VINE)
	strike(witch)
	await frames(20)
	check(count_kind("pool") == 0, "pool blocking the band dissolves before the sweep")
	await frames(110)
	check(player.hp == 21, "sweep still resolves after the safe-path fix")
	# ---------- 二阶段转换 ----------
	await clear_lab()
	witch = await fresh_witch()
	reset_player(Vector3(-5, 0.05, -3))
	var messages: Array[String] = []
	witch.state_changed.connect(func(m: String) -> void: messages.append(m))
	check(witch.begin_attack() and witch._mode == Witch.Move.TRIPLE, "fresh boss opens with triple shot")
	witch.take_damage(witch.max_hp / 2 + 1)
	check(witch.phase == 1 and witch._pending_transition, "crossing half health only marks the transition")
	strike(witch)
	witch._tick_strike(1.7)
	await frames(2)
	check(witch.state == Witch.State.TRANSITION and witch.phase == 2, "transition runs at the next safe move boundary")
	check(count_kind("pool") == 0 and count_kind("mark") == 0, "transition clears old projectiles and hazard zones")
	step_boss(0.9)
	check(witch.state == Witch.State.CHASE, "transition show ends after 0.8 seconds")
	check(witch.begin_attack() and witch._mode == Witch.Move.VINE, "phase two opens with the fixed vine sweep")
	witch.state = Witch.State.CHASE
	check(witch.begin_attack() and witch._mode == Witch.Move.TRIPLE, "phase two rotation interleaves triple shot")
	witch.state = Witch.State.CHASE
	check(witch.begin_attack() and witch._mode == Witch.Move.PULSE, "phase two rotation interleaves pulse seed")
	witch.state = Witch.State.CHASE
	check(witch.begin_attack() and witch._mode == Witch.Move.VINE, "phase two rotation repeats vine sweep")
	witch.state = Witch.State.CHASE
	check(witch.begin_attack() and witch._mode == Witch.Move.PULSE, "phase two rotation repeats pulse seed")
	var transition_msgs := messages.filter(func(m: String) -> bool: return m.contains("阶段转换"))
	check(transition_msgs.size() == 1, "phase change is announced exactly once")
	# ---------- 架势与破绽 ----------
	await clear_lab()
	witch = await fresh_witch()
	reset_player(Vector3(13, 0.05, 9))
	witch.apply_control(1.0)
	check(witch._stance == 25 and witch.state != Witch.State.RECOVER, "first hard control converts to twenty-five stance without interrupting")
	witch.apply_control(1.0)
	check(witch._stance == 25, "stance sources are gated to one request per second")
	step_boss(1.0)
	witch.apply_control(1.0)
	step_boss(1.0)
	witch.apply_control(1.0)
	step_boss(1.0)
	witch.apply_control(1.0)
	check(witch._stance == 0 and witch.state == Witch.State.RECOVER and witch._broken, "one hundred stance triggers the two second break")
	applied_total = 0
	witch.damage_received.connect(func(a: int) -> void: applied_total += a)
	check(witch.take_damage(2) and applied_total == 4, "damage during the break is doubled")
	step_boss(2.1)
	check(witch.state == Witch.State.CHASE and not witch._broken, "break ends and double damage window closes")
	step_boss(1.0)
	witch.apply_control(1.0)
	step_boss(1.0)
	witch.apply_control(1.0)
	step_boss(1.0)
	witch.apply_control(1.0)
	step_boss(1.0)
	witch.apply_control(1.0)
	check(witch.state != Witch.State.RECOVER, "break triggers at most once per phase")
	# ---------- 死亡与奖励幂等 ----------
	await clear_lab()
	witch = await fresh_witch()
	reward_count = 0
	dissolve_count = 0
	witch.reward_requested.connect(func(_s: String, _c: int) -> void: reward_count += 1)
	witch.minions_dissolved.connect(func() -> void: dissolve_count += 1)
	died_total = 0
	witch.died.connect(func() -> void: died_total += 1)
	var death_adapter: Array[Node] = []
	witch.enemy_died.connect(func(enemy: Node3D) -> void: death_adapter.append(enemy))
	check(witch.take_damage(999), "lethal damage accepted")
	check(not witch.take_damage(999) and reward_count == 1 and died_total == 1 and dissolve_count == 1, "death reward and minion dissolve are idempotent")
	check(death_adapter.size() == 1 and death_adapter[0] == witch, "team enemy_died signal passes the actor exactly once")
	await frames(45)
	check(not is_instance_valid(witch), "death animation releases the boss actor")
	var dead_guard := Factory.create("spore_guard", player)
	lab.arena.add_child(dead_guard)
	dead_guard.set_encounter_active(true)
	check(not dead_guard.has_signal("reward_requested"), "spore guard cannot emit rewards")
	dead_guard.take_damage(999)
	await frames(2)
	check(dead_guard.is_dead(), "spore guard dies without coin drops")
	# ---------- 休眠清理与暂停 ----------
	witch = await fresh_witch()
	reset_player(Vector3(0, 0.05, 2))
	witch._spawn_pool(Vector3(0, 0.05, 2))
	await frames(3)
	check(count_kind("pool") == 1, "active witch maintains its hazards")
	witch.set_encounter_active(false)
	await frames(20)
	check(count_kind("pool") == 0, "stopping the room clears witch hazards")
	witch.set_encounter_active(true)
	check(witch.take_damage(1), "reactivated witch accepts damage again")
	await clear_lab()
	lab.load_wave(0)
	await frames(3)
	check(lab.wave == 0 and lab._actors.size() == 1, "laboratory loads the solo witch encounter")
	var live_witch: Node = null
	for actor in lab._actors:
		if actor.enemy_id == "witch": live_witch = actor
	paused = true
	var at_state: int = live_witch.state
	var at_remaining: float = live_witch._remaining
	await create_timer(0.1).timeout
	check(live_witch.state == at_state and live_witch._remaining == at_remaining, "pause freezes the boss state machine")
	paused = false
	lab.load_wave(1)
	await frames(3)
	var living := 0
	for actor in lab._actors:
		if actor.enemy_id == "witch": living = actor._living_minions()
	check(lab._actors.size() == 3 and living == 2, "laboratory registers two spore guards with the boss")
	lab.load_wave(2)
	await frames(3)
	for actor in lab._actors:
		if actor.enemy_id == "witch":
			check(actor.hp <= actor.max_hp / 2, "half health wave demonstrates the phase two entry")
	await clear_lab()
	# 房间适配器：非原点、召唤登记、死亡与奖励转发。
	var room := RoomStub.new()
	var marker := Marker3D.new()
	marker.name = "Spawn"
	room.add_child(marker)
	lab.arena.add_child(room)
	room.position = Vector3(50, 0, 40)
	var spawner := preload("enemy_spawner.gd").new()
	lab.arena.add_child(spawner)
	check(spawner.spawn_for_room(room, player, "", Vector3(50, 0, 40)) == null, "room adapter rejects empty reward identity")
	var room_boss := spawner.spawn_for_room(room, player, "test:room:witch", Vector3(50, 0, 40))
	check(room_boss != null and not room_boss.is_encounter_active() and room_boss.global_position == marker.global_position, "room adapter reads Marker3D and leaves boss dormant")
	check(room_boss._clamp_to_arena(Vector3(100, 0, 100)) == Vector3(62, 0, 50), "arena bounds follow a translated room center")
	spawner.set_encounter_active(true)
	room_boss.set_physics_process(false)
	room_boss.begin_attack(Witch.Move.GUARD)
	await frames(3)
	check(spawner.guards.size() == 2 and room_boss._living_minions() == 2, "adapter spawns and registers both minions")
	spawner.set_encounter_active(false)
	await frames(3)
	check(spawner.guards.is_empty() and room_boss.state == Witch.State.IDLE, "adapter stop clears guards and resets direct cast state")
	spawner.set_encounter_active(true)
	room_boss.begin_attack(Witch.Move.GUARD)
	await frames(3)
	check(spawner.guards.size() == 2, "adapter supports stop then restart without losing summon callbacks")
	var room_rewards: Array[String] = []
	spawner.reward_requested.connect(func(id: String, _coins: int) -> void: room_rewards.append(id))
	room_boss.take_damage(999)
	await frames(3)
	check(spawner.guards.is_empty() and room_rewards == ["test:room:witch"], "adapter dissolves minions and forwards stable reward identity")
	spawner.clear_encounter()
	spawner.queue_free()
	room.queue_free()
	await frames(3)
	print("LEVEL04_TEST_RESULT passed=%d failed=%d" % [passed, failed])
	quit(1 if failed else 0)
