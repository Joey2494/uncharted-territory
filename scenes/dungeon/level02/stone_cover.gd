@tool
extends Node3D
## Natural boulders retain the two original cover colliders and their footprints.
const CAVERN = preload("res://scenes/dungeon/level02/cavern_geometry.gd")

func _ready() -> void:
	var cover := get_parent()
	var maker := CAVERN.new()
	for body in cover.get_children():
		if body is not StaticBody3D: continue
		var old := body.get_node_or_null("StoneCover")
		if old != null:
			body.remove_child(old)
			old.queue_free()
		body.get_node("Mesh").hide()
		var shape: BoxShape3D = body.get_node("CollisionShape3D").shape
		body.add_child(maker.cover_mesh(String(body.name),shape.size))
