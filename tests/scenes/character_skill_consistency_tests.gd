extends SceneTree
const CATALOG = preload("res://scenes/player/character_catalog.gd")
const DOSSIERS = preload("res://scenes/ui/character_dossiers.gd")
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
const ICON_PATHS := {
	"knight":"res://assets/ui/energy.svg",
	"lan":"res://assets/ui/skill_focus.svg",
	"iron":"res://assets/ui/skill_counter.svg",
	"astra":"res://assets/ui/skill_gravity.svg",
}
var host: Node
var checks := 0
var failures := 0
var OUT := OS.get_environment("GODOT_TEST_OUTPUT_DIR") if not OS.get_environment("GODOT_TEST_OUTPUT_DIR").is_empty() else "res://.godot/skill-consistency"

class Target extends CharacterBody3D:
	var damage := 0
	var controls: Array[float] = []
	var slows: Array[float] = []
	func take_damage(amount: int) -> bool:
		damage += amount
		return true
	func apply_control(duration: float) -> void: controls.append(duration)
	func apply_slow(duration: float) -> void: slows.append(duration)

func _initialize() -> void: run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	PROFILE.override_path = test_save_path("skill-consistency-profile")
	PROGRESS.override_path = test_save_path("skill-consistency-campaign")
	PROFILE.set_coins(1000)
	for id in ["lan","iron","astra"]: PROFILE.unlock_character(id)
	change_scene_to_file("res://Main.tscn")
	await frames(8)
	host = current_scene
	await preview_roles()
	for id in ["lan","iron","astra","knight","lan"]:
		await start_role(id)
		check_hud(id)
		await check_behavior(id)
	await scene_handoffs()
	await finish()

func preview_roles() -> void:
	host._start_screen.start_button.pressed.emit()
	var selector: Control = host.get_node("MenuNavigation").character_select
	for id in ["knight","lan","iron","astra","lan"]:
		selector.show_selection(id)
		await frames(3)
		check(selector.get_node("%SkillName").text == CATALOG.definition(id).skill, id+": dossier name matches the actual configured ability")
		var icon: TextureRect = selector.get_node_or_null("%SkillIcon")
		check(icon != null and icon.texture != null and icon.texture.resource_path == ICON_PATHS[id], id+": dossier has the current ability's own icon")
		var skill_tooltip: String = selector.get_node("%SkillTitleRow").tooltip_text
		check(skill_tooltip.contains(DOSSIERS.entry(id).effect), id+": dossier skill tooltip updates with the displayed character")
		var configuration := CATALOG.ability_definition(id)
		check(skill_tooltip.contains(configuration.description) and DOSSIERS.entry(id).skill_name == configuration.name, id+": dossier presentation comes from the canonical ability configuration")
		check(selector.get_node("%SkillCooldown").text == CATALOG.cooldown_text(id), id+": dossier cooldown states both the actual duration and when it starts")
		selector.get_node("%MechanicsButton").pressed.emit()
		check(selector.get_node("%MechanicsOverlay").visible and selector.get_node("%MechanicsText").text.contains(configuration.description), id+": clickable mechanics includes the same active and passive effects as the actual player/HUD")
		var before: String = selector.get_selected_id()
		var right := InputEventKey.new()
		right.keycode = KEY_RIGHT
		right.pressed = true
		root.push_input(right)
		check(selector.get_selected_id() == before, id+": reading mechanics cannot accidentally cycle the selected character")
		var tab := InputEventKey.new()
		tab.keycode = KEY_TAB
		tab.pressed = true
		root.push_input(tab)
		check(selector.get_node("%MechanicsOverlay").is_ancestor_of(root.gui_get_focus_owner()), id+": keyboard focus remains in the mechanics panel")
		if "--capture" in OS.get_cmdline_user_args(): await capture("mechanics-"+id)
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		root.push_input(escape)
		check(not selector.get_node("%MechanicsOverlay").visible and selector.visible and selector.get_node("%MechanicsButton").has_focus(), id+": Escape returns to the same selection and restores focus")
		if "--capture" in OS.get_cmdline_user_args():
			await capture("dossier-"+id)
			selector.get_node("%InfoScroll").ensure_control_visible(selector.get_node("%SkillTitleRow"))
			await capture("dossier-skill-"+id)
	selector.back_requested.emit()
	await frames(3)

func start_role(id: String) -> void:
	if host.get_run_state() != host.RunState.MENU:
		host.get_node("RunBindings").return_to_menu()
		await frames(10)
		host = current_scene
	var nav: Node = host.get_node("MenuNavigation")
	host._start_screen.start_button.pressed.emit()
	nav.character_select.show_selection(id)
	nav.character_select.get_node("%ConfirmButton").pressed.emit()
	nav.level_select.get_level_button(&"level1").pressed.emit()
	await frames(10)
	host = current_scene
	host.get_node("RunBindings").tutorial.skip()
	host._player._invulnerability_remaining = 100000.0
	check(host._player.character_id == id and host.get_run_state() == host.RunState.PLAYING, "actual menu selection creates the intended player: "+id)

func check_hud(id: String) -> void:
	var configuration: Dictionary = host._player.get_node("CharacterAbility").get_configuration()
	var card: Control = host._hud.get_node("%CharacterCooldown")
	check(configuration.name == CATALOG.definition(id).skill and is_equal_approx(configuration.cooldown,CATALOG.definition(id).cooldown), id+": actual player exposes the configured name and cooldown")
	check(card.visible == configuration.active and card.get_node("%AbilityName").text == configuration.name, id+": HUD name and active-button visibility match the current player")
	check(card.icon.texture.resource_path == ICON_PATHS[id] and card.ability_description == configuration.description, id+": HUD icon and effect are synchronized without a previous role's data")
	var text: String = card.get_node("%ActivateButton").tooltip_text
	check(text.contains(configuration.name) and text.contains(configuration.description) and text.contains("冷却 %s 秒" % CATALOG.seconds(configuration.cooldown)), id+": tooltip includes matching name, actual effect and cooldown")
	check(not configuration.active or card.icon.texture.resource_path != "res://assets/ui/guard_rune.svg", id+": character skill no longer uses the consumable guard-rune icon")
	var tooltip: Control = card.get_node("%ActivateButton")._make_custom_tooltip(text)
	root.add_child(tooltip)
	check(tooltip.get_combined_minimum_size().x <= root.get_visible_rect().size.x, id+": complete effect tooltip fits within the viewport")
	tooltip.queue_free()
	# The live actor remains authoritative when an unrelated static handoff is stale.
	CATALOG.selected_id = "astra" if id != "astra" else "lan"
	host._hud._update_combat_cooldowns()
	check(card.get_node("%AbilityName").text == configuration.name, id+": HUD ignores stale global character-selection metadata")
	host._hud.bind_combat_actions(null)
	check(not card.visible, id+": detaching the player hides stale character-skill presentation")
	host._hud.bind_combat_actions(host._player)
	check(card.visible == configuration.active and card.icon.texture.resource_path == ICON_PATHS[id], id+": rebinding the same character restores the current presentation")

func check_behavior(id: String) -> void:
	var ability: Node = host._player.get_node("CharacterAbility")
	var configuration: Dictionary = ability.get_configuration()
	var feedback: Array[String] = []
	ability.feedback.connect(func(text: String) -> void: feedback.append(text))
	if id == "knight":
		host._player.energy = host._player.max_energy
		check(not ability.try_activate(), "Knight rejects supply at full energy")
		host._player.energy -= 15.0
		check(ability.try_activate() and is_equal_approx(host._player.energy,host._player.max_energy-5.0) and is_equal_approx(ability.cooldown_remaining,12.0) and host._hud.get_node("%CharacterCooldown").visible, "Knight supply restores ten energy and starts its twelve-second cooldown")
		return
	check(ability.try_activate() and feedback.back() == configuration.name, id+": activation feedback uses the same configured name")
	var expected_duration: float = {"lan":4.0,"iron":1.2,"astra":0.25}[id]
	check(is_equal_approx(ability.remaining,expected_duration), id+": configured activation duration preserves the existing behavior")
	match id:
		"lan":
			var spell: Node = host._player.get_node("EnergyShock")
			check(ability.is_focused() and is_equal_approx(spell.get_cooldown_duration(),spell.cooldown/1.3), "Lan focus retains the existing spell interval improvement")
			var melee: Node = host._player.get_node("MeleeAttack")
			var motion_duration: float = melee.windup_duration+melee.active_duration+melee.recovery_duration
			check(melee.try_attack() and is_equal_approx(melee.get_cooldown_remaining(),maxf(maxf(melee.attack_cooldown,motion_duration)/1.3,motion_duration)), "Lan melee interval improvement still respects the complete attack motion")
			check(host._player.try_dodge() and ability.is_focused(), "Lan dodge does not cancel focus, as described")
			ability._physics_process(4.01)
			check(not ability.is_focused() and is_equal_approx(ability.get_cooldown_remaining(),10.0), "Lan starts the unchanged ten-second cooldown after focus ends")
		"iron":
			var target := make_target(host._player.global_position+ability._guard_direction*1.5)
			await frames(2)
			host._player._invulnerability_remaining = 0
			check(not host._player.take_direct_damage(2,host._player.global_position+ability._guard_direction*2) and ability.blocked_hits == 1, "Iron still blocks front-facing direct hits")
			check(host._player.take_direct_damage(1,host._player.global_position-ability._guard_direction*2), "Iron still takes rear hits, as the front-only description implies")
			ability._finish_guard(true)
			check(target.damage == 3 and target.controls == [0.5] and is_equal_approx(ability.get_cooldown_remaining(),8.0), "Iron keeps its block-enhanced counter, half-second precise control and approved eight-second cooldown")
			target.queue_free()
		"astra":
			check(host._player.try_dodge() and not ability.is_casting() and is_equal_approx(ability.get_cooldown_remaining(),1.0), "Astra dodge still interrupts the cast")
			await frames(16)
			ability.cooldown_remaining = 0
			check(ability.try_activate(), "Astra can cast again after the interrupted attempt")
			ability._physics_process(0.26)
			var field: Node = get_nodes_in_group("gravity_fields").back()
			field.set_physics_process(false)
			check(is_equal_approx(field.lifetime,3.0) and is_equal_approx(ability.get_cooldown_remaining(),14.0), "Astra retains a three-second field and fourteen-second release cooldown")
			var target := make_target(field.global_position)
			await frames(2)
			field._physics_process(2.99)
			field._physics_process(0.02)
			check(target.damage == 5 and not target.slows.is_empty() and field.is_queued_for_deletion(), "Astra retains periodic damage, slowing and its final burst")
			target.queue_free()
	host._hud._update_combat_cooldowns()
	var card: Control = host._hud.get_node("%CharacterCooldown")
	check(card.ability_description == configuration.description and card.get_node("%ActivateButton").tooltip_text.contains(configuration.name), id+": cooldown/state updates do not overwrite ability identity or effect")
	if "--capture" in OS.get_cmdline_user_args():
		await capture("hud-"+id)
		await capture_tooltip(id,Vector2i(1280,720))
		if id == "astra": await capture_tooltip(id,Vector2i(480,800))

func scene_handoffs() -> void:
	host.get_node("MenuNavigation").progress.complete(1)
	check(host.request_scene_change("res://scenes/dungeon/Level02Run.tscn",{"character_id":"lan","start_run":true}), "cross-level handoff accepts the current role")
	await wait_for_handoff()
	check(host.level_id == 2 and host._player.character_id == "lan", "cross-level handoff preserves the actual selected player")
	check_hud("lan")
	host.get_node("RunBindings").return_to_menu()
	await wait_for_handoff()
	check_hud("lan")
	host._start_screen.get_node("%ContinueButton").pressed.emit()
	await wait_for_handoff()
	check(host.level_id == 2 and host.get_run_state() == host.RunState.PLAYING, "Continue still starts the recent level")
	check_hud("lan")

func wait_for_handoff() -> void:
	# Resource transitions are asynchronous; ten frames can end before loading does.
	var previous := host
	for i in 600:
		await frames(1)
		if current_scene != previous:
			await frames(3)
			host = current_scene
			return
	host = current_scene

func make_target(at: Vector3) -> Target:
	var target := Target.new()
	target.collision_layer = 4
	target.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.6
	collision.shape = shape
	collision.position.y = 0.8
	target.add_child(collision)
	host._dungeon.add_child(target)
	target.global_position = at
	return target

func capture(label: String) -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT.path_join(label+".png"))

func capture_tooltip(id: String, dimensions: Vector2i) -> void:
	root.size = dimensions
	await frames(5)
	var button: Button = host._hud.get_node("%CharacterCooldown").get_node("%ActivateButton")
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	root.push_input(motion,true)
	check(root.gui_get_hovered_control() == button, id+": rendered tooltip hover reaches the skill button at %dx%d" % [dimensions.x,dimensions.y])
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT.path_join("tooltip-%s-%dx%d.png" % [id,dimensions.x,dimensions.y]))
	motion.position = Vector2(4,4)
	root.push_input(motion,true)
	root.size = Vector2i(1280,720)

func finish() -> void:
	paused = false
	root.get_node("MusicManager").stop_music()
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames(3)
	print("CHARACTER_SKILL_CONSISTENCY_RESULT %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1

func test_save_path(label: String) -> String:
	var directory := OS.get_environment("GODOT_TEST_SAVE_DIR")
	if directory.is_empty(): directory = "user://"
	return directory.path_join("%s-%d.cfg" % [label,Time.get_ticks_usec()])
