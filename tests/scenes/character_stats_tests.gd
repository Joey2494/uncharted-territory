extends SceneTree
## Compare the menu with real initialized players, then exercise switching and resizing.
const CATALOG = preload("res://scenes/player/character_catalog.gd")
const DOSSIERS = preload("res://scenes/ui/character_dossiers.gd")
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const RANGES = preload("res://scenes/ui/character_stat_ranges.gd")
var OUT := OS.get_environment("GODOT_TEST_OUTPUT_DIR") if not OS.get_environment("GODOT_TEST_OUTPUT_DIR").is_empty() else ProjectSettings.globalize_path("user://verification")
const SCALES := {"Attack":2.0,"Health":6.0,"Shield":2.0,"Speed":6.0}
var selector: Control
var failures := 0
var checks := 0

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	PROFILE.override_path = OUT.path_join("isolated-profile.cfg")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	selector = load("res://scenes/ui/character_select.tscn").instantiate()
	root.add_child(selector)
	await frames(5)
	for id in CATALOG.IDS:
		selector.show_selection(id)
		await frames(5)
		var actor: Node = load("res://scenes/player/Player%s.tscn" % id.capitalize()).instantiate()
		root.add_child(actor)
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		check(stat("Attack") == str(actor.get_attack_damage(actor.get_node("MeleeAttack").attack_damage)), id+": attack equals the actual unbuffed melee damage")
		check(stat("Shield") == str(actor.max_shield), id+": shield equals actual starting shield")
		check(stat("Health") == str(actor.max_hp), id+": health equals actual maximum HP")
		check(stat("Speed") == "%.1f" % minf(actor.walk_speed,actor.move_speed), id+": speed equals actual ordinary movement speed")
		var spell: Node = actor.get_node("EnergyShock")
		check(actor.get_node("MeleeAttack").attack_cooldown == 0.5 and spell.damage == 2 and spell.cooldown == 0.8 and spell.max_distance == 10.0 and actor.get_spell_cost() == 5.0, id+": described base J/K intervals, damage, range and energy cost match the actual components")
		check(actor.dodge_distance == 3.0 and actor.dodge_duration == 0.2 and actor.dodge_invulnerability == 0.2 and actor.dodge_cooldown == 0.8 and actor.energy_regeneration == 5.0, id+": described dodge and energy regeneration match the actual player")
		check(selector.get_node("%CharacterDescription").text == DOSSIERS.entry(id).summary and selector.get_node("%CharacterDescription").text.count("。") == 2, id+": bottom summary is two sentences")
		check(selector.get_node("%SkillTitleRow").tooltip_text.contains(CATALOG.ability_definition(id).description), id+": complete actual skill effect remains available on hover")
		var actual := {"Attack":float(actor.get_node("MeleeAttack").attack_damage),"Health":float(actor.max_hp),"Shield":float(actor.max_shield),"Speed":minf(actor.walk_speed,actor.move_speed)}
		for attribute: String in actual:
			var card: Control = selector.get_node("%"+attribute+"Stat")
			var bar: ProgressBar = card.get_node("%ComparisonBar")
			check(is_equal_approx(bar.value,actual[attribute]) and is_equal_approx(bar.max_value,SCALES[attribute]) and bar.min_value == 0.0 and not bar.show_percentage, id+": "+attribute+" bar uses raw game units on its stable independent scale")
			check(not card.get_node("%ComparisonLabel").visible and card.get_node("%ComparisonLabel").text.is_empty() and not card.get_node("%ReferenceMarker").visible and not card.tooltip_text.contains("旅人"), id+": "+attribute+" shows only this character's actual attributes")
		if id == "knight":
			check(selector.get_node("%ShieldStat").get_node("%ComparisonBar").value == 2.0, "Knight displays the approved two starting shields")
		actor.free()
		await verify_layout(id, Vector2i(1280,720))
		if "--capture" in OS.get_cmdline_user_args(): await capture(id+"-1280x720")
	selector.show_selection("knight")
	for id in ["lan","iron","astra","knight"]:
		selector.get_node("%NextButton").pressed.emit()
		await frames(3)
		var data := CATALOG.definition(id)
		check(selector.get_selected_id() == id and stat("Attack") == str(data.attack) and stat("Shield") == str(data.shield) and stat("Health") == str(data.hp) and stat("Speed") == "%.1f" % minf(data.walk,data.run) and is_equal_approx(selector.get_node("%ShieldStat").get_node("%ComparisonBar").value,float(data.shield)), "next button refreshes raw values and bars including wrap-around: "+id)
	var left := InputEventKey.new()
	left.keycode = KEY_LEFT
	left.pressed = true
	root.push_input(left)
	await frames(3)
	check(selector.get_selected_id() == "astra" and stat("Health") == "4", "keyboard cycling also refreshes the same stats")
	check(RANGES.upper_bound_for("hp",7.0) == 8.0 and RANGES.upper_bound_for("shield",4.0) == 4.0 and RANGES.upper_bound_for("attack",12.0) == 12.0 and RANGES.upper_bound_for("speed",6.3) == 7.0, "future larger real configurations expand each scale without truncating values")
	for dimensions in [Vector2i(720,720),Vector2i(540,960),Vector2i(1920,1080)]:
		for id in CATALOG.IDS:
			selector.show_selection(id)
			await verify_layout(id,dimensions)
			if "--capture" in OS.get_cmdline_user_args(): await capture("%s-%dx%d" % [id,dimensions.x,dimensions.y])
	if "--capture" in OS.get_cmdline_user_args():
		selector.show_selection("iron")
		root.size = Vector2i(720,720)
		await frames(6)
		var row: Control = selector.get_node("%SkillTitleRow")
		var motion := InputEventMouseMotion.new()
		motion.position = row.get_global_rect().get_center()
		root.push_input(motion,true)
		check(root.gui_get_hovered_control() == row, "skill detail hover reaches the complete summary row")
		await create_timer(0.8).timeout
		await capture("iron-skill-tooltip-720x720")
	selector.free()
	root.get_node("MusicManager").stop_music()
	await frames(2)
	print("CHARACTER_STATS_RESULT %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func stat(attribute: String) -> String:
	return selector.get_node("%"+attribute+"Stat").get_value()

func verify_layout(id: String, dimensions: Vector2i) -> void:
	root.size = dimensions
	await frames(6)
	var scroll: ScrollContainer = selector.get_node("%InfoScroll")
	var viewport := scroll.get_global_rect().grow(1)
	var fits := true
	for attribute in ["Attack","Health","Shield","Speed"]:
		var card: Control = selector.get_node("%"+attribute+"Stat")
		fits = fits and viewport.encloses(card.get_global_rect())
		var value: Label = card.get_node("%Value")
		fits = fits and card.get_global_rect().encloses(value.get_global_rect())
		for name in ["AttributeLabel","DisplayRange","Meter"]:
			fits = fits and card.get_global_rect().grow(1).encloses(card.get_node("%"+name).get_global_rect())
	check(fits, "%s %dx%d: all four stat cards and values visible without scrolling" % [id,dimensions.x,dimensions.y])
	check(not scroll.get_h_scroll_bar().visible, "%s %dx%d: no horizontal overflow" % [id,dimensions.x,dimensions.y])
	check(selector.get_node("%InfoCard").get_global_rect().end.y <= selector.get_node("%BackButton").get_global_rect().position.y, "%s %dx%d: information does not overlap bottom actions" % [id,dimensions.x,dimensions.y])
	check(viewport.encloses(selector.get_node("%CharacterDescription").get_global_rect()), "%s %dx%d: full short summary visible" % [id,dimensions.x,dimensions.y])
	var skill: Control = selector.get_node("%SkillTitleRow")
	var tooltip: Control = skill._make_custom_tooltip(skill.tooltip_text)
	root.add_child(tooltip)
	check(tooltip.get_combined_minimum_size().x <= root.get_visible_rect().size.x, "%s %dx%d: full skill tooltip fits in the viewport" % [id,dimensions.x,dimensions.y])
	tooltip.free()
	selector.get_node("%MechanicsButton").pressed.emit()
	await frames(3)
	var panel: Control = selector.get_node("%MechanicsPanel")
	var details_scroll: ScrollContainer = selector.get_node("%MechanicsScroll")
	check(root.get_visible_rect().encloses(panel.get_global_rect()) and panel.get_global_rect().encloses(selector.get_node("%CloseMechanicsButton").get_global_rect()), "%s %dx%d: mechanics panel and close action stay within the viewport" % [id,dimensions.x,dimensions.y])
	check(not details_scroll.get_h_scroll_bar().visible and selector.get_node("%MechanicsText").size.x <= details_scroll.size.x, "%s %dx%d: mechanics wraps without horizontal overflow" % [id,dimensions.x,dimensions.y])
	details_scroll.scroll_vertical = int(details_scroll.get_v_scroll_bar().max_value)
	await frames(2)
	check(details_scroll.get_v_scroll_bar().value + details_scroll.get_v_scroll_bar().page >= details_scroll.get_v_scroll_bar().max_value - 1, "%s %dx%d: final gameplay tips are reachable by scrolling" % [id,dimensions.x,dimensions.y])
	if "--capture" in OS.get_cmdline_user_args(): await capture("%s-mechanics-%dx%d" % [id,dimensions.x,dimensions.y])
	selector.get_node("%CloseMechanicsButton").pressed.emit()

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT.path_join(label+".png"))

func frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
