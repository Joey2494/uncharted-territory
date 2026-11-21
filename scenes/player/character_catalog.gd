extends RefCounted
## First-level prototypes, scaled to 3 HP enemies and the 24 HP gatekeeper.

const IDS: Array[String] = ["knight", "lan", "iron", "astra"]
static var selected_id: String = "knight"
static var start_pending: bool = false
const DATA := {
	"knight": {"name": "Knight · 初始旅人", "attack": 1, "hp": 5, "shield": 2, "energy": 50.0, "walk": 5.0, "run": 8.0,
		"model": "res://assets/characters/kaykit/Knight.glb", "skill": "战斗补给", "cooldown": 12.0,
		"ability": {"kind":"supply", "active":true, "duration":0.0, "icon":preload("res://assets/ui/energy.svg")},
		"description": "基础战斗 · 免费可用 · 5生命 / 2护盾 / 50能量\nL 恢复10能量，冷却12秒；满能量时不消耗冷却。"},
	"lan": {"name": "Lan · 游侠", "attack": 1, "hp": 5, "shield": 1, "energy": 50.0, "walk": 5.2, "run": 8.5,
		"model": "res://assets/characters/kaykit/Rogue.glb", "skill": "专注射击", "cooldown": 10.0,
		"ability": {"kind":"focus", "active":true, "duration":4.0, "icon":preload("res://assets/ui/skill_focus.svg")},
		"description": "灵活输出 · 5生命 / 1护盾 / 50能量\n停火1.5秒整备K伤害+1（保留5秒，获取间隔6秒）。L 专注4秒，结束后冷却10秒。"},
	"iron": {"name": "Iron · 守卫", "attack": 1, "hp": 6, "shield": 2, "energy": 40.0, "walk": 4.6, "run": 7.4,
		"model": "res://assets/characters/kaykit/IronGuard.tscn", "skill": "举盾反击", "cooldown": 8.0,
		"ability": {"kind":"counter", "active":true, "duration":1.2, "control_duration":0.5, "icon":preload("res://assets/ui/skill_counter.svg")},
		"description": "正面防守 · 6生命 / 2护盾 / 40能量\nJ近距击杀回1盾，每战斗房最多2盾。L举盾反击，前0.6秒精准格挡，冷却8秒。"},
	"astra": {"name": "Astra · 术士", "attack": 1, "hp": 4, "shield": 1, "energy": 60.0, "walk": 5.0, "run": 8.0,
		"model": "res://assets/characters/kaykit/Mage.glb", "skill": "引力印记", "cooldown": 14.0,
		"ability": {"kind":"gravity", "active":true, "duration":0.25, "field_duration":3.0, "icon":preload("res://assets/ui/skill_gravity.svg")},
		"description": "范围控制 · 4生命 / 1护盾 / 60能量\nK消耗5能量，清战斗房额外回5能量。L引力法阵：1+1+1+2伤害，冷却14秒。"}
}

static func definition(id: String) -> Dictionary:
	return DATA.get(id, DATA["knight"])

static func ability_definition(id: String) -> Dictionary:
	var data := definition(id)
	var ability: Dictionary = data.ability.duplicate()
	ability["name"] = data.skill
	ability["cooldown"] = data.cooldown
	match ability.kind:
		"supply":
			ability["description"] = "按 L 立即恢复10能量，不超过上限；成功后冷却 %s 秒。满能量时无法使用，也不进入冷却；不重置 J/K 的动作或冷却。" % seconds(ability.cooldown)
		"focus":
			ability["description"] = "按 L 专注 %s 秒：J近战间隔、K冷却除以1.3（初始约0.385 / 0.615秒），近战仍须完成完整动作。结束后冷却 %s 秒；不清除已有冷却，闪避不打断专注。" % [seconds(ability.duration), seconds(ability.cooldown)]
		"counter":
			ability["description"] = "按住 L 举盾，最多 %s 秒；锁定起始朝向，移速减半，期间不能 J/K。只格挡正面120°内可格挡的直击，成功时不损失护盾；背后攻击和地面持续伤害仍会受伤。\n松开 L 或到时反击：前方120°、2.5米内，基础伤害2，每次格挡+1，最多5，不穿墙。前0.6秒成功格挡后，本次反击对非首领敌人附加 %s 秒控制。反击后冷却 %s 秒；闪避会取消举盾，不反击并进入冷却。" % [seconds(ability.duration), seconds(ability.control_duration), seconds(ability.cooldown)]
		"gravity":
			ability["description"] = "按 L 凝聚 %s 秒，在当前面向前方最远6米处放置半径2.5米、持续 %s 秒的法阵，受墙体阻挡。凝聚时可移动，不能 J/K；成功放置后冷却 %s 秒。\n第1、2、3秒各造成1点伤害，结束再造成2点；目标须在范围内且无遮挡，全程命中才合计5点基础伤害。普通和精英敌人减速30%%并向中心牵引：普通敌人0.6米/秒，精英减半；首领不受减速或牵引。闪避中断凝聚或放置失败时只冷却1秒；成功放置后闪避不取消法阵。" % [seconds(ability.duration), seconds(ability.field_duration), seconds(ability.cooldown)]
		_:
			ability["description"] = "剑击与法术小球构成基础战技，兼顾近远交锋；没有独立主动技能。"
	ability["description"] += "\n" + passive_description(id)
	ability["description"] += "\nL 不消耗能量；伤害为无符文加成的基础值。"
	return ability

static func passive_description(id: String) -> String:
	match id:
		"lan":
			return "整备射击：连续1.5秒未成功发动 J/K 后，获得一次 K 伤害+1（基础2→3），保留5秒，两次获取至少间隔6秒。成功释放 K 即消耗，未命中也消耗；J不消耗已就绪的强化，移动与闪避不打断整备。"
		"iron":
			return "稳固阵地：用 J近战在2.5米内击杀战斗房中的普通或精英敌人，回1护盾，每房最多实际回复2点，不超过上限。召唤物和首领不触发；满盾不消耗额度，重进房间不刷新；K或反击击杀不触发。"
		"astra":
			return "清房回能：每间战斗房（含首领房）首次完成时额外回5能量，不超过上限；满能量时不储存奖励。重进已清房间不重复回复；K仍消耗5能量。"
	return "无额外被动。"

static func cooldown_text(id: String) -> String:
	var timing := {"knight":"成功后", "lan":"专注结束后", "iron":"反击或取消后", "astra":"放置成功后"}
	return "L · %s冷却 %s 秒" % [timing.get(id, timing.knight), seconds(definition(id).cooldown)]

static func seconds(value: float) -> String:
	return str(value).trim_suffix(".0")

static func create_model(id: String) -> Node3D:
	var model := (load(definition(id).model) as PackedScene).instantiate() as Node3D
	var rig := model.get_node_or_null("Rig")
	if rig != null:
		rig.name = "Rig_Medium"
	# The older official free GLBs include optional weapons and their own clips.
	# Shared player animation libraries are the sole playback authority.
	for node in model.find_children("*", "AnimationPlayer", true, false):
		node.get_parent().remove_child(node)
		node.free()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if not node.name.begins_with("Mage_") and not node.name.begins_with("Rogue_") and not node.name.begins_with("Knight_") and not node.name.begins_with("Barbarian_"):
			node.hide()
	return model
