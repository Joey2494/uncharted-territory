extends Node
func _ready() -> void:
	start.call_deferred()
func start() -> void:
	var error: Error = await preload("res://scripts/integration/resource_transition.gd").change(get_tree(),"res://Main.tscn")
	if error != OK:
		var label := Label.new()
		label.text = "无法载入游戏，请重新启动。"
		add_child(label)
