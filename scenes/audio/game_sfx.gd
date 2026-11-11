extends Node
## Presentation adapter: consumes successful world events without changing rules.
## Players inherit the run's pause and lifetime, and use the existing master volume.

signal cue_played(cue: StringName)

const PICKUP := &"pickup"
const DOOR := &"door"
const HIT := &"hit"
const HURT := &"hurt"
const ITEM_USE := &"item_use"
const SPELL := &"spell"
const CUES := {
	PICKUP: preload("res://assets/audio/sfx/freesound_community-item-pick-up-38258.mp3"),
	DOOR: preload("res://assets/audio/sfx/stone_door_open_3-4s.wav"),
	HIT: preload("res://assets/audio/sfx/universfield-combat-impact-352458.mp3"),
	HURT: preload("res://assets/audio/sfx/stepir44-hurt-sound-435314.mp3"),
	ITEM_USE: preload("res://assets/audio/sfx/item_use_0-2s.wav"),
	SPELL: preload("res://assets/audio/sfx/mixkit-short-laser-gun-shot-1670.wav"),
}
const LEVELS_DB := {
	PICKUP: -8.0, DOOR: -6.0, HIT: -10.0,
	HURT: -12.0, ITEM_USE: -9.0, SPELL: -10.0,
}

var _players: Dictionary[StringName, AudioStreamPlayer] = {}
var _impact_played: bool = false
var _last_cue_frame: Dictionary = {}


func _ready() -> void:
	for cue: StringName in CUES:
		var player := AudioStreamPlayer.new()
		player.name = String(cue).to_pascal_case()
		player.stream = CUES[cue]
		player.volume_db = LEVELS_DB[cue]
		player.max_polyphony = 2
		add_child(player)
		_players[cue] = player
	var dungeon := get_node("../DungeonTest")
	var actor := dungeon.get_node("Player")
	var items := actor.get_node("ItemInventory")
	var melee := actor.get_node("MeleeAttack")
	items.pickup_succeeded.connect(func(_target: Node) -> void: play_cue(PICKUP))
	items.item_used.connect(func(_type: int) -> void: play_cue(ITEM_USE))
	actor.damage_received.connect(func(_amount: int) -> void: play_cue(HURT))
	actor.get_node("EnergyShock").released.connect(func(_projectile: Node3D) -> void: play_cue(SPELL))
	melee.attack_started.connect(func() -> void: _impact_played = false)
	melee.hit_confirmed.connect(_on_melee_hit)
	dungeon.exit_opening_started.connect(func() -> void: play_cue(DOOR))
	var puzzle := dungeon.get_node_or_null("RunePuzzle")
	if puzzle != null:
		puzzle.door_opening_started.connect(func() -> void: play_cue(DOOR))
	if puzzle != null:
		puzzle.reward_claimed.connect(func() -> void: play_cue(PICKUP))
	actor.get_node("Firearm").fired.connect(func(_projectile: Node3D) -> void: play_cue(SPELL))


func play_cue(cue: StringName) -> void:
	if not can_process() or not _players.has(cue):
		return
	var frame := Engine.get_process_frames()
	if _last_cue_frame.get(cue, -1) == frame: return
	_last_cue_frame[cue] = frame
	_players[cue].play()
	cue_played.emit(cue)


func _on_melee_hit(_target: Node, _amount: int) -> void:
	# Several colliders/targets in one swing should produce one impact cue.
	if not _impact_played:
		_impact_played = true
		play_cue(HIT)
