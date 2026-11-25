extends SceneTree
## Audit the visual pass against the actual target campaign scene.
const PROFILE := preload("res://scripts/integration/player_profile.gd")
const PROGRESS := preload("res://scripts/integration/campaign_progress.gd")
const PLAN := preload("res://scenes/dungeon/level04/observatory_plan.gd")
var checks := 0
var failures := 0

class AuditedArt:
	extends "res://scenes/dungeon/level04/observatory_selected_room_art.gd"
	var before: Dictionary
	var after: Dictionary
	var floors: Dictionary
	func snapshot(level: Node3D) -> Dictionary:
		var result := {}
		for node in level.find_children("*","Node",true,false):
			var values: Array = [node.get_parent().get_instance_id(),node.name,node.get_class(),node.process_mode,node.get_groups()]
			if node is Node3D: values.append(node.transform)
			if node is MeshInstance3D: values.append_array([node.mesh.get_rid(),node.material_overlay,node.layers,node.cast_shadow])
			elif node is Node3D:
				var well_cover: bool = node.get_parent().name == "D" and not node is CollisionObject3D and node.position.is_equal_approx(Vector3(-1,0.026,0))
				if not well_cover: values.append(node.visible)
			if node is CollisionObject3D: values.append_array([node.collision_layer,node.collision_mask])
			if node is CollisionShape3D: values.append_array([node.shape.get_rid(),node.disabled,node.shape.get_debug_mesh().get_aabb()])
			if node is CollisionPolygon3D: values.append_array([node.polygon.duplicate(),node.depth,node.disabled])
			if node is Label3D: values.append_array([node.text,node.font,node.pixel_size])
			result[node.get_instance_id()] = values
		return result
	func apply(level: Node3D) -> void:
		before = snapshot(level)
		for view in level.layout.find_children("*","MeshInstance3D",true,false):
			if view.get_parent().name == "Deck": floors[view.get_instance_id()] = view.material_override
		super.apply(level)
		after = snapshot(level)

func _initialize() -> void:
	PROFILE.override_path = "user://selected-art-profile.cfg"
	PROGRESS.override_path = "user://selected-art-campaign.cfg"
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL "+message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func run() -> void:
	var host: Node = load("res://scenes/dungeon/Level04Run.tscn").instantiate()
	var audit: Node = host.get_node("DungeonTest/SelectedRoomArt")
	audit.set_script(AuditedArt)
	root.add_child(host)
	current_scene = host
	await frames(12)
	host._on_run_started()
	var world: Node3D = host._dungeon
	check(not audit.before.is_empty(),"Campaign scene automatically applies the independent art pass")
	var originals_preserved := true
	for id: int in audit.before:
		if audit.after.get(id) != audit.before[id]: originals_preserved = false
	check(originals_preserved,"Original nodes, mesh geometry, transforms, colliders, overlays, labels and processing remain intact")
	var additions_are_visual := true
	for id: int in audit.after:
		if audit.before.has(id): continue
		var node := instance_from_id(id)
		if (not node is Node3D and not node is SubViewport) or node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D: additions_are_visual = false
	check(additions_are_visual,"All added room content is visual without physics or interaction nodes")
	check(audit.floors.size() == 28,"Audit covers twelve room floors and sixteen corridor floors")
	for id: int in audit.floors:
		var view := instance_from_id(id) as MeshInstance3D
		var owner_name: String = view.get_parent().get_parent().name
		var special: String = {"D":"counterweight_deck.gdshader","F":"prismatic_walkway.gdshader","L":"darkroom_floor.gdshader"}.get(owner_name,"")
		if owner_name.length() == 2 and owner_name.contains("F"): special = "prismatic_walkway.gdshader"
		if special != "":
			check(view.material_override.shader == load("res://scenes/dungeon/level04/"+special),"Restored special surface on the original Deck "+owner_name)
			for uniform: Dictionary in audit.floors[id].shader.get_shader_uniform_list():
				check(view.material_override.get_shader_parameter(uniform.name) == audit.floors[id].get_shader_parameter(uniform.name),"Special floor retains target background parameter "+owner_name+" "+str(uniform.name))
		else:
			check(view.material_override == audit.floors[id],"Background material remains owned by the existing finish %d" % id)
	check(PLAN.CENTERS.size() == 12 and PLAN.LINKS.size() == 16 and world.layout._gates.size() == 16,"Twelve rooms and sixteen live progression gates remain")
	for pair in [["A/ArrivalArt","MonumentalEntranceArch"],["B/LoadingWorkshopArt","HeavyLiftingCrane"],["C/IndexHallArt",""]]:
		var art: Node3D = world.layout.get_node_or_null(pair[0])
		check(art != null and (pair[1] == "" or art.has_node(pair[1])),"Original room art is installed: "+pair[0])
	var hall: Node3D = world.layout.get_node("C/IndexHallArt")
	check(hall.rotors.size() == 4,"Original mechanical dial and three companion rotors are restored")
	var angle: float = hall.rotors[0].node.rotation.y
	world.player.global_position = world.layout.room_center("C")+Vector3(0,0.05,2)
	world.player._invulnerability_remaining = 100000
	world.player.velocity = Vector3.ZERO
	await frames(5)
	check(not is_equal_approx(angle,hall.rotors[0].node.rotation.y),"Original decorative mechanism animates near the player")
	angle = hall.rotors[0].node.rotation.y
	paused = true
	await frames(3)
	check(is_equal_approx(angle,hall.rotors[0].node.rotation.y),"Decorative animation follows the campaign pause state")
	paused = false
	var beacons: Array = world.layout._wing_beacons.duplicate()
	for state in [[true,false],[false,true],[true,true]]:
		world.layout.set_wing_lights(state[0],state[1])
		check(world.layout._wing_beacons == beacons and beacons[0].visible and beacons[1].visible,"Both target wing beacons remain active and visible: "+str(state))
	var count: int = audit.after.size()
	audit.apply(world)
	check(audit.after.size() == count,"Applying the art pass twice does not duplicate content")
	for pair in [["uid://c8ho3ghd0a765","observatory_arrival_art.gd"],["uid://buvgvohl5ujgo","observatory_loading_art.gd"],["uid://oqb6g3owvq2r","observatory_index_art.gd"]]:
		check(ResourceUID.get_id_path(ResourceUID.text_to_id(pair[0])) == "res://scenes/dungeon/level04/"+pair[1],"Original room art UID resolves: "+pair[1])
	await room_specific_checks(world)
	if "--capture" in OS.get_cmdline_user_args():
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280,720)
		world.set_physics_process(false)
		for id: String in world.combat.ROSTERS: world.combat._cleared[id] = true
		world.puzzles.calibrated = true
		world._refresh_gates()
		var output := OS.get_environment("GODOT_TEST_OUTPUT_DIR")
		DirAccess.make_dir_recursive_absolute(output)
		var camera: Camera3D = world.get_node("Camera3D")
		for id in capture_rooms():
			world.player.global_position = world.layout.room_center(id)+Vector3(0,0.05,2)
			world.player.velocity = Vector3.ZERO
			camera.reset_follow()
			await frames(30)
			RenderingServer.force_draw()
			check(root.get_texture().get_image().save_png(output.path_join(id+".png")) == OK,"Capture "+id)
		# Inspect actual actor fade beneath the restored entrance arch and crane.
		for spec in [["A",Vector3(0,0.05,-3.6)],["B",Vector3(6,0.05,-1)]]:
			world.player.global_position = world.layout.room_center(spec[0])+spec[1]
			world.player.velocity = Vector3.ZERO
			camera.reset_follow()
			await frames(30)
			RenderingServer.force_draw()
			check(root.get_texture().get_image().save_png(output.path_join(spec[0]+"-under-structure.png")) == OK,"Capture actor visibility "+spec[0])
	root.get_node("MusicManager").stop_music()
	host.queue_free()
	await frames(4)
	print("LEVEL04_SELECTED_ROOM_ART: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func room_specific_checks(_world: Node3D) -> void:
	pass

func capture_rooms() -> Array[String]:
	return ["A","B","C"]
