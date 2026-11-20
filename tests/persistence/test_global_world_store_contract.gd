extends Node

const StoreScript = preload("res://scripts/infrastructure/global_world_store.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var ruta := "user://global_world_store_contract/world.json"
	var directorio := ruta.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directorio))
	var store: Variant = StoreScript.new()
	add_child(store)
	store._save_path = ruta

	var primero := {"version": 1, "world_seed": 111, "flags": {"zona": "torres"}}
	var segundo := {"version": 2, "world_seed": 222, "flags": {"zona": "bosque"}}
	if not store._escribir_guardado_global(primero):
		errores.append("No pudo escribir el primer guardado global.")
	if not store._escribir_guardado_global(segundo):
		errores.append("No pudo reemplazar el guardado global anterior.")
	if not _diccionario_coincide(store._leer_json_dictionary(ruta), segundo):
		errores.append("El segundo guardado no quedó publicado como archivo final.")
	if FileAccess.file_exists(ruta + ".bak") or FileAccess.file_exists(ruta + ".tmp"):
		errores.append("Una escritura correcta dejó restos temporales.")

	# Los tipos usados por el estado del mundo deben sobrevivir al JSON anidado.
	var valores_tipados := {
		"posicion": Vector2(12.5, 8.25),
		"tile": Vector2i(3, 4),
		"limites": Rect2(Vector2(1.0, 2.0), Vector2(30.0, 40.0)),
		"tono": Color(0.2, 0.4, 0.6, 1.0),
		"anidado": [{"desplazamiento": Vector2(-2.5, 7.25)}]
	}
	var valores_restaurados: Variant = store._decodificar_variante(store._serializar_variante(valores_tipados))
	if not valores_restaurados is Dictionary:
		errores.append("No restauró el contenedor de tipos del mundo.")
	else:
		var tipos := valores_restaurados as Dictionary
		if tipos.get("posicion") != Vector2(12.5, 8.25):
			errores.append("Vector2 no sobrevivió a la serialización del mundo.")
		if tipos.get("tile") != Vector2i(3, 4):
			errores.append("Vector2i no sobrevivió a la serialización del mundo.")
		if tipos.get("limites") != Rect2(Vector2(1.0, 2.0), Vector2(30.0, 40.0)):
			errores.append("Rect2 no sobrevivió a la serialización del mundo.")
		if tipos.get("tono") != Color(0.2, 0.4, 0.6, 1.0):
			errores.append("Color no sobrevivió a la serialización del mundo.")
		var anidado: Array = tipos.get("anidado", [])
		if anidado.is_empty() or (anidado[0] as Dictionary).get("desplazamiento") != Vector2(-2.5, 7.25):
			errores.append("Un tipo anidado dentro de un array no sobrevivió al roundtrip.")

	# Un destino de respaldo bloqueado debe impedir la escritura sin borrar el final.
	var ruta_backup := ruta + ".bak"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ruta_backup))
	if store._escribir_guardado_global({"version": 3}):
		errores.append("Aceptó reemplazar el mundo sin poder proteger el archivo anterior.")
	if not _diccionario_coincide(store._leer_json_dictionary(ruta), segundo):
		errores.append("El fallo al proteger el respaldo destruyó el último mundo válido.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta_backup))

	# Si el final está corrupto, el backup debe seguir siendo legible y recuperable.
	var respaldo := {"version": 4, "world_seed": 444}
	_escribir_texto(ruta_backup, JSON.stringify(respaldo))
	_escribir_texto(ruta, "{ JSON incompleto")
	if not _diccionario_coincide(store._leer_guardado_global(), respaldo):
		errores.append("No recuperó el mundo desde un respaldo válido.")
	if not _diccionario_coincide(store._leer_json_dictionary(ruta), respaldo):
		errores.append("La recuperación no restauró el archivo principal.")

	# La carga debe recuperar un backup incluso si el archivo principal falta.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	var respaldo_sin_final := {
		"version": 5,
		"world_seed": 555,
		"world_seed_valida": true,
		"elapsed_time": 12.5,
		"flags": {"zona_actual_tipo": "bosque"}
	}
	_escribir_texto(ruta_backup, JSON.stringify(respaldo_sin_final))
	var game_state: Variant = get_node_or_null("/root/GameState")
	if game_state == null or not store.restaurar_en_game_state(game_state):
		errores.append("No restauró el mundo cuando sólo quedaba un backup válido.")
	elif int(game_state.world_state.world_seed) != 555:
		errores.append("La recuperación desde backup no aplicó la semilla al GameState.")

	# Una apertura temporal fallida no debe pausar el mundo ni borrar el save.
	var ruta_temporal := ruta + ".tmp"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ruta_temporal))
	if store.guardar_desde_runtime():
		errores.append("Consideró exitoso el guardado con el temporal bloqueado.")
	if not _diccionario_coincide(store._leer_json_dictionary(ruta), respaldo_sin_final):
		errores.append("El guardado fallido alteró el archivo principal.")
	store.guardar_y_pausar()
	if get_tree().paused:
		errores.append("Pausó el mundo pese a no poder confirmar el guardado.")
	if not bool(store._pause_after_save_pending):
		errores.append("No dejó pendiente el reintento del guardado fallido.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta_temporal))
	store.guardar_y_pausar()
	if not get_tree().paused:
		errores.append("No pausó el mundo después de confirmar el reintento.")
	if bool(store._pause_after_save_pending):
		errores.append("Mantuvo un reintento pendiente después de guardar correctamente.")
	get_tree().paused = false

	store.queue_free()
	await get_tree().process_frame
	_eliminar_archivo(ruta)
	_eliminar_archivo(ruta + ".bak")
	_eliminar_archivo(ruta + ".tmp")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directorio))
	if not errores.is_empty():
		for error in errores:
			push_error("GlobalWorldStoreContract: FAIL: " + error)
		get_tree().quit(1)
		return
	print("GlobalWorldStoreContract: PASS")
	get_tree().quit(0)


func _diccionario_coincide(actual: Dictionary, esperado: Dictionary) -> bool:
	for clave in esperado:
		if actual.get(clave) != esperado.get(clave):
			return false
	return true


func _escribir_texto(ruta_archivo: String, contenido: String) -> void:
	var archivo := FileAccess.open(ruta_archivo, FileAccess.WRITE)
	if archivo == null:
		push_error("GlobalWorldStoreContract: no pudo escribir " + ruta_archivo)
		return
	archivo.store_string(contenido)
	archivo.flush()
	archivo.close()


func _eliminar_archivo(ruta_archivo: String) -> void:
	if FileAccess.file_exists(ruta_archivo):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta_archivo))
