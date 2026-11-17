extends RefCounted
## Display ranges use game units and remain fixed while browsing the roster.
const CATALOG = preload("res://scenes/player/character_catalog.gd")
const RANGES := {
	"attack": {"maximum": 2.0, "step": 1.0},
	"hp": {"maximum": 6.0, "step": 2.0},
	"shield": {"maximum": 2.0, "step": 1.0},
	"speed": {"maximum": 6.0, "step": 1.0},
}

static func value_for(data: Dictionary, attribute: String) -> float:
	return minf(data.walk,data.run) if attribute == "speed" else float(data[attribute])

static func maximum_for(attribute: String) -> float:
	var largest := 0.0
	for id in CATALOG.IDS:
		largest = maxf(largest,value_for(CATALOG.definition(id),attribute))
	return upper_bound_for(attribute,largest)

static func upper_bound_for(attribute: String, largest: float) -> float:
	var scale: Dictionary = RANGES[attribute]
	return maxf(scale.maximum,ceilf(largest/scale.step)*scale.step)
