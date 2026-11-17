@static_unload
extends RefCounted
## Build one small spatial grid per physics tick so a dense swarm spreads instead of overlapping.
static var _frame := -1
static var _grid: Dictionary = {}
static func separation(actor: Node3D) -> Vector3:
	var frame := Engine.get_physics_frames()
	if frame != _frame:
		_frame = frame
		_grid.clear()
		for node in actor.get_tree().get_nodes_in_group("broodlings"):
			if node.is_queued_for_deletion() or node._attached or node._emerge_remaining > 0: continue
			var cell := Vector2i(floori(node.global_position.x / 0.65), floori(node.global_position.z / 0.65))
			if not _grid.has(cell): _grid[cell] = []
			_grid[cell].append(node.global_position)
	var cell := Vector2i(floori(actor.global_position.x / 0.65), floori(actor.global_position.z / 0.65))
	var force := Vector3.ZERO
	for x in range(-1, 2):
		for y in range(-1, 2):
			for point: Vector3 in _grid.get(cell + Vector2i(x, y), []):
				var offset := actor.global_position - point
				offset.y = 0
				var distance := offset.length()
				if distance > 0.001 and distance < 0.58:
					force += offset / distance * (0.58 - distance) / 0.58
	return force.limit_length(1.5)
