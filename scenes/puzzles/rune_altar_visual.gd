@tool
extends Node3D
## Visual follower only: the original RuneSwitch remains the sole interaction.

const Visuals = preload("res://scenes/dungeon/almsyone_visuals.gd")
const ALTAR: PackedScene = preload("res://assets/dungeon/almsyone/SM_Altar.glb")

var _visuals: RefCounted
var _crystals: Array[BaseMaterial3D] = []


func _ready() -> void:
	_visuals = Visuals.new()
	var model: Node3D = _visuals.add_model(self, ALTAR, "Model", Transform3D.IDENTITY)
	for mesh in model.get_children():
		var material: BaseMaterial3D = mesh.mesh.surface_get_material(0)
		if material.resource_name == "M_CrystalPurple": _crystals.append(material)
	set_process(not Engine.is_editor_hint())
	# RuneSwitch binds its state material after its children become ready,
	# including while the start menu has disabled world processing.
	get_parent().ready.connect(_sync_state, CONNECT_ONE_SHOT)
	_sync_state()


func _process(_delta: float) -> void:
	_sync_state()


func _sync_state() -> void:
	var rune := get_parent().get_node_or_null("RuneMesh") as MeshInstance3D
	if rune == null: return
	var source := rune.get_active_material(0) as BaseMaterial3D
	if source == null: return
	for material in _crystals:
		# Follow existing correct/error/reset feedback without activating a rune
		# or maintaining any separate progress, sequence, timer or door state.
		if material.albedo_color != source.albedo_color:
			material.albedo_color = source.albedo_color
		if material.emission != source.emission:
			material.emission = source.emission
		if not is_equal_approx(material.emission_energy_multiplier, source.emission_energy_multiplier):
			material.emission_energy_multiplier = source.emission_energy_multiplier
