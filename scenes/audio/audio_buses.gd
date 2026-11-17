extends RefCounted
## Leave existing effects on Master; only background music uses this child bus.
const MUSIC := &"Music"

static func ensure_music_bus() -> int:
	var index := AudioServer.get_bus_index(MUSIC)
	if index < 0:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, MUSIC)
		AudioServer.set_bus_send(index, &"Master")
	return index
