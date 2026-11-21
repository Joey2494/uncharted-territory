extends SceneTree
## Run from this project: godot --headless --path . --script res://tools/rendering/bake_static_art.gd
const Cache = preload("res://scripts/rendering/static_art_cache.gd")
const Library = preload("res://scripts/rendering/static_art_library.gd")
const Cave = preload("res://scenes/dungeon/level02/cavern_geometry.gd")
const Ground = preload("res://scenes/dungeon/level02/cavern_floor_detail.gd")
const Habitat = preload("res://scenes/dungeon/level02/spider_habitat.gd")
const Tomb = preload("res://scenes/dungeon/level03/tomb_geometry.gd")
const Profile = preload("res://scripts/integration/player_profile.gd")
const Progress = preload("res://scripts/integration/campaign_progress.gd")
var images: Dictionary = {}
var converted: Dictionary = {}
var material_ids: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func image_texture(texture: Texture2D) -> Texture2D:
	if texture == null or not texture is NoiseTexture2D: return texture
	if converted.has(texture.get_instance_id()): return converted[texture.get_instance_id()]
	var image := texture.get_image()
	assert(image != null,"Noise must finish before baking")
	var key := var_to_bytes([image.get_width(),image.get_height(),image.get_format(),image.has_mipmaps(),image.get_data()]).hex_encode().sha256_text()
	if not images.has(key):
		images[key] = ImageTexture.create_from_image(image)
		images[key].resource_name = texture.resource_name
	converted[texture.get_instance_id()] = images[key]
	return images[key]
func convert_material(material: Material) -> void:
	if not material is BaseMaterial3D or material_ids.has(material.get_instance_id()): return
	material_ids[material.get_instance_id()] = true
	for slot in BaseMaterial3D.TEXTURE_MAX:
		var texture: Texture2D = material.get_texture(slot)
		if texture is NoiseTexture2D: material.set_texture(slot,image_texture(texture))
func convert_world(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		convert_material(node.material_override)
		for i in node.mesh.get_surface_count(): convert_material(node.mesh.surface_get_material(i))
	for child in node.get_children(true): convert_world(child)
func source_hashes(family: String) -> Dictionary:
	var common := ["res://scripts/rendering/static_art_cache.gd","res://scenes/dungeon/level02/cavern_geometry.gd"]
	var paths := ["res://scenes/dungeon/level02/cavern_floor_detail.gd","res://scenes/dungeon/level02/stone_region.gd","res://scenes/dungeon/level02/spider_habitat.gd","res://scenes/dungeon/level02/Level02.tscn"] if family == "cave" else ["res://scenes/dungeon/level03/tomb_geometry.gd","res://scenes/dungeon/level03/tomb_layout.gd","res://scenes/dungeon/level03/tide_layout.gd","res://scenes/dungeon/level03/Level03Preview.tscn"]
	var result := {}
	for path in common+paths: result[path] = FileAccess.get_sha256(path)
	return result
func run() -> void:
	Profile.override_path = "user://bake-profile.cfg"
	Progress.override_path = "user://bake-progress.cfg"
	Cache.capturing = true
	DirAccess.make_dir_recursive_absolute("res://assets/environment_cache")
	for level in [2,3]:
		var family := "cave" if level == 2 else "tomb"
		var host: Node3D = load("res://scenes/dungeon/Level0%dRun.tscn" % level).instantiate()
		host.get_node("DungeonTest").process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(host)
		for i in 12: await process_frame
		var library := Library.new()
		library.family = family
		library.generator_revision = Cache.REVISION
		library.engine_version = Engine.get_version_info().string
		library.source_hashes = source_hashes(family)
		library.scenes = Cache.captured[family].scenes
		library.random_states = Cache.captured[family].states
		if level == 2:
			library.materials = {"rock":Cave._rock,"sediment":Cave._sediment,"ambient":Cave._ambient_ramp}
			library.textures = {"ground_ripple":image_texture(Ground._water_material.normal_texture),"cocoon":image_texture(Habitat._silk_texture)}
		else:
			library.materials = {"stone":Tomb.stone,"sand":Tomb.sand,"shadow":Tomb.shadow,"pigment":Tomb.pigment,"bronze":Tomb.bronze,"linen":Tomb.linen,"flame":Tomb.flame}
			var layout: Node3D = host.get_node("DungeonTest/Layout")
			var water: MeshInstance3D = layout._water[&"BC"].find_children("*","MeshInstance3D",true,false)[0]
			library.textures = {"reservoir_ripple":image_texture(water.material_override.normal_texture)}
		convert_world(host)
		for material in library.materials.values():
			if material is Material: convert_material(material)
		# Save atomically: a failed bake never replaces a working cache.
		var temporary: String = Cache.PATHS[family].get_basename()+".pending.res"
		var error := ResourceSaver.save(library,temporary,ResourceSaver.FLAG_COMPRESS)
		assert(error == OK,"Unable to write static art bundle")
		error = DirAccess.rename_absolute(temporary,Cache.PATHS[family])
		assert(error == OK,"Unable to install static art bundle")
		print("BAKE_RESULT family=",family," scenes=",library.scenes.size()," textures=",images.size())
		host.queue_free()
		for i in 3: await process_frame
	root.get_node("MusicManager").stop_music()
	quit()
