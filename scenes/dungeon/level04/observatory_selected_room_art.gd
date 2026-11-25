extends Node
## Additive visual pass after the target layout and background are ready.
## Architecture, colliders, route indicators and gameplay keep their ownership.
const ARRIVAL := preload("res://scenes/dungeon/level04/observatory_arrival_art.gd")
const LOADING := preload("res://scenes/dungeon/level04/observatory_loading_art.gd")
const INDEX_HALL := preload("res://scenes/dungeon/level04/observatory_index_art.gd")
const MECHANICAL_ROOMS := preload("res://scenes/dungeon/level04/observatory_mechanical_room_art.gd")
const OPTICAL_ROOMS := preload("res://scenes/dungeon/level04/observatory_optical_room_art.gd")

func _ready() -> void:
	apply.call_deferred(get_parent())

func apply(level: Node3D) -> void:
	var layout := level.get_node("Layout") as Node3D
	var arrival := layout.get_node("A") as Node3D
	if not arrival.has_node("ArrivalArt"):
		var plinth := _cover_at(arrival,Vector3(-3.9,0.57,1.6))
		if plinth != null: ARRIVAL.new().build(arrival,plinth)
	var loading := layout.get_node("B") as Node3D
	if not loading.has_node("LoadingWorkshopArt"):
		var tower := _cover_at(loading,Vector3(4,0.88,1))
		if tower != null:
			LOADING.new().build(loading,tower)
			# The old crane replaces only these visual placeholder boom pieces.
			# Keep the existing tower body, Surface and collider intact.
			for child in tower.get_children():
				if child is MeshInstance3D and child.name != "Surface": child.hide()
	var hall := layout.get_node("C") as Node3D
	if not hall.has_node("IndexHallArt"):
		INDEX_HALL.new().build(layout)
		# Replace only the three placeholder rings with the original scale dial.
		# Wing beacons and signs remain active and visible under the target code.
		for child in hall.get_children():
			if not child is MeshInstance3D or not child.mesh is TorusMesh: continue
			if not child.position.is_equal_approx(Vector3(0,0.017,0)): continue
			for radius: float in [1.8,2.1,3.35]:
				if is_equal_approx(child.mesh.inner_radius,radius-0.036) and is_equal_approx(child.mesh.outer_radius,radius+0.036): child.hide()
	OPTICAL_ROOMS.new().apply(level)
	MECHANICAL_ROOMS.new().apply(level)

func _cover_at(room: Node3D, at: Vector3) -> StaticBody3D:
	# Original architecture uses generated names: match the existing body by
	# its local transform and named render surface, never by child index.
	for child in room.get_children():
		if child is StaticBody3D and child.position.is_equal_approx(at) and child.get_node_or_null("Surface") is MeshInstance3D:
			return child
	push_error("Missing existing observatory cover in " + str(room.get_path()))
	return null
