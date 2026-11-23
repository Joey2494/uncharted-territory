extends SceneTree
const Cache = preload("res://scripts/rendering/static_art_cache.gd")
const Library = preload("res://scripts/rendering/static_art_library.gd")
const Provider = preload("res://scripts/rendering/static_art_provider.gd")
const Cave = preload("res://scenes/dungeon/level02/cavern_geometry.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL "+message)
func mesh_arrays(node: Node) -> Array:
	var result := []
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count(): result.append(node.mesh.surface_get_arrays(i))
	for child in node.get_children(): result.append_array(mesh_arrays(child))
	return result
func is_static_visual(node: Node) -> bool:
	if not node is Node3D or node is CollisionObject3D or node is CollisionShape3D or node.get_script() != null: return false
	for child in node.get_children():
		if not is_static_visual(child): return false
	return true
func run() -> void:
	for family: String in Cache.PATHS:
		var library: Resource = load(Cache.PATHS[family])
		check(library is Library and Cache.activate(library),family+" bundle has current schema, generators and required materials")
		for material in library.materials.values():
			if not material is BaseMaterial3D: continue
			for slot in BaseMaterial3D.TEXTURE_MAX: check(not material.get_texture(slot) is NoiseTexture2D,"baked material contains no deferred noise generator")
		for entry: String in library.scenes:
			var first := Cache.lookup(family,entry)
			var second := Cache.lookup(family,entry)
			check(first.node != second.node and is_static_visual(first.node),"cache creates separate visual nodes with no scripts or colliders")
			check(first.state == library.random_states[entry],"cache restores the exact generator RNG state")
			check(var_to_bytes(mesh_arrays(first.node)) == var_to_bytes(mesh_arrays(second.node)),"instances preserve the baked geometry")
			var meshes: Array = first.node.find_children("*","MeshInstance3D",true,false)
			if not meshes.is_empty():
				var mesh: MeshInstance3D = meshes[0]
				var source := mesh.get_active_material(0) as BaseMaterial3D
				var color := source.albedo_color
				# The camera uses a per-instance override, never the shared baked surface.
				mesh.material_override = source.duplicate()
				mesh.material_override.albedo_color = Color(1,0,0,0.2)
				check(source.albedo_color == color,"camera fade/material overrides cannot alter the baked prototype")
			first.node.free()
			second.node.free()
		check(Cache.lookup(family,"missing-input").is_empty(),"changed or unknown generator inputs miss safely")
		check(Cache.texture(family,"missing-texture") == null,"missing texture uses the existing procedural fallback")
		Cache.deactivate(library)
	check(not Cache.activate(Resource.new()),"wrong cache resource type is rejected")
	var library: Resource = load(Cache.PATHS.cave)
	var invalid := Library.new()
	invalid.family = "cave"
	invalid.engine_version = library.engine_version
	invalid.materials = library.materials
	invalid.source_hashes = {"res://scenes/dungeon/level02/cavern_geometry.gd":"stale"}
	check(not Cache.activate(invalid),"edited generator source invalidates the cache")
	invalid.source_hashes = {}
	invalid.schema = 999
	check(not Cache.activate(invalid),"unsupported schema is rejected")
	Cache.activate(library)
	Cache.activate(library)
	Cache.prepared.cave = library
	var provider := Provider.new()
	provider.family = "cave"
	root.add_child(provider)
	check(Cache.prepared.is_empty(),"provider consumes the threaded preload reference")
	provider.free()
	Cache.deactivate(library)
	check(Cache.libraries.has("cave"),"one scene leaving does not release another scene's shared bundle")
	Cache.deactivate(library)
	check(Cache.libraries.is_empty() and Cache.references.is_empty(),"last provider releases the bundle without retaining a node tree")
	var maker := Cave.new()
	Cache.activate(library)
	var before_misses := Cache.misses
	var fallback := maker.wall_mesh("ChangedRoom",Vector3(0,1.5,0),Vector3(6.17,3,0.6),Vector3.FORWARD,true,Vector3.ZERO,Vector2(16,16))
	var state := maker._rng.state
	check(Cache.misses == before_misses+1,"new wall dimensions use the procedural generator")
	Cache.disabled = true
	var procedural := maker.wall_mesh("ChangedRoom",Vector3(0,1.5,0),Vector3(6.17,3,0.6),Vector3.FORWARD,true,Vector3.ZERO,Vector2(16,16))
	check(var_to_bytes(mesh_arrays(fallback)) == var_to_bytes(mesh_arrays(procedural)) and state == maker._rng.state,"fallback preserves geometry and RNG state")
	Cache.disabled = false
	fallback.free()
	procedural.free()
	Cache.deactivate(library)
	root.get_node("MusicManager").stop_music()
	print("STATIC_ART_CACHE_RESULT ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
