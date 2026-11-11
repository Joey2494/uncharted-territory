extends Node3D
## Isolated combat sandbox, not the team's final level-two map or unlock flow.

@onready var _player: CharacterBody3D = $World/Player
@onready var _boss: CharacterBody3D = $World/RuinColossus
var _hud: Control
var _restart: Button
var _commerce: CanvasLayer
var _elapsed_seconds := 0.0


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = preload("res://scenes/ui/hud.tscn").instantiate()
	layer.add_child(_hud)
	_hud.total_rooms = 1
	_hud.update_hp_bar(_player.hp, _player.max_hp)
	_hud.update_weapon_status(true)
	_hud.update_room_label(0)
	_hud.bind_combat_actions(_player)
	_player.hp_changed.connect(_hud.update_hp_bar)
	_player.death_animation_finished.connect(func() -> void:
		$World.process_mode = Node.PROCESS_MODE_DISABLED
		_hud.show_death_screen(0))
	_hud.restart_requested.connect(func() -> void: get_tree().reload_current_scene())
	var inventory := _player.get_node("ItemInventory")
	inventory.inventory_changed.connect(_hud.update_inventory)
	inventory.buff_changed.connect(_hud.update_attack_buff)
	inventory.feedback.connect(_hud.show_item_message)
	inventory.pickup_prompt_changed.connect(_hud.update_pickup_prompt)
	_hud.use_potion_requested.connect(inventory.try_use_potion)
	_hud.use_rune_requested.connect(inventory.try_use_rune)
	inventory.state_changed.connect(func(_snapshot: Dictionary) -> void:
		_hud.update_gold(inventory.gold)
		_hud.update_ammo(inventory.ammo))
	_player.energy_changed.connect(_hud.update_energy_bar)
	_hud.update_energy_bar(_player.energy, _player.max_energy)
	# Explicit sandbox loadout, never granted in the first-level main scene.
	inventory.grant_reward("prototype_loadout", {0: 3, 1: 2, 2: 2, 3: 1, 4: 12}, 80)
	_commerce = preload("res://scenes/ui/CommerceLayer.tscn").instantiate()
	add_child(_commerce)
	_commerce.bind_inventory(inventory,
		func() -> bool: return not _player.is_dead() and $World.process_mode != Node.PROCESS_MODE_DISABLED,
		func() -> float: return _elapsed_seconds)
	_commerce.set_run_active(true)
	_commerce.restart_requested.connect(func() -> void: get_tree().reload_current_scene())
	_commerce.main_menu_requested.connect(func() -> void: get_tree().change_scene_to_file("res://Main.tscn"))
	_player.died.connect(_commerce.finish_run)
	var boss_bar := preload("res://scenes/ui/BossHealthBar.tscn").instantiate()
	layer.add_child(boss_bar)
	boss_bar.begin_encounter(_boss.boss_name, _boss.hp, _boss.max_hp)
	boss_bar.update_state("尚未交战")
	_boss.get_node("Visuals").rotation.y = PI
	var layout := preload("res://scenes/ui/responsive_layout.gd").new()
	layout.camera_path = NodePath("../../World/Camera3D")
	layout.compact_combat_layout = true
	layer.add_child(layout)
	_boss.battle_started.connect(func() -> void: boss_bar.begin_encounter(_boss.boss_name, _boss.hp, _boss.max_hp))
	_boss.hp_changed.connect(boss_bar.update_hp)
	_boss.state_changed.connect(boss_bar.update_state)
	_boss.died.connect(func() -> void:
		boss_bar.show_defeated()
		_hud.show_item_message("灾厄巨蝎已击败"))
	_restart = Button.new()
	_restart.text = "重新挑战"
	_restart.size = Vector2(120, 38)
	_restart.pressed.connect(func() -> void: get_tree().reload_current_scene())
	layer.add_child(_restart)
	get_viewport().size_changed.connect(_place_restart)
	_place_restart()


func _process(delta: float) -> void:
	if not _player.is_dead():
		_elapsed_seconds += delta


func _place_restart() -> void:
	var width := get_viewport().get_visible_rect().size.x
	var height := get_viewport().get_visible_rect().size.y
	_restart.position = Vector2(width - 144, height - 126) if width < 960 else Vector2(24, 246)
