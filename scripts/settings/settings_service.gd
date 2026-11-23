extends Node
## Loaded before music and LoadingEntry, and retained through every scene handoff.
const Model = preload("res://scripts/settings/game_settings.gd")
var data := Model.new()
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data.load_settings()
	data.apply(get_tree().root)
	get_tree().node_added.connect(_node_added)
func _node_added(node: Node) -> void:
	if node is Viewport: _apply_viewport.call_deferred(weakref(node))
func _apply_viewport(reference: WeakRef) -> void:
	var viewport := reference.get_ref() as Viewport
	if viewport != null and viewport.is_inside_tree(): data.apply_quality(viewport)
