extends RefCounted
## 第四关孢冠女巫数值表。稳定 ID：存档与场景引用必须使用 ID，不依赖显示名。
## 按当前角色 4–6 生命、1–2 护盾与双武器 1/2 伤害校准；详见 docs/combat_balance.md。
const ARENA := {"size": Vector2(26, 22), "inset": 1.0, "pillar": 2.0}
## 全场同时存在的毒池上限；生成第 4 个时最旧一个消散（§12.4）。
const POOL_CAP := 3
## 毒池寿命 4 秒，每秒 1 点，进入立即结算一次（§6.2 地面危险规则）。
const POOL_LIFE := 4.0
## 孢子守卫整场最多召唤 3 批、共 6 只（§12.4）。
const GUARD_BATCH_CAP := 3
const ENEMIES := {
	"witch": {
		"name": "袍冠女巫", "role": "四式咒术 第四关首领", "hp": 52, "damage": 2,
		"speed": 1.8, "reach": 12.0, "windup": 0.80, "recovery": 1.2,
		"gold": 160, "rank": 6, "color": Color("202636"), "boss": true,
	},
	"spore_guard": {
		"name": "孢子守卫", "role": "近身扑咬 召唤物", "hp": 4, "damage": 1,
		"speed": 3.0, "reach": 1.5, "windup": 0.45, "recovery": 0.9,
		"gold": 0, "rank": 1, "color": Color("7a8f5a"), "boss": false,
	},
}
const WAVES := [
	{"name": "袍冠试炼", "ids": ["witch"], "tip": "连续移动躲开飞行孢弹 留意地面的毒液"},
	{"name": "守卫随行", "ids": ["witch", "spore_guard", "spore_guard"], "tip": "优先清理孢子守卫 避免与毒池夹击"},
	{"name": "半血觉醒", "ids": ["witch"], "tip": "半血进入二阶段 首次藤蔓横扫固定出现"},
]
static func definition(id: String) -> Dictionary:
	return ENEMIES.get(id, {}).duplicate(true)
