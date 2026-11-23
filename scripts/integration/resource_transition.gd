extends RefCounted
const CACHE = preload("res://scripts/rendering/static_art_cache.gd")
const SCREEN = preload("res://scenes/ui/loading_screen.gd")
static var last_metrics := {}

static func change(tree: SceneTree, destination: String) -> Error:
	var started := Time.get_ticks_msec()
	var screen := SCREEN.new()
	screen.name = "LoadingScreen"
	tree.root.add_child(screen)
	last_metrics = {"destination":destination,"screen_setup_ms":Time.get_ticks_msec()-started}
	# Submit only after the first loading frame has had an opportunity to render.
	await screen.present()
	var resource_started := Time.get_ticks_msec()
	var error := ResourceLoader.load_threaded_request(destination,"PackedScene",false)
	if error != OK:
		screen.queue_free()
		return error
	# Optional art is genuine resource work. Missing bundles retain the procedural path.
	var cache_path := CACHE.optional_path(destination)
	var cache_requested := not cache_path.is_empty() and ResourceLoader.load_threaded_request(cache_path) == OK
	var progress: Array = []
	while true:
		var state := ResourceLoader.load_threaded_get_status(destination,progress)
		var cache_progress: Array = []
		var cache_state := ResourceLoader.load_threaded_get_status(cache_path,cache_progress) if cache_requested else ResourceLoader.THREAD_LOAD_LOADED
		var cache_done := cache_state != ResourceLoader.THREAD_LOAD_IN_PROGRESS
		if not progress.is_empty():
			var work := float(progress[0])
			if cache_requested: work = (work+(1.0 if cache_done else (float(cache_progress[0]) if not cache_progress.is_empty() else 0.0)))*0.5
			screen.set_progress(work)
		if state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			if state == ResourceLoader.THREAD_LOAD_FAILED: ResourceLoader.load_threaded_get(destination)
			if cache_requested: ResourceLoader.load_threaded_get(cache_path)
			screen.queue_free()
			return ERR_CANT_OPEN
		if state == ResourceLoader.THREAD_LOAD_LOADED and cache_done: break
		await tree.process_frame
	if cache_requested:
		var library := ResourceLoader.load_threaded_get(cache_path) as Resource
		# Remember a failed optional request too, so the provider does not retry it synchronously.
		CACHE.prepared[CACHE.family_for_scene(destination)] = library
	var scene := ResourceLoader.load_threaded_get(destination) as PackedScene
	last_metrics.resource_ms = Time.get_ticks_msec()-resource_started
	if scene == null:
		CACHE.prepared.erase(CACHE.family_for_scene(destination))
		screen.queue_free()
		return ERR_CANT_CREATE
	screen.set_progress(1)
	# A real resource-complete frame reaches the display before blocking scene work.
	await screen.present()
	last_metrics.complete_frame_presented = 1.0 in screen.presented_ratios
	tree.paused = false
	var instantiation_started := Time.get_ticks_msec()
	error = tree.change_scene_to_packed(scene)
	last_metrics.instantiate_ms = Time.get_ticks_msec()-instantiation_started
	if error == OK:
		var metrics: Dictionary = last_metrics
		tree.scene_changed.connect(func() -> void:
			metrics.scene_ready_ms = Time.get_ticks_msec()-instantiation_started
			screen.finish(),CONNECT_ONE_SHOT)
	else:
		CACHE.prepared.erase(CACHE.family_for_scene(destination))
		screen.queue_free()
	return error
