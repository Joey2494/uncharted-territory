extends SceneTree
## Use actual key events against the integrated menu and an isolated wallet.
const PROFILE = preload("res://scripts/integration/player_profile.gd")
const PROGRESS = preload("res://scripts/integration/campaign_progress.gd")
var host: Node
var nav: Node
var selector: Control
var checks := 0
var failures := 0
var confirmations := 0
var purchases := 0
var backs := 0

func _initialize() -> void: run.call_deferred()
func run() -> void:
	PROFILE.override_path = test_save_path("keyboard-profile")
	PROGRESS.override_path = test_save_path("keyboard-progress")
	PROFILE.set_coins(1000)
	PROFILE.unlock_character("lan")
	PROFILE.set_selected_character("lan")
	change_scene_to_file("res://Main.tscn")
	await frames(8)
	host = current_scene
	nav = host.get_node("MenuNavigation")
	selector = nav.character_select
	selector.character_confirmed.connect(func(_id: StringName) -> void: confirmations += 1)
	selector.character_purchased.connect(func() -> void: purchases += 1)
	selector.back_requested.connect(func() -> void: backs += 1)
	await back_with_enter(KEY_ENTER)
	await back_with_enter(KEY_KP_ENTER)
	await locked_purchase()
	if "--baseline" not in OS.get_cmdline_user_args():
		await poor_character()
		await browse_and_mouse_purchase()
		await keyboard_confirm_and_cancel()
		await keypad_unlock()
	paused = false
	root.get_node("MusicManager").stop_music()
	current_scene.queue_free()
	await frames(3)
	print("CHARACTER_KEYBOARD_RESULT %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func open_character(id: String = "lan") -> void:
	nav._back_to_menu()
	host._start_screen.start_button.pressed.emit()
	selector.show_selection(id)
	await frames(3)

func back_with_enter(code: Key) -> void:
	await open_character()
	var before := confirmations
	var before_backs := backs
	selector.get_node("%BackButton").grab_focus()
	await key(code)
	check(host._start_screen.visible and not nav.level_select.visible and not selector.visible, "focused Back returns to the main menu with key %d" % code)
	check(confirmations == before and backs == before_backs+1 and host.get_run_state() == host.RunState.MENU and not host._transition_queued, "Back cannot confirm a character or start a scene transition")

func locked_purchase() -> void:
	await open_character()
	check(selector.get_node("%ConfirmButton").has_focus(), "owned role opens with confirmation focused")
	selector._cycle(1)
	var confirm: Button = selector.get_node("%ConfirmButton")
	check(confirm.disabled and not confirm.has_focus(), "switching to a locked role immediately removes the disabled confirmation focus")
	await frames(3)
	var unlock: Button = selector.get_node("%UnlockButton")
	check(unlock.visible and not unlock.disabled and unlock.has_focus(), "affordable locked role focuses Unlock")
	check(confirm.focus_mode == Control.FOCUS_NONE, "disabled confirmation cannot regain a gold focus outline through keyboard traversal")
	if "--capture" in OS.get_cmdline_user_args(): await capture("locked-affordable")
	var before := confirmations
	var before_purchases := purchases
	var coins_before: int = PROFILE.coins
	unlock.grab_focus()
	await key(KEY_ENTER, true)
	check(PROFILE.owns("iron") and PROFILE.coins == coins_before-PROFILE.PRICES.iron and purchases == before_purchases+1, "Enter unlocks Iron and charges exactly once even with key-repeat events")
	check(selector.visible and not nav.level_select.visible and confirmations == before and not selector._confirm_sent, "one Unlock key press cannot also confirm the character")
	check(selector.get_selected_id() == "iron" and not confirm.disabled and confirm.has_focus() and not unlock.visible, "purchase transfers focus from the hidden Unlock button to enabled confirmation")
	check(PROFILE.get_selected_character() == "lan", "unlocking keeps the previously confirmed role until explicit confirmation")

func poor_character() -> void:
	PROFILE.set_coins(0)
	await open_character("astra")
	var confirm: Button = selector.get_node("%ConfirmButton")
	var unlock: Button = selector.get_node("%UnlockButton")
	check(confirm.disabled and unlock.disabled and not confirm.has_focus() and not unlock.has_focus(), "unaffordable role leaves neither disabled action highlighted")
	check(selector.get_node("%BackButton").has_focus(), "unaffordable role falls back to the usable Back action")
	var skipped_disabled := true
	for i in 8:
		await key(KEY_TAB)
		var focus := root.gui_get_focus_owner()
		skipped_disabled = skipped_disabled and focus != confirm and focus != unlock
	check(skipped_disabled, "Tab traverses the page without focusing disabled confirmation or purchase actions")
	if "--capture" in OS.get_cmdline_user_args(): await capture("locked-unaffordable")
	var before := confirmations
	selector.get_node("%BackButton").grab_focus()
	await key(KEY_ENTER)
	check(host._start_screen.visible and confirmations == before and not PROFILE.owns("astra") and PROFILE.coins == 0, "keyboard Back on an unaffordable role never confirms or purchases it")

func browse_and_mouse_purchase() -> void:
	PROFILE.set_coins(500)
	await open_character("astra")
	selector.get_node("%BackButton").grab_focus()
	selector._refresh()
	await frames(3)
	check(selector.get_node("%BackButton").has_focus(), "refresh preserves an existing usable Back focus")
	selector.get_node("%NextButton").pressed.emit()
	await frames(3)
	check(selector.get_selected_id() == "knight" and not selector.get_node("%ConfirmButton").disabled, "existing mouse role cycling still works")
	await key(KEY_LEFT)
	check(selector.get_selected_id() == "astra", "existing left-arrow role cycling still works")
	var before := purchases
	selector.get_node("%UnlockButton").pressed.emit()
	await frames(3)
	check(PROFILE.owns("astra") and PROFILE.coins == 500-PROFILE.PRICES.astra and purchases == before+1, "existing mouse unlock keeps its ownership and pricing rules")
	check(selector.get_node("%ConfirmButton").has_focus() and selector.get_node("%ConfirmButton").focus_mode == Control.FOCUS_ALL, "newly enabled confirmation is reachable and focused after purchase")

func keyboard_confirm_and_cancel() -> void:
	for code in [KEY_ENTER, KEY_KP_ENTER]:
		await open_character("iron")
		var before := confirmations
		await key(code)
		check(nav.level_select.visible and not selector.visible and confirmations == before+1 and host.get_run_state() == host.RunState.MENU, "keyboard confirmation opens levels exactly once with key %d" % code)
		check(PROFILE.get_selected_character() == "iron" and host._start_screen.selected_character_id == "iron", "keyboard confirmation persists the chosen role")
	await open_character("astra")
	await key(KEY_ESCAPE)
	check(host._start_screen.visible and not nav.level_select.visible and PROFILE.get_selected_character() == "iron", "Escape preserves the previous choice and existing back behavior")
	# A same-frame reopen must select its final role, rather than a stale deferred target.
	selector.show_selection("lan")
	selector.hide()
	selector.show_selection("iron")
	await frames(3)
	check(selector.visible and selector.get_selected_id() == "iron" and selector.get_node("%ConfirmButton").has_focus(), "rapid reopen restores a valid default focus for the currently displayed role")

func keypad_unlock() -> void:
	PROFILE.override_path = test_save_path("keyboard-keypad-profile")
	PROFILE.set_coins(200)
	await open_character("lan")
	var before := purchases
	await key(KEY_KP_ENTER)
	check(PROFILE.owns("lan") and PROFILE.coins == 100 and purchases == before+1, "keypad Enter also activates the default Unlock action once")
	check(selector.visible and not nav.level_select.visible and selector.get_node("%ConfirmButton").has_focus(), "keypad unlock stays on the character page with enabled confirmation focused")

func key(code: Key, repeat: bool = false) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.pressed = true
	root.push_input(down)
	if repeat:
		for i in 3:
			var echo := down.duplicate() as InputEventKey
			echo.echo = true
			root.push_input(echo)
	var up := InputEventKey.new()
	up.keycode = code
	up.pressed = false
	root.push_input(up)
	await frames(3)
func capture(label: String) -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	await frames(5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/My File/Game/Team Game/output/character-keyboard-2026-11-13/"+label+".png")
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func test_save_path(label: String) -> String:
	var directory := OS.get_environment("GODOT_TEST_SAVE_DIR")
	if directory.is_empty(): directory = "user://"
	return directory.path_join("%s-%d.cfg" % [label,Time.get_ticks_usec()])
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
