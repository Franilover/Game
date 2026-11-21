extends Node

const GameStateScript = preload("res://scripts/core/game_state.gd")
const MissionManagerScript = preload("res://scripts/gameplay/mission_manager.gd")
const RelationshipSystemScript = preload("res://scripts/gameplay/relationship_system.gd")
const PlayerStateScript = preload("res://scripts/state/player_state.gd")
const SaveRepositoryScript = preload("res://scripts/infrastructure/save_file_repository.gd")
const PlayerScene: PackedScene = preload("res://scenes/characters/player.tscn")
const ZoneManagerScript = preload("res://scripts/world/zone_manager.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var origen := GameStateScript.new() as GameStateService
	var misiones := MissionManagerScript.new() as MissionManagerService
	origen._mission_manager = misiones

	origen.player_state.health = 73
	origen.player_state.mana = 41
	origen.player_state.stamina = 1.5
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
	origen.world_state.flags["relaciones_sociales"] = {
		"ivo": {"amistad": 12.0, "confianza": 8.0},
		"nima": {"amistad": 34.0, "confianza": 21.0}
	}
	origen.world_state.flags["recuerdos_sociales"] = {
		"ivo": [{
			"tipo": "tema_conversacion", "clave": "viaje_garlia", "importancia": 3.5,
			"momento": "momento_inicial", "primer_momento": "primer_momento",
			"veces_conversado": 1, "mencionado_en_dialogo": false,
			"frase_jugador": "Hablemos del viaje", "recuerdo_uid": "ivo:viaje_garlia"
		}],
		"nima": [{"tipo": "evento_social", "clave": "festival", "importancia": 4.0}]
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

	# El roundtrip atraviesa el archivo real, no solo dos objetos en memoria.
	# Simula cerrar la sesión y volver a abrir el save antes de restaurar misiones.
	var repositorio := SaveRepositoryScript.new() as SaveFileRepository
	var directorio_contrato := "user://contracts/game_state_roundtrip"
	repositorio.configurar(directorio_contrato)
	repositorio.asegurar_directorio()
	repositorio.eliminar_partida("roundtrip_contract")
	var archivo_snapshot := {
		"id": "roundtrip_contract",
		"version": 1,
		"estado": snapshot
	}
	if not repositorio.escribir_partida("roundtrip_contract", archivo_snapshot):
		errores.append("No pudo persistir el snapshot completo en el contrato de roundtrip.")
	var archivo_reabierto := repositorio.leer_partida("roundtrip_contract")
	if archivo_reabierto.is_empty():
		errores.append("No pudo reabrir el snapshot persistido desde disco.")
	else:
		var estado_reabierto: Variant = archivo_reabierto.get("estado", {})
		if not estado_reabierto is Dictionary:
			errores.append("El archivo reabierto no contiene un estado de partida válido.")
		else:
			snapshot = (estado_reabierto as Dictionary).duplicate(true)
	if not repositorio.eliminar_partida("roundtrip_contract"):
		errores.append("No pudo limpiar el archivo temporal del contrato de roundtrip.")

	var destino := GameStateScript.new() as GameStateService
	var misiones_destino := MissionManagerScript.new() as MissionManagerService
	destino._mission_manager = misiones_destino
	destino._aplicar_estado_memoria(snapshot)
	destino._aplicar_estado_misiones()

	if destino.player_state.health != 73 or destino.player_state.mana != 41:
		errores.append("Vida o Eterium no sobrevivieron al roundtrip.")
	if not is_equal_approx(destino.player_state.stamina, 1.5):
		errores.append("La stamina fraccionaria se redondeó durante la carga.")
	var estado_legacy := PlayerStateScript.new() as PlayerState
	estado_legacy.from_dictionary({"stamina": 50.0})
	if not is_equal_approx(estado_legacy.stamina, 1.5):
		errores.append("La migración de stamina antigua (0..100) no conservó su valor proporcional.")

	# Las partidas históricas sin campo version se leen como v1 y se
	# normalizan sin perder campos de progreso que el código actual desconoce.
	var legado_v1 := {
		"id": "legacy_v1",
		"nombre": "Partida antigua",
		"estado": {
			"player": {"health": 80, "mana": 25, "stamina": 50.0},
			"elapsed_time": 123.0,
			"flags": {
				"zona_actual_tipo": "reino_torres",
				"progreso_personalizado_legacy": {"marcador": 17}
			}
		}
	}
	var legado_migrado := destino._migrar_datos_partida("legacy_v1", legado_v1)
	if legado_migrado.is_empty():
		errores.append("No aceptó una partida v1 sin campo version.")
	else:
		if int(legado_migrado.get("version", 0)) != GameStateScript.SAVE_VERSION:
			errores.append("La migración no actualizó la versión del save.")
		var mundo_legacy: Dictionary = legado_migrado.get("mundo", {}) as Dictionary
		if not mundo_legacy.has("semilla") or not mundo_legacy.has("generador_version"):
			errores.append("La migración no incorporó la semilla y versión del generador.")
		var flags_legacy: Dictionary = (legado_migrado.get("estado", {}) as Dictionary).get("flags", {}) as Dictionary
		if int((flags_legacy.get("progreso_personalizado_legacy", {}) as Dictionary).get("marcador", 0)) != 17:
			errores.append("La migración descartó progreso desconocido de la partida antigua.")
		if int((legado_v1.get("estado", {}) as Dictionary).get("player", {}).get("health", 0)) != 80:
			errores.append("La migración modificó el archivo legacy original en memoria.")
	if not destino._migrar_datos_partida("future_version", {
		"id": "future_version", "version": GameStateScript.SAVE_VERSION + 1,
		"estado": {}
	}).is_empty():
		errores.append("Aceptó una partida de una versión futura incompatible.")
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
	var relacion_jugador_ivo := destino.obtener_relacion_social_jugador_npc("ivo")
	if not is_equal_approx(float(relacion_jugador_ivo.get("amistad", 0.0)), 12.0):
		errores.append("La lectura puntual de relación jugador-NPC no devolvió sus valores.")
	relacion_jugador_ivo["amistad"] = 0.0
	if not is_equal_approx(float(destino.obtener_relacion_social_jugador_npc("ivo").get("amistad", 0.0)), 12.0):
		errores.append("La lectura puntual de relación jugador-NPC expuso el estado interno.")
	var relacion_ivo_modificada := relaciones_sociales.modificar_relacion("ivo", {"amistad": 2.0})
	if not is_equal_approx(float(relacion_ivo_modificada.get("amistad", 0.0)), 14.0):
		errores.append("La modificación de relación jugador-NPC no usó el valor persistido.")
	if not is_equal_approx(float(destino.obtener_relacion_social_jugador_npc("nima").get("amistad", 0.0)), 34.0):
		errores.append("La escritura puntual de Ivo alteró la relación jugador-NPC de Nima.")
	var recuerdos_ivo := destino.obtener_recuerdos_sociales_npc("ivo")
	if recuerdos_ivo.size() != 1 or str((recuerdos_ivo[0] as Dictionary).get("clave", "")) != "viaje_garlia":
		errores.append("La lectura puntual de recuerdos no devolvió el historial del NPC.")
	if not recuerdos_ivo.is_empty():
		(recuerdos_ivo[0] as Dictionary)["clave"] = "alterado"
	if str((destino.obtener_recuerdos_sociales_npc("ivo")[0] as Dictionary).get("clave", "")) != "viaje_garlia":
		errores.append("La lectura puntual de recuerdos expuso el estado interno modificable.")
	relaciones_sociales.registrar_recuerdo("ivo", {
		"tipo": "tema_conversacion", "clave": "viaje_garlia", "importancia": 1.0,
		"momento": "momento_actual", "frase_jugador": "Hablemos del viaje otra vez"
	})
	var recuerdos_actualizados := destino.obtener_recuerdos_sociales_npc("ivo")
	if recuerdos_actualizados.size() != 1:
		errores.append("La actualización de un tema recurrente duplicó el recuerdo.")
	else:
		var recuerdo_actualizado := recuerdos_actualizados[0] as Dictionary
		if int(recuerdo_actualizado.get("veces_conversado", 0)) != 2:
			errores.append("El tema recurrente no incrementó su contador.")
		if str(recuerdo_actualizado.get("primer_momento", "")) != "primer_momento":
			errores.append("El tema recurrente perdió su primer momento.")
		if str(recuerdo_actualizado.get("momento", "")) != "momento_actual":
			errores.append("El tema recurrente no actualizó su último momento.")
		if not is_equal_approx(float(recuerdo_actualizado.get("importancia", 0.0)), 3.5):
			errores.append("El tema recurrente redujo su importancia acumulada.")
	var pendiente := relaciones_sociales.obtener_recuerdo_pendiente_mencionar("ivo")
	if str(pendiente.get("recuerdo_uid", "")) != "ivo:viaje_garlia":
		errores.append("No encontró el recuerdo social pendiente de mencionar.")
	elif not relaciones_sociales.marcar_recuerdo_mencionado("ivo", -1, str(pendiente.get("recuerdo_uid", ""))):
		errores.append("No pudo marcar el recuerdo por su identificador estable.")
	if not relaciones_sociales.obtener_recuerdo_pendiente_mencionar("ivo").is_empty():
		errores.append("Un recuerdo ya mencionado volvió a aparecer como pendiente.")
	if destino.obtener_recuerdos_sociales_npc("nima").size() != 1:
		errores.append("La escritura de recuerdos de Ivo alteró los recuerdos de Nima.")
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
	if relaciones_sociales.obtener_conocimiento_npc("ivo", "conocimiento_nuevo_prueba").is_empty():
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

	# La ruta de introducción no puede reemplazar una historia existente
	# aunque algún acceso todavía invoque preparar_historia(..., true).
	var historia_probe := GameStateScript.new() as GameStateService
	var historia_dir := "user://contracts/story_resume_guard"
	historia_probe.story_save_repository.configurar(historia_dir)
	historia_probe.story_save_repository.asegurar_directorio()
	historia_probe.story_save_repository.eliminar_partida("reserva_carmesi")
	var estado_historia := {
		"player": PlayerStateScript.new().to_dictionary(),
		"elapsed_time": 456.0,
		"flags": {
			"story_resume_marker": 73,
			"tiempo_mundo": {
				"dia_del_anio": 8,
				"anio": 12,
				"hora_del_dia": 14.5
			}
		},
		"scene": "res://scenes/world/main.tscn"
	}
	var archivo_historia := {
		"version": 1,
		"id": "reserva_carmesi",
		"nombre": "La Reserva Carmesí",
		"estado": estado_historia
	}
	if not historia_probe.story_save_repository.escribir_partida("reserva_carmesi", archivo_historia):
		errores.append("No pudo preparar el snapshot narrativo de reanudación.")
	historia_probe.preparar_historia_reserva_carmesi(true)
	if int(historia_probe.world_state.flags.get("story_resume_marker", 0)) != 73:
		errores.append("El inicio narrativo reemplazó una partida existente por una nueva.")
	if not historia_probe._historia_requiere_aplicar:
		errores.append("La historia existente no quedó marcada para restaurarse en la escena.")
	if historia_probe.guardar_progreso_historia():
		errores.append("Se permitió guardar sobre un snapshot antes de aplicarlo al Player real.")
	var historia_persistida := historia_probe.story_save_repository.leer_partida("reserva_carmesi")
	var estado_historia_persistida: Dictionary = historia_persistida.get("estado", {}) as Dictionary
	var flags_historia_persistida: Dictionary = estado_historia_persistida.get("flags", {}) as Dictionary
	if int(flags_historia_persistida.get("story_resume_marker", 0)) != 73:
		errores.append("El snapshot narrativo original fue sobrescrito antes de restaurarse.")
	historia_probe.story_save_repository.eliminar_partida("reserva_carmesi")
	historia_probe.free()

	# Integración real del guardado narrativo: jugador + ZoneManager + JSON.
	# Comprueba el mismo punto de entrada que usan autosave, pausa y cierre.
	var mundo_runtime := Node2D.new()
	mundo_runtime.name = "World"
	add_child(mundo_runtime)
	var zone_runtime := ZoneManagerScript.new() as Node2D
	zone_runtime.name = "ZoneManager"
	zone_runtime.set("tipo_actual", "historia:reserva_carmesi")
	mundo_runtime.add_child(zone_runtime)
	var jugador_runtime := PlayerScene.instantiate() as Player
	if jugador_runtime == null:
		errores.append("No pudo instanciar al jugador para la integración del guardado narrativo.")
	else:
		jugador_runtime.global_position = Vector2(321.5, 654.25)
		add_child(jugador_runtime)
	var guardado_runtime := GameStateScript.new() as GameStateService
	guardado_runtime.name = "GameStateSaveIntegration"
	add_child(guardado_runtime)
	await get_tree().process_frame
	var directorio_integracion := "user://contracts/story_save_integration"
	guardado_runtime.story_save_repository.configurar(directorio_integracion)
	guardado_runtime.story_save_repository.asegurar_directorio()
	guardado_runtime.story_save_repository.eliminar_partida("reserva_carmesi")
	guardado_runtime.preparar_historia_reserva_carmesi(true)
	guardado_runtime.world_state.flags["integration_progress_marker"] = 91
	if jugador_runtime != null:
		guardado_runtime.configurar_dependencias(null, jugador_runtime)
		await get_tree().process_frame
		await get_tree().process_frame
		if not guardado_runtime.guardar_progreso_actual("prueba de cierre"):
			errores.append("El guardado narrativo integrado no confirmó la escritura al solicitar cierre.")
	var archivo_integracion := guardado_runtime.story_save_repository.leer_partida("reserva_carmesi")
	var estado_integracion: Dictionary = archivo_integracion.get("estado", {}) as Dictionary
	var flags_integracion: Dictionary = estado_integracion.get("flags", {}) as Dictionary
	if int(flags_integracion.get("integration_progress_marker", 0)) != 91:
		errores.append("El guardado narrativo integrado no persistió el progreso de la sesión.")
	var jugador_guardado: Dictionary = estado_integracion.get("player", {}) as Dictionary
	if not is_equal_approx(float(jugador_guardado.get("position_x", 0.0)), 321.5):
		errores.append("El guardado narrativo integrado no conservó la posición del jugador.")
	var reapertura_runtime := GameStateScript.new() as GameStateService
	reapertura_runtime.name = "GameStateSaveReloadIntegration"
	add_child(reapertura_runtime)
	await get_tree().process_frame
	reapertura_runtime.story_save_repository.configurar(directorio_integracion)
	if not reapertura_runtime.preparar_historia_reserva_carmesi(false):
		errores.append("No pudo preparar la reapertura del guardado narrativo integrado.")
	if int(reapertura_runtime.world_state.flags.get("integration_progress_marker", 0)) != 91:
		errores.append("El progreso narrativo integrado no sobrevivió a cerrar y reabrir el estado.")
	reapertura_runtime.story_save_repository.eliminar_partida("reserva_carmesi")
	reapertura_runtime.queue_free()
	guardado_runtime.queue_free()
	if jugador_runtime != null:
		jugador_runtime.queue_free()
	mundo_runtime.queue_free()
	await get_tree().process_frame

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
