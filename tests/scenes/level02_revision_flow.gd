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
	var test_id := str(Time.get_ticks_usec())
	Profile.override_path = "user://flow-profile-%s.cfg" % test_id
	Campaign.override_path = "user://flow-campaign-%s.cfg" % test_id
	Profile.ensure_loaded()
	Profile.coins = 100
	Profile.settled_runs = []
	Profile.save()
	change_scene_to_file("res://scenes/dungeon/Level02Run.tscn")
	await scene_changed
	await frames()
	var h := current_scene
	var map: Node = h.get_node("DungeonTest")
	var player: CharacterBody3D = map.player
	h._on_run_started()
	player.set_physics_process(false)
	player._invulnerability_remaining = 100000.0
	var items: Node = player.get_node("ItemInventory")
	items.add_gold(37)
	var exit: Area3D = map.get_node("ExitArea")
	# Project the real trigger onto the floor so the player's body overlaps it.
	var exit_position := Vector3(exit.global_position.x, player.global_position.y, exit.global_position.z)
	await go(player, exit_position)
	check(exit.overlaps_body(player), "premature exit check uses the physical trigger")
	check(h._run_state == h.RunState.PLAYING and Profile.coins == 100, "premature exit cannot settle")
	for room in [0, 1, 2]:
		var region: Node3D = map.get_node("Regions/" + ["Hub", "Relay", "Antechamber"][room])
		await go(player, region.global_position + Vector3.UP * 0.05)
		var enemies: Array = [["Hub1", "Hub2"], ["Relay1", "Relay2"], ["Antechamber1", "Antechamber2", "Antechamber3"]][room]
		for id in enemies: check(map.get_node("Enemies/" + id).take_damage(999), "real kill " + id)
		await create_timer(1.05).timeout
		if room == 1:
			var relay: Node3D = map.get_node("Devices/Relay")
			await go(player, relay.global_position + Vector3(0, 0.05, 1.35))
			check(items.try_interact_nearest() and map.relay_activated, "real relay interaction activates after room clear")
	check(Profile.coins == 100, "clearing all three rooms still does not bank")
	await go(player, map.get_node("Regions/Boss").global_position + Vector3(0, 0.05, 4))
	check(map.boss.take_damage(999), "real boss death")
	check(h._run_state == h.RunState.PLAYING and Profile.coins == 100, "boss death alone cannot settle")
	await create_timer(1.1).timeout
	await go(player, exit_position)
	await frames(12)
	check(h._run_state == h.RunState.VICTORY and Profile.coins == 137, "physical exit banks exactly pending coins")
	h._on_exit_reached()
	check(Profile.coins == 137, "duplicate exit callback cannot double pay")
	var restarted: bool = h.restart_run()
	check(restarted, "victory allows restart")
	if restarted: await scene_changed
	await frames(12)
	check(current_scene._items.gold == 0 and Profile.coins == 137, "restart clears pending and preserves permanent balance")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.override_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.override_path))
	print("FLOW_RESULT checks=%d failed=%d" % [checks, failures])
	quit(1 if failures else 0)
