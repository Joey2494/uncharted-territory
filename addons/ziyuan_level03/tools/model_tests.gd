extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	passed+=int(ok)
	failed+=int(not ok)
	print("PASS " if ok else "FAIL ",text)
func run() -> void:
	root.size=Vector2i(1280,720)
	for name in ["BoneAxe","BoneSpike","TombSword","ChainJailer","SandKing"]:
		var packed: PackedScene=load("res://addons/ziyuan_level03/models/"+name+"Model.tscn")
		var model: Node3D=packed.instantiate()
		check(model.find_children("*","MeshInstance3D",true,false).size()>=200,name+" has serialized geometry before ready")
		check(model.has_node("Body/Head/Jaw") and model.has_node("ArmR/Hand") and model.has_node("LegL"),name+" has separate inspectable anatomical parts")
		var valid:=true
		for child in model.find_children("*","MeshInstance3D",true,false):
			if child.mesh==null or child.material_override==null: valid=false
		check(valid,name+" owns mesh and material resources")
		if name=="BoneSpike":
			check(model.find_children("RibLance*","",true,false).is_empty() and model.find_children("Point*","",true,false).is_empty(),"revenant contains no external bone spikes or horns")
			check(not model.find_children("TornFascialMembrane*","",true,false).is_empty(),"revenant has saved ragged skin surfaces")
		if name=="SandKing":
			check(model.find_children("AzureEye*","",true,false).size()==2,"titan has two cyan eyes")
			check(model.find_children("*Tooth*","",true,false).is_empty(),"titan face is wrapped without exposed skeleton teeth")
			check(model.find_children("SculptedLayeredWrapping*","",true,false).size()>=6,"titan has conforming torso and limb wraps")
		model.free()
		var preview: Node3D=load("res://addons/ziyuan_level03/previews/"+name+"Preview.tscn").instantiate()
		root.add_child(preview)
		for i in 3: await process_frame
		var camera: Camera3D=preview.get_node("Camera3D")
		var visible:=true
		var rect:=Rect2(12,100,1256,608)
		for mesh in preview.get_node("Slot/Model").find_children("*","MeshInstance3D",true,false):
			var bounds: AABB=mesh.get_aabb()
			for i in 8:
				var at: Vector3=mesh.global_transform*bounds.get_endpoint(i)
				if camera.is_position_behind(at) or not rect.has_point(camera.unproject_position(at)): visible=false
		check(visible,name+" fits preview outside toolbar")
		var count: int=preview.get_node("Slot/Model").find_children("*","MeshInstance3D",true,false).size()
		preview.get_node("Slot/Model").pose(3,0.5,2,0.02)
		check(preview.get_node("Slot/Model").find_children("*","MeshInstance3D",true,false).size()==count,name+" animation reuses saved meshes")
		preview.free()
		await process_frame
	for alias in ["RevenantModel","BandagedTitanModel"]:
		var named_model=load("res://addons/ziyuan_level03/models/"+alias+".tscn").instantiate()
		check(named_model.has_node("Body/Head"),alias+" standalone scene alias loads")
		named_model.free()
	print("LEVEL03_MODEL_TEST_RESULT passed=%d failed=%d"%[passed,failed])
	quit(1 if failed else 0)
