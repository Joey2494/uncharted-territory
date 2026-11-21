extends CanvasLayer
## 独立试玩使用本局背包，返回时恢复正式选关菜单。
const NAV := preload("res://scripts/integration/menu_navigation.gd")

@onready var level := get_parent()
@onready var overlay := $Overlay
@onready var message := $Readout/Rows/Message
@onready var goal := $Readout/Rows/Goal
var remaining := 0.0
var switching := false

func _ready() -> void:
	level.feedback.connect(_notice)
	level.completed.connect(_finish)
	level.get_node("Player/ItemInventory").pickup_prompt_changed.connect(func(s: String):
		$Readout/Rows/Prompt.text = s
		$Readout/Rows/Prompt.visible = s != "")
	$Overlay/Card/Resume.pressed.connect(_resume)
	$Overlay/Card/Restart.pressed.connect(_restart)
	$Overlay/Card/Return.pressed.connect(_return_to_levels)
	_refresh_goal()

func _refresh_goal() -> void:
	if not level.powered:
		goal.text = "在前厅升起遮光闸"
	elif level.reward_claimed():
		goal.text = "已取得星图符文 · 沿金色中线向北离站"
	elif level.vault_open():
		goal.text = "北行离站   /   支线：开启的星图柜可领取符文"
	elif level.inscription_lit:
		goal.text = "北行离站   /   支线：循南壁的星纹引光"
	else:
		goal.text = "北行离站   /   支线：向东寻找无字星盘"

func _notice(s: String) -> void:
	_refresh_goal()
	message.text = s
	message.show()
	remaining = 4.5

func _process(delta: float) -> void:
	if overlay.visible: return
	if remaining > 0:
		remaining -= delta
		if remaining <= 0:
			message.hide()
			_refresh_goal()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or event.is_echo() or level.finished: return
	get_viewport().set_input_as_handled()
	if overlay.visible:
		_resume()
	else:
		_show_overlay("观测暂停", "沿金色中线向北离站；青色菱纹通往可选镜室。", true)

func _finish() -> void:
	var result := "带回了星图符文。" if level.reward_claimed() else "经主线抵达北出口。"
	_show_overlay("已抵达天窗出口", result, false)

func _show_overlay(title: String, body: String, can_resume: bool) -> void:
	$Overlay/Card/Title.text = title
	$Overlay/Card/Body.text = body
	$Overlay/Card/Resume.visible = can_resume
	overlay.show()
	get_tree().paused = true
	if can_resume: $Overlay/Card/Resume.grab_focus()
	else: $Overlay/Card/Return.grab_focus()

func _resume() -> void:
	if level.finished or switching: return
	overlay.hide()
	get_tree().paused = false

func _restart() -> void:
	if switching: return
	switching = true
	var tree := get_tree()
	tree.paused = false
	var err := tree.reload_current_scene()
	if err != OK:
		switching = false
		tree.paused = true
		$Overlay/Card/Body.text = "重开失败：" + error_string(err)

func _return_to_levels() -> void:
	if switching: return
	switching = true
	var tree := get_tree()
	var previous := NAV.pending_level_select
	NAV.pending_level_select = true
	tree.paused = false
	var err := tree.change_scene_to_file("res://Main.tscn")
	if err != OK:
		NAV.pending_level_select = previous
		switching = false
		tree.paused = true
		$Overlay/Card/Body.text = "返回选关失败：" + error_string(err)
