extends Node
## Persistencia exclusiva del mundo compartido.
## Nunca guarda vida, inventario, personaje ni progreso individual de jugadores.

const SAVE_PATH := "user://garlia_global_world.json"
const SAVE_INTERVAL := 15.0
const GLOBAL_FLAGS := [
	# Datos que describen el mundo compartido, no un personaje.
	"zona_actual_tipo",
	"estado_zona_actual",
	"tiempo_mundo",
	"reino_torres_visitado",
	"reinos_desbloqueados"
]

var _elapsed_save: float = 0.0
var _main: Node = null
var _entidades_por_zona: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func configurar_runtime(main: Node) -> void:
	_main = main


func restaurar_en_game_state(game_state: Node) -> bool:
	if game_state == null or not is_instance_valid(game_state):
		return false
	if not FileAccess.file_exists(SAVE_PATH):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		game_state.world_state.world_seed = rng.randi()
		game_state.world_state.world_seed_valida = true
		print("GlobalWorldStore: se creó la semilla inicial del mundo global.")
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GlobalWorldStore: no se pudo abrir el guardado global.")
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("GlobalWorldStore: el archivo del mundo global no es válido.")
		return false

	var data := parsed as Dictionary
	game_state.world_state.world_seed = int(data.get("world_seed", 0))
	game_state.world_state.world_seed_valida = bool(data.get("world_seed_valida", false))
	game_state.world_state.elapsed_time = float(data.get("elapsed_time", 0.0))
	var flags: Variant = _decodificar_variante(data.get("flags", {}))
	if flags is Dictionary:
		game_state.world_state.flags = (flags as Dictionary).duplicate(true)
	else:
		game_state.world_state.flags = {}
	var entidades_variant: Variant = _decodificar_variante(data.get("entidades_por_zona", {}))
	_entidades_por_zona = (entidades_variant as Dictionary).duplicate(true) if entidades_variant is Dictionary else {}
	print("GlobalWorldStore: mundo global restaurado. Semilla: ", game_state.world_state.world_seed)
	return true


func restaurar_estado_entidades(entity_manager: Node, zona: String) -> bool:
	if not is_instance_valid(entity_manager) or not entity_manager.has_method("restaurar_estado_persistente_mundo"):
		return false
	var estado_variant: Variant = _entidades_por_zona.get(zona, {})
	if not estado_variant is Dictionary or (estado_variant as Dictionary).is_empty():
		return false
	entity_manager.call("restaurar_estado_persistente_mundo", (estado_variant as Dictionary).duplicate(true))
	print("GlobalWorldStore: runtime de entidades restaurado para ", zona)
	return true


func _serializar_variante(valor: Variant) -> Variant:
	if valor is Vector2:
		var vector := valor as Vector2
		return {"__garlia_type": "Vector2", "x": vector.x, "y": vector.y}
	if valor is Vector2i:
		var vector_i := valor as Vector2i
		return {"__garlia_type": "Vector2i", "x": vector_i.x, "y": vector_i.y}
	if valor is Color:
		var color := valor as Color
		return {"__garlia_type": "Color", "r": color.r, "g": color.g, "b": color.b, "a": color.a}
	if valor is Array:
		var resultado_array: Array = []
		for elemento in valor as Array:
			resultado_array.append(_serializar_variante(elemento))
		return resultado_array
	if valor is Dictionary:
		var resultado_diccionario: Dictionary = {}
		for clave_variant in (valor as Dictionary).keys():
			resultado_diccionario[str(clave_variant)] = _serializar_variante((valor as Dictionary)[clave_variant])
		return resultado_diccionario
	return valor


func _decodificar_variante(valor: Variant) -> Variant:
	if valor is Array:
		var resultado_array: Array = []
		for elemento in valor as Array:
			resultado_array.append(_decodificar_variante(elemento))
		return resultado_array
	if valor is Dictionary:
		var diccionario := valor as Dictionary
		var tipo := str(diccionario.get("__garlia_type", ""))
		match tipo:
			"Vector2":
				return Vector2(float(diccionario.get("x", 0.0)), float(diccionario.get("y", 0.0)))
			"Vector2i":
				return Vector2i(int(diccionario.get("x", 0)), int(diccionario.get("y", 0)))
			"Color":
				return Color(float(diccionario.get("r", 1.0)), float(diccionario.get("g", 1.0)), float(diccionario.get("b", 1.0)), float(diccionario.get("a", 1.0)))
		var resultado_diccionario: Dictionary = {}
		for clave_variant in diccionario.keys():
			resultado_diccionario[str(clave_variant)] = _decodificar_variante(diccionario[clave_variant])
		return resultado_diccionario
	return valor


func guardar_desde_runtime() -> bool:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state == null:
		return false

	if is_instance_valid(_main):
		var zone_manager := _main.get_node_or_null("World/ZoneManager")
		if is_instance_valid(zone_manager):
			var zona_tipo := str(zone_manager.call("obtener_tipo_actual"))
			game_state.world_state.flags["zona_actual_tipo"] = zona_tipo
			var zone: Node = zone_manager.call("obtener_zona_actual") as Node
			if is_instance_valid(zone) and zone.has_method("obtener_estado_guardado"):
				game_state.world_state.flags["estado_zona_actual"] = zone.call("obtener_estado_guardado").duplicate(true)
			var atmosphere: Node = _main.get_node_or_null("Systems/WorldAtmosphere")
			if is_instance_valid(atmosphere) and atmosphere.has_method("obtener_estado_guardado"):
				game_state.world_state.flags["tiempo_mundo"] = atmosphere.call("obtener_estado_guardado").duplicate(true)
			var world_generator: WorldGenerator = zone_manager.call("obtener_world_generator") as WorldGenerator
			if is_instance_valid(world_generator) and is_instance_valid(world_generator.entity_manager):
				if world_generator.entity_manager.has_method("capturar_estado_persistente_mundo"):
					_entidades_por_zona[zona_tipo] = world_generator.entity_manager.call("capturar_estado_persistente_mundo")

	var flags: Dictionary = {}
	for key in GLOBAL_FLAGS:
		if game_state.world_state.flags.has(key):
			flags[key] = game_state.world_state.flags[key].duplicate(true) if game_state.world_state.flags[key] is Dictionary or game_state.world_state.flags[key] is Array else game_state.world_state.flags[key]

	var data := {
		"version": 1,
		"world_seed": int(game_state.world_state.world_seed),
		"world_seed_valida": bool(game_state.world_state.world_seed_valida),
		"elapsed_time": float(game_state.world_state.elapsed_time),
		"flags": _serializar_variante(flags),
		"entidades_por_zona": _serializar_variante(_entidades_por_zona),
		"saved_at": Time.get_datetime_string_from_system(true)
	}
	var temporary_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("GlobalWorldStore: no se pudo escribir el guardado temporal.")
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()

	var absolute_temp := ProjectSettings.globalize_path(temporary_path)
	var absolute_final := ProjectSettings.globalize_path(SAVE_PATH)
	var error := DirAccess.rename_absolute(absolute_temp, absolute_final)
	if error != OK:
		DirAccess.remove_absolute(absolute_final)
		error = DirAccess.rename_absolute(absolute_temp, absolute_final)
	if error != OK:
		push_error("GlobalWorldStore: no se pudo publicar el guardado global. Error: " + str(error))
		return false
	return true


func _process(delta: float) -> void:
	if not GarliaMultiplayer.es_servidor_dedicado():
		return
	if GarliaMultiplayer.obtener_cantidad_jugadores_remotos() <= 0:
		return
	_elapsed_save += delta
	if _elapsed_save < SAVE_INTERVAL:
		return
	_elapsed_save = 0.0
	guardar_desde_runtime()


func guardar_y_pausar() -> void:
	guardar_desde_runtime()
	get_tree().paused = true
	print("GlobalWorldStore: no quedan jugadores; mundo guardado y pausado.")
