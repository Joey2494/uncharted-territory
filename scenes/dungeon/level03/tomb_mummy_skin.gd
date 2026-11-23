extends Node3D
## Existing teammate model, presentation only. Shared AI/attack/death timing is retained.
const MODEL = preload("res://addons/ziyuan_level03/models/BoneAxeModel.tscn")
const Art = preload("res://scenes/dungeon/level03/tomb_geometry.gd")
var _actor: CharacterBody3D
var _model: Node3D
var _clock := 0.0
var _fall := 0.0
var _attack_duration := 0.36
var _native_pose := false
func _ready() -> void:
	_actor = get_parent()
	_native_pose = _actor.has_method("is_boss")
	if _native_pose:
		# Keep the native model, weapons, articulated pose and death tween.
		_model = _actor.get_node("Visuals/Model")
	else:
		_actor.get_node("Visuals/Model").hide()
		_model = MODEL.instantiate()
		_model.name = "BandagedTombGuardian"
		_actor.get_node("Visuals").add_child(_model)
		_model.scale = Vector3.ONE*0.82
		_model.rotation.y = PI
		var attack: Node3D = _actor.get_node("MeleeAttack")
		_attack_duration = attack.windup_duration+attack.active_duration+attack.recovery_duration
		attack.attack_started.connect(func(): _clock = 0.0)
	var art := Art.new()
	art.begin("AncientTombLinen")
	var boss: bool = _native_pose and _actor.is_boss()
	_wrap(art,"Body",1.08,1.82,Vector2(0.47,0.32) if boss else Vector2(0.36,0.25),14)
	_wrap(art,"Body/Head",0.20,0.34,Vector2(0.24,0.22),3)
	_wrap(art,"Body/Head",-0.16,-0.025,Vector2(0.21,0.19),3)
	for limb in ["ArmL","ArmR"]: _wrap(art,limb,-0.72,-0.07,Vector2(0.16,0.16) if boss else Vector2(0.10,0.11),10)
	for limb in ["LegL","LegR"]: _wrap(art,limb,-0.91,-0.09,Vector2(0.16,0.15) if boss else Vector2(0.12,0.11),12)

func _wrap(art: RefCounted, path: String, low: float, high: float, radius: Vector2, bands: int) -> void:
	var surface := Art.Surface.new()
	var part: Node3D = _model.get_node(path)
	for band in bands:
		var bottom := lerpf(low,high,float(band)/bands)
		var top := lerpf(low,high,(float(band)+0.89)/bands)
		for segment in 16:
			var points: Array[Vector3] = []
			for pair in [Vector2i(segment,0),Vector2i(segment+1,0),Vector2i(segment,1),Vector2i(segment+1,1)]:
				var angle: float = TAU*pair.x/16.0
				var y: float = bottom if pair.y == 0 else top
				y += sin(angle+band*0.7)*0.012
				var taper := 0.91+0.09*sin(PI*(y-low)/(high-low))
				points.append(Vector3(cos(angle)*radius.x*taper,y,sin(angle)*radius.y*taper))
			surface.quad(points[2],points[3],points[0],points[1],Color(0.91,0.88,0.77)*(0.91+0.08*sin(band*2.1)))
	art.commit(part,surface,art.linen,"FrayedLinenBands")

func _process(delta: float) -> void:
	if _native_pose: return
	_clock += delta
	if not is_instance_valid(_model): return
	if _actor.is_dead():
		_fall = minf(_fall+delta*1.4,1.0)
		_model.rotation.z = -_fall*1.45
		_model.position.y = -_fall*0.20
		return
	var moving := minf(Vector2(_actor.velocity.x,_actor.velocity.z).length()*0.24,1.0)
	var attack: bool = _actor.state == _actor.State.ATTACK
	_model.pose(3 if attack else 0,clampf(_clock/_attack_duration,0.0,1.0),moving,delta)
