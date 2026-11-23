extends RefCounted
## 第四关敌人工厂：按稳定 ID 创建实例，显式传入玩家目标。
const SCENES := {
	"witch": preload("Witch.tscn"),
	"spore_guard": preload("SporeGuard.tscn"),
	"dawn_shade": preload("DawnShade.tscn"),
	"sun_puppet": preload("SunPuppet.tscn"),
	"iron_thistle": preload("IronThistle.tscn"),
	"raven_roost": preload("RavenRoost.tscn"),
}
static func create(id: String, target: Node3D = null) -> CharacterBody3D:
	if not SCENES.has(id): return null
	var enemy: CharacterBody3D = SCENES[id].instantiate()
	if target != null: enemy.bind_target(target)
	return enemy
