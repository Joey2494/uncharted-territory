extends Control
## Receives a zero-based room index, and presents the number of rooms reached.

signal restart_requested
signal main_menu_requested
signal revive_requested
signal forfeit_requested

@export_range(1, 99, 1) var total_rooms: int = 3

var _room_index: int = 0
var _revival_count := 0

@onready var restart_button: Button = %RestartButton
@onready var depth_label: Label = %DepthLabel
@onready var room_reached_label: Label = %RoomReachedLabel


func _ready() -> void:
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	%ReviveButton.pressed.connect(func() -> void: revive_requested.emit())
	%ForfeitButton.pressed.connect(func() -> void: forfeit_requested.emit())
	%MainMenuButton.pressed.connect(func() -> void: main_menu_requested.emit())
	visibility_changed.connect(_focus_action)
	_refresh_depth()
	_focus_action()
	set_revival_choice(_revival_count)


func set_revival_choice(count: int) -> void:
	_revival_count = maxi(0, count)
	if not is_node_ready(): return
	%ReviveButton.visible = _revival_count > 0
	%RevivalArt.visible = _revival_count > 0
	%ForfeitButton.visible = _revival_count > 0
	restart_button.visible = _revival_count == 0
	%MainMenuButton.visible = _revival_count == 0
	%TitleLabel.text = "余烬未熄" if _revival_count > 0 else "探索结束"
	$Center/Card/Padding/Content/Eyebrow.text = "尚可原地复活" if _revival_count > 0 else "本次探索结束"
	%DepthLabel.visible = _revival_count == 0
	$Center/Card/Padding/Content/DepthCaption.visible = _revival_count == 0
	%ReviveButton.text = "使用复活卡 · 原地复活（持有 %d）" % _revival_count
	$Center/Card/Padding/Content/Description.text = "满血复活 · 3 秒无敌 · 消耗一张\n保留当前战斗、机关进度与背包。" if _revival_count > 0 else "本次携带的金币和全部道具已清空。\n角色解锁与关卡通关记录保留。"
	_focus_action()


func show_failure_error(message: String) -> void:
	$Center/Card/Padding/Content/Description.text = message + "\n离开前将重试保存失败清空结果。"


func set_room_index(room_index: int) -> void:
	_room_index = room_index
	if is_node_ready():
		_refresh_depth()


func _refresh_depth() -> void:
	if _room_index < 0 or _room_index >= total_rooms:
		depth_label.text = "--"
		room_reached_label.text = "探索到房间 --"
		return
	depth_label.text = "%02d" % [_room_index + 1]
	room_reached_label.text = "探索到房间 %d" % [_room_index + 1]


func _focus_action() -> void:
	if is_node_ready() and is_visible_in_tree():
		_safe_focus.call_deferred(%ReviveButton if _revival_count > 0 else restart_button)


func _safe_focus(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree() and button.is_visible_in_tree():
		button.grab_focus()
