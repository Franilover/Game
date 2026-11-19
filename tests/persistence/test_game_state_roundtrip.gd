extends Node

const GameStateScript = preload("res://scripts/core/game_state.gd")
const MissionManagerScript = preload("res://scripts/gameplay/mission_manager.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var origen := GameStateScript.new() as GameStateService
	var misiones := MissionManagerScript.new() as MissionManagerService
	origen._mission_manager = misiones

	origen.player_state.health = 73
	origen.player_state.mana = 41
	origen.player_state.stamina = 1.0
	origen.player_state.position = Vector2(123.5, 456.25)
	origen.player_state.position_valida = true
	origen.player_state.tile = Vector2i(12, 45)
	origen.player_state.tile_valido = true
	origen.player_state.facing = Vector2.RIGHT
	origen.world_state.elapsed_time = 987.5
	origen.world_state.current_scene = "res://scenes/world/main.tscn"
	origen.world_state.flags = {
		"inventario_estado": {
			"items": [{
				"id": "carta_aoris_id",
				"item_id": "carta_aoris_id",
				"nombre": "Carta Aoris de Elian",
				"nombre_sprite": "Carta Aoris",
				"ejemplar_id": "ejemplar_elian_test",
				"es_ejemplar": true,
				"descripcion_detallada": "Descripción única de prueba.",
				"cantidad": 1,
				"max_stack": 1
			}],
			"hotbar": [0, -1, -1]
		},
		"estado_zona_actual": {
			"interior": "casa_ivo",
			"jugador": {"x": 123.5, "y": 456.25}
		},
		"proceso_ium_equipado": {"id": "ium_test", "cantidad": 2},
		"tiempo_mundo": {"dia": 4, "minuto": 510}
	}
	misiones._estado = {"mision_recompensa_test": "completada"}
	misiones._progreso = {"mision_recompensa_test": 3}
	misiones._recompensas_reclamadas = {"mision_recompensa_test": true}

	origen._capturar_estado_misiones()
	var snapshot := origen._serializar_estado()

	var destino := GameStateScript.new() as GameStateService
	var misiones_destino := MissionManagerScript.new() as MissionManagerService
	destino._mission_manager = misiones_destino
	destino._aplicar_estado_memoria(snapshot)
	destino._aplicar_estado_misiones()

	if destino.player_state.health != 73 or destino.player_state.mana != 41:
		errores.append("Vida o Eterium no sobrevivieron al roundtrip.")
	if destino.player_state.position != Vector2(123.5, 456.25) or not destino.player_state.position_valida:
		errores.append("La posición válida del jugador no sobrevivió al roundtrip.")
	if destino.player_state.tile != Vector2i(12, 45) or not destino.player_state.tile_valido:
		errores.append("El tile del jugador no sobrevivió al roundtrip.")
	if destino.player_state.facing != Vector2.RIGHT:
		errores.append("La orientación del jugador no sobrevivió al roundtrip.")
	if not is_equal_approx(destino.world_state.elapsed_time, 987.5):
		errores.append("El tiempo de mundo no sobrevivió al roundtrip.")

	var flags := destino.world_state.flags
	var inventario_guardado: Dictionary = flags.get("inventario_estado", {}) as Dictionary
	var items_guardados: Array = inventario_guardado.get("items", []) as Array
	if items_guardados.is_empty():
		errores.append("El inventario no sobrevivió al roundtrip.")
	else:
		var ejemplar_guardado: Dictionary = items_guardados[0] as Dictionary
		if str(ejemplar_guardado.get("ejemplar_id", "")) != "ejemplar_elian_test":
			errores.append("La identidad del ejemplar no sobrevivió al roundtrip.")
		if str(ejemplar_guardado.get("nombre", "")) != "Carta Aoris de Elian":
			errores.append("El nombre propio del ejemplar no sobrevivió al roundtrip.")
		if str(ejemplar_guardado.get("nombre_sprite", "")) != "Carta Aoris":
			errores.append("La referencia al sprite base no sobrevivió al roundtrip.")
		if str(ejemplar_guardado.get("descripcion_detallada", "")) != "Descripción única de prueba.":
			errores.append("La descripción del ejemplar no sobrevivió al roundtrip.")
	if (flags.get("estado_zona_actual", {}) as Dictionary).get("interior", "") != "casa_ivo":
		errores.append("El estado de interior/zona no sobrevivió al roundtrip.")
	if (flags.get("proceso_ium_equipado", {}) as Dictionary).get("id", "") != "ium_test":
		errores.append("El proceso IUM equipado no sobrevivió al roundtrip.")
	if (flags.get("tiempo_mundo", {}) as Dictionary).get("dia", 0) != 4:
		errores.append("El tiempo ambiental no sobrevivió al roundtrip.")
	if str(misiones_destino._estado.get("mision_recompensa_test", "")) != "completada":
		errores.append("El estado de misión no sobrevivió al roundtrip.")
	if int(misiones_destino._progreso.get("mision_recompensa_test", 0)) != 3:
		errores.append("El progreso de misión no sobrevivió al roundtrip.")
	if not bool(misiones_destino._recompensas_reclamadas.get("mision_recompensa_test", false)):
		errores.append("La reclamación de recompensa no sobrevivió al roundtrip.")

	misiones.free()
	misiones_destino.free()
	origen.free()
	destino.free()
	if not errores.is_empty():
		for error in errores:
			push_error("GameStateRoundtrip: FAIL: " + error)
		get_tree().quit(1)
		return
	print("GameStateRoundtrip: PASS")
	get_tree().quit(0)
