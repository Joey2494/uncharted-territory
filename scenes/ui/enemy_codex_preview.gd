extends Node3D
## Model-only stage: no enemy AI, collision, projectiles or rewards are instantiated.
const Catalog = preload("res://data/enemy_codex.gd")
var avatar: Node3D
var camera: Camera3D
var _clock := 0.0
var _yaw := 0.0
var _extent := 3.0
var _center := Vector3(0, 1, 0)
var _base_yaw := 0.2
var _pedestal: MeshInstance3D
var _zoom := 1.0

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("080d14")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c6d0df")
	settings.ambient_light_energy = 0.55
	environment.environment = settings
	add_child(environment)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	camera.current = true
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -30, 0)
	key.light_color = Color("ffe0ab")
	key.light_energy = 1.2
	add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2, 3, -3)
	rim.light_color = Color("8bbde1")
	rim.light_energy = 1.8
	rim.omni_range = 15
	add_child(rim)
	var pedestal := MeshInstance3D.new()
	_pedestal = pedestal
	var mesh := CylinderMesh.new()
	mesh.top_radius = 2.0
	mesh.bottom_radius = 2.1
	mesh.height = 0.16
	pedestal.mesh = mesh
	pedestal.position.y = -0.12
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("171c23")
	material.roughness = 0.8
	pedestal.material_override = material
	add_child(pedestal)
	get_viewport().size_changed.connect(_frame)

func show_enemy(id: String, known: bool) -> void:
	if is_instance_valid(avatar):
		remove_child(avatar)
		avatar.free()
	_clock = 0
	_yaw = 0
	_zoom = 1.0
	_base_yaw = 0.2 if id in ["ruin_guard", "gatekeeper"] or not known else PI + 0.2
	if known:
		avatar = Catalog.create_model(id)
	else:
		avatar = Node3D.new()
		var silhouette := MeshInstance3D.new()
		var shape := CapsuleMesh.new()
		shape.radius = 0.32
		shape.height = 1.55
		silhouette.mesh = shape
		silhouette.position.y = 0.8
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("202731")
		silhouette.material_override = material
		avatar.add_child(silhouette)
	if avatar == null: return
	add_child(avatar)
	avatar.rotation.y = _base_yaw
	_fit_model.call_deferred()

func _fit_model() -> void:
	if not is_instance_valid(avatar): return
	var bounds := AABB()
	var found := false
	for view: Node in avatar.find_children("*", "MeshInstance3D", true, false):
		if not view.visible: continue
		var box: AABB = (global_transform.affine_inverse() * view.global_transform) * view.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	if not found: bounds = AABB(Vector3(-1, 0, -1), Vector3(2, 3, 2))
	_center = bounds.get_center()
	_extent = maxf(1.6, maxf(bounds.size.y * 1.22, maxf(bounds.size.x, bounds.size.z) * 1.16))
	_pedestal.scale = Vector3.ONE * clampf(_extent * 0.17, 0.35, 0.85)
	_frame()

func _frame() -> void:
	if camera == null: return
	var dimensions := get_viewport().get_visible_rect().size
	var aspect := dimensions.x / maxf(1, dimensions.y)
	camera.size = _extent * _zoom * maxf(1.0, 1.0 / maxf(0.25, aspect))
	camera.position = _center + Vector3(3.2, 1.7, 6.0) * maxf(1.0, _extent / 3.0)
	camera.look_at(_center, Vector3.UP)

func rotate_model(amount: float) -> void:
	_yaw += amount

func zoom_model(factor: float) -> void:
	_zoom = clampf(_zoom * factor, 0.5, 1.8)
	_frame()

func _process(delta: float) -> void:
	if not is_instance_valid(avatar): return
	_clock += delta
	avatar.rotation.y = _base_yaw + _yaw + sin(_clock * 0.35) * 0.12
	if avatar.has_method("pose"): avatar.pose(0, 0.0, 0.1, delta)
