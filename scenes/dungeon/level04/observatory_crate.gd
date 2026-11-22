extends StaticBody3D
## 装卸场木箱。层 1 挡路挡弹，层 3 让剑的扇区和技能找到同一实体。
var hits_left := 3
var layout: Node3D

func build(builder: Node3D) -> void:
	layout = builder
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group("breakable_cover")
	var size := Vector3(1.8, 1.65, 1.5)
	var box := BoxShape3D.new()
	box.size = size
	var hitbox := CollisionShape3D.new()
	hitbox.shape = box
	hitbox.position.y = size.y * 0.5
	add_child(hitbox)
	for i in 5:
		layout.block(self, Vector3((i-2)*0.36,0.825,0), Vector3(0.345,1.65,1.47), Color("99714f") if i%2 == 0 else Color("825a3d"))
	for side in [-1,1]:
		for height in [0.17,1.46]:
			layout.block(self, Vector3(0,height,side*0.75), Vector3(1.86,0.16,0.08), Color("c69c69"))
		var brace: MeshInstance3D = layout.block(self, Vector3(0,0.81,side*0.76), Vector3(1.83,0.12,0.06), Color("c49a69"))
		brace.rotation.z = -0.62
	var crack: Node3D = layout.block(self,Vector3(-0.39,1.29,0.80),Vector3(0.07,0.47,0.033),Color("493325"))
	crack.rotation.z = 0.35

func take_damage(amount: int) -> bool:
	if hits_left <= 0 or amount <= 0 or not can_process(): return false
	hits_left -= 1
	if hits_left > 0:
		var split := layout.block(self, Vector3(0.24*hits_left,0.86,0.805), Vector3(0.075,0.52+0.15*hits_left,0.025), Color("392b23")) as MeshInstance3D
		split.rotation.z = -0.26*hits_left
		return true
	# 同步撤走模型和物理层；木屑只有网格，不能形成隐形障碍。
	collision_layer = 0
	hide()
	var debris := Node3D.new()
	get_parent().add_child(debris)
	debris.global_position = global_position
	for i in 5:
		var chip: Node3D = layout.block(debris, Vector3(0,0.7,0), Vector3(0.22,0.1,0.42), Color("aa8156"))
		var spread := Vector3(sin(i*2.4),0,cos(i*2.4))
		chip.rotation.y = i
		var fall := chip.create_tween()
		fall.tween_property(chip,"position",spread*1.25+Vector3.UP*0.08,0.32)
	var cleanup := debris.create_tween()
	cleanup.tween_interval(0.55)
	cleanup.tween_callback(debris.queue_free)
	queue_free()
	return true
