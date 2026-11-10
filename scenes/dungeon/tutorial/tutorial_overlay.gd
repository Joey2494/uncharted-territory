extends Control
## 当前目标与主动跳过入口。地图控制器仍负责门体与房间进度。

@onready var _progress: Label = $Card/Stack/Top/Progress
@onready var _prompt: Label = $Card/Stack/Prompt
@onready var _skip: Button = $Card/Stack/Top/Skip

var _tutorial: Node


func bind(tutorial: Node) -> void:
	if not is_instance_valid(tutorial):
		return
	_tutorial = tutorial
	tutorial.step_changed.connect(_on_step_changed)
	tutorial.stopped.connect(hide)
	_skip.pressed.connect(_request_skip)


func _on_step_changed(prompt: String, step: int, total: int) -> void:
	_progress.text = "入口教学   %02d / %02d" % [step + 1, total]
	_prompt.text = prompt
	show()


func _request_skip() -> void:
	if is_instance_valid(_tutorial):
		_tutorial.request_skip()
