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
		# 第三关沿用团队现有探索曲，保留独立的关卡上下文，不新增音乐资源。
		&"level_2", &"level_3": return level_2
		&"victory": return victory
	return null
