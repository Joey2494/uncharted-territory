extends Label3D
## Pure display: bind explicit initial HP plus the source's hp_changed signal.

@export var hide_when_empty: bool = true
@export var healthy_color: Color = Color("ddd1b6")
@export var low_hp_color: Color = Color("c8846f")

var _source: WeakRef


func update_hp(current: int, maximum: int) -> void:
	if maximum <= 0:
		text = "HP --/--"
		modulate = Color("9a968b")
		show()
		return
	var hp: int = clampi(current, 0, maximum)
	text = "HP %d/%d" % [hp, maximum]
	modulate = low_hp_color if float(hp) / float(maximum) <= 0.4 else healthy_color
	visible = not (hide_when_empty and hp == 0)


func bind_health_source(source: Node, initial_hp: int, maximum: int) -> bool:
	unbind_health_source()
	update_hp(initial_hp, maximum)
	if not is_instance_valid(source) or not source.has_signal("hp_changed"):
		return false
	_source = weakref(source)
	source.connect("hp_changed", update_hp)
	source.tree_exiting.connect(_on_source_exiting, CONNECT_ONE_SHOT)
	return true


func unbind_health_source() -> void:
	var source = _source.get_ref() if _source != null else null
	if is_instance_valid(source):
		if source.is_connected("hp_changed", update_hp):
			source.disconnect("hp_changed", update_hp)
		if source.tree_exiting.is_connected(_on_source_exiting):
			source.tree_exiting.disconnect(_on_source_exiting)
	_source = null


func _on_source_exiting() -> void:
	unbind_health_source()
	hide()


func _exit_tree() -> void:
	unbind_health_source()
