extends RefCounted
## Character presentation; stats and skill effects come from the actual catalog.
const CATALOG = preload("res://scenes/player/character_catalog.gd")
const ENTRIES := {
	"knight": {
		"name": "Knight · 余烬骑士",
		"summary": "均衡入门，兼用近战与法术。能量不足时用补给续上法术，走位与闪避仍是自保关键。",
		"background": "旧王国的烽火熄灭后，仍沿驿道巡行的骑士。那面伤痕累累的盾上，从未刻下新主人的纹章。",
		"personality": "寡言守诺 · 临危不退",
		"role": "骑士 · 均衡入门",
		"combat": "用 K 远攻、J 近战收尾，缺能量时用 L 补给；技能只回能，仍需走位躲避攻击。",
		"weapon": "旧制长剑与纹章盾。每一道刃痕，都记录着一段不肯遗忘的誓言。"
	},
	"lan": {
		"name": "Lan · 逐影游侠",
		"summary": "移速最快，护盾较少。走位整备下一发强化法术，安全时开专注加快进攻。",
		"background": "猎团的名册早已将她除名，遗迹间却仍流传着逐影者的传闻。两道刃光交错时，胜负便已分明。",
		"personality": "敏锐不羁 · 决断迅捷",
		"role": "兰 · 机动输出",
		"combat": "停手走位取得整备，用强化 K 起手；安全窗口开 L 加快 J/K，留意更快的能量消耗，护盾较少时及时闪避。",
		"weapon": "成对短刃轻巧利落，交错突刺后向两侧展锋，留下迅捷凌厉的剪影。"
	},
	"iron": {
		"name": "Iron · 铁誓守卫",
		"summary": "生命最多，移速最慢。面向来袭方向举盾反击，用近战收尾争取回盾。",
		"background": "关隘陷落后，仍在巡夜的老兵。城墙已成残垣，他却执意将最后一道防线带进未知之境。",
		"personality": "沉稳执拗 · 护誓如命",
		"role": "铁卫 · 正面防守",
		"combat": "正面对敌短时举盾，松开反击；用 K 削血、J 收尾回复护盾。移动较慢，留意绕后与地面伤害。",
		"weapon": "包铜圆盾与层叠甲片。盾面凹痕是旧日守城战留下的勋记，也是拒敌于外的底气。"
	},
	"astra": {
		"name": "Astra · 星烬术士",
		"summary": "能量最多，生命最少。用法阵牵制聚集的小怪，配合法术并保持距离。",
		"background": "观星院最后一册星图指向了这片遗迹。循着残缺的坐标，术士试图找回那场星陨被抹去的记录。",
		"personality": "冷静求知 · 执着于禁忌",
		"role": "奥术师 · 区域牵制",
		"combat": "预判追兵路线放 L 法阵，再用 K 补伤害；敌人离阵会漏伤，首领不受牵引，低生命需要保持距离。",
		"weapon": "掌心法球凝聚蓝色奥能，游移的环轨是术式的刻度，无需钢刃亦能投射杀机。"
	}
}

static func entry(id: String) -> Dictionary:
	var dossier: Dictionary = ENTRIES.get(id, ENTRIES["knight"]).duplicate()
	var ability := CATALOG.ability_definition(id)
	dossier["skill_name"] = ability.name
	dossier["effect"] = ability.description
	dossier["skill_icon"] = ability.icon
	return dossier

static func mechanics_text(id: String) -> String:
	var data := CATALOG.definition(id)
	var ability := CATALOG.ability_definition(id)
	var dossier := entry(id)
	return "[b]初始属性[/b]\n生命 %d · 护盾 %d · 能量 %d（初始/上限）\n近战伤害 %d · 步行 %.1f / 疾跑 %.1f 米/秒\n\n[b]通用操作[/b]\nWASD / 方向键移动，按住 Shift 疾跑。\n空格：闪避3米 / 0.2秒，期间无敌，冷却0.8秒；撞墙会受阻。\nJ：默认近战，间隔0.5秒；装备枪械后改为射击。\nK：法术小球，基础伤害2，消耗5能量，冷却0.8秒，最远10米；命中首个目标或墙体后消失。\n能量不会随时间自然回复。星蓝药剂恢复20能量；Knight 按 L 补给恢复10能量；Astra 每间战斗房首次清场额外恢复5能量，均不超过上限。护盾优先承伤，不会自然回复。\n\n[b]L · %s[/b]\n%s\n\n[b]玩法提示[/b]\n%s\n\n以上为初始配置；强化符文、装备及减速等状态会影响实际战斗。计时随游戏暂停而停止。" % [data.hp, data.shield, int(data.energy), data.attack, data.walk, data.run, ability.name, ability.description, dossier.combat]
