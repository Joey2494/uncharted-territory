extends SceneTree
## 在导出的 PCK 内验证两个真实关卡入口，失败以非零状态退出。
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	print("PACKAGE ", "PASS: " if ok else "FAIL: ", description)
	if not ok:
		failures += 1

func run() -> void:
	check(str(ProjectSettings.get_setting("application/config/version", "")).begins_with("week09-"), "固定提交版本已注入")
	for path in ["res://Main.tscn", "res://tests/scenes/Level02Preview.tscn"]:
		var packed := load(path) as PackedScene
		check(packed != null, "资源可加载：" + path)
		if packed == null:
			continue
		var scene := packed.instantiate()
		root.add_child(scene)
		current_scene = scene
		await process_frame
		if path.ends_with("Main.tscn"):
			scene._on_run_started()
			await physics_frame
			check(scene.get_node("DungeonTest").request_tutorial_skip(), "第一关教学可主动跳过")
		else:
			scene.start_run()
			await physics_frame
			check(scene.get_node("Level02").is_run_active(), "第二关可开始")
		for i in 90:
			await physics_frame
		paused = false
		scene.queue_free()
		await process_frame
	print("PACKAGE_SMOKE: ", failures, " failures")
	quit(0 if failures == 0 else 1)
