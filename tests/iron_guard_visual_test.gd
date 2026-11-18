extends SceneTree
const Catalog = preload("res://scenes/player/character_catalog.gd")
var checks := 0
var failures := 0
var capture := false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()
func frames(n: int = 8) -> void:
	for i in n: await physics_frame
	await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)
func screenshot(label: String) -> void:
	if not capture: return
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/iron_guard_%s.png" % label)

func run() -> void:
	var profile = preload("res://scripts/integration/player_profile.gd")
	profile.override_path = "res://.godot/iron_visual_profile.cfg"
	if FileAccess.file_exists(profile.override_path): DirAccess.remove_absolute(profile.override_path)
	profile.ensure_loaded()
	profile.set_coins(150)
	check(profile.unlock_character("iron"), "guard uses existing paid unlock")
	preload("res://scripts/integration/campaign_progress.gd").override_path = "res://.godot/iron_visual_campaign.cfg"
	Catalog.selected_id = "iron"
	change_scene_to_file("res://Main.tscn")
	await frames()
	if capture:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
	var main := current_scene
	var player := main.get_node("DungeonTest/Player")
	var model := player.get_node("Visuals/Model/Knight")
	check(Catalog.definition("iron").model != Catalog.definition("knight").model, "separate guard model resource")
	check(model.find_child("Breastplate", true, false) != null, "gameplay has authored steel armor")
	check(model.find_child("IronRoundShield", true, false) != null, "gameplay has round shield")
	check(model.find_child("Knight_Helmet", true, false) == null, "guard does not reuse traveler helmet")
	check(not model.find_children("Barbarian_*", "MeshInstance3D", true, false).is_empty(), "guard receives former first Boss body")
	check(model.find_child("IronHelm", true, false) == null, "bronze helmet is now reserved for the Boss")
	var own_geometry := true
	# Preview is the character body; gameplay additionally attaches the shared sword.
	for mesh in main._start_screen._preview.find_children("*", "MeshInstance3D", true, false):
		if mesh.name.begins_with("Knight_"): own_geometry = false
	check(own_geometry, "guard remains distinct from the starting traveler")
	check(main._start_screen._preview.find_child("Breastplate", true, false) != null, "menu uses same guard appearance")
	check(player.max_hp == 6 and player.max_shield == 2, "guard statistics preserved")
	var animator := player.get_node("Visuals/Model/AnimationPlayer") as AnimationPlayer
	for name in ["locomotion/Walking_A", "melee/Melee_1H_Attack_Slice_Diagonal", "magic/Ranged_Magic_Shoot", "death/Death_A"]:
		check(animator.has_animation(name), "shared animation available: " + name)
	await screenshot("menu")
	main._on_run_started()
	await frames(10)
	main.get_node("RunBindings/TutorialController").skip()
	check(player.get_node("MeleeAttack").try_attack(), "guard can attack")
	await frames(35)
	check(player.get_node("EnergyShock").try_cast(), "guard can cast")
	check(player.try_dodge(), "guard can dodge")
	await frames(60)
	var ability := player.get_node("CharacterAbility")
	check(ability.try_activate(), "guard can raise shield")
	check(ability.block_direct_hit(player.global_position - player.visuals.global_basis.z * 2), "guard can block forward damage")
	await screenshot("block")
	ability._finish_guard(true)
	check(ability.cooldown_remaining == 10, "counter uses existing cooldown")
	player._invulnerability_remaining = 0
	player.take_damage(100)
	await frames(75)
	check(main._run_state == main.RunState.DEAD, "new model completes death into result")
	current_scene = null
	main.free()
	await frames()
	var original := load("res://scenes/player/PlayerKnight.tscn").instantiate() as Node3D
	root.add_child(original)
	check(original.find_child("Knight_Helmet", true, false) != null, "free traveler retains original helmet")
	check(original.find_child("Breastplate", true, false) == null, "guard armor does not affect traveler")
	original.free()
	await frames()
	if capture: await comparison()
	print("IRON VISUAL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func comparison() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("111610")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color("c5c9ce")
	sky.ambient_light_energy = 0.65
	environment.environment = sky
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.5
	stage.add_child(light)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0, 1.15, 5)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.5
	camera.current = true
	var ids := ["knight", "lan", "astra", "boss", "iron"]
	for index in ids.size():
		var id: String = ids[index]
		var model: Node3D = load("res://assets/characters/kaykit/BronzeGatekeeper.tscn").instantiate() if id == "boss" else Catalog.create_model(id)
		stage.add_child(model)
		model.scale = Vector3.ONE * 0.85
		model.position.x = (index - 2) * 1.2
		model.rotation.y = -0.25
		var animator := AnimationPlayer.new()
		model.add_child(animator)
		animator.root_node = NodePath("..")
		animator.add_animation_library("locomotion", preload("res://assets/characters/kaykit/animations/locomotion.tres"))
		animator.play("locomotion/Idle_A")
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	var labels := ["初始旅人", "游侠 Lan", "术士 Astra", "第一关 Boss", "守卫 Iron"]
	for index in labels.size():
		var label := Label.new()
		label.theme = preload("res://scenes/ui/menu_theme.tres")
		label.text = labels[index]
		label.add_theme_font_size_override("font_size", 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size.x = root.size.x / 5.0
		label.position = Vector2(root.size.x * index / 5.0, 25)
		layer.add_child(label)
	await screenshot("comparison")
	stage.free()
	await frames()
