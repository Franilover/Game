extends Node

const WorldEntityManagerScript = preload("res://scripts/world/world_entity_manager.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var manager: Variant = WorldEntityManagerScript.new()
	var replica_criatura := Node.new()
	var replica_prop := Node.new()
	var persistente_extra := Node.new()

	manager._registrar_clave_persistente(persistente_extra, "extra:1")
	manager._registrar_clave_persistente(persistente_extra, "extra:2")
	manager._remover_persistencia(persistente_extra)
	if manager._persistent_by_key.has("extra:1") or manager._persistent_by_key.has("extra:2"):
		errores.append("La limpieza de persistencia conservó claves del índice inverso.")
	if manager._persistent_keys_by_entity.has(persistente_extra):
		errores.append("La limpieza de persistencia conservó el índice inverso de la entidad.")
	persistente_extra.free()

	manager._persistent_by_key = {"personaje:1": replica_criatura}
	manager._persistent_keys_by_entity = {replica_criatura: ["personaje:1"]}
	manager._global_entities = [replica_criatura]
	manager._active_chunks = {Vector2i.ZERO: true}
	manager._active_creature_chunks = {Vector2i.ZERO: true}
	manager._active_prop_chunks = {Vector2i.ZERO: true}
	manager._replicas_red_by_key = {"zona|criatura": replica_criatura}
	manager._replicas_red_props_by_key = {"zona|prop": replica_prop}
	manager._runtime_state_by_key = {"0:0:criatura": {"health": 10}}
	manager._runtime_prop_state_by_key = {"0:0:prop": {"position": Vector2.ZERO}}
	manager._data_by_chunk = {
		Vector2i.ZERO: {
			"criaturas": [{"id": "criatura", "nested": {"health": 10}}],
			"props": [{"id": "prop", "nested": {"present": true}}]
		}
	}

	# El perfil expone costes separados sin asumir que ambos tipos
	# necesariamente estuvieron presentes en la última descarga.
	var perfil_despawn: Dictionary = manager.obtener_diagnostico_despawn()
	if not perfil_despawn.has("creatures") or not perfil_despawn.has("props"):
		errores.append("El diagnóstico de despawn no separó criaturas y props.")
	elif int(perfil_despawn["creatures"]["entities"]) != 0 or int(perfil_despawn["props"]["entities"]) != 0:
		errores.append("El diagnóstico de despawn no comenzó en cero.")

	# Un trabajo de descarga debe avanzar por lotes y mantener los flags del
	# chunk hasta terminar. Los Nodes genéricos se conservan como entidades
	# ajenas a Creature/WorldProp.
	var chunk_lote := Vector2i(7, -2)
	var lote_a := Node.new()
	var lote_b := Node.new()
	var lote_c := Node.new()
	manager._by_chunk[chunk_lote] = [lote_a, lote_b, lote_c]
	manager._active_chunks[chunk_lote] = true
	manager._active_creature_chunks[chunk_lote] = true
	manager._active_prop_chunks[chunk_lote] = true
	if not manager.iniciar_despawn_chunk(chunk_lote):
		errores.append("No se pudo iniciar el trabajo incremental de descarga.")
	if manager.procesar_despawn_chunk(chunk_lote, 1):
		errores.append("La descarga terminó antes de consumir el primer lote.")
	if int(manager._despawn_jobs[chunk_lote]["cursor"]) != 1:
		errores.append("El primer lote no procesó exactamente una entrada.")
	if not manager._active_chunks.has(chunk_lote):
		errores.append("El chunk perdió su estado activo antes de completar el despawn.")
	# Una transición LOD selectiva concurrente no debe cancelar el trabajo
	# completo que ya retirará ambos tipos de entidad.
	manager.despawn_props_chunk(chunk_lote)
	if not manager._despawn_jobs.has(chunk_lote) or int(manager._despawn_jobs[chunk_lote]["cursor"]) != 1:
		errores.append("Un despawn LOD selectivo canceló el trabajo incremental activo.")
	if manager.procesar_despawn_chunk(chunk_lote, 1):
		errores.append("La descarga terminó antes de consumir el segundo lote.")
	if not manager.procesar_despawn_chunk(chunk_lote, 1):
		errores.append("El último lote no completó la descarga.")
	if manager._despawn_jobs.has(chunk_lote):
		errores.append("El trabajo incremental permaneció registrado después de terminar.")
	if manager._by_chunk.get(chunk_lote, []).size() != 3:
		errores.append("La descarga perdió entidades ajenas al tipo Creature/WorldProp.")
	if manager._active_chunks.has(chunk_lote):
		errores.append("El chunk conservó su estado activo tras completar el despawn.")
	manager._by_chunk.erase(chunk_lote)
	lote_a.free()
	lote_b.free()
	lote_c.free()

	# La lectura predeterminada mantiene aislamiento profundo para consumidores
	# que puedan modificar los datos recibidos.
	var copia_profunda: Array = manager.obtener_datos_chunk(Vector2i.ZERO, "criaturas")
	(copia_profunda[0] as Dictionary)["nested"]["health"] = 1
	if int(manager._data_by_chunk[Vector2i.ZERO]["criaturas"][0]["nested"]["health"]) != 10:
		errores.append("La lectura profunda permitió mutar los datos internos.")

	# El modo superficial sólo comparte los Dictionaries; el materializador
	# debe duplicar cada registro antes de aplicar cambios runtime.
	var copia_superficial: Array = manager.obtener_datos_chunk(Vector2i.ZERO, "props", false)
	var prop_local: Dictionary = (copia_superficial[0] as Dictionary).duplicate(true)
	prop_local["nested"]["present"] = false
	if not bool(manager._data_by_chunk[Vector2i.ZERO]["props"][0]["nested"]["present"]):
		errores.append("La lectura superficial, usada con duplicación por registro, alteró los datos internos.")

	# El materializador de props sólo necesita presencia y posición. Su
	# snapshot no debe copiar el payload anidado de datos del objeto.
	manager._runtime_prop_state_by_key["0:0:prop"] = {
		"is_present": true,
		"position": Vector2(12.0, 24.0),
		"datos": {"nested": {"large_payload": [1, 2, 3]}}
	}
	var estado_prop_minimo: Dictionary = manager.obtener_estado_prop_materializacion(Vector2i.ZERO, "prop")
	if estado_prop_minimo.size() != 2 or not estado_prop_minimo.has("position") or not estado_prop_minimo.has("is_present"):
		errores.append("El snapshot de materialización de props incluyó campos innecesarios o perdió los requeridos.")
	if estado_prop_minimo.has("datos"):
		errores.append("El snapshot de materialización copió el payload completo del prop.")
	estado_prop_minimo["position"] = Vector2.ZERO
	if manager.obtener_estado_prop_materializacion(Vector2i.ZERO, "prop").get("position") != Vector2(12.0, 24.0):
		errores.append("Modificar el snapshot de materialización alteró el estado persistente.")
	manager._runtime_prop_state_by_key["0:0:prop_sin_posicion"] = {"is_present": true}
	var estado_sin_posicion: Dictionary = manager.obtener_estado_prop_materializacion(Vector2i.ZERO, "prop_sin_posicion")
	if estado_sin_posicion.has("position"):
		errores.append("El snapshot inventó una posición cuando el estado persistente no la tenía.")

	# Descargar todos los chunks debe invalidar el snapshot inmediatamente,
	# sin depender de que queue_free dispare tree_exiting al final del frame.
	manager._global_entities.clear()
	var chunk_cache := Vector2i(11, 4)
	var entidad_cache := Node.new()
	manager._by_chunk[chunk_cache] = [entidad_cache]
	manager._active_entities_cache_dirty = true
	if manager.obtener_entidades_activas().size() != 1:
		errores.append("El snapshot inicial no incluyó la entidad del chunk.")
	manager.despawn_entidades_de_chunks()
	if not manager.obtener_entidades_activas().is_empty():
		errores.append("La descarga global devolvió entidades desde un snapshot obsoleto.")

	manager.limpiar_todo()

	var registros: Array[Dictionary] = [
		manager._persistent_by_key,
		manager._persistent_keys_by_entity,
		manager._active_chunks,
		manager._active_creature_chunks,
		manager._active_prop_chunks,
		manager._replicas_red_by_key,
		manager._replicas_red_props_by_key,
		manager._runtime_state_by_key,
		manager._runtime_prop_state_by_key,
		manager._data_by_chunk
	]
	for registro in registros:
		if not registro.is_empty():
			errores.append("limpiar_todo dejó un registro interno con datos.")
			break
	if not manager._global_entities.is_empty():
		errores.append("limpiar_todo dejó entidades globales registradas.")

	manager.free()
	await get_tree().process_frame
	replica_prop.free()

	if not errores.is_empty():
		for error in errores:
			push_error("WorldEntityManagerReset: FAIL: " + error)
		get_tree().quit(1)
		return
	print("WorldEntityManagerReset: PASS")
	get_tree().quit(0)
