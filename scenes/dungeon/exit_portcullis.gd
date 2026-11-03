@tool
extends Node3D
## No separate animation or state: the original parent receives the gate tween.

const Visuals = preload("res://scenes/dungeon/almsyone_visuals.gd")
const GATE: PackedScene = preload("res://assets/dungeon/almsyone/SM_Portcullis.glb")

var _visuals: RefCounted


func _ready() -> void:
	_visuals = Visuals.new()
	_visuals.add_model(self, GATE, "Model", Transform3D.IDENTITY)
