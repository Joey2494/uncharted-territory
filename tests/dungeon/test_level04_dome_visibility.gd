extends SceneTree
## 穹顶北缘持续近战时，检查铜盘、双环和轴与实体岛一同透出角色。
const LEVEL := "res://scenes/dungeon/level04/Level04Preview.tscn"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	change_scene_to_file(LEVEL)
	for i in 5: await physics_frame
	var level = current_scene
	var center: Vector3 = level.layout.room_center("I")
	level.combat._cleared["I"] = true
	level.player.position = center + Vector3(-0.448,0.001,-2.664)
	for i in 90: await physics_frame
	var island: StaticBody3D
	# 在实际遮挡点从上方射入岛体，取得参与游戏碰撞的同一个对象。
	var ray := PhysicsRayQueryParameters3D.create(center+Vector3.UP*4,center+Vector3.UP,1)
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): island = hit.collider as StaticBody3D
	var visible_surfaces := 0
	var faded_surfaces := 0
	if island:
		for mesh: MeshInstance3D in island.find_children("*","MeshInstance3D",true,false):
			visible_surfaces += 1
			var mat := mesh.material_override as BaseMaterial3D
			if mat != null and mat.albedo_color.a < 0.25:
				faded_surfaces += 1
	var passed := visible_surfaces == 5 and faded_surfaces == 5
	print("north rim / faded island pieces = %d of %d (expected five)" % [faded_surfaces,visible_surfaces])
	if not passed: printerr("FAIL dome instrument hides knight at northern rim")
	level.player.position = center + Vector3(0,0.001,4)
	for i in 90: await physics_frame
	var restored := 0
	if island:
		for mesh: MeshInstance3D in island.find_children("*","MeshInstance3D",true,false):
			var mat := mesh.material_override as BaseMaterial3D
			if mat != null and mat.albedo_color.a > 0.99: restored += 1
	print("south rim / restored island pieces = %d of %d" % [restored,visible_surfaces])
	passed = passed and restored == 5
	root.get_node("MusicManager").stop_music()
	level.queue_free()
	for i in 3: await process_frame
	quit(0 if passed else 1)
