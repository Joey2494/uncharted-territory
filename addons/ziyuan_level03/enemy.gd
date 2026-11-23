extends CharacterBody3D
## Public combat contract: bind_target, set_encounter_active, damage, control, slow, hp_changed, died.
signal hp_changed(current: int, maximum: int)
signal damage_received(amount: int)
signal died
signal battle_started
signal state_changed(message: String)
signal attack_telegraphed(enemy_id: String, mode: int, duration: float)
signal attack_started(enemy_id: String, mode: int)
signal attack_resolved(enemy_id: String, mode: int)
signal reward_requested(source_id: String, coins: int)
signal summon_requested(enemy_id: String, position: Vector3)
signal status_requested(target: Node3D, status_id: String, duration: float, strength: float)
const Catalog=preload("catalog.gd")
const FX=preload("effects.gd")
const Visual=preload("visual.gd")
const Bolt=preload("bone_projectile.gd")
enum State { IDLE, CHASE, WINDUP, STRIKE, RECOVER, HURT, DEAD }
@export_enum("bone_axe","bone_spike","tomb_sword","chain_jailer","sand_king") var enemy_id := "bone_axe"
@export var target_path := NodePath("../Player")
@export var start_active := false
@export var reward_source_id := ""
var definition: Dictionary
var max_hp := 6
var hp := 6
var boss_name := "沙缚王"
var state: State=State.IDLE
var _target: Node3D
var _aggro := false
var _enabled := false
var _battle := false
var _remaining := 0.0
var _duration := 1.0
var _direction := Vector3.FORWARD
var _visual: Node3D
var _warning: Node3D
var _timer := 0.0
var _strike_index := 0
var _hit: Dictionary = {}
var _accepted_hit := false
var _mode := 0
var _next_mode := 0
var _phase_two := false
var _strike_fired := false
var _control := 0.0
var _slow := 0.0
var _dash_left := 0.0
var _marks: Array[Vector3]=[]
var _flash: Node
var _health: Node3D
func _ready() -> void:
	definition=Catalog.definition(enemy_id)
	assert(not definition.is_empty(),"Unknown level03 enemy_id")
	max_hp=definition.hp
	hp=max_hp
	boss_name=definition.name
	collision_layer=4
	collision_mask=3 # World + player; enemies avoid one another in the encounter layout.
	add_to_group("camera_targets")
	add_to_group("l3_enemies")
	set_meta("is_elite",enemy_id in ["tomb_sword","chain_jailer"])
	set_meta("camera_radius",2.0 if is_boss() else 1.2)
	set_meta("camera_height",4.2 if is_boss() else 3.1)
	var shape:=CollisionShape3D.new()
	shape.name="CollisionShape3D"
	var capsule:=CapsuleShape3D.new()
	capsule.radius=0.78 if is_boss() else 0.45
	capsule.height=3.6 if is_boss() else 2.3
	shape.shape=capsule
	shape.position.y=capsule.height*0.5
	add_child(shape)
	_visual=get_node_or_null("Visuals")
	if _visual==null:
		_visual=Visual.new()
		_visual.name="Visuals"
		add_child(_visual)
	_visual.build(enemy_id,definition.color)
	_warning=Node3D.new()
	_warning.name="Telegraph"
	add_child(_warning)
	_flash=preload("res://scenes/ui/hit_flash_3d.gd").new()
	_flash.visual_root=NodePath("../Visuals")
	add_child(_flash)
	if not is_boss():
		_health=preload("res://scenes/ui/enemy_health_label_3d.tscn").instantiate()
		_health.name="HealthLabel"
		_health.position.y=3.05
		_health.elite=enemy_id in ["tomb_sword","chain_jailer"]
		add_child(_health)
		_health.bind_health_source(self,hp,max_hp)
	if _target==null: _target=get_node_or_null(target_path) as Node3D
	if reward_source_id.is_empty(): reward_source_id="l3:"+str(get_instance_id())
	set_encounter_active(start_active)
func is_boss() -> bool: return enemy_id=="sand_king"
func is_dead() -> bool: return state==State.DEAD
func is_encounter_active() -> bool: return _enabled and can_process() and not is_dead()
func bind_target(target: Node3D) -> bool:
	if not is_instance_valid(target) or not target.has_method("take_damage") or not target.has_method("is_dead"): return false
	_target=target
	return true
func set_encounter_active(active: bool) -> void:
	if is_dead(): return
	_enabled=active and not is_dead()
	_aggro=false
	if not active:
		_clear_warning()
		_clear_hazards()
		state=State.IDLE
		_remaining=0
		_control=0
	process_mode=Node.PROCESS_MODE_PAUSABLE if _enabled else Node.PROCESS_MODE_DISABLED
func _clear_warning() -> void:
	if not is_instance_valid(_warning): return
	for child in _warning.get_children(): child.queue_free()
func _clear_hazards() -> void:
	if not is_inside_tree(): return
	for hazard in get_tree().get_nodes_in_group("l3_hazards"):
		if hazard.get("_source") != null and hazard._source.get_ref()==self: hazard.queue_free()
func _live_target() -> bool:
	return is_instance_valid(_target) and not _target.is_dead()
func _can_see(point: Vector3) -> bool:
	var a:=global_position+Vector3.UP
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,Vector3(point.x,a.y,point.z),1,[get_rid()])).is_empty()
func _physics_process(delta: float) -> void:
	if not _enabled or is_dead(): return
	velocity.x=0
	velocity.z=0
	velocity.y=0 if is_on_floor() else velocity.y+get_gravity().y*delta
	_slow=maxf(0,_slow-delta)
	_control=maxf(0,_control-delta)
	if not _live_target():
		_clear_warning()
		_clear_hazards()
		state=State.IDLE
		return
	_timer+=delta
	if _control>0:
		state=State.HURT
		_remaining=_control
	elif state==State.WINDUP:
		_remaining=maxf(0,_remaining-delta)
		if _remaining<=0: _begin_strike()
	elif state==State.STRIKE:
		_tick_strike(delta)
	elif state in [State.RECOVER,State.HURT]:
		_remaining=maxf(0,_remaining-delta)
		if state==State.RECOVER: _reposition()
		if _remaining<=0: state=State.CHASE
	else:
		_pursue(delta)
	var progress:=clampf(1.0-_remaining/maxf(_duration,0.01),0,1)
	_visual.pose(state,progress,Vector2(velocity.x,velocity.z).length(),delta,_strike_index)
	if enemy_id!="tomb_sword" or state!=State.STRIKE: move_and_slide()
func _reposition() -> void:
	# 远程敌人在收招时保持距离并横移；其他单位收招仍留反击窗口。
	if enemy_id!="bone_spike" or not _live_target(): return
	var offset:=_target.global_position-global_position
	offset.y=0
	var dir:=offset.normalized()
	var desired: Vector3=-dir if offset.length()<4.0 else dir.rotated(Vector3.UP,PI*0.5)*0.55
	var speed: float=definition.speed*(0.65 if _slow>0 else 1.0)
	velocity.x=desired.x*speed
	velocity.z=desired.z*speed
func _pursue(_delta: float) -> void:
	var offset:=_target.global_position-global_position
	offset.y=0
	var distance:=offset.length()
	if not _aggro and distance<18 and _can_see(_target.global_position):
		_aggro=true
		if not _battle: _battle=true; battle_started.emit()
	if not _aggro: state=State.IDLE; return
	_direction=offset.normalized() if distance>0.01 else Vector3.FORWARD
	_visual.rotation.y=atan2(-_direction.x,-_direction.z)
	var reach: float=definition.reach
	if is_boss() and _next_mode==1: reach=14
	elif is_boss() and _next_mode==2: reach=5.3
	if distance<=reach and _can_see(_target.global_position):
		if enemy_id=="bone_spike" and distance<4:
			velocity=-_direction*1.2
		begin_attack()
	else:
		state=State.CHASE
		var speed: float=definition.speed*(0.65 if _slow>0 else 1.0)
		velocity.x=_direction.x*speed
		velocity.z=_direction.z*speed
func begin_attack(mode: int=-1) -> bool:
	if not is_encounter_active() or not _live_target() or state in [State.WINDUP,State.STRIKE,State.RECOVER,State.HURT]: return false
	_mode=(_next_mode if mode<0 else clampi(mode,0,2)) if is_boss() else 0
	if is_boss(): _next_mode=(_mode+1)%3
	_strike_index=0
	_start_attack()
	return true
func _start_attack() -> void:
	# 直接进入执行动作；保留 WINDUP 枚举和旧信号用于外部兼容，永不进入或发射。
	_clear_warning()
	var offset:=_target.global_position-global_position
	offset.y=0
	_direction=offset.normalized() if offset.length()>0.01 else Vector3.FORWARD
	_visual.rotation.y=atan2(-_direction.x,-_direction.z)
	_marks.clear()
	_begin_strike()
	attack_started.emit(enemy_id,_mode)
	var message: String=definition.name+" 攻击"
	if is_boss(): message=["绷带撕扯","飞行沙咒","沙王重踏"][_mode]
	state_changed.emit(("狂暴 " if _phase_two else "")+message)
func _begin_strike() -> void:
	state=State.STRIKE
	_duration=definition.active*(0.8 if _phase_two else 1.0)
	_remaining=_duration
	_strike_fired=false
	_hit.clear()
	_accepted_hit=false
	_dash_left=6.5
func _tick_strike(delta: float) -> void:
	if state!=State.STRIKE or not _live_target(): return
	var old:=1.0-_remaining/_duration
	_remaining=maxf(0,_remaining-delta)
	var t:=1.0-_remaining/_duration
	if enemy_id=="tomb_sword":
		var motion:=_direction*minf(_dash_left,19.0*delta)
		var collision:=move_and_collide(motion)
		_dash_left=maxf(0,_dash_left-motion.length())
		if collision!=null:
			if collision.get_collider()==_target: _hit_player(definition.damage)
			_remaining=0
		if _dash_left<=0.01: _remaining=0
	elif enemy_id=="chain_jailer":
		# 加快后的扫链仍覆盖本帧跨过的角度，低帧率不会跳过玩家。
		var steps:=maxi(1,ceili((t-old)*250.0/8.0))
		for i in steps+1:
			var angle:=lerpf(-125,125,lerpf(old,t,float(i)/steps))*(1 if _strike_index==0 else -1)
			_zone(global_position,4.8,definition.damage,20,0.95,_direction.rotated(Vector3.UP,deg_to_rad(angle)))
	elif not _strike_fired and t>=0.28:
		_strike_fired=true
		if enemy_id=="bone_axe": _zone(global_position,2.1,definition.damage,100)
		elif enemy_id=="bone_spike":
			for i in 3:
				var b:=Bolt.new()
				get_parent().add_child(b)
				b.global_position=global_position+Vector3.UP*1.25+_direction*0.55
				b.launch(self,_target,_direction.rotated(Vector3.UP,(i-1)*0.22),definition.damage)
		elif _mode==0: _zone(global_position,7,definition.damage,70); _bandages()
		elif _mode==1:
			# 可见的飞行沙咒取代无预警脚下爆炸，发射后不追踪。
			for i in 3:
				var b:=Bolt.new()
				b.speed=8.5
				b.sand_curse=true
				get_parent().add_child(b)
				b.global_position=global_position+Vector3.UP*1.25+_direction*0.9
				b.launch(self,_target,_direction.rotated(Vector3.UP,(i-1)*0.2),definition.damage+1)
		else: _zone(global_position,5.3,definition.damage,360); FX.burst(get_parent(),global_position+Vector3.UP*0.1,Color("c6a16b"),5.3)
		_clear_warning()
	if _remaining<=0:
		attack_resolved.emit(enemy_id,_mode)
		if enemy_id=="chain_jailer" and _strike_index==0:
			_strike_index=1
			_start_attack()
		else:
			_clear_warning()
			state=State.RECOVER
			_remaining=definition.recovery*(0.75 if _phase_two else 1.0)
			_duration=_remaining
			state_changed.emit("收招破绽 可反击")
func _zone(origin: Vector3, radius: float, damage: int, degrees: float, inner := 0.0, facing := Vector3.ZERO) -> void:
	if not _live_target(): return
	var offset:=_target.global_position-origin
	offset.y=0
	if offset.length()>radius+0.3 or offset.length()<inner: return
	var dir:=_direction if facing.is_zero_approx() else facing
	if degrees<360 and offset.length()>0.01 and dir.dot(offset.normalized())<cos(deg_to_rad(degrees/2)): return
	if _can_see(_target.global_position): _hit_player(damage)
func _hit_player(amount: int) -> void:
	if not _live_target() or _hit.has(_target.get_instance_id()): return
	_hit[_target.get_instance_id()]=true
	var inventory:=_target.get_node_or_null("ItemInventory")
	var guarded: bool=is_instance_valid(inventory) and inventory.get("guard_active")==true
	var accepted: bool=_target.take_direct_damage(amount,global_position) if _target.has_method("take_direct_damage") else _target.take_damage(amount)
	_accepted_hit=accepted and not guarded
func _bandages() -> void:
	var ribbons:=Node3D.new()
	ribbons.add_to_group("l3_transient")
	get_parent().add_child(ribbons)
	for i in 5:
		var start:=global_position+Vector3((i-2)*0.18,2.0,0)
		var end:=start+_direction.rotated(Vector3.UP,(i-2)*0.13)*7
		FX.line(ribbons,start,end,FX.mat(Color("d6c697")),0.055)
	var tween:=ribbons.create_tween()
	tween.tween_interval(0.16)
	tween.tween_callback(ribbons.queue_free)
func apply_control(duration: float) -> void:
	if not is_encounter_active() or is_boss(): return
	_control=maxf(_control,minf(duration,2.5))
	_remaining=_control
	state=State.HURT
	_clear_warning()
func apply_slow(duration: float) -> void:
	if is_encounter_active(): _slow=maxf(_slow,minf(duration,4))
func take_direct_damage(amount: int, source_position: Vector3) -> bool:
	var value:=amount
	if enemy_id=="tomb_sword" and state not in [State.RECOVER,State.HURT]:
		var direction:=source_position-global_position
		direction.y=0
		if direction.length()>0.01 and (-_visual.global_basis.z).dot(direction.normalized())>0.25: value=maxi(1,ceili(amount*0.5))
	return take_damage(value)
func take_damage(amount: int) -> bool:
	if not is_node_ready() or not is_encounter_active() or amount<=0: return false
	var value:=amount*2 if state==State.RECOVER and enemy_id in ["tomb_sword","chain_jailer"] else amount
	var applied:=mini(value,hp)
	hp-=applied
	if hp==0: state=State.DEAD; _enabled=false
	_flash.flash()
	hp_changed.emit(hp,max_hp)
	damage_received.emit(applied)
	if hp==0:
		_clear_warning()
		_clear_hazards()
		set_deferred("collision_layer",0)
		set_deferred("collision_mask",0)
		set_physics_process(false)
		reward_requested.emit(reward_source_id,definition.gold)
		died.emit()
		var t:=create_tween()
		t.tween_property(_visual,"rotation:z",PI*0.5,0.35)
		t.parallel().tween_property(_visual,"position:y",-0.5,0.35)
		t.tween_interval(0.3)
		t.tween_callback(queue_free)
	elif is_boss() and not _phase_two and hp<=max_hp/2:
		_phase_two=true
		# Phase two changes attack cadence only; every room keeps a single species.
		state_changed.emit("沙王狂暴 · 攻击与收招加速")
	elif _stagger_on_hit():
		state=State.HURT
		_remaining=0.08
		_clear_warning()
	return true

## 保留最新主分支的子类硬直挂钩；普通命中不打断已执行的动作。
func _stagger_on_hit() -> bool:
	return not is_boss() and enemy_id!="tomb_sword" and state!=State.STRIKE

## 主分支第四关观测站的机关行进标记仍调用此方法。
## 第三关普通攻击不调用它，不会生成预警或攻击范围。
func _disc(at: Vector3, radius: float, degrees: float, inner := 0.0) -> void:
	var node:=MeshInstance3D.new()
	node.mesh=FX.sector(radius,degrees,inner)
	_warning.add_child(node)
	node.global_position=at+Vector3.UP*0.05
	node.rotation.y=atan2(-_direction.x,-_direction.z)
