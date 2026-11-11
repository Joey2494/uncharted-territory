extends Node3D
## Human guard adapted from the former first-level Boss: sword, armor and round shield.
var _skeleton: Skeleton3D

func _ready() -> void:
 _skeleton = get_node("Rig_Medium/Skeleton3D")
 var steel := _material(Color("355565"), 0.55)
 var bronze := _material(Color("a58b54"), 0.5)
 var ivory := _material(Color("d8c8a4"), 0.1)
 var chest := CylinderMesh.new()
 chest.top_radius = 0.36
 chest.bottom_radius = 0.30
 chest.height = 0.43
 chest.radial_segments = 8
 var plate := _piece("chest", "Breastplate", chest, Vector3(0, 1.0, 0.06), steel)
 plate.scale.z = 0.75
 for side in ["l", "r"]:
  var shoulder := SphereMesh.new()
  shoulder.radius = 0.19
  shoulder.height = 0.27
  shoulder.radial_segments = 8
  shoulder.rings = 4
  var joint := _skeleton.get_bone_global_rest(_skeleton.find_bone("upperarm." + side)).origin
  _piece("upperarm." + side, "Pauldron_" + side, shoulder, joint, steel)
 var badge := BoxMesh.new()
 badge.size = Vector3(0.12, 0.20, 0.045)
 _piece("chest", "GuardBadge", badge, Vector3(0, 0.99, 0.34), ivory)
 var hand := BoneAttachment3D.new()
 hand.name = "IronRoundShield"
 hand.bone_name = "handslot.l"
 _skeleton.add_child(hand)
 _disc(hand, "ShieldRim", 0.40, 0.09, 0.18, bronze)
 _disc(hand, "ShieldFace", 0.34, 0.12, 0.20, steel)
 _disc(hand, "ShieldBoss", 0.10, 0.16, 0.23, bronze)

func _material(color: Color, metallic: float) -> StandardMaterial3D:
 var material := StandardMaterial3D.new()
 material.albedo_color = color
 material.metallic = metallic
 material.roughness = 0.8
 return material

func _piece(bone: String, label: String, mesh: Mesh, center: Vector3, material: Material) -> MeshInstance3D:
 var socket := BoneAttachment3D.new()
 socket.name = label + "Socket"
 socket.bone_name = bone
 _skeleton.add_child(socket)
 var visual := MeshInstance3D.new()
 visual.name = label
 visual.mesh = mesh
 visual.material_override = material
 visual.transform = _skeleton.get_bone_global_rest(_skeleton.find_bone(bone)).affine_inverse() * Transform3D(Basis.IDENTITY, center)
 socket.add_child(visual)
 return visual

func _disc(parent: Node3D, label: String, radius: float, thickness: float, depth: float, material: Material) -> void:
 var visual := MeshInstance3D.new()
 visual.name = label
 var disc := CylinderMesh.new()
 disc.top_radius = radius
 disc.bottom_radius = radius
 disc.height = thickness
 disc.radial_segments = 12
 visual.mesh = disc
 visual.material_override = material
 visual.position.y = depth
 parent.add_child(visual)
