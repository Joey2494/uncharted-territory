extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	preload("res://scripts/integration/player_profile.gd").override_path = "res://.godot/badge_layout_profile.cfg"
	preload("res://scripts/integration/campaign_progress.gd").override_path = "res://.godot/badge_layout_progress.cfg"
	run.call_deferred()
func frames(count: int = 8) -> void:
	for i in count: await process_frame
func check(ok: bool, context: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ",context)
func glyph_rect(badge: Control, label: Label) -> Rect2:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var extent := Vector2(font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x,font.get_height(font_size))
	var top_left := badge.get_global_transform().affine_inverse()*label.global_position
	return Rect2(top_left+(label.size-extent)*0.5,extent)
func inspect(badge: Control, state: String) -> void:
	badge.update_cooldown(0.2 if state == "冷却" else 0.0,0.2,"" if state in ["可用","冷却"] else state)
	var radius := minf(badge.size.x,badge.size.y)*0.5
	var center := badge.size*0.5
	var bounds: Array[Rect2] = []
	for label: Label in [badge.get_node("%InputHint"),badge.get_node("%StateLabel")]:
		var rect := glyph_rect(badge,label)
		bounds.append(rect)
		var contained := true
		for corner in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y)]:
			contained = contained and center.distance_to(corner) <= radius-2.0
		check(contained,"glyphs inside circle: %s %s %s" % [badge.name,state,label.text])
	check(not bounds[0].intersects(bounds[1]),"key and state do not overlap")
	var icon: Control = badge.get_node("%AbilityIcon")
	var icon_origin := badge.get_global_transform().affine_inverse()*icon.global_position
	var icon_rect := Rect2(icon_origin,icon.size)
	check(not icon_rect.intersects(bounds[0]) and not icon_rect.intersects(bounds[1]),"icon and glyphs do not overlap")
func run() -> void:
	for scene in ["res://Main.tscn","res://scenes/dungeon/Level02Run.tscn"]:
		change_scene_to_file(scene)
		await frames(12)
		var host := current_scene
		host._on_run_started()
		await frames()
		for viewport_size in [Vector2i(1280,720),Vector2i(900,600),Vector2i(720,480)]:
			root.size = viewport_size
			await frames()
			var badges: Array[Control] = []
			var cluster: Control = host.get_node("UILayer/HUD/CooldownBar")
			var primary: Control = cluster.get_node("MeleeCooldown")
			check(primary.get_global_rect().end.distance_to(cluster.get_global_rect().end) < 1.0,"J stays at the original bottom-right edge")
			for badge: Control in cluster.get_children():
				if badge.is_visible_in_tree(): badges.append(badge)
			for i in badges.size():
				var button: Button = badges[i].get_node("%ActivateButton")
				check(button._has_point(button.size*0.5) and not button._has_point(Vector2.ZERO),"click region follows the visible circle")
				for j in range(i+1,badges.size()):
					var a := badges[i].get_global_rect()
					var b := badges[j].get_global_rect()
					check(a.get_center().distance_to(b.get_center()) >= (minf(a.size.x,a.size.y)+minf(b.size.x,b.size.y))*0.5+4.0,"badge circles separated")
				for state in ["可用","暂不可用","法力不足","闪避中","冷却","弹匣已满","法力已满","无需补给"]: inspect(badges[i],state)
	current_scene.queue_free()
	await frames()
	print("BADGE_LAYOUT_RESULT checks=%d failed=%d" % [checks,failures])
	quit(1 if failures else 0)
