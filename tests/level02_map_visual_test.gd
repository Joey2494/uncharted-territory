extends SceneTree
## Compare every dressed room's collision to the unchanged base generator.
const REGION = preload("res://scenes/dungeon/DungeonRegion.tscn")
var checks := 0
var failures := 0

func _initialize() -> void:
	preload("res://scripts/integration/player_profile.gd").override_path = "res://.godot/map_visual_profile.cfg"
	preload("res://scripts/integration/campaign_progress.gd").override_path = "res://.godot/map_visual_progress.cfg"
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)

func shapes(node: Node, result: Dictionary, prefix: String = "") -> void:
	for child in node.get_children(true):
		var path := prefix + "/" + child.name
		if child is CollisionShape3D:
			result[path] = [child.position, child.shape.size]
		shapes(child, result, path)

func frames(count: int = 8) -> void:
	for i in count: await process_frame

func run() -> void:
	change_scene_to_file("res://scenes/dungeon/Level02Run.tscn")
	await frames()
	var host := current_scene
	var world := host.get_node("DungeonTest")
	for region in world.get_node("Regions").get_children():
		var reference := REGION.instantiate()
		for property in ["dimensions", "doorway_width", "open_north", "open_south", "open_east", "open_west"]:
			reference.set(property, region.get(property))
		root.add_child(reference)
		var actual := {}
		var expected := {}
		shapes(region.get_node("Geometry"), actual)
		shapes(reference.get_node("Geometry"), expected)
		check(actual == expected, str(region.name) + " exact original collision shapes and positions")
		var floor_body := region.get_node("Geometry/Floor")
		check(not floor_body.get_node("MeshInstance3D").visible, str(region.name) + " blockout hidden")
		var batches := 0
		for child in floor_body.get_children():
			if child is MultiMeshInstance3D:
				batches += 1
				check(child.multimesh.instance_count > 0, "nonempty floor batch")
		check(batches > 0, str(region.name) + " imported stone tiles render")
		reference.free()
	for cover in ["West", "East"]:
		var body := world.get_node("Cover/" + cover)
		check(body.has_node("StoneCover") and not body.get_node("Mesh").visible, "cover rendered as masonry")
		check(body.get_node("CollisionShape3D").shape.size == Vector3(2, 1.2, 2), "original enemy cover collision retained")
	if OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		host._on_run_started()
		await frames()
		# Use actual player position and camera; freeze AI while touring the art.
		for enemies in [world.get_node("Enemies"), world.get_node("Boss")]:
			enemies.process_mode = Node.PROCESS_MODE_DISABLED
		for room in ["Arrival", "Hub", "Relay", "Antechamber", "Archive", "Vault", "Boss", "Exit"]:
			world.player.global_position = world.get_node("Regions/" + room).global_position + Vector3(0, 0.05, 1)
			world.player.velocity = Vector3.ZERO
			world.get_node("Camera3D").reset_follow()
			await frames(20)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/level02_stone_%s.png" % room.to_lower())
	current_scene = null
	host.free()
	await frames()
	print("LEVEL02 MAP VISUALS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
