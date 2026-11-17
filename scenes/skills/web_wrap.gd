extends Node3D
## Recognizable radial/spiral orb web growing over the torso, plus wrapping silk rings.
const FX = preload("res://scenes/enemies/creature_fx.gd")
var _age := 0.0
func _ready() -> void:
	var silk := Color(0.88, 0.96, 1.0, 0.90)
	# Two intersecting vertical orb webs remain readable as the camera turns.
	for plane in 2:
		var face := Node3D.new()
		face.rotation.y = plane * PI * 0.5
		add_child(face)
		for spoke in 12:
			var a := spoke * TAU / 12
			FX.strand(face, Vector3(0, 0.74, 0), Vector3(cos(a) * 0.65, 0.74 + sin(a) * 0.72, 0), silk, 0.010)
		for ring in range(1, 5):
			for spoke in 12:
				var a := spoke * TAU / 12
				var b := (spoke + 1) * TAU / 12
				var r := ring / 4.0
				FX.strand(face, Vector3(cos(a) * 0.65 * r, 0.74 + sin(a) * 0.72 * r, 0), Vector3(cos(b) * 0.65 * r, 0.74 + sin(b) * 0.72 * r, 0), silk, 0.009)
	for ring in 4:
		for i in 12:
			var a := i * TAU / 12
			var b := (i + 1) * TAU / 12
			FX.strand(self, Vector3(cos(a) * 0.46, 0.25 + ring * 0.28, sin(a) * 0.36), Vector3(cos(b) * 0.46, 0.25 + ring * 0.28, sin(b) * 0.36), silk, 0.011)
	form()
func form() -> void:
	_age = 0
	show()
	scale = Vector3.ONE * 0.08
func _process(delta: float) -> void:
	_age += delta
	var growth := minf(1, _age / 0.23)
	scale = Vector3.ONE * lerpf(0.08, 1.0, 1.0 - pow(1.0 - growth, 3))
