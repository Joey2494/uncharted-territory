extends RefCounted
## First-level prototypes, scaled to 3 HP enemies and the 24 HP gatekeeper.

const IDS: Array[String] = ["knight", "lan", "iron", "astra"]
static var selected_id: String = "knight"
static var start_pending: bool = false
const DATA := {
	"knight": {"name": "Knight · 初始旅人", "attack": 1, "hp": 5, "shield": 0, "energy": 50.0, "walk": 5.0, "run": 8.0,
		"model": "res://assets/characters/kaykit/Knight.glb", "skill": "无独特技能", "cooldown": 0.0,
		"ability": {"kind":"none", "active":false, "duration":0.0, "icon":preload("res://assets/ui/weapon_equipped.svg")},
		"description": "原有初始人物 · 免费可用 · 5生命 / 50能量\n保留原有近战、法术小球和四方向闪避。"},
	"lan": {"name": "Lan · 游侠", "attack": 1, "hp": 5, "shield": 1, "energy": 50.0, "walk": 5.0, "run": 8.0,
		"model": "res://assets/characters/kaykit/Rogue.glb", "skill": "专注射击", "cooldown": 10.0,
		"ability": {"kind":"focus", "active":true, "duration":4.0, "icon":preload("res://assets/ui/skill_focus.svg")},
		"description": "灵活输出 · 5生命 / 1护盾 / 50能量\nL 专注4秒：J/K攻击间隔缩短，闪避可保留专注。"},
	"iron": {"name": "Iron · 守卫", "attack": 1, "hp": 6, "shield": 2, "energy": 40.0, "walk": 4.6, "run": 7.4,
		"model": "res://assets/characters/kaykit/IronGuard.tscn", "skill": "举盾反击", "cooldown": 10.0,
		"ability": {"kind":"counter", "active":true, "duration":1.2, "control_duration":0.5, "icon":preload("res://assets/ui/skill_counter.svg")},
		"description": "正面防守 · 6生命 / 2护盾 / 40能量\n按住L举盾，松开反击；闪避取消。背后攻击仍会受伤。"},
	"astra": {"name": "Astra · 术士", "attack": 1, "hp": 4, "shield": 1, "energy": 60.0, "walk": 5.0, "run": 8.0,
		"model": "res://assets/characters/kaykit/Mage.glb", "skill": "引力印记", "cooldown": 14.0,
		"ability": {"kind":"gravity", "active":true, "duration":0.25, "field_duration":3.0, "icon":preload("res://assets/ui/skill_gravity.svg")},
		"description": "范围控制 · 4生命 / 1护盾 / 60能量\nL 在前方放置法阵：持续伤害、减速和牵引，结束时爆发。"}
}

static func definition(id: String) -> Dictionary:
	return DATA.get(id, DATA["knight"])

static func ability_definition(id: String) -> Dictionary:
	var data := definition(id)
	var ability: Dictionary = data.ability.duplicate()
	ability["name"] = data.skill
	ability["cooldown"] = data.cooldown
	match ability.kind:
		"focus":
			ability["description"] = "专注持续 %s 秒，缩短近战攻击与法术的攻击间隔，近战仍需完成完整动作；闪避不打断专注，效果结束后开始冷却。" % seconds(ability.duration)
		"counter":
			ability["description"] = "举盾至多 %s 秒，抵御正面直击；松开或举盾结束时反击，格挡越多伤害越高，精准格挡附带 %s 秒控制。闪避会取消举盾。" % [seconds(ability.duration),seconds(ability.control_duration)]
		"gravity":
			ability["description"] = "短暂凝聚后，在前方形成持续 %s 秒的引力法阵，周期性造成伤害并减速、牵引敌人，消散时再次爆发；释放后开始冷却，闪避可中断凝聚。" % seconds(ability.field_duration)
		_:
			ability["description"] = "剑击与法术小球构成基础战技，兼顾近远交锋；没有独立主动技能。"
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
