extends SceneTree
## Real positions, visibility, collection, rune interaction and pause drive contextual hints.
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
var host: Node
var hints: Control
var shown: Array[String] = []
var checks := 0
var failures := 0
var captures := false
var output := "user://castle-context-captures"

func _initialize() -> void: run.call_deferred()
func run() -> void:
	PROFILE.override_path = "user://castle-context-profile.cfg"
	PROGRESS.override_path = "user://castle-context-campaign.cfg"
	captures = "--capture" in OS.get_cmdline_user_args()
	if not OS.get_environment("GODOT_TEST_OUTPUT_DIR").is_empty(): output = OS.get_environment("GODOT_TEST_OUTPUT_DIR")
	if captures: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	await boot()
	check(not hints.card.visible and hints._seen.is_empty(),"Menus do not display or consume proximity hints")
	await start()
	await go(Vector3(-2.4,0.05,-0.8))
	await wait_hint("supply:EntrancePotion")
	check(hints.get_node("%HintCategory").text == "可选补给" and hints.get_node("%HintBody").text.contains("生命药剂"),"Supply hint identifies a real nearby potion as optional")
	verify_card()
	await capture("01-optional-supply")
	var remaining: float = hints._remaining
	await create_timer(0.12).timeout
	check(hints._remaining < remaining,"Standing nearby does not restart the lifetime every frame")
	host.set_paused(true)
	remaining = hints._remaining
	await create_timer(0.12).timeout
	check(not hints.card.visible and is_equal_approx(remaining,hints._remaining),"Pause hides local hints and freezes their remaining time")
	host.set_paused(false)
	var supply_deadline := Time.get_ticks_msec()+10000
	while hints._active.get("key","") == "supply:EntrancePotion" and Time.get_ticks_msec() < supply_deadline: await frames(2)
	check(not hints.card.visible and shown.count("supply:EntrancePotion") == 1,"Supply hint expires without repeating while the player stays nearby")
	await go(Vector3(5,0.05,4))
	await go(Vector3(-2.4,0.05,-0.8))
	await create_timer(0.2).timeout
	check(shown.count("supply:EntrancePotion") == 1,"Re-entering the same supply does not repeat its hint in this run")
	await boot()
	await start()
	# A temporary wall fixture verifies the same layer-1 sightline rule as real walls.
	var wall := StaticBody3D.new()
	wall.position = Vector3(-2.4,1.0,0.5)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3,3,0.25)
	shape.shape = box
	wall.add_child(shape)
	host._dungeon.add_child(wall)
	await go(Vector3(-2.4,0.05,-0.8))
	await frames(8)
	check(not hints.card.visible and not hints.guide.visible and not hints._seen.has("supply:EntrancePotion"),"A blocking wall prevents a supply hint without consuming its one-time opportunity")
	wall.queue_free()
	await frames(3)
	await wait_hint("supply:EntrancePotion")
	await go(Vector3(-2.4,0.05,0.5))
	check(not hints.card.visible and host._hud.pickup_prompt.visible,"At collection range, the original E prompt replaces the optional supply hint")
	check(host._hud.pickup_prompt.text.contains("生命药剂 ×1"),"The original E prompt now includes the first-level supply's actual quantity")
	check(host._items.try_interact_nearest(),"The real potion pickup still uses its original interaction")
	await frames(3)
	check(not host._dungeon.has_node("EntrancePotion") and not hints.card.visible,"Collected supplies cannot leave stale floating hints")
	await go(Vector3(0,0.05,-23))
	host._dungeon.get_node("MeleeEnemy").take_damage(999)
	await frames(4)
	await go(Vector3(-26,0.05,-23))
	await wait_hint("puzzle:observe")
	check(hints.get_node("%HintBody").text.contains("石刻") and hints.get_node("%HintBody").text.contains("图案"),"The local puzzle hint directs observation of the actual stone inscription and rune patterns")
	check(not host._hud.get_node("LevelObjective").has_node("%QuestOptional"),"Mandatory objectives remain separate from optional puzzle and supply hints")
	verify_no_spoiler()
	verify_card()
	await capture("02-observe-runes")
	var puzzle: Node3D = host._rune_puzzle
	check(puzzle.progress == 0 and puzzle.state == puzzle.State.READY,"Reading a hint never activates a rune or changes the puzzle")
	# Extend only this presentation clock while native windows resize; gameplay is untouched.
	var original_lifetime: float = hints._remaining
	hints._remaining = 30.0
	for dimensions in [Vector2i(720,720),Vector2i(480,800),Vector2i(640,360),Vector2i(1280,720)]:
		root.size = dimensions
		await frames(6)
		if hints.card.visible:
			verify_card()
			await capture("03-local-hint-%dx%d" % [dimensions.x,dimensions.y])
		else:
			check(not hints.card.visible,"Crowded viewports defer the local card instead of covering HUD or actors")
	hints._remaining = minf(original_lifetime,1.0)
	await create_timer(5.2).timeout
	check(shown.count("puzzle:observe") == 1,"Observing the same mechanism cannot continuously repeat its hint")
	await go(puzzle.get_node("SunRune").global_position+Vector3(0,0.05,1.2))
	check(puzzle.activate_rune(0,host._player),"Actual wrong rune interaction triggers the original reset")
	await frames(2)
	host._hud.show_item_message("")
	await wait_hint("puzzle:retry")
	verify_no_spoiler()
	check(puzzle.progress == 0,"Retry guidance never reveals or applies a correct step")
	await capture("04-retry-observation")
	await create_timer(0.8).timeout
	await go(puzzle.get_node("MoonRune").global_position+Vector3(0,0.05,1.2))
	check(puzzle.activate_rune(1,host._player),"Actual correct rune interaction retains original gameplay")
	await frames(2)
	host._hud.show_item_message("")
	await frames(3)
	if hints.card.visible:
		check(hints.get_node("%HintProgress").text.contains("1/3"),"Local mechanism progress follows a real successful input")
		verify_no_spoiler()
	await go(Vector3(0,0.05,2))
	check(not hints.card.visible,"Leaving a mechanism removes its local hint")
	await go(Vector3(28,0.05,-23))
	check(not hints.card.visible,"Boss combat does not show local observation or supply cards")
	await verify_supply_discovery()
	await boot()
	check(hints._seen.is_empty(),"A fresh run resets local hint deduplication")
	paused = false
	root.get_node("MusicManager").stop_music()
	current_scene.queue_free()
	await frames(3)
	print("CASTLE_HINTS_RESULT %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func verify_supply_discovery() -> void:
	await boot()
	await start()
	await go(Vector3(0,0.05,10))
	await wait_guide("guide:entrance:arrival")
	check(hints.get_node("%GuideText").text.contains("大厅内有补给"),"The entrance approach proactively points into the actual supply room")
	verify_guide()
	await capture("05-entrance-supply-direction")
	await go(Vector3(0,0.05,-23))
	check(not hints.guide.visible,"Active courtyard combat suppresses supply route guidance")
	host._dungeon.get_node("MeleeEnemy").take_damage(999)
	await go(Vector3(-3,0.05,-23))
	await wait_guide("guide:west:junction")
	check(hints.get_node("%GuideText").text == "← 西侧通道有补给","The courtyard points left before entering the west passage")
	check(host._player.global_position.distance_to(host._dungeon.get_node("SupplyPotion").global_position) > hints.NEAR,"The supply route is announced before proximity discovery")
	verify_guide()
	await capture("06-before-west-passage")
	var original_guide_time: float = hints._guide_seconds["guide:west:junction"]
	hints._guide_seconds["guide:west:junction"] = 30.0
	for dimensions in [Vector2i(720,720),Vector2i(480,800),Vector2i(640,360),Vector2i(1280,720)]:
		root.size = dimensions
		await frames(6)
		if hints.guide.visible:
			verify_guide()
			await capture("06-supply-direction-%dx%d" % [dimensions.x,dimensions.y])
		else:
			check(not hints.guide.visible,"Crowded screens safely defer supply directions")
	hints._guide_seconds["guide:west:junction"] = original_guide_time
	var remaining: float = hints._guide_seconds[hints._guide_key]
	host.set_paused(true)
	await create_timer(0.12).timeout
	check(not hints.guide.visible and is_equal_approx(remaining,hints._guide_seconds["guide:west:junction"]),"Pause hides and freezes the short directional message")
	host.set_paused(false)
	await create_timer(3.4).timeout
	check(hints.guide.visible and hints.get_node("%GuideText").text == "← 补给","A brief direction collapses into a quiet cache icon and arrow")
	check(shown.count("guide:west:junction") == 1,"The same junction direction is announced only once")
	await capture("07-quiet-supply-marker")
	var wall := StaticBody3D.new()
	wall.position = Vector3(-6,1,-23)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.25,3,6)
	shape.shape = box
	wall.add_child(shape)
	host._dungeon.add_child(wall)
	await frames(5)
	check(not hints.guide.visible,"Directional guidance cannot point through a blocked approach")
	wall.queue_free()
	await frames(5)
	await go(Vector3(-2,0.05,-23))
	check(hints.guide.visible and hints.get_node("%GuideText").text == "← 补给" and shown.count("guide:west:junction") == 1,"Returning to a doorway retains only its small marker rather than replaying the announcement")
	await go(Vector3(-12,0.05,-23))
	await wait_guide("guide:west:passage")
	check(hints.get_node("%GuideText").text == "← 通道尽头有补给","The adjacent passage guides toward the actual room entrance")
	verify_guide()
	await capture("08-passage-to-supply-room")
	await go(Vector3(-19.7,0.05,-18.5))
	await wait_guide("guide:west:chamber")
	check(hints.get_node("%GuideText").text.contains("石室内有补给"),"Room entry guides toward the remaining real supplies")
	verify_guide()
	await capture("09-supply-room-entry")
	host._dungeon.get_node("SupplyPotion").quantity = 3
	host._dungeon.get_node("AttackRune").quantity = 2
	await go(Vector3(-23,0.05,-23))
	await wait_hint("supply:SupplyPotion")
	check(not hints.guide.visible and hints.get_node("%HintBody").text.contains("生命药剂 ×3"),"Near the actual potion, the route marker yields to its live name and quantity")
	verify_card()
	await capture("10-near-potion-details")
	await wait_hint("supply:AttackRune")
	check(hints.get_node("%HintBody").text.contains("强化符文 ×2"),"The second supply has its own real quantity rather than sharing the room's consumed hint")
	await capture("11-near-rune-details")
	await go(Vector3(-24,0.05,-24.8))
	check(host._hud.pickup_prompt.text.contains("生命药剂 ×3"),"At interaction range the E prompt keeps the actual potion quantity")
	check(host._items.try_interact_nearest(),"The potion keeps its original pickup behavior")
	await frames(4)
	await go(Vector3(-27,0.05,-21.8))
	check(host._hud.pickup_prompt.text.contains("强化符文 ×2"),"At interaction range the E prompt keeps the actual rune quantity")
	check(host._items.try_interact_nearest(),"The rune keeps its original pickup behavior")
	await frames(4)
	for point in [Vector3(-19.7,0.05,-18.5),Vector3(-12,0.05,-23),Vector3(-3,0.05,-23)]:
		await go(point)
		check(not hints.guide.visible and hints._guide_candidate().is_empty(),"Collected supplies remove guidance from their room, passage and adjacent courtyard")
	var default_pickup: Area3D = load("res://scenes/items/item_pickup.gd").new()
	check(not default_pickup.show_prompt_quantity and default_pickup.get_interaction_prompt() == "[E] 拾取 生命药剂","Other levels retain their default pickup prompt wording")
	default_pickup.free()

func wait_guide(key: String) -> void:
	var deadline := Time.get_ticks_msec()+12000
	while (not hints.guide.visible or hints._guide_key != key) and Time.get_ticks_msec() < deadline: await frames(2)
	check(hints.guide.visible and hints._guide_key == key,"Expected proactive supply guide appears: "+key)

func verify_guide() -> void:
	var rect: Rect2 = hints.guide.get_global_rect()
	check(root.get_visible_rect().grow(1).encloses(rect),"Supply direction marker fits inside the viewport")
	var clear := true
	for obstacle in host._hud.hint_dock.obstacles():
		if rect.intersects(obstacle): clear = false
	check(clear and not hints.card.visible,"Supply direction marker avoids HUD, player, key labels and other local cards")
	check(hints.guide.mouse_filter == Control.MOUSE_FILTER_IGNORE and hints.guide.get_node("Icon").texture != null,"The cache icon is visible and never captures player input")

func boot() -> void:
	paused = false
	change_scene_to_file("res://Main.tscn")
	await frames(8)
	host = current_scene
	hints = host._hud.get_node("CastleHints")
	shown.clear()
	hints.hint_shown.connect(func(_kind: String,key: String): shown.append(key))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
func start() -> void:
	host._on_run_started()
	host._player.global_position = Vector3(6,0.05,5)
	host._player._invulnerability_remaining = 100000.0
	host.get_node("RunBindings").tutorial.skip()
	await frames(4)
	host._hud.show_item_message("")
func go(point: Vector3) -> void:
	host._player.global_position = point
	await frames(4)
	host._hud.show_item_message("")
	host._dungeon.get_node("Camera3D").reset_follow()
	await frames(4)
func wait_hint(key: String) -> void:
	var deadline := Time.get_ticks_msec()+12000
	while (not hints.card.visible or hints._active.get("key","") != key) and Time.get_ticks_msec() < deadline:
		await frames(2)

	var arrived: bool = hints.card.visible and hints._active.get("key","") == key
	if not arrived:
		print("HINT_DIAGNOSTIC "+JSON.stringify({"expected":key,"active":str(hints._active),"seen":hints._seen,"remaining":hints._remaining,"feedback":host._hud.item_message.text,"feedback_visible":host._hud.item_message.visible,"player":str(host._player.global_position),"camera":str(host._dungeon.get_node("Camera3D").global_position),"card":str(hints.card.get_global_rect()),"obstacles":str(host._hud.hint_dock.obstacles())}))
	check(arrived,"Expected local hint appears: "+key)
func verify_no_spoiler() -> void:
	var text: String = hints.get_node("%HintCategory").text+hints.get_node("%HintBody").text+hints.get_node("%HintProgress").text
	var journal: Dictionary = host._hud.get_node("LevelObjective")._snapshot
	for task in journal.optional: text += task.title+task.detail
	check(not text.contains("月→星→日") and not text.contains("月升") and not text.contains("星现") and not text.contains("日出"),"Added HUD guidance never prints the puzzle answer")
func verify_card() -> void:
	var rect: Rect2 = hints.card.get_global_rect()
	check(root.get_visible_rect().grow(1).encloses(rect),"Local card fits inside the viewport")
	var clear := true
	for obstacle in host._hud.hint_dock.obstacles():
		if rect.intersects(obstacle): clear = false
	check(clear,"Local card avoids HUD, player silhouette and the stone/rune inscriptions")
	check(hints.mouse_filter == Control.MOUSE_FILTER_IGNORE and hints.card.mouse_filter == Control.MOUSE_FILTER_IGNORE,"Local hints never capture combat input")
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func capture(label: String) -> void:
	if not captures: return
	await process_frame
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"Capture "+label)
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
