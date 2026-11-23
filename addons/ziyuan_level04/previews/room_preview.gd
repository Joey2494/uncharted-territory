extends "witch_preview.gd"
@export var enemy_id := "dawn_shade"
func _ready() -> void:
	super._ready()
	distance = 8.2
	_update_camera()
	var labels: Array[Node] = find_children("*", "Label", true, false)
	# UI 位于 CanvasLayer 下，find_children 按类型定位，无需依赖节点名称。
	if labels.size() >= 2:
		labels[0].text = "第四关前四房 · " + preload("../room_catalog.gd").definition(enemy_id).name
		labels[1].text = {"dawn_shade": "朦胧光纱 / 非实体 / 镜像分身", "sun_puppet": "烧熔木纹 / 金红熔光 / 摇晃日斑", "iron_thistle": "铁硬茎秆 / 白芒尖刺 / 扎根阻挡", "raven_roost": "七只乌鸦 / 四散偷袭 / 聚拢冲击"}[enemy_id]
	if labels.size() >= 4: labels[3].text = "F 正面复位 · 当前展示待机动作"
