extends SceneTree
const Profile = preload("res://scripts/integration/player_profile.gd")
const Progress = preload("res://scripts/integration/campaign_progress.gd")
const Catalog = preload("res://data/item_catalog.gd")
const Presenter = preload("res://scenes/items/commerce_presenter.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", description)
func frames(count := 3) -> void:
	for i in count: await physics_frame
	await process_frame
func capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/integration_%s.png" % name)
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	Profile.override_path = "res://.godot/local_integration_profile.cfg"
	Progress.override_path = "res://.godot/local_integration_progress.cfg"
	if FileAccess.file_exists(Profile.override_path): DirAccess.remove_absolute(Profile.override_path)
	Profile.ensure_loaded()
	Profile.set_coins(500)
	preload("res://scenes/player/character_catalog.gd").selected_id = "knight"
	change_scene_to_file("res://Main.tscn")
	await frames(8)
	var host := current_scene
	var actor: Node = host._player
	var items: Node = host._items
	var commerce: Node = host._commerce
	check(actor.max_shield == 2 and actor.get_node("CharacterAbility").get_configuration().active, "local Knight mechanisms kept")
	var selector: Control = host.get_node("MenuNavigation").character_select
	selector.show_selection("iron")
	await frames()
	for key in ["Attack", "Health", "Shield", "Speed"]:
		var card := selector.get_node("%" + key + "Stat")
		check(not card.get_node("%ComparisonLabel").visible and card.get_node("%ComparisonLabel").text.is_empty(), "roster comparison removed: " + key)
		check(not card.get_node("%ReferenceMarker").visible and not card.tooltip_text.contains("旅人"), "no reference line or baseline tooltip: " + key)
	await capture("character")
	selector.hide()
	host._on_run_started()
	await frames()
	if host.get_node("RunBindings").tutorial != null: host.get_node("RunBindings").tutorial.skip()
	check(host.get_run_state() == host.RunState.PLAYING, "game starts after character preview")
	check(items.gold == 0 and Profile.coins == 500, "per-run gold separate from wallet")
	check(Catalog.get_products().size() == 6 and Catalog.get_item(5).price == 15, "six products including 15 coin energy potion")
	items.add_gold(30, "potion_test")
	commerce.open_shop()
	await frames()
	var products := Presenter.products(items, commerce)
	check(products.size() == 6 and products[5].icon != null and products[5].id == &"energy_potion", "shop supplies potion art and data")
	var shop: Control = host.get_node("CommerceLayer/ShopScreen")
	var potion_card: Control = shop.get_product_card(&"energy_potion")
	(potion_card.get_parent().get_parent() as ScrollContainer).ensure_control_visible(potion_card)
	await frames()
	await capture("shop")
	potion_card.get_buy_button().pressed.emit()
	check(items.energy_potion_count == 1, "shop purchase button buys potion while world is frozen")
	check(items.gold == 15 and items.energy_potion_count == 1 and Profile.coins == 500, "purchase uses run gold only")
	commerce.close_all()
	commerce.open_backpack()
	await frames()
	actor.energy = 12.5
	var hp: int = actor.hp
	var shield: int = actor.shield
	check(items.try_use_item(Catalog.ENERGY_POTION, commerce), "backpack can use potion while paused")
	check(actor.energy == 32.5 and actor.hp == hp and actor.shield == shield, "potion restores exactly 20 energy only")
	check(items.energy_potion_count == 0, "instant potion consumes one without enabling passive recovery")
	commerce.close_all()
	await frames()
	items._use_remaining = 0.0
	items.add_item(Catalog.ENERGY_POTION, 2)
	actor.energy = actor.max_energy
	check(not items.try_use_item(Catalog.ENERGY_POTION) and items.energy_potion_count == 2, "full energy does not consume")
	actor.energy = actor.max_energy - 0.25
	check(items.try_use_item(Catalog.ENERGY_POTION) and actor.energy == actor.max_energy, "fractional missing energy clamps to cap")
	check(not items.try_use_item(Catalog.ENERGY_POTION) and items.energy_potion_count == 1, "shared use cooldown prevents repeat")
	items._use_remaining = 0.0
	actor.energy = 0.0
	host.get_node("RunBindings")._use_hotbar(5, &"energy_potion")
	check(actor.energy == 20.0 and items.energy_potion_count == 0, "sixth hotbar slot uses actual potion")
	items.add_item(Catalog.ENERGY_POTION)
	items._use_remaining = 0.0
	host._dungeon.process_mode = Node.PROCESS_MODE_DISABLED
	check(not items.try_use_item(Catalog.ENERGY_POTION), "frozen world rejects unapproved item use")
	host._dungeon.process_mode = Node.PROCESS_MODE_PAUSABLE
	actor.take_damage(999)
	check(not items.try_use_item(Catalog.ENERGY_POTION) and items.energy_potion_count == 1, "death rejects potion use")
	check(Profile.coins == 500, "death does not persist pending gold")
	host.queue_free()
	await frames()
	change_scene_to_file("res://scenes/dungeon/Level03Run.tscn")
	await frames(10)
	host = current_scene
	host._on_run_started()
	await frames(8)
	var stone: Array[Node] = host._dungeon.find_children("FirstLevelStone", "MultiMeshInstance3D", true, false)
	check(not stone.is_empty(), "third level uses first-level stone art")
	check(stone.all(func(node: Node) -> bool: return String(node.get_meta("source_model", "")).begins_with("res://assets/dungeon/almsyone/")), "third level reuses first-level source assets")
	await capture("level03")
	host.queue_free()
	await frames()
	root.get_node("MusicManager").stop_music()
	await create_timer(0.15).timeout # Let the audio server release its playback references.
	print("LOCAL_INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
