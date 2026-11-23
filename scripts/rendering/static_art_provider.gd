@tool
extends Node
## Normal transitions preload asynchronously; standalone/editor scenes also work.
const Cache = preload("res://scripts/rendering/static_art_cache.gd")
@export var family := ""
var library: Resource
func _enter_tree() -> void:
	library = Cache.acquire(family)
	Cache.activate(library)
func _exit_tree() -> void: Cache.deactivate(library)
