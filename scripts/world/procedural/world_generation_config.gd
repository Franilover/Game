extends RefCounted
class_name WorldGenerationConfig

## Configuration immutable-in-practice for one world-generation run.
## Keep algorithm_version explicit: changing generation rules can change existing worlds.

var seed: int = 0
var world_width_tiles: int = 1024
var world_height_tiles: int = 1024
var chunk_size_tiles: int = 32
var algorithm_version: int = 1

func _init(
	p_seed: int = 0,
	p_world_width_tiles: int = 1024,
	p_world_height_tiles: int = 1024,
	p_chunk_size_tiles: int = 32,
	p_algorithm_version: int = 1
) -> void:
	seed = p_seed
	world_width_tiles = p_world_width_tiles
	world_height_tiles = p_world_height_tiles
	chunk_size_tiles = p_chunk_size_tiles
	algorithm_version = p_algorithm_version

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if world_width_tiles <= 0:
		errors.append("world_width_tiles debe ser mayor que cero.")
	if world_height_tiles <= 0:
		errors.append("world_height_tiles debe ser mayor que cero.")
	if chunk_size_tiles <= 0:
		errors.append("chunk_size_tiles debe ser mayor que cero.")
	if algorithm_version <= 0:
		errors.append("algorithm_version debe ser mayor que cero.")
	return errors

func is_valid() -> bool:
	return validate().is_empty()
