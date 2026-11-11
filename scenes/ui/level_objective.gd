extends PanelContainer
## Reads map objectives; never changes progression or combat clocks.
var world: Node3D
var _last_text := ""

func _process(_delta: float) -> void:
	if not is_instance_valid(world) or not world.is_node_ready(): return
	var region: Node3D = world.get_region_at(world.player.global_position)
	var room_name: String = region.display_name if region != null else "连接通道"
	var objective: String = world.get_objective()
	var detail := "已探索 %d/%d · 导能%s · 回环%s" % [world.get_visited_count(), world.get_room_count(), "已接通" if world.relay_activated else "未启动", "已开启" if world.shortcut_unlocked else "未开启"]
	var signature := room_name + objective + detail
	if signature == _last_text: return
	_last_text = signature
	%ObjectiveRoom.text = "第二关 · " + room_name
	%ObjectiveTask.text = objective
	%ObjectiveDetail.text = detail
