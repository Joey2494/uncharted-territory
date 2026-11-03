@tool
extends Node3D
## Fixed visual frame: 5 m clear width, 3 m underside. No collision.

const Visuals = preload("res://scenes/dungeon/almsyone_visuals.gd")
const PILLAR: PackedScene = preload("res://assets/dungeon/almsyone/SM_Pillar.glb")

var _visuals: RefCounted


func _ready() -> void:
	_rebuild_visuals()


func _rebuild_visuals() -> void:
	var old := get_node_or_null("Geometry")
	if old != null:
		remove_child(old)
		old.queue_free()
	var geometry := Node3D.new()
	geometry.name = "Geometry"
	add_child(geometry, false, Node.INTERNAL_MODE_BACK)
	_visuals = Visuals.new()
	# Native pillars are 0.8 m wide: +/-2.9 leaves precisely +/-2.5 clear.
	_visuals.add_model(geometry, PILLAR, "LeftPillar", Transform3D(Basis.IDENTITY, Vector3(-2.9, 0, 0)))
	_visuals.add_model(geometry, PILLAR, "RightPillar", Transform3D(Basis.IDENTITY, Vector3(2.9, 0, 0)))
	var material: Material
	for part in _visuals.parts(PILLAR):
		var candidate: Material = part.mesh.surface_get_material(0)
		if candidate.resource_name == "M_Stone": material = candidate
	# Independent lintel preserves the required clearance; native pack door
	# openings are too narrow for the existing 5 m route and 2.8 m Boss.
	var box := BoxMesh.new()
	box.size = Vector3(6.6, 0.3, 0.8)
	box.material = material
	var beam := MeshInstance3D.new()
	beam.name = "Lintel"
	beam.mesh = box
	beam.position = Vector3(0, 3.15, 0)
	geometry.add_child(beam)
