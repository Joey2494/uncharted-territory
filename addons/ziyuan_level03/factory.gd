extends RefCounted
const SCENES := {"bone_axe":preload("BoneAxe.tscn"),"bone_spike":preload("BoneSpike.tscn"),"tomb_sword":preload("TombSword.tscn"),"chain_jailer":preload("ChainJailer.tscn"),"sand_king":preload("SandKing.tscn")}
static func create(id: String, target: Node3D=null) -> CharacterBody3D:
	if not SCENES.has(id): return null
	var enemy: CharacterBody3D=SCENES[id].instantiate()
	if target!=null: enemy.bind_target(target)
	return enemy
