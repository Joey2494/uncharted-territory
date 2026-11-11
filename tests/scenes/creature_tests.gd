extends SceneTree

var passed := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	passed += int(condition)
	failed += int(not condition)
	print("PASS " if condition else "FAIL ", label)


func frames(count := 3) -> void:
	for i in range(count):
		await physics_frame
	await process_frame


func _run() -> void:
	var actors := ["res://scenes/enemies/RuinCrawler.tscn", "res://scenes/enemies/RuinSentinel.tscn", "res://scenes/bosses/RuinColossus.tscn"]
	for path in actors:
		var actor: Node3D = load(path).instantiate()
		# No tree/_ready(): this is the property the old Boss failed.
		var visual := actor.get_node("Visuals/Model")
		var meshes := visual.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() >= 80, path.get_file() + " has saved geometry before ready")
		check(visual.find_children("Leg*", "Node3D", false, false).size() == 8, "eight authored limbs")
		check(visual.find_children("*Skeleton*", "", true, false).is_empty(), "no tiny skeleton placeholder")
		check(actor.get_meta("camera_radius", 0) > 1.5, "silhouette framing metadata")
		if path.contains("Colossus"):
			check(visual.has_node("Tail") and visual.has_node("ClawL/Jaw") and visual.has_node("ClawR/Jaw"), "Boss tail and both articulated pincers")
		actor.free()
	for size in [Vector2i(1280, 720), Vector2i(720, 720)]:
		root.size = size
		for kind in ["Crawler", "Sentinel", "Colossus"]:
			var folder := "bosses" if kind == "Colossus" else "enemies"
			var scene: Node3D = load("res://scenes/%s/Ruin%sPreview.tscn" % [folder, kind]).instantiate()
			root.add_child(scene)
			await frames()
			var camera := scene.get_node("Camera3D") as Camera3D
			check(camera.current, "%s %s preview has current camera" % [kind, size])
			var viewport := Rect2(Vector2(8, 80), Vector2(size.x - 16, size.y - 88))
			var model: Node3D = scene.get_node("Slot/Model")
			var inside := true
			for mesh in model.find_children("*", "MeshInstance3D", true, false):
				var bounds: AABB = mesh.get_aabb()
				for corner in range(8):
					var point: Vector3 = mesh.global_transform * bounds.get_endpoint(corner)
					if camera.is_position_behind(point) or not viewport.has_point(camera.unproject_position(point)):
						inside = false
			check(inside, "%s %s complete model fits outside toolbar" % [kind, size])
			var distance: float = scene._distance
			scene.zoom(0.8)
			check(scene._distance < distance, "zoom control changes distance")
			scene.reset_view()
			check(is_equal_approx(scene._distance, scene.base_distance), "reset restores framing")
			var yaw: float = scene._yaw
			scene._rotating = true
			scene._process(0.1)
			check(scene._yaw > yaw, "rotation control moves view")
			scene.queue_free()
			await frames()
		var combat: Node3D = load("res://scenes/dungeon/LevelTwoCombat.tscn").instantiate()
		root.add_child(combat)
		for name in ["Player", "Sentinel", "MeleeEnemy", "RuinColossus"]:
			combat.get_node("World/" + name).set_physics_process(false)
		await frames(5)
		var boss := combat.get_node("World/RuinColossus")
		var camera := combat.get_node("World/Camera3D")
		var bar := combat.find_children("BossHealthBar", "PanelContainer", true, false)[0] as PanelContainer
		check(bar.visible and bar.title_label.text == "灾厄巨蝎", "Boss bar visible at initial spawn")
		check(not boss._active and boss.state == 0, "initial preview does not force battle activation")
		var frame: Rect2 = camera.get_safe_frame()
		check(frame.size.y > 0.43, "combat framing reserves useful vertical space")
		var contained := true
		for actor in camera._get_actors():
			var point: Vector2 = camera.unproject_position(actor.global_position + Vector3.UP)
			if not frame.has_point(point / Vector2(size)):
				contained = false
		check(contained, "player and all three enemies visible at initial spawn")
		var crawler := combat.get_node("World/MeleeEnemy")
		check(crawler.get_node("Visuals/Model").creature_kind == 0, "combat melee actor uses spider")
		check(crawler.take_damage(99), "new crawler accepts fatal damage")
		await frames(55)
		check(not is_instance_valid(crawler), "new crawler death animation frees actor")
		combat.queue_free()
		await frames()
	print("CREATURE_RESULT passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)
