extends Node3D
## 所有地块、边墙与门洞共用坐标。低矮墙保留视线，两条路线用不同形状的地面标线区分。
const FONT = preload("res://scenes/ui/dungeon_font.tres")
const WALL := Color("#526373")
const MAIN := Color("#c49358")
const SIDE := Color("#5ebeb6")

func build() -> void:
	_floor(Rect2(-5, -17, 10, 32), Color("#6e6862"))
	_floor(Rect2(5, -2.5, 4, 5), Color("#475d61"))
	_floor(Rect2(9, -7, 16, 14), Color("#53676a"))
	_floor(Rect2(17.5, -11, 5, 4), Color("#786a51"))
	# 主厅四周与主闸两侧的防绕行墙。
	_wall(-5, -17, -5, 15)
	_wall(-5, 15, 5, 15)
	_wall(-5, -17, 5, -17)
	_wall(5, -17, 5, -2.5)
	_wall(5, 2.5, 5, 15)
	_wall(-5, -8, -2.5, -8)
	_wall(2.5, -8, 5, -8)
	# 支线入口始终开放，奖励隔间只有北壁闸门一处入口。
	_wall(5, -2.5, 9, -2.5)
	_wall(5, 2.5, 9, 2.5)
	_wall(9, -7, 9, -2.5)
	_wall(9, 2.5, 9, 7)
	_wall(9, 7, 25, 7)
	_wall(25, -7, 25, 7)
	_wall(9, -7, 17.5, -7)
	_wall(22.5, -7, 25, -7)
	_wall(17.5, -11, 17.5, -7)
	_wall(22.5, -11, 22.5, -7)
	_wall(17.5, -11, 22.5, -11)
	for z in range(-14, 13, 3):
		block(self, Vector3(0, 0.012, z), Vector3(0.19, 0.02, 1.6), MAIN)
	for x in range(2, 13, 2):
		var marker := block(self, Vector3(x, 0.019, 0), Vector3(0.40, 0.024, 0.40), SIDE)
		marker.rotation.y = PI / 4
	block(self, Vector3(0, 0.028, -14.8), Vector3(8.8, 0.035, 2.8), MAIN)
	caption(self, "北 · 离站", Vector3(0, 1.1, -15.4))
	caption(self, "观测前厅", Vector3(-3.15, 1.05, 11.8))
	caption(self, "星图镜室  →", Vector3(6.3, 1.05, -1.75))


func _floor(rect: Rect2, color: Color) -> void:
	var center := rect.get_center()
	solid(self, Vector3(center.x, -0.20, center.y), Vector3(rect.size.x, 0.4, rect.size.y), color)

func _wall(x1: float, z1: float, x2: float, z2: float) -> void:
	solid(self, Vector3((x1+x2)*0.5, 0.56, (z1+z2)*0.5),
		Vector3(maxf(0.25, absf(x2-x1)), 1.12, maxf(0.25, absf(z2-z1))), WALL)

func material(color: Color, glowing := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	if glowing:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.7
	return mat

func block(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glowing := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material(color, glowing)
	parent.add_child(view)
	view.position = pos
	return view

func solid(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_mask = 0
	parent.add_child(body)
	body.position = pos
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	block(body, Vector3.ZERO, size, color)
	return body

func caption(parent: Node3D, content: String, pos: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = content
	label.font = FONT
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.pixel_size = 0.008
	label.modulate = Color("#fff1c4")
	label.outline_size = 6
	parent.add_child(label)
	label.position = pos
	return label

func beam(parent: Node3D, p: Vector2, q: Vector2, color: Color) -> void:
	var mid := (p + q) * 0.5
	var delta := (p - q).abs()
	var view := block(parent, Vector3(mid.x, 1.15, mid.y),
		Vector3(maxf(0.09, delta.x), 0.08, maxf(0.09, delta.y)), color, true)
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
