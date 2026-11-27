extends Node3D
## 货运的单向状态保证取药和发车互斥，到站收货时背包一次性入账。
const REWARDS := preload("res://data/reward_balance.gd")
enum State { WAITING, TAKEN, TRAVELLING, ARRIVED, RECEIVED }
var state := State.WAITING
var level: Node3D
var cart: Node3D
var cargo: MeshInstance3D
var route := PackedVector3Array()
var segment := 0
var departure_label: Label3D

func setup(host: Node3D) -> void:
	level = host
	var g: Vector3 = level.layout.room_center("G")
	var h: Vector3 = level.layout.room_center("H")
	var i: Vector3 = level.layout.room_center("I")
	var take: Node3D = level.add_station(&"mail_take",g+Vector3(-2,0,0),"补给包 · 生命/星蓝×2\n强化/守护×10")
	var send: Node3D = level.add_station(&"mail_send",g+Vector3(2,0,0),"寄往穹顶 · 复活卡")
	var receive: Node3D = level.add_station(&"mail_receive",i+Vector3(3,0,7.4),"领取复活卡")
	for station: Node3D in [take,send,receive]:
		level.layout.block(station,Vector3(0,0.63,0),Vector3(0.55,0.22,0.46),Color("#639f9d"),true)
	route = PackedVector3Array([g+Vector3(0,2.2,-1.5),g+Vector3(0,2.6,-9),h+Vector3(-5,2.6,4),h+Vector3(-5,2.6,-4),i+Vector3(3,2.2,7.4)])
	for n in range(1,route.size()):
		var start := route[n-1]
		var end := route[n]
		var rail = level.layout.block(self,(start+end)*0.5+Vector3.UP*0.65,Vector3(0.09,0.12,start.distance_to(end)),Color("#b68d55"))
		rail.look_at(end+Vector3.UP*0.65,Vector3.UP)
	cart = Node3D.new()
	add_child(cart)
	cart.position = route[0]
	level.layout.block(cart,Vector3.ZERO,Vector3(0.85,0.48,1.12),Color("#b0864e"))
	level.layout.block(cart,Vector3(0,0.42,0),Vector3(0.13,0.44,0.13),Color("#415665"))
	cargo = level.layout.block(cart,Vector3(0,0.28,0.24),Vector3(0.36,0.26,0.38),Color("#67cdd9"),true)
	departure_label = level.layout.caption(self,"邮车 → 主穹顶",g+Vector3(0,1.2,-2.9))

func chosen() -> bool:
	return state != State.WAITING

func available(id: StringName) -> bool:
	if id == &"mail_receive": return state == State.ARRIVED
	return state == State.WAITING and id in [&"mail_take",&"mail_send"]

func interact(id: StringName) -> bool:
	if not available(id): return false
	match id:
		&"mail_take":
			var bundle := REWARDS.task("l4_mail_take")
			if not level.claim("observatory_mail",bundle.items,"补给入包 · 生命×2、星蓝×2、强化×10、守护×10。",bundle.gold): return false
			state = State.TAKEN
			cargo.hide()
			departure_label.text = "物资已取"
		&"mail_send":
			state = State.TRAVELLING
			departure_label.text = "已发车"
			level.note("邮车出站。去 I 安全门廊领取复活卡 ×1。")
		&"mail_receive":
			if not level.claim("observatory_mail",REWARDS.task("l4_mail").items,"邮包已签收 · 复活卡 ×1"): return false
			state = State.RECEIVED
			cargo.hide()
	return true

func advance(delta: float) -> void:
	if state != State.TRAVELLING: return
	# 邮车在 H 观察窗稍候，玩家进试车场或先到终点时继续。
	if segment == 2 and not (level.visited.has("H") or level.visited.has("I")): return
	cart.position = cart.position.move_toward(route[segment+1],delta*5.5)
	if cart.position.is_equal_approx(route[segment+1]):
		segment += 1
		if segment == route.size()-1:
			state = State.ARRIVED
			level.note("邮车已到 I 入口，复活卡 ×1 等候签收。")
