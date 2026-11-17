extends Node3D
## Adapter for the combat API. Meshes and materials are stored in independent model scenes.
const MODELS := {
	"bone_axe":preload("models/BoneAxeModel.tscn"),
	"bone_spike":preload("models/BoneSpikeModel.tscn"),
	"tomb_sword":preload("models/TombSwordModel.tscn"),
	"chain_jailer":preload("models/ChainJailerModel.tscn"),
	"sand_king":preload("models/SandKingModel.tscn")}
var _model: Node3D
func build(id: String, _tint: Color) -> void:
	_model=get_node_or_null("Model")
	if _model!=null: return
	if not MODELS.has(id): return
	_model=MODELS[id].instantiate()
	_model.name="Model"
	add_child(_model)
func pose(state: int, progress: float, moving: float, delta: float, strike := 0) -> void:
	if is_instance_valid(_model): _model.pose(state,progress,moving,delta,strike)
