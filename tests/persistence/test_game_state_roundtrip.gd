extends Node

const GameStateScript = preload("res://scripts/core/game_state.gd")
const MissionManagerScript = preload("res://scripts/gameplay/mission_manager.gd")
const RelationshipSystemScript = preload("res://scripts/gameplay/relationship_system.gd")


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
	origen.world_state.flags["conversaciones_npc"] = {
		"_relaciones_npc": {
			"ivo|nima": {"confianza": 42.0, "historial": [{"evento": "prueba"}]}
		},
		"_conocimientos_npc": {
			"ivo": [
				{"clave": "noticia_prueba", "titulo": "Noticia de prueba", "tipo": "noticia", "compartible": true, "privacidad": "publica"},
				{"clave": "privada_prueba", "titulo": "Dato privado", "tipo": "testimonio", "compartible": true, "privacidad": "personal", "permiso_transmision": true}
			],
			"nima": [{"clave": "otra_noticia", "titulo": "Otra noticia"}]
		},
		"_promesas_npc": [{"id": "promesa_prueba", "estado": "pendiente"}],
		"_asuntos_pendientes_npc": [{"id": "asunto_prueba", "personaje_id": "ivo", "personaje_relacionado": "nima", "estado": "pendiente"}]
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
	var relacion_npc := destino.obtener_relacion_npc_entre("ivo|nima")
	if not is_equal_approx(float(relacion_npc.get("confianza", 0.0)), 42.0):
		errores.append("La consulta puntual de relación entre NPC no devolvió su valor.")
	relacion_npc["confianza"] = 0.0
	if not is_equal_approx(float(destino.obtener_relacion_npc_entre("ivo|nima").get("confianza", 0.0)), 42.0):
		errores.append("La consulta puntual de relación expuso el estado interno modificable.")
	var conocimientos_ivo := destino.obtener_conocimientos_npc("ivo")
	if conocimientos_ivo.size() != 2 or str((conocimientos_ivo[0] as Dictionary).get("clave", "")) != "noticia_prueba":
		errores.append("La consulta puntual de conocimientos no devolvió los datos del NPC.")
	if not conocimientos_ivo.is_empty():
		(conocimientos_ivo[0] as Dictionary)["titulo"] = "Modificado desde la copia"
	if str((destino.obtener_conocimientos_npc("ivo")[0] as Dictionary).get("titulo", "")) != "Noticia de prueba":
		errores.append("La consulta puntual de conocimientos expuso el estado interno modificable.")
	var relaciones_sociales := RelationshipSystemScript.new() as RelationshipSystemService
	relaciones_sociales._game_state = destino
	if not relaciones_sociales.tiene_conocimiento_compartible_nuevo_npc("ivo", "nima"):
		errores.append("No detectó una noticia pública nueva que puede compartirse.")
	var conversaciones := destino.obtener_conversaciones_npc()
	var conocimientos_guardados: Dictionary = conversaciones.get("_conocimientos_npc", {})
	var conocimientos_nima: Array = conocimientos_guardados.get("nima", [])
	conocimientos_nima.append({"clave": "noticia_prueba", "tipo": "noticia", "compartible": true, "privacidad": "publica"})
	conocimientos_guardados["nima"] = conocimientos_nima
	var conocimientos_ivo_guardados: Array = conocimientos_guardados.get("ivo", [])
	if conocimientos_ivo_guardados.size() > 1:
		(conocimientos_ivo_guardados[1] as Dictionary)["permiso_transmision"] = false
	conocimientos_guardados["ivo"] = conocimientos_ivo_guardados
	conversaciones["_conocimientos_npc"] = conocimientos_guardados
	destino.guardar_conversaciones_npc(conversaciones)
	if relaciones_sociales.tiene_conocimiento_compartible_nuevo_npc("ivo", "nima"):
		errores.append("Consideró nueva una noticia que el destinatario ya conoce sin otro dato transmisible.")
	conocimientos_ivo_guardados = destino.obtener_conversaciones_npc().get("_conocimientos_npc", {}).get("ivo", [])
	if conocimientos_ivo_guardados.size() > 1:
		(conocimientos_ivo_guardados[1] as Dictionary)["permiso_transmision"] = true
	conversaciones = destino.obtener_conversaciones_npc()
	conocimientos_guardados = conversaciones.get("_conocimientos_npc", {})
	conocimientos_guardados["ivo"] = conocimientos_ivo_guardados
	conversaciones["_conocimientos_npc"] = conocimientos_guardados
	destino.guardar_conversaciones_npc(conversaciones)
	if not relaciones_sociales.tiene_conocimiento_compartible_nuevo_npc("ivo", "nima"):
		errores.append("No reconoció el conocimiento privado autorizado con confianza suficiente.")
	conversaciones = destino.obtener_conversaciones_npc()
	var relaciones_guardadas: Dictionary = conversaciones.get("_relaciones_npc", {})
	var relacion_guardada: Dictionary = relaciones_guardadas.get("ivo|nima", {})
	relacion_guardada["confianza"] = 29.0
	relaciones_guardadas["ivo|nima"] = relacion_guardada
	conversaciones["_relaciones_npc"] = relaciones_guardadas
	destino.guardar_conversaciones_npc(conversaciones)
	if relaciones_sociales.tiene_conocimiento_compartible_nuevo_npc("ivo", "nima"):
		errores.append("Permitió compartir conocimiento privado por debajo del umbral de confianza.")
	var promesas_guardadas: Variant = destino.obtener_conversaciones_npc().get("_promesas_npc", [])
	if not promesas_guardadas is Array:
		errores.append("La lectura completa de conversaciones dejó de conservar las demás secciones.")
	var asuntos_puntuales := destino.obtener_asuntos_pendientes_npc()
	var promesas_puntuales := destino.obtener_promesas_npc()
	if asuntos_puntuales.size() != 1 or promesas_puntuales.size() != 1:
		errores.append("Las lecturas puntuales de asuntos y promesas no devolvieron sus listas.")
	else:
		(asuntos_puntuales[0] as Dictionary)["estado"] = "resuelto"
		(promesas_puntuales[0] as Dictionary)["estado"] = "cumplida"
		if str((destino.obtener_asuntos_pendientes_npc()[0] as Dictionary).get("estado", "")) != "pendiente":
			errores.append("La lectura puntual de asuntos expuso el estado interno modificable.")
		if str((destino.obtener_promesas_npc()[0] as Dictionary).get("estado", "")) != "pendiente":
			errores.append("La lectura puntual de promesas expuso el estado interno modificable.")
	var relacion_actualizada := relaciones_sociales.registrar_interaccion_entre_npc(
		"ivo", "nima", {"confianza": 2.0}, {"tipo": "interaccion_prueba"}
	)
	if not is_equal_approx(float(relacion_actualizada.get("confianza", 0.0)), 31.0):
		errores.append("La escritura puntual de relación no conservó ni actualizó sus valores.")
	if int(relacion_actualizada.get("interacciones", 0)) != 1:
		errores.append("La escritura puntual de relación no registró la interacción.")
	if not relaciones_sociales.registrar_conocimiento_npc("ivo", {
		"clave": "conocimiento_nuevo_prueba", "tipo": "noticia", "titulo": "Dato nuevo"
	}):
		errores.append("No pudo registrar conocimiento mediante la escritura puntual.")
	if destino.obtener_conocimiento_npc("ivo", "conocimiento_nuevo_prueba").is_empty():
		errores.append("El conocimiento escrito puntualmente no quedó disponible.")
	var asunto_id := relaciones_sociales.registrar_asunto_pendiente_npc("ivo", {
		"clave": "asunto_nuevo_prueba", "descripcion": "Asunto nuevo"
	})
	if asunto_id.is_empty() or destino.obtener_asuntos_pendientes_npc().size() != 2:
		errores.append("No pudo registrar un asunto con escritura puntual.")
	var promesa_id := relaciones_sociales.registrar_promesa_entre_npc("ivo", "nima", {
		"clave": "promesa_nueva_prueba", "descripcion": "Promesa nueva"
	})
	if promesa_id.is_empty() or destino.obtener_promesas_npc().size() != 2:
		errores.append("No pudo registrar una promesa con escritura puntual.")
	relaciones_sociales.free()
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
