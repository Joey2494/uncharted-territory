extends SceneTree
const MODELS = preload("res://scenes/weapons/weapon_models.gd")
const CATALOG = preload("res://scenes/weapons/weapon_catalog.gd")
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/weapons/models")
	for id in CATALOG.DATA:
		var model := MODELS.create(id)
		for child in model.find_children("*", "", true, false): child.owner = model
		var scene := PackedScene.new()
		scene.pack(model)
		ResourceSaver.save(scene,"res://assets/weapons/models/"+id+".tscn")
		model.free()
	for id in ["pistol_ammo","coil_ammo"]:
		var model := preload("res://scenes/weapons/ammo_models.gd").create(id == "coil_ammo")
		for child in model.find_children("*", "", true, false): child.owner = model
		var scene := PackedScene.new()
		scene.pack(model)
		ResourceSaver.save(scene,"res://assets/weapons/models/"+id+".tscn")
		model.free()
	quit()
