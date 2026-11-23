extends SceneTree
const PROFILE = preload("res://scripts/integration/player_profile.gd")
func _initialize() -> void:
	PROFILE.override_path = "res://.godot/character_details_capture.cfg"
	run.call_deferred()
func frames(count: int = 8) -> void:
	for i in count: await process_frame
func capture(label: String) -> void:
	await frames()
	RenderingServer.force_draw()
	var result := root.get_texture().get_image().save_png("res://docs/change/week10-evidence/"+label+".png")
	print("CHARACTER_CAPTURE ",label," ",result)
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	var selector := preload("res://scenes/ui/character_select.tscn").instantiate()
	root.add_child(selector)
	for id in ["knight","lan","iron","astra"]:
		selector.show_selection(id)
		await frames()
		selector.get_node("%SkillJump").pressed.emit()
		await capture("character_"+id+"_skill")
		selector.get_node("%WeaponsJump").pressed.emit()
		await capture("character_"+id+"_weapons")
	root.size = Vector2i(900,600)
	selector.show_selection("astra")
	await frames()
	selector.get_node("%WeaponsJump").pressed.emit()
	await capture("character_compact_weapons")
	quit()
