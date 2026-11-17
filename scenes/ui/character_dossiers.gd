extends RefCounted
## Lore stays here; skill display fields always come from the actual ability catalog.
const CATALOG = preload("res://scenes/player/character_catalog.gd")
const ENTRIES := {
	"knight": {
		"name": "Knight · 余烬骑士",
		"summary": "烽火熄灭后，仍守誓巡行的骑士。剑术与基础奥术兼备，适合稳健推进。",
		"background": "旧王国的烽火熄灭后，仍沿驿道巡行的骑士。那面伤痕累累的盾上，从未刻下新主人的纹章。",
		"personality": "寡言守诺 · 临危不退",
		"role": "均衡近战 · 稳健前锋",
		"combat": "剑术与基础奥术交织进攻，兼顾近身压制与中距牵制，攻守节奏从容。",
		"weapon": "旧制长剑与纹章盾。每一道刃痕，都记录着一段不肯遗忘的誓言。"
	},
	"lan": {
		"name": "Lan · 逐影游侠",
		"summary": "被猎团除名的逐影者。双刃游走寻找破绽，专注时发动密集攻势。",
		"background": "猎团的名册早已将她除名，遗迹间却仍流传着逐影者的传闻。两道刃光交错时，胜负便已分明。",
		"personality": "敏锐不羁 · 决断迅捷",
		"role": "机动输出 · 破绽猎手",
		"combat": "游走于敌阵边缘，以敏捷身法寻找破绽，将短暂专注化为密集攻势。",
		"weapon": "成对短刃轻巧利落，交错突刺后向两侧展锋，留下迅捷凌厉的剪影。"
	},
	"iron": {
		"name": "Iron · 铁誓守卫",
		"summary": "将最后一道防线带入遗迹的老兵。生命与护盾厚实，擅长举盾承伤后反击。",
		"background": "关隘陷落后，仍在巡夜的老兵。城墙已成残垣，他却执意将最后一道防线带进未知之境。",
		"personality": "沉稳执拗 · 护誓如命",
		"role": "正面防守 · 近身反击",
		"combat": "厚实的生命与护盾支撑正面交锋，以承受冲击换取反击时机，步伐较为沉缓。",
		"weapon": "包铜圆盾与层叠甲片。盾面凹痕是旧日守城战留下的勋记，也是拒敌于外的底气。"
	},
	"astra": {
		"name": "Astra · 星烬术士",
		"summary": "循着残缺星图而来的求知者。能量充裕，以引力法阵牵制群敌，依靠距离自保。",
		"background": "观星院最后一册星图指向了这片遗迹。循着残缺的坐标，术士试图找回那场星陨被抹去的记录。",
		"personality": "冷静求知 · 执着于禁忌",
		"role": "范围控制 · 奥术牵制",
		"combat": "以充裕能量延续施法，善于将群敌困在法阵之中；脆弱的身躯依赖距离庇护。",
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
