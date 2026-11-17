@tool
extends Node3D
## Saved geometry is editor-visible. This script only articulates existing nodes.
@export_enum("bone_axe","bone_spike","tomb_sword","chain_jailer","sand_king") var kind := "bone_axe"
@export var preview_motion := false
var _time := 0.0
var _rest: Dictionary={}
func _ready() -> void:
	for path in ["Body","Body/Head","ArmR","ArmL","LegR","LegL"]:
		var node:=get_node_or_null(path) as Node3D
		if node: _rest[path]=node.transform
func _process(delta: float) -> void:
	if preview_motion: pose(0,0,0.5,delta)
func pose(state: int, progress: float, moving: float, delta: float, strike := 0) -> void:
	if _rest.is_empty(): return
	_time+=delta
	for path in _rest: get_node(path).transform=_rest[path]
	var r:=get_node("ArmR") as Node3D
	var l:=get_node("ArmL") as Node3D
	var head:=get_node("Body/Head") as Node3D
	head.rotation.y+=sin(_time*1.2)*0.025
	for i in 2:
		var leg:=get_node("LegR" if i==0 else "LegL") as Node3D
		leg.rotation.x+=sin(_time*7+i*PI)*minf(moving*0.1,0.26)
	if state==2:
		r.rotation.x-=progress*0.65
		l.rotation.x-=progress*0.3
	elif state==3:
		r.rotation.x+=-0.65+sin(progress*PI)*1.55
		l.rotation.x+=-0.4+sin(progress*PI)*1.0
		if kind=="tomb_sword": r.position.z-=sin(progress*PI)*0.8
	if kind=="chain_jailer":
		for side in [-1,1]:
			var chain:=get_node_or_null("ChainR" if side>0 else "ChainL") as Node3D
			if chain==null: continue
			var limb:=get_node("ArmR" if side>0 else "ArmL") as Node3D
			chain.position=limb.transform*Vector3(side*0.07,-0.7,-0.2)
			if state==3:
				var angle: float=lerpf(-2.18,2.18,progress)*(1 if strike==0 else -1)+side*0.05
				chain.rotation.y=angle
				chain.rotation.x=-0.55*sin(progress*PI)
			else: chain.rotation=Vector3.ZERO
