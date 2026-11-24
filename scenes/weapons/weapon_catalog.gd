extends RefCounted
## Fixed character-exclusive loadouts; weapons cannot be bought or exchanged.
const LOADOUTS := {"knight": ["traveler", "rune"], "lan": ["pistol", "coil"], "iron": ["guard", "frost"], "astra": ["practice", "fire"]}
const DATA := {
	"traveler": {"name":"旅人短剑", "melee":true, "damage":1, "interval":0.5, "range":2.2, "cost":0, "magazine":0, "reload":0.0, "speed":0.0, "effect":"轻微击退", "color":Color("d6c394")},
	"guard": {"name":"守卫短剑", "melee":true, "damage":1, "interval":0.5, "range":2.2, "cost":0, "magazine":0, "reload":0.0, "speed":0.0, "effect":"轻微击退", "color":Color("9dbbc9")},
	"pistol": {"name":"制式手枪", "melee":false, "damage":1, "interval":0.5, "range":12.0, "cost":0, "magazine":8, "reload":1.2, "speed":32.0, "effect":"精准单发", "color":Color("ffc776")},
	"practice": {"name":"练习魔杖", "melee":false, "damage":1, "interval":0.5, "range":11.0, "cost":0, "magazine":0, "reload":0.0, "speed":12.0, "effect":"直线光弹", "color":Color("b5a1fa")},
	"rune": {"name":"符文短杖", "melee":false, "damage":2, "interval":0.8, "range":10.0, "cost":5, "magazine":0, "reload":0.0, "speed":18.0, "effect":"直线法术小球", "color":Color("7dedd5")},
	"coil": {"name":"线圈卡宾枪", "melee":false, "damage":2, "interval":0.8, "range":14.0, "cost":0, "magazine":6, "reload":1.5, "speed":45.0, "effect":"高速能量弹", "color":Color("65cfff")},
	"frost": {"name":"寒晶短杖", "melee":false, "damage":2, "interval":0.8, "range":10.0, "cost":5, "magazine":0, "reload":0.0, "speed":18.0, "effect":"普通敌人减速30% / 2秒", "color":Color("a4eaff")},
	"fire": {"name":"引火法杖", "melee":false, "damage":2, "interval":0.8, "range":11.0, "cost":5, "magazine":0, "reload":0.0, "speed":16.0, "effect":"余烬：1秒后1伤害，不叠加", "color":Color("ff8c45")}
}
static func definition(id: String) -> Dictionary:
	return DATA[id]

static func energy_cost(id: String, character_id: String) -> int:
	return roundi(DATA[id].cost*0.8) if character_id == "astra" and id == "fire" else DATA[id].cost

static func description(id: String, character_id: String) -> String:
	var d: Dictionary = DATA[id]
	var styles := {
		"traveler":"轻便的菱脊短剑，以近身扇形斩击应对敌人。",
		"guard":"宽刃与誓约宝石构成守卫的近战配装，可衔接举盾反击。",
		"pistol":"滑套与机械瞄具构成精准单发手枪，不散布、不穿透、不追踪。",
		"coil":"铜绕组和导轨加速磁芯弹，以高速单发打出较高伤害。",
		"practice":"短木柄与单枚石英构成零费远程武器，无额外控制效果。",
		"rune":"悬浮符石与刻印铜环引导直线法术小球，无额外控制效果。",
		"frost":"三簇寒晶发射减速晶弹；Boss 不受减速，不叠加、不冻结。",
		"fire":"三爪火盆与长杖引导火焰弹；同一目标只保留一份余烬。"
	}
	var text: String = styles[id]+"\n基础伤害 %d · 间隔 %s 秒\n射程 %s 米" % [d.damage,str(d.interval).trim_suffix(".0"),str(d.range).trim_suffix(".0")]
	if d.melee:
		text += " · 扇形 100°\n零消耗 · 无需换弹 · 轻微击退"
	elif d.magazine > 0:
		text += " · 弹速 %s 米/秒\n弹匣 %d 发 · 换弹 %s 秒\n%s · 每发 1 枚 · 不耗蓝" % [str(d.speed).trim_suffix(".0"),d.magazine,str(d.reload).trim_suffix(".0"),"黄铜手枪弹" if id == "pistol" else "线圈磁芯弹"]
	else:
		text += " · 弹速 %s 米/秒\n%s · 无弹匣\n%s" % [str(d.speed).trim_suffix(".0"),"每发耗蓝 %d" % energy_cost(id,character_id) if d.cost > 0 else "零消耗",d.effect]
	return text
static func state(id: String) -> Dictionary:
	return {"id":id, "ammo":DATA[id].magazine, "cooldown":0.0, "reload":0.0}
static func comparison(state_data: Dictionary) -> String:
	var d: Dictionary = DATA[state_data.id]
	return "%s · 伤害%d / 间隔%.1fs / 射程%.1fm / 能量%d\n弹匣%s · 换弹%.1fs · %s" % [d.name,d.damage,d.interval,d.range,d.cost,"%d/%d" % [state_data.ammo,d.magazine] if d.magazine > 0 else "无",d.reload,d.effect]
