extends Node

const StoreScript = preload("res://scripts/infrastructure/global_world_store.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var ruta := "user://global_world_store_contract/world.json"
	var ruta_absoluta := ProjectSettings.globalize_path(ruta)
	var directorio := ruta.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directorio))
	var store := StoreScript.new() as Node
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

	# Una apertura temporal fallida no debe pausar el mundo ni borrar el save.
	var ruta_temporal := ruta + ".tmp"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ruta_temporal))
	if store.guardar_desde_runtime():
		errores.append("Consideró exitoso el guardado con el temporal bloqueado.")
	if not _diccionario_coincide(store._leer_json_dictionary(ruta), respaldo):
		errores.append("El guardado fallido alteró el archivo principal.")
	store.guardar_y_pausar()
	if get_tree().paused:
		errores.append("Pausó el mundo pese a no poder confirmar el guardado.")
	get_tree().paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta_temporal))

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
