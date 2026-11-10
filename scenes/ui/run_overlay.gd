extends Control
## 第一关暂停与指引界面。关卡状态及 SceneTree 暂停由 Main 管理。

signal pause_requested
signal guide_requested
signal resume_requested
signal restart_requested

@onready var _corner: HBoxContainer = $Corner
@onready var _modal: Control = $Modal
@onready var _resume: Button = %ResumeButton
@onready var _restart: Button = %RestartButton
@onready var _notice: Label = %Notice


func _ready() -> void:
	$Corner/PauseButton.pressed.connect(func() -> void: pause_requested.emit())
	$Corner/GuideButton.pressed.connect(func() -> void: guide_requested.emit())
	_resume.pressed.connect(func() -> void: resume_requested.emit())
	_restart.pressed.connect(func() -> void: restart_requested.emit())
	$VersionFooter.text = str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	if $VersionFooter.text.is_empty():
		$VersionFooter.text = "开发版"
	get_viewport().size_changed.connect(_layout_corner)
	_layout_corner()


## 显示可用入口，并仅在进入模态面板时将键盘焦点移到继续按钮。
func update_view(playing: bool, paused: bool, guide: bool) -> void:
	_corner.visible = playing
	_modal.visible = paused or guide
	_notice.hide()
	_restart.visible = paused
	%Title.text = "探索指引" if guide else "探索已暂停"
	%Body.text = (
		"WASD / 方向键移动，角色沿移动方向转身。左键近战，Q 发射能量弹，方向键加 Space 闪避。\n\n靠近道具或机关按 E，R 使用药剂，F 使用强化符文。战斗房完整入场后封门，清除守卫即可继续。留意墙边的符文与异样石门。\n\n生命耗尽可从入口重开。击败守门者后踏入出口即可通关，再从结算页前往第二关。新关卡会重新整备生命和道具。"
		if guide else "继续当前探索，或从入口重新开始。"
	)
	if _modal.visible:
		_resume.grab_focus()


## 切换失败时保留暂停界面，供玩家继续或重试。
func show_error(message: String) -> void:
	_notice.text = message
	_notice.show()


func _layout_corner() -> void:
	# 窄窗口的道具面板横跨底部，控制按钮移到该面板上方。
	var bottom := -226.0 if get_viewport_rect().size.x < 960.0 else -44.0
	_corner.offset_top = bottom - 44.0
	_corner.offset_bottom = bottom
