extends SceneTree
var checks := 0
var failures := 0
var cues: Array[StringName] = []
func _initialize() -> void: run.call_deferred()
func frames(n: int = 6) -> void:
	for i in n: await physics_frame
	await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)
func run() -> void:
	preload("res://scripts/integration/player_profile.gd").override_path = "res://.godot/tutorial_profile.cfg"
	preload("res://scripts/integration/campaign_progress.gd").override_path = "res://.godot/tutorial_campaign.cfg"
	preload("res://scenes/player/character_catalog.gd").selected_id = "knight"
	change_scene_to_file("res://Main.tscn")
	await frames()
	var main := current_scene
	var player = main._player
	var tutorial := main.get_node("RunBindings/TutorialController")
	var audio := main.get_node("GameSfx")
	audio.cue_played.connect(func(cue: StringName) -> void: cues.append(cue))
	main._on_run_started()
	await frames()
	for action in ["move_forward", "move_left", "move_backward", "move_right"]:
		Input.action_press(action)
		await frames(8)
		Input.action_release(action)
		await frames(2)
	check(tutorial.index == 1, "four real movement directions complete lesson")
	player.global_position = main._dungeon.get_node("EntrancePotion").global_position + Vector3(0, 0, 0.6)
	await frames()
	check(main._items.try_interact_nearest(), "real E interaction succeeds")
	check(tutorial.index == 2 and &"pickup" in cues, "pickup progresses lesson and plays sound")
	check(player.get_node("MeleeAttack").try_attack(), "J attack succeeds")
	check(tutorial.index == 3, "accepted J advances attack lesson")
	await frames(35)
	check(player.get_node("EnergyShock").try_cast(), "K cast succeeds")
	check(tutorial.index == 4 and &"spell" in cues, "accepted K advances spell lesson and sound")
	check(player.try_dodge(), "dodge succeeds")
	check(tutorial.index == 5 and player.hp < player.max_hp, "dodge advances and prepares heal opportunity")
	await frames(20)
	check(main._items.try_use_potion(), "tutorial potion heals")
	check(tutorial.index == 6 and player.hp == player.max_hp, "successful healing advances lesson")
	await frames(20)
	check(main._items.rune_count == 0 and not main._hud.get_node("%TutorialPrompt").visible, "rune lesson waits without a free rune in starting room")
	player.global_position = main._dungeon.get_node("AttackRune").global_position + Vector3(0, 0, 0.7)
	await frames()
	check(main._hud._tutorial_message == "rune_pickup", "branch rune shows pickup lesson")
	check(main._items.try_interact_nearest(), "actual branch rune picked up")
	await frames()
	check(main._hud._tutorial_message == "rune", "owning rune shows F lesson")
	check(main._items.try_use_rune(), "tutorial rune activates")
	check(tutorial.finished and not main._hud.get_node("%TutorialPrompt").visible, "all seven lessons finish and hide prompt")
	check(cues.count(&"item_use") == 2, "successful potion and rune each play one cue")
	await frames(20)
	check(not main._items.try_use_potion() and cues.count(&"item_use") == 2, "rejected full-health use is silent")
	var before := cues.count(&"hit")
	audio.play_cue(&"hit")
	audio.play_cue(&"hit")
	check(cues.count(&"hit") == before + 1, "duplicate callbacks play one cue per frame")
	check(main.set_paused(true), "pause succeeds")
	before = cues.count(&"spell")
	audio.play_cue(&"spell")
	check(cues.count(&"spell") == before, "paused world rejects gameplay sound")
	paused = false
	current_scene = null
	main.free()
	await frames()
	print("TUTORIAL AUDIO: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
