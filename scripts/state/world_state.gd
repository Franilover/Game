extends RefCounted
class_name WorldState

var world_seed: int = 0
var world_seed_valida: bool = false
var elapsed_time: float = 0.0
var current_scene: String = ""
var flags: Dictionary = {}

func to_dictionary() -> Dictionary:
	return {
		"mundo": {
			"semilla": world_seed,
			"generador_version": 1
		},
		"elapsed_time": elapsed_time,
		"flags": flags.duplicate(true),
		"scene": current_scene
	}

func from_dictionary(data: Dictionary) -> void:
	var world_data: Variant = data.get("mundo", {})
	if world_data is Dictionary:
		var mundo := world_data as Dictionary
		world_seed = int(mundo.get("semilla", 0))
		world_seed_valida = mundo.has("semilla")
	else:
		world_seed = 0
		world_seed_valida = false

	elapsed_time = float(data.get("elapsed_time", 0.0))
	current_scene = str(data.get("scene", ""))

	var flags_data: Variant = data.get("flags", {})
	if flags_data is Dictionary:
		flags = (flags_data as Dictionary).duplicate(true)
	else:
		flags = {}
