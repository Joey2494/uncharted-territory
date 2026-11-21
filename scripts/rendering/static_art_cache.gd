@tool
extends RefCounted
## Immutable baked visuals are scoped to an active level, never to a save file.
const REVISION := "static-art-v1"
const Library = preload("res://scripts/rendering/static_art_library.gd")
static var disabled := false
static var capturing := false
static var libraries: Dictionary = {}
static var captured: Dictionary = {}
static var hits := 0
static var misses := 0
static var material_hits := 0
static var prepared: Dictionary = {}
static var references: Dictionary = {}
const PATHS := {"cave":"res://assets/environment_cache/cave.res","tomb":"res://assets/environment_cache/tomb.res"}

static func family_for_scene(path: String) -> String:
	if path in ["res://scenes/dungeon/Level02Run.tscn","res://scenes/dungeon/level02/Level02Campaign.tscn","res://scenes/dungeon/level02/Level02.tscn"]: return "cave"
	if path in ["res://scenes/dungeon/Level03Run.tscn","res://scenes/dungeon/level03/Level03Campaign.tscn","res://scenes/dungeon/level03/Level03Preview.tscn"]: return "tomb"
	return ""

static func optional_path(destination: String) -> String:
	var family := family_for_scene(destination)
	if disabled or capturing or family.is_empty(): return ""
	var path: String = PATHS[family]
	return path if ResourceLoader.exists(path) else ""

static func acquire(family: String) -> Resource:
	if disabled or capturing: return null
	if prepared.has(family):
		var library: Resource = prepared[family]
		prepared.erase(family)
		return library
	var path: String = PATHS.get(family,"")
	return load(path) if ResourceLoader.exists(path) else null

static func activate(library: Resource) -> bool:
	if disabled or capturing or library == null: return false
	if not library is Library: return false
	if library.schema != 1 or library.generator_revision != REVISION: return false
	if library.engine_version != Engine.get_version_info().string: return false
	if not PATHS.has(library.family): return false
	var required: Array = ["rock","sediment","ambient"] if library.family == "cave" else ["stone","sand","shadow","pigment","bronze","linen","flame"]
	for name in required:
		if not library.materials.has(name) or library.materials[name] == null: return false
		if name != "ambient" and not library.materials[name] is StandardMaterial3D: return false
		if name == "ambient" and not library.materials[name] is Texture2D: return false
	# Source files are available in the editor/debug project; exports use the baked revision.
	for path: String in library.source_hashes:
		if FileAccess.file_exists(path) and FileAccess.get_sha256(path) != library.source_hashes[path]:
			push_warning("Static art cache is stale; using procedural visuals: "+path)
			return false
	if libraries.get(library.family) == library:
		references[library.family] += 1
	else:
		libraries[library.family] = library
		references[library.family] = 1
	return true

static func deactivate(library: Resource) -> void:
	if not library is Library or libraries.get(library.family) != library: return
	references[library.family] -= 1
	if references[library.family] == 0:
		libraries.erase(library.family)
		references.erase(library.family)

static func key(kind: String, arguments: Array) -> String:
	return kind+":"+var_to_bytes(arguments).hex_encode().sha256_text()

static func lookup(family: String, entry: String) -> Dictionary:
	if disabled or capturing or not libraries.has(family): return {}
	var library: Resource = libraries[family]
	if not library.scenes.has(entry) or not library.random_states.has(entry):
		misses += 1
		return {}
	var packed := library.scenes[entry] as PackedScene
	if packed == null or not packed.can_instantiate():
		misses += 1
		return {}
	hits += 1
	return {"node":packed.instantiate(),"state":library.random_states[entry]}

static func material_set(family: String) -> Dictionary:
	if disabled or capturing or not libraries.has(family): return {}
	material_hits += 1
	return libraries[family].materials

static func texture(family: String, entry: String) -> Texture2D:
	if disabled or capturing or not libraries.has(family): return null
	return libraries[family].textures.get(entry) as Texture2D

static func record(family: String, entry: String, visual: Node3D, state: int) -> void:
	if not capturing: return
	if not captured.has(family): captured[family] = {"scenes":{},"states":{}}
	if captured[family].scenes.has(entry): return
	var copy := visual.duplicate()
	_prepare(copy,copy)
	var packed := PackedScene.new()
	var error := packed.pack(copy)
	assert(error == OK,"Unable to pack static visual")
	captured[family].scenes[entry] = packed
	captured[family].states[entry] = state
	copy.free()

static func _prepare(node: Node, owner: Node) -> void:
	assert(node is Node3D and not node is CollisionObject3D and not node is CollisionShape3D and node.get_script() == null,"Only static visual nodes may be baked")
	if node != owner: node.owner = owner
	for group in node.get_groups():
		node.remove_from_group(group)
		node.add_to_group(group,true)
	for child in node.get_children(): _prepare(child,owner)
