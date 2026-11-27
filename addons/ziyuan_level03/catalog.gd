extends RefCounted
## Stable IDs: saved/scene references must use IDs, never translated display names.
const ENEMIES := {
	"bone_axe": {"name":"骨斧斥候", "role":"近战压迫", "hp":4, "damage":1, "speed":3.4, "reach":2.1, "windup":0.45, "active":0.28, "recovery":0.75, "gold":12, "rank":1, "color":Color("c5b58e")},
	"bone_spike": {"name":"枯筋腐尸", "role":"远程封路", "hp":5, "damage":1, "speed":2.7, "reach":11.0, "windup":0.55, "active":0.26, "recovery":0.95, "gold":18, "rank":2, "color":Color("6b6046")},
	"tomb_sword": {"name":"长剑墓卫", "role":"直线突刺", "hp":8, "damage":2, "speed":3.0, "reach":7.0, "windup":0.65, "active":0.36, "recovery":1.10, "gold":25, "rank":3, "color":Color("6d756f")},
	"chain_jailer": {"name":"双链执刑官", "role":"环形扫场", "hp":12, "damage":2, "speed":2.5, "reach":4.8, "windup":0.70, "active":0.36, "recovery":1.20, "gold":34, "rank":4, "color":Color("9a653b")},
	"sand_king": {"name":"沙缚王", "role":"三式咒术 首领", "hp":44, "damage":2, "speed":2.5, "reach":8.0, "windup":0.80, "active":0.36, "recovery":1.30, "gold":120, "rank":5, "color":Color("c4bba2")}
}
const WAVES := [
	{"name":"墓门试刃", "ids":["bone_axe","bone_axe"], "tip":"侧移避斧 切入收招破绽"},
	{"name":"腐影回廊", "ids":["bone_spike","bone_spike"], "tip":"借柱躲腐质弹 等齐射结束再近身"},
	{"name":"王陵仪仗", "ids":["tomb_sword","tomb_sword"], "tip":"引诱墓卫撞柱 收招时造成双倍伤害"},
	{"name":"双链刑场", "ids":["chain_jailer"], "tip":"链鞭外圈危险 内圈可钻入"},
	{"name":"沙王苏醒", "ids":["sand_king"], "tip":"侧移躲飞行沙咒 近身留意重踏 半血加速但不召唤"}
]
static func definition(id: String) -> Dictionary:
	return ENEMIES.get(id, {}).duplicate(true)
