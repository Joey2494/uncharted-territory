extends Area3D
## 只负责检测和发信号，不能在这里直接 heal / equip（防止整合时重复生效）。
signal item_picked(item_type: String)

@export_enum("heal", "weapon") var item_type: String = "heal"
var player_ref: CharacterBody3D
var _picked: bool = false
var _time: float = 0.0
@onready var visual: Node3D = $Visual

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta
	visual.position.y = sin(_time * 2.5) * 0.09
	visual.rotation.y += delta * 0.8

func _on_body_entered(body: Node3D) -> void:
	if _picked or not (body == player_ref or body.is_in_group("player")):
		return
	_picked = true # 同一物理帧多次进入也只结算一次。
	item_picked.emit(item_type)
	queue_free()

