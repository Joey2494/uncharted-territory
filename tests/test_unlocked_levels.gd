extends SceneTree
const Progress = preload("res://scripts/integration/campaign_progress.gd")
const Profile = preload("res://scripts/integration/player_profile.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func frames(n := 8) -> void:
	for i in n: await physics_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)
func run() -> void:
	var token := str(Time.get_ticks_usec())
	Profile.override_path = "res://.godot/unlocked-profile-" + token + ".cfg"
	Progress.override_path = "res://.godot/unlocked-campaign-" + token + ".cfg"
	change_scene_to_file("res://Main.tscn")
	await frames()
	var host := current_scene
	var nav: Node = host.get_node("MenuNavigation")
	check(nav.progress.completed.is_empty() and nav.progress.played.is_empty(), "fresh save has no fabricated progress")
	check(host._start_screen.get_node("%ContinueButton").disabled, "fresh save still has no continue target")
	check(Profile.coins == 0 and Profile.unlocked == ["knight"], "level access does not alter wallet or character ownership")
	host._start_screen.start_button.pressed.emit()
	nav.character_select.get_node("%ConfirmButton").pressed.emit()
	await frames(3)
	for id in Progress.LEVEL_IDS:
		var button: Button = nav.level_select.get_level_button(StringName(id))
		check(nav.progress.is_unlocked(StringName(id)), id + " is accessible without prior completion")
		check(not button.disabled and button.icon == null, id + " has an enabled tile without a lock icon")
	check(not nav.progress.is_unlocked(&"level0") and not nav.progress.is_unlocked(&"level5"), "unknown levels remain invalid")
	nav.level_select.get_level_button(&"level4").pressed.emit()
	await frames(12)
	host = current_scene
	nav = host.get_node("MenuNavigation")
	check(host.level_id == 4 and not host.practice_run and host.get_run_state() == host.RunState.PLAYING, "fresh save directly starts the fourth campaign level")
	check(nav.progress.completed.is_empty() and nav.progress.played == ["level4"], "direct entry records only the level actually played")
	check(nav.progress.get_last_played_level() == &"level4", "direct entry becomes the real continue target")
	nav.host.get_node("RunBindings").return_to_menu()
	await frames(12)
	host = current_scene
	check(not host._start_screen.get_node("%ContinueButton").disabled, "returning home enables Continue after playing")
	host._start_screen.get_node("%ContinueButton").pressed.emit()
	await frames(12)
	host = current_scene
	check(host.level_id == 4 and not host.practice_run and host.get_run_state() == host.RunState.PLAYING, "Continue directly reopens the fourth campaign level")
	host.queue_free()
	await frames(3)
	root.get_node("MusicManager").stop_music()
	await create_timer(0.15).timeout
	print("UNLOCKED_LEVELS_RESULT %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
