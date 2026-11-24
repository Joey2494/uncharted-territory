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
		"weapon": "旅人短剑以皮革缠柄、黄铜护手与菱脊钢刃构成；符文短杖以悬浮符石和刻印铜环引导奥术。"
	},
	"lan": {
		"name": "Lan · 逐影游侠",
		"summary": "被猎团除名的逐影者。持枪游走寻找破绽，专注时发动密集攻势。",
		"background": "猎团的名册早已将她除名，遗迹间却仍流传着逐影者的传闻。线圈亮起时，胜负便已分明。",
		"personality": "敏锐不羁 · 决断迅捷",
		"role": "机动输出 · 破绽猎手",
		"combat": "游走于敌阵边缘，以敏捷身法寻找破绽，将短暂专注化为密集攻势。",
		"weapon": "制式手枪有独立滑套、握把与机械瞄具；线圈卡宾枪以铜绕组、导轨、能量匣和枪托形成长枪轮廓。"
	},
	"iron": {
		"name": "Iron · 铁誓守卫",
		"summary": "将最后一道防线带入遗迹的老兵。生命与护盾厚实，擅长举盾承伤后反击。",
		"background": "关隘陷落后，仍在巡夜的老兵。城墙已成残垣，他却执意将最后一道防线带进未知之境。",
		"personality": "沉稳执拗 · 护誓如命",
		"role": "正面防守 · 近身反击",
		"combat": "厚实的生命与护盾支撑正面交锋，以承受冲击换取反击时机，步伐较为沉缓。",
		"weapon": "守卫短剑使用宽刃、上翘护手与誓约宝石；寒晶短杖以三簇冰晶和银制束环形成独立轮廓。"
	},
	"astra": {
		"name": "Astra · 星烬术士",
		"summary": "循着残缺星图而来的求知者。能量充裕，以引力法阵牵制群敌，依靠距离自保。",
		"background": "观星院最后一册星图指向了这片遗迹。循着残缺的坐标，术士试图找回那场星陨被抹去的记录。",
		"personality": "冷静求知 · 执着于禁忌",
		"role": "范围控制 · 奥术牵制",
		"combat": "以充裕能量延续施法，善于将群敌困在法阵之中；脆弱的身躯依赖距离庇护。",
		"weapon": "练习魔杖仅有短木柄与一枚石英；引火法杖使用长杖身、三爪火盆和多层火舌，投射余烬火弹。"
	}
}

static func entry(id: String) -> Dictionary:
	var dossier: Dictionary = ENTRIES.get(id, ENTRIES["knight"]).duplicate()
	var ability := CATALOG.ability_definition(id)
	dossier["skill_name"] = ability.name
	dossier["effect"] = ability.description
	dossier["skill_icon"] = ability.icon
	return dossier
