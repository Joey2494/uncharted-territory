extends RefCounted
## 第四关前四房敌人数值；首轮平衡初值，J=1 / K=2。
const ENEMIES := {
	"dawn_shade": {"name": "曦影", "hp": 8, "speed": 2.1, "damage": 1, "gold": 16, "period": 3.6},
	"dawn_echo": {"name": "曦影假身", "hp": 1, "speed": 2.1, "damage": 0, "gold": 0, "period": 3.6},
	"sun_puppet": {"name": "赤阳傀儡", "hp": 12, "speed": 1.5, "damage": 1, "gold": 20, "period": 3.8},
	"iron_thistle": {"name": "白芒尖蓟", "hp": 14, "speed": 0.0, "damage": 1, "gold": 22, "period": 2.7},
	"raven_roost": {"name": "群鸦归巢", "hp": 12, "speed": 2.0, "damage": 1, "gold": 24, "period": 4.2},
}
const ROOMS := [
	{"id": "dawn_shade", "name": "第一房 · 薄光回廊", "tip": "曦影受击分身；击散假身后追踪本体。晨光会短暂扰乱视野。", "spawns": [Vector3(-4, 0.05, -4), Vector3(4, 0.05, -4)]},
	{"id": "sun_puppet", "name": "第二房 · 赤阳木庭", "tip": "傀儡周期性释放真实热浪；保持距离，侧移或翻滚穿过波前。", "spawns": [Vector3(-4, 0.05, -4), Vector3(4, 0.05, -4)]},
	{"id": "iron_thistle", "name": "第三房 · 暴晒刺径", "tip": "尖蓟扎根挡路；绕开正面飞刺，近身时留意长出的实体刺丛。", "spawns": [Vector3(-5, 0.05, -2), Vector3(0, 0.05, -5), Vector3(5, 0.05, -2)]},
	{"id": "raven_roost", "name": "第四房 · 暮鸦巢台", "tip": "群鸦交替四散与聚拢；击中任一乌鸦都会削减整群生命。", "spawns": [Vector3(0, 0.05, -4)]},
]
static func definition(id: String) -> Dictionary:
	return ENEMIES.get(id, {}).duplicate(true)
