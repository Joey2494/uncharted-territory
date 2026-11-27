extends RefCounted
## Species IDs are stable across rooms, saves and visual-only previews.
const THIRD = preload("res://addons/ziyuan_level03/catalog.gd")
const FOURTH = preload("res://addons/ziyuan_level04/room_catalog.gd")
const WITCH = preload("res://addons/ziyuan_level04/catalog.gd")
const IDS: Array[String] = ["ruin_guard", "gatekeeper", "silk_spider", "brood_spider", "broodling", "scorpion", "bone_axe", "bone_spike", "tomb_sword", "chain_jailer", "sand_king", "dawn_shade", "sun_puppet", "iron_thistle", "raven_roost", "witch", "spore_guard"]
const ENTRIES := {
	"ruin_guard": {"name":"骸骨巡守", "level":1, "role":"近战守卫", "lore":"旧巡逻路线早已被尘土掩埋，持剑的骸骨却仍在回廊中往返。它记得职责，已经忘记了王国。", "skills":"追击斩击：靠近后起剑，向面前挥出一击。", "tips":"观察起剑动作，向侧面闪避；等挥剑结束再反击。", "model":"res://assets/characters/kaykit/skeletons/Skeleton_Warrior.glb", "scale":0.618},
	"gatekeeper": {"name":"遗迹守门者", "level":1, "role":"首领 · 重装近战", "lore":"青铜甲胄下的守门者从未得到撤退的命令。它用最后的力量，守着一扇早已无人问津的门。", "skills":"近身重斩；蓄力冲锋：锁定前方后快速突进。", "tips":"与冲锋方向错开，利用收招近身；贴身时留意重斩。", "model":"res://assets/characters/kaykit/BronzeGatekeeper.tscn", "scale":1.168},
	"silk_spider": {"name":"丝蛛", "level":2, "role":"远程牵制", "lore":"洞穴的蛛网牵着每一道气流。丝蛛伏在断裂的石刻旁，等待闯入者走进它精心编织的距离。", "skills":"蛛丝射击：蓄力后喷出蛛丝，命中使目标短暂减速。", "tips":"借石柱阻挡蛛丝，侧移避开射线，再切入收招。", "model":"res://scenes/enemies/CryptSpiderModel.tscn"},
	"brood_spider": {"name":"母蛛", "level":2, "role":"召唤压制", "lore":"母蛛把遗迹变成了孵化巢。只要它仍能呼唤，石缝里的幼蛛就会不断涌出。", "skills":"孵化召唤：蓄力后放出一批幼蛛。", "tips":"优先压制母蛛，边移动边清理幼蛛，避免被两面夹击。", "model":"res://scenes/enemies/VenomSpiderModel.tscn"},
	"broodling": {"name":"幼蛛", "level":2, "role":"召唤物 · 接触即消耗", "lore":"刚破壳的幼蛛循着母蛛的振动奔来。它还没有坚硬的甲壳，却已经懂得如何追逐温热的足迹。", "skills":"追踪扑咬：接触目标后攻击一次并消失；撞到障碍也会消失。", "tips":"保持移动，借障碍物截断追踪；别在蛛群中停留。"},
	"scorpion": {"name":"灾厄巨蝎", "level":2, "role":"首领 · 尾击与毒刺", "lore":"矿道深处的巨蝎以碎石为巢，尾钩上凝着遗迹残留的毒光。它转身时，整座石厅都能听见甲壳摩擦。", "skills":"尾部重击；毒刺齐射；近身连续甩尾。", "tips":"远处借掩体躲毒刺，近处留意抬尾；连续攻击结束后再靠近。", "model":"res://scenes/bosses/DreadScorpionModel.tscn"},
	"bone_axe": {"name":"骨斧斥候", "level":3, "role":"近战压迫", "lore":"斥候沿低潮露出的石路巡行，骨斧一次次划过同一条磨痕。潮水带走了名字，没能带走它的杀意。", "skills":"骨斧横劈：追近目标后蓄力挥斧。", "tips":"侧移避开斧面，抓住收招反击。", "model":"res://addons/ziyuan_level03/models/BoneAxeModel.tscn"},
	"bone_spike": {"name":"枯筋腐尸", "level":3, "role":"远程封路", "lore":"潮气让腐尸的筋骨绷得更紧。它在水线后徘徊，用腐质弹赶走每一个靠近工坊的人。", "skills":"腐质弹：保持距离并发射弹丸，也会横移或后撤。", "tips":"利用墙柱接近，等一轮射击结束再追击。", "model":"res://addons/ziyuan_level03/models/BoneSpikeModel.tscn"},
	"tomb_sword": {"name":"长剑墓卫", "level":3, "role":"直线突刺", "lore":"墓卫的剑刃比它的记忆更完整。它把蓄能工房当成墓室，将每个闯入者都视作盗墓人。", "skills":"长剑突刺：蓄势后沿直线出剑。", "tips":"横向错开突刺；引它撞上障碍，在收招破绽中进攻。", "model":"res://addons/ziyuan_level03/models/TombSwordModel.tscn"},
	"chain_jailer": {"name":"双链执刑官", "level":3, "role":"精英 · 环形扫场", "lore":"维修井里回荡着锁链拖过地面的声音。执刑官已分不清囚徒与访客，只剩下挥链的本能。", "skills":"双链扫击：连续正反挥动锁链，覆盖周围空间。", "tips":"不要在链鞭外圈久留，找准连击间隙穿入或后撤。", "model":"res://addons/ziyuan_level03/models/ChainJailerModel.tscn"},
	"sand_king": {"name":"沙缚王", "level":3, "role":"首领 · 三式沙咒", "lore":"沙缚王坐镇最后一道闸庭。每一次潮汐回流，都在它的裹尸布上留下一层新的细沙。", "skills":"飞行沙咒、近身重踏与咒术连攻；半血后节奏加快。", "tips":"保持侧向移动躲沙咒，贴身时预留闪避；低血阶段更要耐心等待收招。", "model":"res://addons/ziyuan_level03/models/SandKingModel.tscn"},
	"dawn_shade": {"name":"曦影", "level":4, "role":"虚影 · 分身迷惑", "lore":"清晨的薄光在旧观测窗里凝成模糊的人影。没有实体的它，仿佛还在重复某次未完成的值班。", "skills":"镜像迷惑：受击分出假身；晨光致盲：短暂扰乱视野。", "tips":"辨认真身，击散假身后集中攻击；视线受扰时继续移动。"},
	"sun_puppet": {"name":"赤阳傀儡", "level":4, "role":"热浪压迫", "lore":"烈阳把木傀儡的纹路烧成金红色。头顶那团摇晃的日斑，是观测站正午时刻遗留的余温。", "skills":"热浪冲击：蓄力后向周围释放扩散的热浪。", "tips":"观察木躯蓄力，留出距离；侧移或闪避穿过波前。"},
	"iron_thistle": {"name":"白芒尖蓟", "level":4, "role":"扎根阻挡", "lore":"尖蓟在暴晒中疯长，铁一般的茎秆拦住了栈道。刺尖反射白光，像一排永不熄灭的警戒灯。", "skills":"飞刺弹幕；近身刺丛爆发。", "tips":"借掩体挡飞刺，绕开正面；近身时注意刺丛，分段进攻。"},
	"raven_roost": {"name":"群鸦归巢", "level":4, "role":"群体 · 分散偷袭", "lore":"暮色落在空巢上，归鸦却迟迟不肯安静。它们散成黑影，又在同一声啼鸣里聚成一支箭。", "skills":"四散偷袭与聚拢冲击交替进行，整群共用生命。", "tips":"留意聚拢方向，别被夹在鸦群中心；击中任意乌鸦都可削减共享生命。"},
	"witch": {"name":"袍冠女巫", "level":4, "role":"首领 · 孢子咒术", "lore":"黑袍压住银发，金饰映着穹顶中最后一束光。她从观测记录之外归来，肩上的乌鸦记得每一个访客。", "skills":"孢弹与毒池、三点孢弹、召唤孢子守卫、藤蔓横扫；半血后进入二阶段。", "tips":"连续移动躲孢弹，尽快离开毒池；处理守卫后抓住施法收招，利用障碍躲藤蔓。"},
	"spore_guard": {"name":"孢子守卫", "level":4, "role":"召唤物 · 近身扑咬", "lore":"女巫的孢子在地面结成短命的守卫。它们循着召唤者的意志行动，消散后只留下一阵干燥的尘息。", "skills":"近身扑咬：短暂蓄力后扑向目标。", "tips":"侧移避开扑击，在扑空后的停顿清理；召唤物不掉落金币。"},
}
const ALIASES := {"res://scenes/enemies/MeleeEnemy.gd":"ruin_guard", "res://scenes/bosses/RuinGatekeeper.gd":"gatekeeper", "res://scenes/bosses/ruin_colossus.gd":"scorpion"}

static func identify(actor: Node) -> String:
	if not is_instance_valid(actor): return ""
	var script: Script = actor.get_script()
	while script != null:
		var path := script.resource_path
		if path == "res://scenes/enemies/spider_combat.gd": return "silk_spider" if actor.attack_kind == 0 else "brood_spider"
		if path == "res://scenes/skills/creature_projectile.gd": return "broodling" if actor.kind == 1 else ""
		if path in ["res://addons/ziyuan_level03/enemy.gd", "res://addons/ziyuan_level04/room_enemy.gd", "res://addons/ziyuan_level04/witch.gd", "res://addons/ziyuan_level04/spore_guard.gd"]:
			return actor.enemy_id if actor.enemy_id in IDS else ""
		if ALIASES.has(path): return ALIASES[path]
		script = script.get_base_script()
	return ""

static func entry(id: String) -> Dictionary:
	if not ENTRIES.has(id): return {}
	var data: Dictionary = ENTRIES[id].duplicate(true)
	data.id = id
	data.stats = stats(id)
	return data

static func stats(id: String) -> Dictionary:
	var source: Dictionary = {}
	if THIRD.ENEMIES.has(id): source = THIRD.definition(id)
	elif FOURTH.ENEMIES.has(id): source = FOURTH.definition(id)
	elif WITCH.ENEMIES.has(id): source = WITCH.definition(id)
	if not source.is_empty(): return {"hp":source.hp, "damage":source.damage, "speed":source.speed}
	return {"ruin_guard":{"hp":3,"damage":1,"speed":2.4}, "gatekeeper":{"hp":24,"damage":2,"speed":1.8}, "silk_spider":{"hp":4,"damage":1,"speed":3.4}, "brood_spider":{"hp":5,"damage":1,"speed":1.8}, "broodling":{"hp":0,"damage":1,"speed":2.6}, "scorpion":{"hp":36,"damage":2,"speed":3.2}}.get(id, {})

static func create_model(id: String) -> Node3D:
	var data := entry(id)
	if data.is_empty(): return null
	var model: Node3D
	if data.has("model"):
		var rig: Node3D = (load(data.model) as PackedScene).instantiate()
		if id in ["ruin_guard", "gatekeeper"]:
			model = Node3D.new()
			rig.name = "Rig"
			model.add_child(rig)
			var animator := AnimationPlayer.new()
			animator.root_node = NodePath("../Rig")
			var library: AnimationLibrary = load("res://assets/characters/kaykit/skeletons/animations/warrior.tres" if id == "ruin_guard" else "res://assets/characters/kaykit/animations/locomotion.tres")
			animator.add_animation_library("idle", library)
			animator.autoplay = "idle/Idle_A"
			model.add_child(animator)
		else: model = rig
		model.scale *= float(data.get("scale", 1.0))
	elif id == "broodling": model = load("res://scenes/enemies/broodling_visual.gd").new()
	elif id == "witch": model = load("res://addons/ziyuan_level04/witch_model.gd").new()
	elif id == "spore_guard":
		model = load("res://addons/ziyuan_level04/visual.gd").new()
		model.build(id, Color.WHITE)
	else:
		model = load("res://addons/ziyuan_level04/room_visual.gd").new()
		model.enemy_id = id
	return model
