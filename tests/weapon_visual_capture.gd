extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1600,900)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("121d2a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d8e6ff")
	env.environment.ambient_light_energy = 0.75
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-25,0)
	light.light_energy = 1.8
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,2.1,9)
	camera.look_at(Vector3(0,1,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.4
	var ammo_only: bool = "--ammo" in OS.get_cmdline_user_args()
	var characters: bool = "--characters" in OS.get_cmdline_user_args()
	var ids := ["traveler","rune","pistol","coil","guard","frost","practice","fire"]
	if ammo_only:
		ids = ["pistol_ammo","coil_ammo"]
		camera.size = 2.4
	for i in ids.size():
		var id: String = ids[i]
		var model: Node3D
		if characters:
			model = preload("res://scenes/player/Player.tscn").instantiate()
			model.character_id = ["knight","knight","lan","lan","iron","iron","astra","astra"][i]
		else:
			model = (load("res://assets/weapons/models/"+id+".tscn") as PackedScene).instantiate()
		world.add_child(model)
		model.position = Vector3(-3.4+(i%4)*2.25,2.0-(i/4)*2.35,0)
		model.rotation_degrees = Vector3(-8,-25,-18)
		if ammo_only: model.position = Vector3(-0.85+i*1.7,0.85,0)
		if id in ["pistol","coil"]: model.rotation_degrees = Vector3(0,65,-15)
		if characters:
			model.set_physics_process(false)
			model.rotation = Vector3.ZERO
			model.get_node("Visuals").rotation.y = PI+0.4
			model.scale = Vector3.ONE*0.75
			model.position.y -= 0.4
			if i%2 == 1:
				model.get_node("WeaponLoadout").active = 1
				model.get_node("WeaponLoadout")._show_weapon()
		var label := Label3D.new()
		label.text = ("黄铜手枪弹" if id == "pistol_ammo" else "线圈磁芯弹") if ammo_only else preload("res://scenes/weapons/weapon_catalog.gd").DATA[id].name
		label.font_size = 42
		label.pixel_size = 0.004
		world.add_child(label)
		label.position = model.position+Vector3(0,-0.55,0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/week11-evidence")
	root.get_texture().get_image().save_png("res://docs/change/week10-evidence/ammo.png" if ammo_only else "res://docs/week11-evidence/characters.png" if characters else "res://docs/week11-evidence/weapons.png")
	quit()
