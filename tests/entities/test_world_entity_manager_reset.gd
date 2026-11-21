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
