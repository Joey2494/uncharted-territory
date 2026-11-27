extends RefCounted
## 当前双武器基础伤害 1/2；period 为完整攻击循环的目标间隔，含前后摇。
const ENEMIES := {
	"dawn_shade": {"name": "曦影", "hp": 6, "speed": 2.1, "damage": 1, "gold": 16, "period": 3.6, "windup": 0.55, "active": 0.25, "recovery": 0.8},
	"dawn_echo": {"name": "曦影假身", "hp": 1, "speed": 2.1, "damage": 0, "gold": 0, "period": 3.6, "windup": 0.55, "active": 0.25, "recovery": 0.8},
	"sun_puppet": {"name": "赤阳傀儡", "hp": 8, "speed": 1.5, "damage": 1, "gold": 20, "period": 3.8, "windup": 0.75, "active": 0.25, "recovery": 1.0},
	"iron_thistle": {"name": "白芒尖蓟", "hp": 10, "speed": 0.0, "damage": 1, "gold": 22, "period": 3.2, "windup": 0.65, "active": 0.25, "recovery": 1.0},
	"raven_roost": {"name": "群鸦归巢", "hp": 12, "speed": 2.0, "damage": 1, "gold": 24, "period": 4.2, "windup": 0.7, "active": 1.7, "recovery": 1.0},
}
const ROOMS := [
	{"id": "dawn_shade", "name": "第一房 · 薄光回廊", "tip": "曦影受击分身；击散假身后追踪本体。晨光会短暂扰乱视野。", "spawns": [Vector3(-4, 0.05, -4), Vector3(4, 0.05, -4)]},
	{"id": "sun_puppet", "name": "第二房 · 赤阳木庭", "tip": "傀儡周期性释放真实热浪；保持距离，侧移或翻滚穿过波前。", "spawns": [Vector3(-4, 0.05, -4), Vector3(4, 0.05, -4)]},
	{"id": "iron_thistle", "name": "第三房 · 暴晒刺径", "tip": "尖蓟扎根挡路；绕开正面飞刺，近身时留意长出的实体刺丛。", "spawns": [Vector3(-5, 0.05, -2), Vector3(0, 0.05, -5), Vector3(5, 0.05, -2)]},
	{"id": "raven_roost", "name": "第四房 · 暮鸦巢台", "tip": "群鸦交替四散与聚拢；击中任一乌鸦都会削减整群生命。", "spawns": [Vector3(0, 0.05, -4)]},
]
static func definition(id: String) -> Dictionary:
	return ENEMIES.get(id, {}).duplicate(true)
