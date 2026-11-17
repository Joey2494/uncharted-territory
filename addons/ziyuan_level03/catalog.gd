extends RefCounted
## Stable IDs: saved/scene references must use IDs, never translated display names.
const ENEMIES := {
	"bone_axe": {"name":"骨斧斥候", "role":"近战压迫", "hp":6, "damage":1, "speed":2.9, "reach":2.1, "windup":0.52, "recovery":0.9, "gold":12, "rank":1, "color":Color("c5b58e")},
	"bone_spike": {"name":"枯筋腐尸", "role":"远程封路", "hp":9, "damage":2, "speed":2.5, "reach":10.0, "windup":0.68, "recovery":1.5, "gold":18, "rank":2, "color":Color("6b6046")},
	"tomb_sword": {"name":"长剑墓卫", "role":"直线突刺", "hp":14, "damage":3, "speed":2.4, "reach":7.0, "windup":0.82, "recovery":1.25, "gold":25, "rank":3, "color":Color("6d756f")},
	"chain_jailer": {"name":"双链执刑官", "role":"环形扫场", "hp":22, "damage":4, "speed":2.1, "reach":4.8, "windup":0.9, "recovery":1.3, "gold":34, "rank":4, "color":Color("9a653b")},
	"sand_king": {"name":"沙缚王", "role":"三式咒术 首领", "hp":90, "damage":6, "speed":2.2, "reach":8.0, "windup":0.95, "recovery":1.2, "gold":120, "rank":5, "color":Color("c4bba2")}
}
const WAVES := [
	{"name":"墓门试刃", "ids":["bone_axe","bone_axe"], "tip":"侧移避斧 切入收招破绽"},
	{"name":"腐影回廊", "ids":["bone_axe","bone_spike"], "tip":"借柱躲腐质弹 优先切远程"},
	{"name":"王陵仪仗", "ids":["bone_spike","tomb_sword"], "tip":"引诱墓卫撞柱 再击其背侧"},
	{"name":"双链刑场", "ids":["bone_axe","chain_jailer"], "tip":"链鞭外圈危险 内圈可钻入"},
	{"name":"沙王苏醒", "ids":["sand_king"], "tip":"躲绷带 离开沙印 半血召唤斥候"}
]
static func definition(id: String) -> Dictionary:
	return ENEMIES.get(id, {}).duplicate(true)
