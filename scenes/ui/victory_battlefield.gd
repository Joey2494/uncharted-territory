extends Node3D
## Migrated presentation adapter. No combat, economy or campaign mutations.
@onready var _host: Node3D = get_parent()
@onready var _world: Node3D = _host.get_node("DungeonTest")
@onready var _player: Node3D = _world.get_node("Player")
var _battle_position := Vector3.ZERO
var _presented := false

func _ready() -> void:
	_host._boss.died.connect(_keep_boss_remains)

func _keep_boss_remains() -> void:
	var boss: Node3D = _host._boss
	_battle_position = boss.global_position
	var source: Node3D = boss.get_node("Visuals")
	var remains: Node3D = source.duplicate(0)
	remains.name = "BossRemains"
	_world.add_child(remains)
	remains.global_transform = source.global_transform
	for mesh in remains.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = null
	var animator: AnimationPlayer = remains.find_child("AnimationPlayer", true, false)
	if animator != null and animator.has_animation(&"death/Death_A"):
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		animator.play(&"death/Death_A")
		animator.seek(animator.get_animation(&"death/Death_A").length, true)
		animator.pause()
	else:
		# The integrated second Boss has procedural art rather than Death_A.
		remains.rotation.z += PI * 0.5
		remains.global_position.y += 0.35
	remains.process_mode = Node.PROCESS_MODE_DISABLED

func present() -> void:
	if _presented or _host.get_run_state() != _host.RunState.VICTORY:
		return
	_presented = true
	var layout: Node = _host.get_node("UILayer/ResponsiveLayout")
	layout.process_mode = Node.PROCESS_MODE_DISABLED
	# Disabled processing still permits already queued layout callbacks. Detach
	# terminal presentation from resize signals, then hide after that last call.
	for connection in layout.get_incoming_connections():
		var incoming: Signal = connection.signal
		if incoming.is_connected(connection.callable):
			incoming.disconnect(connection.callable)
	_host._hud.process_mode = Node.PROCESS_MODE_DISABLED
	_host.get_node("RunBindings").process_mode = Node.PROCESS_MODE_DISABLED
	_hide_gameplay_hud()
	_hide_gameplay_hud.call_deferred()
	for label in _world.find_children("*", "Label3D", true, false):
		label.hide()
	var camera := Camera3D.new()
	camera.name = "VictoryCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.3
	camera.h_offset = 0.4
	_world.add_child(camera)
	camera.global_position = _battle_position + Vector3(4, 8, 13)
	camera.look_at(_battle_position + Vector3(-0.5, 1, 0))
	camera.current = true
	create_tween().tween_property(camera, "size", 11.3, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var ceremony := preload("res://scenes/ui/victory_ceremony.gd").new()
	ceremony.name = "VictoryCeremony"
	ceremony.hero_source = _player.get_node("Visuals")
	add_child(ceremony)
	ceremony.global_position = _battle_position

func _hide_gameplay_hud() -> void:
	for child in _host._hud.get_children():
		if child is Control:
			child.hide()
