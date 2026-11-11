@tool
extends Node3D
## Fit the same stone masonry to existing cover boxes without altering physics.
const Visuals = preload("res://scenes/dungeon/almsyone_visuals.gd")
const WALL = preload("res://assets/dungeon/almsyone/SM_Wall.glb")

func _ready() -> void:
	var cover := get_parent()
	var visuals := Visuals.new()
	for body in cover.get_children():
		if body is not StaticBody3D: continue
		var old := body.get_node_or_null("StoneCover")
		if old != null:
			body.remove_child(old)
			old.queue_free()
		body.get_node("Mesh").hide()
		var shape: BoxShape3D = body.get_node("CollisionShape3D").shape
		var bounds := AABB()
		var first := true
		for part in visuals.parts(WALL):
			var box: AABB = part.transform * part.mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var sizing := shape.size / bounds.size
		var pose := Transform3D(Basis.from_scale(sizing), -bounds.get_center() * sizing)
		visuals.add_model(body, WALL, "StoneCover", pose)
