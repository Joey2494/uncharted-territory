extends SceneTree
const Profile = preload("res://scripts/integration/player_profile.gd")
const Campaign = preload("res://scripts/integration/campaign_progress.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)
func frames(count := 6) -> void:
	for i in count: await physics_frame
	await process_frame
func go(player: Node3D, at: Vector3) -> void:
	player.global_position = at
	await frames()
func run() -> void:
	Profile.override_path = "res://tests/flow_profile.cfg"
	Campaign.override_path = "res://tests/flow_campaign.cfg"
	Profile.ensure_loaded()
	Profile.coins = 100
	Profile.settled_runs = []
	Profile.save()
	change_scene_to_file("res://scenes/dungeon/Level02Run.tscn")
	await frames()
	var h := current_scene
	var map: Node = h.get_node("DungeonTest")
	var player: CharacterBody3D = map.player
	h._on_run_started()
	player.set_physics_process(false)
	var items: Node = player.get_node("ItemInventory")
	items.add_gold(37)
	await go(player, Vector3(34, 0.05, -111))
	check(h._run_state == h.RunState.PLAYING and Profile.coins == 100, "premature exit cannot settle")
	for room in [0, 1, 2]:
		await go(player, [Vector3(0, 0.05, -26), Vector3(34, 0.05, -26), Vector3(34, 0.05, -56)][room])
		var enemies: Array = [["Hub1", "Hub2"], ["Relay1", "Relay2"], ["Antechamber1", "Antechamber2", "Antechamber3"]][room]
		for id in enemies: check(map.get_node("Enemies/" + id).take_damage(999), "real kill " + id)
		await create_timer(1.05).timeout
		if room == 1: check(map.perform_control(&"relay", player), "relay activates after room clear")
	check(Profile.coins == 100, "clearing all three rooms still does not bank")
	await go(player, Vector3(34, 0.05, -80))
	check(map.boss.take_damage(999), "real boss death")
	check(h._run_state == h.RunState.PLAYING and Profile.coins == 100, "boss death alone cannot settle")
	await create_timer(1.1).timeout
	await go(player, Vector3(34, 0.05, -111))
	await frames(12)
	check(h._run_state == h.RunState.VICTORY and Profile.coins == 137, "physical exit banks exactly pending coins")
	h._on_exit_reached()
	check(Profile.coins == 137, "duplicate exit callback cannot double pay")
	check(h.restart_run(), "victory allows restart")
	await frames(12)
	check(current_scene._items.gold == 0 and Profile.coins == 137, "restart clears pending and preserves permanent balance")
	print("FLOW_RESULT checks=%d failed=%d" % [checks, failures])
	quit(1 if failures else 0)
