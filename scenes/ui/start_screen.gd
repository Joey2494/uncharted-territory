extends Control
## The host decides which gameplay scene to launch; this view has no scene path.

signal start_requested
signal shop_requested
signal backpack_requested
signal character_purchased

const CHARACTERS = preload("res://scenes/player/character_catalog.gd")
const Profile = preload("res://scripts/integration/player_profile.gd")
var selected_character_id: String = "knight"
var _preview: Node3D
var _unlock_button: Button

@onready var start_button: Button = %StartButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	Profile.ensure_loaded()
	selected_character_id = CHARACTERS.selected_id
	var options: OptionButton = %CharacterChoice
	for id in CHARACTERS.IDS:
		options.add_item(CHARACTERS.definition(id).name + (" · 锁定" if not Profile.owns(id) else ""))
	options.select(CHARACTERS.IDS.find(selected_character_id))
	options.item_selected.connect(func(index: int) -> void: select_character(CHARACTERS.IDS[index]))
	_unlock_button = Button.new()
	_unlock_button.name = "UnlockCharacterButton"
	$Center/Card/Padding/Content.add_child(_unlock_button)
	$Center/Card/Padding/Content.move_child(_unlock_button, $Center/Card/Padding/Content/StartButton.get_index())
	_unlock_button.pressed.connect(_purchase_character)
	select_character(selected_character_id)
	%ShopButton.pressed.connect(func() -> void: shop_requested.emit())
	%BackpackButton.pressed.connect(func() -> void: backpack_requested.emit())
	start_button.pressed.connect(func() -> void: start_requested.emit())
	visibility_changed.connect(_focus_action)
	_focus_action()

func select_character(id: String) -> void:
	if id not in CHARACTERS.IDS:
		return
	selected_character_id = id
	%CharacterChoice.select(CHARACTERS.IDS.find(id))
	var owned := Profile.owns(id)
	start_button.disabled = not owned
	_unlock_button.visible = not owned
	_unlock_button.text = "解锁角色 · %d 金币（持有 %d）" % [Profile.PRICES.get(id, 0), Profile.coins]
	_unlock_button.disabled = Profile.coins < int(Profile.PRICES.get(id, 0))
	%CharacterInfo.text = CHARACTERS.definition(id).description
	if is_instance_valid(_preview):
		_preview.get_parent().remove_child(_preview)
		_preview.queue_free()
	_preview = CHARACTERS.create_model(id)
	%PreviewWorld.add_child(_preview)
	_preview.rotation.y = -0.25
	var animator := AnimationPlayer.new()
	_preview.add_child(animator)
	animator.root_node = NodePath("..")
	animator.add_animation_library("locomotion", preload("res://assets/characters/kaykit/animations/locomotion.tres"))
	animator.play("locomotion/Idle_A")
	show_status("持有金币 %d · 已解锁" % Profile.coins if owned else "角色尚未解锁，可先使用初始旅人探索获得金币")

func _purchase_character() -> void:
	if Profile.unlock_character(selected_character_id):
		character_purchased.emit()
		%CharacterChoice.set_item_text(CHARACTERS.IDS.find(selected_character_id), CHARACTERS.definition(selected_character_id).name)
		select_character(selected_character_id)
	show_status(Profile.message)


func show_status(message: String) -> void:
	status_label.text = message


func _focus_action() -> void:
	if is_node_ready() and is_visible_in_tree():
		_safe_focus.call_deferred(start_button)


func _safe_focus(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree() and button.is_visible_in_tree():
		button.grab_focus()
