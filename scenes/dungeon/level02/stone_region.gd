@tool
extends "res://scenes/dungeon/entrance_hall.gd"
## Level-two dressing shares level-one stone assets; the base owns all physics.
const EXTRA := {
	"cracked": preload("res://assets/dungeon/almsyone/SM_Floor_Stone_Cracked.glb"),
	"moss": preload("res://assets/dungeon/almsyone/SM_Floor_Stone_Mossy.glb"),
	"bookshelf": preload("res://assets/dungeon/almsyone/SM_Bookshelf.glb"),
	"crystal": preload("res://assets/dungeon/almsyone/SM_Crystals_Blue.glb"),
	"purple": preload("res://assets/dungeon/almsyone/SM_Crystals_Purple.glb"),
	"brazier": preload("res://assets/dungeon/almsyone/SM_Brazier.glb"),
	"red_banner": preload("res://assets/dungeon/almsyone/SM_Banner_Red.glb"),
	"bones": preload("res://assets/dungeon/almsyone/SM_Bones_Pile.glb"),
	"broken_pillar": preload("res://assets/dungeon/almsyone/SM_Pillar_Broken.glb"),
}

func _material(source: Material) -> Material:
	var cached := _tinted_materials.has(source.get_instance_id())
	var material := super._material(source) as BaseMaterial3D
	if not cached:
		if material.resource_name == "M_Moss":
			var color := material.albedo_color
			material.albedo_color = Color(color.r * stone_brightness, color.g * stone_brightness, color.b * stone_brightness, color.a)
		if material.resource_name.begins_with("M_Crystal"):
			material.emission_energy_multiplier = 0.12
	return material

func _build_floor(body: StaticBody3D) -> void:
	body.get_node("MeshInstance3D").hide()
	var columns := maxi(1, ceili(dimensions.x / 2.0))
	var rows := maxi(1, ceili(dimensions.y / 2.0))
	var cell := dimensions / Vector2(columns, rows)
	var tiles := {"floor": [], "cracked": [], "moss": []}
	for z in rows:
		for x in columns:
			var worn := (x * 7 + z * 11) % 17 == 0
			var edge := (x == 0 or z == 0) and (x + z) % 3 == 0
			var key := "moss" if edge and name != &"Arrival" else ("cracked" if worn else "floor")
			tiles[key].append(Vector2i(x, z))
	var room_to_body := body.global_transform.affine_inverse() * global_transform
	for key in tiles:
		if tiles[key].is_empty(): continue
		var parts := _parts(MODELS.floor if key == "floor" else EXTRA[key])
		var top := -INF
		for part in parts:
			var bounds: AABB = part.transform * part.mesh.get_aabb()
			top = maxf(top, bounds.end.y)
		for surface in parts.size():
			var part: Dictionary = parts[surface]
			var instances := MultiMesh.new()
			instances.transform_format = MultiMesh.TRANSFORM_3D
			instances.mesh = part.mesh
			instances.instance_count = tiles[key].size()
			for index in tiles[key].size():
				var tile: Vector2i = tiles[key][index]
				# Visible tiles end exactly at room boundaries; the wider collision
				# slab remains untouched and adjacent corridors cannot z-fight.
				var at := Vector3((tile.x + 0.5) * cell.x - dimensions.x * 0.5, -top - 0.002, (tile.y + 0.5) * cell.y - dimensions.y * 0.5)
				var pose := Transform3D(Basis.from_scale(Vector3(cell.x / 2.0, 1, cell.y / 2.0)), at)
				instances.set_instance_transform(index, room_to_body * pose * part.transform)
			var visual := MultiMeshInstance3D.new()
			visual.name = "Stone_%s_%d" % [key, surface]
			visual.multimesh = instances
			body.add_child(visual)

func _prop(walls: Node3D, key: String, at: Vector3, yaw: float = 0.0, sizing: Vector3 = Vector3.ONE) -> void:
	var parent := _nearest_wall(walls, at)
	var model := Node3D.new()
	model.name = "Decor_" + key
	parent.add_child(model, true)
	model.transform = parent.global_transform.affine_inverse() * global_transform * Transform3D(Basis(Vector3.UP, yaw).scaled_local(sizing), at)
	var source: PackedScene = EXTRA[key] if EXTRA.has(key) else MODELS[key]
	model.set_meta("source_model", source.resource_path)
	for part in _parts(source):
		var mesh := MeshInstance3D.new()
		mesh.mesh = part.mesh
		mesh.transform = part.transform
		model.add_child(mesh)

func _build_dressing(_geometry: Node3D, walls: Node3D) -> void:
	var half := dimensions * 0.5
	if not exploration_room:
		# Corridors keep their entire original five-metre lane open.
		if dimensions.y > 8.0:
			_prop(walls, "wall_torch", Vector3(-half.x + 0.04, 1.8, 0), PI * 0.5)
		elif dimensions.x > 8.0:
			_prop(walls, "wall_torch", Vector3(0, 1.8, -half.y + 0.04))
		return
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_prop(walls, "corner", Vector3(x * (half.x + 0.3), 0, z * (half.y + 0.3)), 0, Vector3(0.947, 3.04 / 3.12, 0.947))
	# Torches and banners sit on closed wall spans, away from door throats.
	for x in [-1.0, 1.0]:
		_prop(walls, "wall_torch", Vector3(x * (half.x - 2.0), 1.7, -half.y + 0.04))
		_prop(walls, "wall_torch", Vector3(x * (half.x - 2.0), 1.7, half.y - 0.04), PI)
		_prop(walls, "pillar", Vector3(x * (half.x - 0.45), 0, -half.y + 0.45))
	match String(name):
		"Arrival":
			for x in [-1.0, 1.0]:
				_prop(walls, "banner", Vector3(x * 4.5, 2.75, -half.y + 0.04))
				_prop(walls, "statue", Vector3(x * 5.6, 0, 4.25))
			_prop(walls, "crate", Vector3(-5.7, 0, -4.2))
			_prop(walls, "crate", Vector3(-4.9, 0, -4.8), 0.2, Vector3.ONE * 0.8)
			_prop(walls, "barrel", Vector3(5.5, 0, -4.5))
			_prop(walls, "bench", Vector3(6.1, 0, 0), -PI * 0.5)
		"Hub":
			for x in [-1.0, 1.0]:
				_prop(walls, "red_banner", Vector3(x * 6.7, 2.75, -half.y + 0.04))
				_prop(walls, "broken_pillar", Vector3(x * 9.4, 0, 6.8))
				_prop(walls, "barrel", Vector3(x * 9.5, 0, -6.9))
		"Relay":
			for x in [-1.0, 1.0]:
				_prop(walls, "crystal", Vector3(x * 7.2, 0, -4.8), x * 0.4)
				_prop(walls, "banner", Vector3(x * 5.4, 2.75, -half.y + 0.04))
		"Antechamber":
			for x in [-1.0, 1.0]:
				_prop(walls, "statue", Vector3(x * 8.1, 0, -6.1))
				_prop(walls, "red_banner", Vector3(x * 6, 2.75, -half.y + 0.04))
			_prop(walls, "crate", Vector3(8.3, 0, 6))
		"Boss":
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					_prop(walls, "brazier", Vector3(x * 10.6, 0, z * 9.6))
				_prop(walls, "red_banner", Vector3(x * 7.5, 2.75, -half.y + 0.04))
				_prop(walls, "bones", Vector3(x * 11.3, 0, 2.2))
		"Archive":
			for x in [-1.0, 1.0]:
				for z in [-4.5, 0.0, 4.5]:
					if x > 0 and z == 0.0: continue # East entry remains visibly clear.
					_prop(walls, "bookshelf", Vector3(x * 7.3, 0, z), -x * PI * 0.5)
				_prop(walls, "purple", Vector3(x * 6.6, 0, -5.7), x * 0.5, Vector3.ONE * 0.65)
		"Vault":
			for x in [-1.0, 1.0]:
				_prop(walls, "crystal", Vector3(x * 4.4, 0, -3.4))
				_prop(walls, "crate", Vector3(x * 4.6, 0, 3.3))
		"Exit":
			for x in [-1.0, 1.0]:
				_prop(walls, "banner", Vector3(x * 3.8, 2.75, -half.y + 0.04))
				_prop(walls, "statue", Vector3(x * 4.5, 0, -2.4))
