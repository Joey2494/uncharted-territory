extends Node
## One persistent, non-positional player survives scene reloads and pause screens.
signal context_changed(context: StringName)
signal track_started(source: AudioStream)

const BUSES = preload("res://scenes/audio/audio_buses.gd")
@export var playlist: Resource = preload("res://scenes/audio/default_music_playlist.tres")
@export_range(0.0, 2.0, 0.05) var fade_seconds: float = 0.35
@export_range(-24.0, 0.0, 0.5) var base_volume_db: float = -8.0
@export_range(-24.0, 0.0, 0.5) var gameplay_volume_db: float = -4.0
const AMBIENCE_DUCK_DB := -5.0
var current_context: StringName = &""
var _player: AudioStreamPlayer
var _source: AudioStream
var _requested: AudioStream
var _fade: Tween
var _fade_gain_db: float = 0.0:
	set(value):
		_fade_gain_db = value
		_apply_mix()
var _duck_gain_db := 0.0
var _duck_owners: Dictionary[int, WeakRef] = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	BUSES.ensure_music_bus()
	_player = AudioStreamPlayer.new()
	_player.name = "BackgroundMusic"
	_player.bus = BUSES.MUSIC
	_player.max_polyphony = 1
	add_child(_player)
	_player.finished.connect(_on_finished)
	_apply_mix()

func _process(delta: float) -> void:
	var duck := false
	for id in _duck_owners.keys():
		var owner: Node = _duck_owners[id].get_ref()
		if not is_instance_valid(owner) or not owner.is_inside_tree():
			_duck_owners.erase(id)
		elif owner.can_process():
			duck = true
	var target := AMBIENCE_DUCK_DB if duck else 0.0
	_duck_gain_db = move_toward(_duck_gain_db,target,(80.0 if target < _duck_gain_db else 12.0)*delta)
	_apply_mix()

func set_ambience_duck(owner: Node, enabled: bool) -> void:
	if not is_instance_valid(owner): return
	if enabled: _duck_owners[owner.get_instance_id()] = weakref(owner) as WeakRef
	else: _duck_owners.erase(owner.get_instance_id())

func _apply_mix() -> void:
	if is_instance_valid(_player):
		# Fade and ambience ducking own separate envelopes, never competing tweens.
		# Follow the sounding track so outgoing menu music keeps its gain during a fade.
		var gameplay := _same_track(_source,playlist.level_1) or _same_track(_source,playlist.level_2)
		var gain := gameplay_volume_db if gameplay else base_volume_db
		_player.volume_db = gain+_fade_gain_db+_duck_gain_db

func _exit_tree() -> void:
	stop_music()

func play_level(level_id: int) -> bool:
	return play_context(StringName("level_%d" % level_id))

func play_context(context: StringName) -> bool:
	var next: AudioStream = playlist.stream_for(context)
	if next == null:
		push_warning("No background music assigned for context: %s" % context)
		return false
	if current_context != context:
		current_context = context
		context_changed.emit(context)
	# Shared assignments and repeated requests must never restart the same track.
	if _same_track(next, _requested) and _player.playing:
		return true
	_requested = next
	_cancel_fade()
	if _same_track(next, _source) and _player.playing:
		_fade = create_tween()
		_fade.tween_property(self, "_fade_gain_db", 0.0, fade_seconds)
		return true
	_fade = create_tween()
	if _player.playing:
		_fade.tween_property(self, "_fade_gain_db", -60.0, fade_seconds)
		_fade.tween_callback(_start_track.bind(next))
	else:
		_start_track(next)
	_fade.tween_property(self, "_fade_gain_db", 0.0, fade_seconds)
	return true

func stop_music() -> void:
	_cancel_fade()
	_requested = null
	_source = null
	current_context = &""
	_player.stop()
	_player.stream = null
	_fade_gain_db = 0.0

func _start_track(source: AudioStream) -> void:
	# A rapid scene transition can supersede an earlier fade-out request.
	if not _same_track(source, _requested): return
	var stream := source.duplicate() as AudioStream
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	_player.stop()
	_source = source
	_player.stream = stream
	_fade_gain_db = -60.0
	_player.play()
	track_started.emit(source)

func _on_finished() -> void:
	# Fallback for non-loopable AudioStream resources; standard MP3/OGG/WAV loop natively.
	if _requested != null and _same_track(_source, _requested):
		_player.play()

func _cancel_fade() -> void:
	if _fade != null and _fade.is_valid(): _fade.kill()
	_fade = null

func _same_track(first: AudioStream, second: AudioStream) -> bool:
	if first == null or second == null: return false
	return first == second or (not first.resource_path.is_empty() and first.resource_path == second.resource_path)
