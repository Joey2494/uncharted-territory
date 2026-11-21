@tool
extends Resource
## Build artifact only: no gameplay nodes, colliders or running scripts.
@export var schema := 1
@export var generator_revision := "static-art-v1"
@export var engine_version := ""
@export var family := ""
@export var source_hashes: Dictionary = {}
@export var scenes: Dictionary = {}
@export var random_states: Dictionary = {}
@export var materials: Dictionary = {}
@export var textures: Dictionary = {}
