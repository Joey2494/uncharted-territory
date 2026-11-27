extends SceneTree
const Profile = preload("res://scripts/integration/player_profile.gd")
const Progress = preload("res://scripts/integration/campaign_progress.gd")
const Catalog = preload("res://data/enemy_codex.gd")
const Characters = preload("res://scenes/player/character_catalog.gd")
var checks := 0
var failures := 0
var host
var controller
var fixture_path := ""

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)
func frames(n := 5) -> void:
	for i in n: await physics_frame
func load_host(path: String, start := true) -> void:
	paused = false
	Characters.selected_id = "knight"
	Characters.start_pending = false
	change_scene_to_file(path)
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path and current_scene.is_node_ready(): break
	await frames(8)
	host = current_scene
	controller = host.get_node("EnemyCodexController")
	if start: host._on_run_started()
	host._player._invulnerability_remaining = 1000.0
	await frames()
func go(point: Vector3) -> void:
	host._player.global_position = point
	host._player.velocity = Vector3.ZERO
	await frames(6)
func wait_popup(id: String) -> void:
	var deadline := Time.get_ticks_msec() + 2500
	while not controller.is_open() and Time.get_ticks_msec() < deadline: await physics_frame
	check(controller.is_open() and controller.screen.selected_id == id, "first encounter displays " + id)
func dismiss() -> void:
	controller.close()
	await frames()
func press_b() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_B
	event.pressed = true
	root.push_input(event)
	event = InputEventKey.new()
	event.physical_keycode = KEY_B
	event.pressed = false
	root.push_input(event)
	await frames()
func run() -> void:
	fixture_path = "user://enemy-codex-" + str(Time.get_ticks_usec()) + ".cfg"
	Profile.override_path = fixture_path
	Progress.override_path = fixture_path + ".progress"
	Profile.ensure_loaded()
	Profile.coins = 900
	Profile.inventory = {0:2, 8:1}
	Profile.save()
	await test_menu_and_first_level()
	if not failures: await test_second_level()
	if not failures: await test_third_level()
	if not failures: await test_fourth_level()
	if not failures: await test_persistence_and_practice()
	if not failures: await test_models()
	paused = false
	if is_instance_valid(current_scene): current_scene.queue_free()
	root.get_node("MusicManager").stop_music()
	await frames()
	print("ENEMY_CODEX_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func test_menu_and_first_level() -> void:
	await load_host("res://Main.tscn", false)
	check(Profile.discovered_enemies.is_empty() and not controller.is_open(), "start menu and preloaded enemies do not unlock anything")
	host._start_screen.get_node("%EnemyCodexButton").pressed.emit()
	check(controller.is_open() and paused and host._run_state == host.RunState.CODEX, "title button opens empty bestiary")
	controller.screen.select_enemy("witch")
	check(controller.screen._name.text == "未遭遇的敌人" and not controller.screen._skills.text.contains("孢弹"), "locked entry hides its identity and abilities")
	controller.screen._filter(4)
	check(controller.screen._rows.size() == 6, "level filter lists the six fourth-level entries")
	await dismiss()
	check(host._run_state == host.RunState.MENU and not paused and host._start_screen.visible, "closing title bestiary restores the menu")
	await press_b()
	check(controller.is_open(), "physical B hotkey opens the codex")
	await press_b()
	check(not controller.is_open() and host._run_state == host.RunState.MENU, "physical B closes it without opening another menu")
	host._on_run_started()
	await go(host._dungeon.get_node("Regions/Crossroads").global_position + Vector3(0, 0.05, 0))
	await wait_popup("ruin_guard")
	check(Profile.discovered_enemies == ["ruin_guard"], "only the entered room species unlocks")
	check(controller.screen.stage.avatar != null, "new discovery presents a 3D model")
	var hp: int = host._player.hp
	var elapsed: float = host._elapsed_seconds
	check(not host._player.take_damage(1) and not host._items.try_purchase(0), "bestiary pause rejects damage and commerce actions")
	check(not host.set_paused(false) and not host.request_scene_change("res://Main.tscn"), "other pause and navigation cannot bypass the bestiary")
	await frames(20)
	check(host._player.hp == hp and host._elapsed_seconds == elapsed, "reading freezes health and run time")
	var saved := ConfigFile.new()
	saved.load(fixture_path)
	check(saved.get_value("profile", "discovered_enemies") == ["ruin_guard"], "first encounter is saved immediately without a victory")
	controller.next_discovery()
	await frames()
	check(not paused and host._run_state == host.RunState.PLAYING, "continue battle restores active play")
	controller.record_actor(host._dungeon.get_node("MeleeEnemy"))
	await frames()
	check(not controller.is_open() and controller._pending.is_empty(), "repeat species does not create another popup")
	check(host.set_paused(true) and controller.open_library(), "bestiary can be opened from a paused run")
	await dismiss()
	check(paused and host._run_state == host.RunState.PAUSED, "closing manual bestiary preserves prior pause")
	host.set_paused(false)
	host._dungeon.get_node("MeleeEnemy").take_damage(999)
	await frames(35)
	await go(host._dungeon.get_node("Regions/BossArena").global_position + Vector3(0, 0.05, 0))
	await wait_popup("gatekeeper")
	await dismiss()
	check("gatekeeper" in Profile.discovered_enemies, "first-level boss has a separate entry")

func test_second_level() -> void:
	await load_host("res://scenes/dungeon/Level02Run.tscn")
	await go(host._dungeon.get_node("Regions/Hub").global_position + Vector3(0, 0.05, 0))
	await wait_popup("silk_spider")
	check(Catalog.identify(host._dungeon.get_node("Enemies/Hub1")) == "silk_spider", "overridden hub script resolves to a silk spider")
	await dismiss()
	for enemy in [host._dungeon.get_node("Enemies/Hub1"), host._dungeon.get_node("Enemies/Hub2")]: enemy.take_damage(999)
	await frames(35)
	await go(host._dungeon.get_node("Regions/Relay").global_position + Vector3(0, 0.05, 0))
	await wait_popup("brood_spider")
	await dismiss()
	var mother = host._dungeon.get_node("Enemies/Relay2")
	mother._release()
	await frames()
	await wait_popup("broodling")
	check("broodling" in Profile.discovered_enemies, "actual summoned broodlings unlock separately from their mother")
	await dismiss()

func test_third_level() -> void:
	await load_host("res://scenes/dungeon/Level03Run.tscn")
	check("sand_king" not in Profile.discovered_enemies, "preloaded third-level boss remains locked")
	await go(Vector3(-25, 0.05, 0))
	await wait_popup("bone_axe")
	check(controller.screen._meters[0].raw_value == 4, "discovery displays real enemy health")
	await dismiss()
	await go(Vector3(0, 0.05, 0))
	await go(Vector3(-25, 0.05, 0))
	check(not controller.is_open(), "reentering a known combat room does not repeat discovery")

func test_fourth_level() -> void:
	await load_host("res://scenes/dungeon/Level04Run.tscn")
	check("witch" not in Profile.discovered_enemies, "hidden prepared witch does not leak into the codex")
	await go(host._dungeon.layout.room_center("B") + Vector3(0, 0.05, 2))
	await wait_popup("dawn_shade")
	await dismiss()
	var decoy: Node = load("res://addons/ziyuan_level04/DawnShade.tscn").instantiate()
	decoy.enemy_id = "dawn_echo"
	host._dungeon.add_child(decoy)
	controller.record_actor(decoy)
	check(Catalog.identify(decoy).is_empty() and "dawn_echo" not in Profile.discovered_enemies, "decoys do not become fake species")
	decoy.queue_free()
	for enemy in host._dungeon.combat.get_encounter_enemies(): enemy.take_damage(999)
	await frames()
	host._dungeon.combat._cleared["H"] = true
	await go(host._dungeon.layout.room_center("I") + Vector3(0, 0.05, 3))
	await wait_popup("witch")
	check(controller._pending == ["iron_thistle"], "mixed first encounter queues the second new species")
	controller.next_discovery()
	check(controller.is_open() and paused and controller.screen.selected_id == "iron_thistle", "next discovery retains the same paused encounter")
	controller.next_discovery()
	await frames()
	var witch = host._dungeon.combat.boss_guard()
	witch.summon_requested.emit("spore_guard", host._dungeon.layout.room_center("I") + Vector3(-3, 0.05, 0))
	await frames()
	await wait_popup("spore_guard")
	await dismiss()
	check(Profile.discovered_enemies.count("spore_guard") == 1, "summoned guard entry is deduplicated")

func test_persistence_and_practice() -> void:
	var discoveries: Array[String] = Profile.discovered_enemies.duplicate()
	check(Profile.forfeit_run("codex-loss-" + str(Time.get_ticks_usec())), "test defeat commits the carried asset loss")
	Profile._loaded_path = ""
	Profile.ensure_loaded()
	check(Profile.coins == 0 and Profile.discovered_enemies == discoveries, "enemy unlocks survive defeat and a profile reload")
	var bad := "user://codex-missing-" + str(Time.get_ticks_usec()) + "/profile.cfg"
	Profile.override_path = bad
	Profile._loaded_path = bad
	check(Profile.discover_enemy("sun_puppet") and Profile.bestiary_unsaved, "unwritable storage retains a session discovery")
	Profile.override_path = fixture_path
	Profile._loaded_path = fixture_path
	check(Profile.save() and not Profile.bestiary_unsaved, "retry persists the pending discovery")
	check(not Profile.discover_enemy("sun_puppet") and not Profile.discover_enemy("invalid"), "duplicate and invalid IDs cannot expand the ledger")
	await load_host("res://scenes/dungeon/Level04Practice.tscn")
	var saved := Profile.discovered_enemies.duplicate()
	var actor = load("res://addons/ziyuan_level04/RavenRoost.tscn").instantiate()
	actor.bind_target(host._player)
	host._dungeon.add_child(actor)
	actor.set_encounter_active(true)
	controller.record_actor(actor)
	await frames()
	check("raven_roost" in controller.get_known() and Profile.discovered_enemies == saved, "practice discovery stays outside the formal profile")
	if controller.is_open(): await dismiss()
	actor.queue_free()

func test_models() -> void:
	check(Catalog.IDS.size() == 17, "all seventeen species have distinct entries")
	for id in Catalog.IDS:
		check(not Catalog.entry(id).lore.is_empty() and not Catalog.entry(id).tips.is_empty(), "complete dossier: " + id)
		controller.open_library()
		var known: Array[String] = Catalog.IDS.duplicate()
		controller.screen.present(known, id, false, 0, false, {})
		await frames(2)
		check(is_instance_valid(controller.screen.stage.avatar) and controller.screen.stage.camera.size > 0, "visual-only preview loads and frames: " + id)
		controller.close()
