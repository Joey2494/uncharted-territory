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
		"description": "灵活输出 · 5生命 / 1护盾 / 50能量\n停火1.5秒整备战术武器伤害+1（保留5秒，获取间隔6秒）。L 专注4秒，结束后冷却10秒。"},
	"iron": {"name": "Iron · 守卫", "attack": 1, "hp": 6, "shield": 2, "energy": 40.0, "walk": 4.6, "run": 7.4,
		"model": "res://assets/characters/kaykit/IronGuard.tscn", "skill": "举盾反击", "cooldown": 8.0,
		"ability": {"kind":"counter", "active":true, "duration":1.2, "control_duration":0.5, "icon":preload("res://assets/ui/skill_counter.svg")},
		"description": "正面防守 · 6生命 / 2护盾 / 40能量\nJ近距击杀回1盾，每战斗房最多2盾。L举盾反击，前0.6秒精准格挡，冷却8秒。"},
	"astra": {"name": "Astra · 术士", "attack": 1, "hp": 4, "shield": 1, "energy": 60.0, "walk": 5.0, "run": 8.0,
		"model": "res://assets/characters/kaykit/Mage.glb", "skill": "引力印记", "cooldown": 14.0,
		"ability": {"kind":"gravity", "active":true, "duration":0.25, "field_duration":3.0, "icon":preload("res://assets/ui/skill_gravity.svg")},
		"description": "范围控制 · 4生命 / 1护盾 / 60能量\n引火法杖基础耗蓝5，被动后消耗4，清战斗房额外回5能量。L引力法阵：1+1+1+2伤害，冷却14秒。"}
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
			ability["description"] = "按 L 立即恢复 10 点法力，最多恢复至角色法力上限。成功使用后冷却 %s 秒；满蓝时不消耗冷却。技能消耗 0 蓝，不重置武器动作、攻击间隔或弹匣。" % seconds(ability.cooldown)
			ability["passive_description"] = "均衡配装：近战短剑零消耗，符文短杖每发 5 蓝；可先射击消耗法力，再用 L 补给。"
		"focus":
			ability["description"] = "按 L 专注 %s 秒，当前武器攻击间隔 ÷ 1.3：手枪 0.50 → 0.38 秒，卡宾枪 0.80 → 0.62 秒。弹匣容量、换弹时间与每发弹药消耗不变。技能消耗 0 蓝；专注结束后开始 %s 秒冷却，闪避不取消专注。" % [seconds(ability.duration),seconds(ability.cooldown)]
			ability["passive_description"] = "整备射击：停火 1.5 秒获得一次强化，保留 5 秒，两次获得至少间隔 6 秒。下一发线圈卡宾枪基础伤害 2 → 3，成功发射即消耗；手枪不消耗已获得的强化。"
		"counter":
			ability["description"] = "按住 L 最多举盾 %s 秒，格挡正面 120° 的直接攻击；举盾时移速减半，不能按 J 攻击。松开或时限结束时反击正面 120°、半径 2.5 米：基础伤害 2 + 格挡次数，上限 5。前 0.6 秒内成功格挡为精准格挡，使本次反击附带 %s 秒控制。结束后冷却 %s 秒，消耗 0 蓝；闪避会取消举盾，不触发反击。" % [seconds(ability.duration),seconds(ability.control_duration),seconds(ability.cooldown)]
			ability["passive_description"] = "稳固阵地：用短剑在 2.5 米内击杀普通、非召唤敌人恢复 1 护盾，每个战斗房最多恢复 2 护盾，不超过护盾上限。"
		"gravity":
			ability["description"] = "按 L 凝聚 %s 秒，在前方最多 6 米放置半径 2.5 米、持续 %s 秒的法阵。第 1 / 2 / 3 秒各造成 1 点基础伤害，结束再造成 2 点，共 5 点。普通敌人减速 30%%，以 0.6 米/秒向中心牵引；精英牵引速度 0.3 米/秒，Boss 不受减速与牵引。生成后冷却 %s 秒，消耗 0 蓝；凝聚中闪避取消或放置失败时冷却 1 秒。" % [seconds(ability.duration),seconds(ability.field_duration),seconds(ability.cooldown)]
			ability["passive_description"] = "余烬亲和：引火法杖耗蓝降低 20%（5 → 4）；每个战斗房清理完成后额外恢复 5 点法力。"
		_:
			ability["description"] = "无独立主动技能。"
			ability["passive_description"] = ""

	return ability

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
