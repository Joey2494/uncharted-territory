extends Node3D

signal feedback(message: String)
signal door_opening_started
signal solved
signal reward_claimed

enum State { READY, RESETTING, OPENING, OPEN, CLAIMED }

const CORRECT_SEQUENCE: Array[int] = [1, 2, 0]
const SYMBOLS: Array[String] = ["日", "月", "星"]
@export var opening_gold: int = 40
@export var reward_items: Dictionary = {0: 2, 1: 2, 2: 1, 3: 1}

@onready var _runes: Array[StaticBody3D] = [$SunRune, $MoonRune, $StarRune]
@onready var _hidden_passage: Node3D = $"../Regions/SecretPassage"
@onready var _hidden_room: Node3D = $"../Regions/HiddenRewardRoom"

var state: State = State.READY
var progress: int = 0
var _input_remaining: float = 0.0
var _reset_remaining: float = 0.0


func _ready() -> void:
	$ClueLabel.text = "碑文：月升 → 星现 → 日出"
	_refresh_runes()
	_hidden_passage.hide()
	_hidden_room.hide()
	$RewardChest.hide()


func _process(delta: float) -> void:
	_input_remaining = maxf(0.0, _input_remaining - delta)
	if state == State.RESETTING:
		_reset_remaining = maxf(0.0, _reset_remaining - delta)
		if _reset_remaining <= 0.0:
			state = State.READY
			_refresh_runes()
			feedback.emit("符文已复位 · 可重新尝试")


func is_solved() -> bool:
	return state == State.OPEN or state == State.CLAIMED


func is_reward_claimed() -> bool:
	return state == State.CLAIMED


func is_interaction_available(kind: int) -> bool:
	return state == State.OPEN if kind == 3 else state == State.READY


func get_interaction_prompt(kind: int) -> String:
	if kind == 3:
		return "[E] 开启密室奖励宝箱"
	return "[E] 激活%s符文 · %d/3" % [SYMBOLS[kind], progress]


func activate_rune(kind: int, player: CharacterBody3D) -> bool:
	if kind < 0 or kind >= _runes.size() or not can_process() or state != State.READY or _input_remaining > 0.0:
		return false
	if not _runes[kind].can_interact(player):
		return false
	_input_remaining = 0.22
	if kind != CORRECT_SEQUENCE[progress]:
		progress = 0
		state = State.RESETTING
		_reset_remaining = 0.7
		_refresh_runes()
		feedback.emit("顺序错误 · 符文正在复位，可重试")
		return true
	progress += 1
	_refresh_runes()
	if progress == CORRECT_SEQUENCE.size():
		_open_hidden_room()
	else:
		feedback.emit("%s符文已点亮 · %d/3" % [SYMBOLS[kind], progress])
	return true


func claim_reward(player: CharacterBody3D) -> bool:
	if state != State.OPEN or not can_process() or not $RewardChest.can_interact(player):
		return false
	var inventory := player.get_node_or_null("ItemInventory")
	if inventory == null:
		return false
	# Reserve before inventory signals fire so repeated E requests cannot dupe it.
	state = State.CLAIMED
	if not inventory.grant_reward("chest:" + str(get_path()), reward_items):
		state = State.OPEN
		feedback.emit("背包空间不足，奖励保留在宝箱内")
		return false
	$RewardChest/ChestLabel.text = "奖励已领取"
	var tween := create_tween()
	tween.tween_property($RewardChest/LidPivot, "rotation:x", -1.2, 0.35)
	$StatusLabel.text = "共鸣完成 · 奖励已领取"
	var names := PackedStringArray()
	for item_id in reward_items:
		names.append("%s ×%d" % [preload("res://data/item_catalog.gd").get_item(item_id).name, reward_items[item_id]])
	feedback.emit("密室奖励：" + "，".join(names))
	reward_claimed.emit()
	return true


func _open_hidden_room() -> void:
	door_opening_started.emit()
	state = State.OPENING
	$StatusLabel.text = "符文共鸣 · 暗门开启中"
	_hidden_passage.show()
	_hidden_room.show()
	$RewardChest.show()
	feedback.emit("顺序正确 · 暗门正在开启")
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($HiddenDoor/MeshInstance3D, "position:y", -3.6, 0.9)
	tween.finished.connect(_finish_opening)


func _finish_opening() -> void:
	if state != State.OPENING:
		return
	$HiddenDoor/CollisionShape3D.set_deferred("disabled", true)
	$HiddenDoor.hide()
	state = State.OPEN
	$StatusLabel.text = "隐藏奖励房间已开启"
	feedback.emit("符文共鸣！隐藏奖励房间已开启")
	preload("res://scenes/items/coin_pickup.gd").spawn(
		get_parent(), _hidden_room.global_position + Vector3(1.5, 0.05, 1.5),
		opening_gold, "secret:" + str(get_path()))
	solved.emit()


func _refresh_runes() -> void:
	for i in range(_runes.size()):
		var lit := CORRECT_SEQUENCE.slice(0, progress).has(i)
		_runes[i].set_rune_state(lit, state == State.RESETTING)
	$StatusLabel.text = "顺序错误 · 正在复位" if state == State.RESETTING else "符文共鸣 %d/3" % progress
