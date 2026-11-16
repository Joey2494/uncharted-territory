extends Resource
## Scene-specific assignments, editable together in the Inspector.
@export var menu: AudioStream
@export var level_1: AudioStream
@export var level_2: AudioStream
@export var victory: AudioStream

func stream_for(context: StringName) -> AudioStream:
	match context:
		&"menu": return menu
		&"level_1": return level_1
		&"level_2": return level_2
		&"victory": return victory
	return null
