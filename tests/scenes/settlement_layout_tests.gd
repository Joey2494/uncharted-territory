extends SceneTree
## Merge regression: reward fields and wallet status coexist, including five actions.
var failures := 0
var checks := 0

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var capture := "--capture" in OS.get_cmdline_user_args()
	var output := "user://settlement-layout"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if capture: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.mode = Window.MODE_WINDOWED
	for level in [2, 3]:
		for saved in [false, true]:
			var data := {"level_id":level, "elapsed_seconds":125.0, "rooms_visited":10, "rooms_total":10, "player_hp":12, "player_max_hp":16, "puzzle_solved":true, "reward_claimed":true, "settlement_ok":saved, "settled_gold":37 if saved else 0, "boss_name":"灾厄巨蝎", "boss_defeated":true}
			if level == 3:
				data.merge({"completion_summary":"最终守卫已清除 · 成功抵达远航出口", "puzzle_name":"潮汐机关", "reward_name":"溢流花园奖励"}, true)
			var screen: Control = load("res://scenes/ui/win_screen.tscn").instantiate()
			screen.offer_next_level = level == 2
			screen.set_run_result(data)
			root.add_child(screen)
			for dimensions in [Vector2i(1280,720), Vector2i(720,720)]:
				root.size = dimensions
				if capture: await create_timer(2.2).timeout
				else:
					for i in 10: await process_frame
				var controls: Array[Control] = [screen.get_node("%ResultDetails"), screen.get_node("%RewardsPanel"), screen.get_node("%SettlementLabel"), screen.get_node("%ProgressLabel"), screen.restart_button, screen.get_node("%LevelSelectButton"), screen.get_node("%MainMenuButton")]
				if screen._retry.visible: controls.append(screen._retry)
				if screen.next_level_button.visible: controls.append(screen.next_level_button)
				var okay := true
				for i in controls.size():
					okay = okay and root.get_visible_rect().encloses(controls[i].get_global_rect())
					for j in range(i+1,controls.size()):
						if controls[i].get_global_rect().intersects(controls[j].get_global_rect()):
							okay = false
							print("LAYOUT_OVERLAP ", controls[i].name, " ", controls[j].name)
				check(okay, "level=%d saved=%s size=%s: result, wallet and actions fit without overlaps" % [level,saved,dimensions])
				if capture:
					await RenderingServer.frame_post_draw
					var result := root.get_texture().get_image().save_png(output.path_join("level%d-%s-%dx%d.png" % [level,"saved" if saved else "retry",dimensions.x,dimensions.y]))
					check(result == OK, "rendered settlement screenshot saved")
			screen.queue_free()
			await process_frame
	print("SETTLEMENT_LAYOUT_RESULT checks=%d failed=%d" % [checks,failures])
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)
