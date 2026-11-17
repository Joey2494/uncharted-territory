extends Node
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--revision-smoke"):
		preload("res://scripts/integration/player_profile.gd").override_path = "user://revision_smoke_profile.cfg"
		preload("res://scripts/integration/campaign_progress.gd").override_path = "user://revision_smoke_campaign.cfg"
		var host := preload("res://scenes/dungeon/Level02Run.tscn").instantiate()
		get_tree().root.add_child.call_deferred(host)
		await get_tree().process_frame
		await get_tree().process_frame
		host._on_run_started()
		var ok: bool = host._run_state == host.RunState.PLAYING and host._dungeon.is_run_active()
		print("REVISION_PACKAGE_SMOKE ", "PASS" if ok else "FAIL")
		get_tree().quit(0 if ok else 1)
	else:
		get_tree().change_scene_to_file.call_deferred("res://Main.tscn" if args.has("--level01") else "res://scenes/dungeon/Level02Run.tscn")
