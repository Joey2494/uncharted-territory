extends RefCounted
const M = preload("res://scenes/weapons/weapon_models.gd")
static func create(coil: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "CoilAmmo" if coil else "PistolAmmo"
	var brass := M.material("bd904e",0.8)
	var lead := M.material("8c8077",0.75)
	var graphite := M.material("283f52",0.7)
	var core := M.material("63dff4",0.2,true)
	M.box(root,"Carrier",Vector3(0.72,0.12,0.34),Vector3(0,0.06,0),graphite if coil else M.material("4c3426"))
	for i in 3:
		var at := Vector3((i-1)*0.22,0.28+(0.04 if i==1 else 0.0),0)
		if coil:
			M.cylinder(root,"MagneticCore",0.077,0.35,at,core)
			for y in [-0.17,0.17]:
				var cap := M.cylinder(root,"HexagonalCap",0.096,0.07,at+Vector3.UP*y,graphite)
				cap.mesh.radial_segments = 6
				M.ring(root,"CopperInductor",0.10,at+Vector3.UP*y,brass)
			for side in [-1,1]: M.box(root,"RetainingRail",Vector3(0.018,0.33,0.035),at+Vector3(side*0.08,0,0),graphite)
		else:
			M.cylinder(root,"BrassCasing",0.075,0.28,at,brass)
			M.cylinder(root,"RoundedBullet",0.072,0.14,at+Vector3.UP*0.21,lead,0.025)
			M.ring(root,"ExtractionRim",0.084,at-Vector3.UP*0.12,brass)
			M.cylinder(root,"Primer",0.025,0.012,at-Vector3.UP*0.148,lead)
	return root
