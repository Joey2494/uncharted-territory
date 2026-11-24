extends SceneTree
func _initialize() -> void:
	preload("res://scripts/integration/player_profile.gd").override_path = "res://.godot/weapon_ui_profile.cfg"
	preload("res://scripts/integration/campaign_progress.gd").override_path = "res://.godot/weapon_ui_progress.cfg"
	run.call_deferred()
func frames(count: int = 8) -> void:
	for i in count: await process_frame
func capture(label: String) -> void:
	await frames()
	RenderingServer.force_draw()
	var result := root.get_texture().get_image().save_png("res://docs/change/week10-evidence/"+label+".png")
	print("UI_CAPTURE ",label," ",result)
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	change_scene_to_file("res://Main.tscn")
	await frames(12)
	var host := current_scene
	host._on_run_started()
	await frames()
	host.get_node("RunBindings/TutorialController").skip()
	host._items.add_gold(200)
	await capture("hud")
	host._commerce.open_shop()
	await capture("shop")
	host._items.try_purchase(6,1,host._commerce)
	host._items.try_purchase(7,1,host._commerce)
	host._commerce.close_all()
	host._commerce.open_backpack()
	await capture("ammo_backpack")
	if "--weapon-states" in OS.get_cmdline_user_args():
		host._commerce.close_all()
		var profile = preload("res://scripts/integration/player_profile.gd")
		profile.ensure_loaded()
		profile.unlocked.assign(["knight","lan","iron","astra"])
		for id in ["lan","astra","iron","knight"]:
			profile.set_selected_character(id)
			change_scene_to_file("res://Main.tscn")
			await frames(12)
			host = current_scene
			host._on_run_started()
			await frames()
			host.get_node("RunBindings/TutorialController").skip()
			var weapons: Node = host._player.get_node("WeaponLoadout")
			if id == "lan": weapons.slots[0].ammo = 6
			await capture("hud_"+weapons.slots[0].id)
			print("WEAPON_READOUT ",host._hud.weapon_label.text," ",host._hud.ammo_label.text)
			weapons.try_switch()
			for i in 15: await physics_frame
			await capture("hud_"+weapons.slots[1].id)
			print("WEAPON_READOUT ",host._hud.weapon_label.text," ",host._hud.ammo_label.text)
		profile.set_selected_character("knight")
	quit()
