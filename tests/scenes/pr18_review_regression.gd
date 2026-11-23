extends "res://tests/scenes/campaign_quest_tests.gd"
## 实际主线交互与可见任务/地图复核，复用完整第三关尺寸矩阵。
func run() -> void:
	var token := "%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	PROFILE.override_path = "res://.godot/review-quest-profile-"+token+".cfg"
	PROGRESS.override_path = "res://.godot/review-quest-progress-"+token+".cfg"
	capture_enabled = "--capture" in OS.get_cmdline_user_args()
	out = "res://docs/review/pr18-evidence"
	if capture_enabled: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await third()
	paused = false
	root.get_node("MusicManager").stop_music()
	current_scene.queue_free()
	await frames(3)
	print("PR18_REVIEW_QUEST_RESULT %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	super.check(ok,message)
	if message.begins_with("Existing nearest") or message.begins_with("Current real") or not ok:
		print("CHECK ",message)

func matrix(label: String) -> void:
	await super.matrix(label)
	if capture_enabled and label == "third-before-release":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("review-release-journal.png"))
