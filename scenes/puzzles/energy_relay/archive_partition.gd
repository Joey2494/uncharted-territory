extends StaticBody3D
## 档案室不可通行的低矮设备隔断。始终不透明，边框与碰撞轮廓一致。
## 不加入 camera_occluders：地面采样会命中台面，普通墙的淡化会使它变成隐形墙。
func _ready() -> void:
	var box := $CollisionShape3D.shape as BoxShape3D
	var dimensions := box.size
	var top := dimensions.y*0.5+0.012
	var border := StandardMaterial3D.new()
	border.albedo_color = Color(0.64,0.48,0.25)
	border.metallic = 0.5
	border.roughness = 0.65
	for side: float in [-1.0,1.0]:
		_add_trim(Vector3(side*(dimensions.x*0.5-0.06),top,0),Vector3(0.10,0.024,dimensions.z),border)
		_add_trim(Vector3(0,top,side*(dimensions.z*0.5-0.06)),Vector3(dimensions.x,0.024,0.10),border)
	# 顶部散热肋把平板读作设备外壳，避免误认为可以行走的普通地板。
	for index in 3:
		var z := (float(index)-1.0)*dimensions.z*0.22
		_add_trim(Vector3(0,top,z),Vector3(dimensions.x*0.65,0.024,0.07),border)

func _add_trim(at: Vector3, dimensions: Vector3, material: StandardMaterial3D) -> void:
	var view := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = dimensions
	shape.material = material
	view.mesh = shape
	view.position = at
	add_child(view)
