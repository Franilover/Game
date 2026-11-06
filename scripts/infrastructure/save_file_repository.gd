extends RefCounted
class_name SaveFileRepository

## Persistencia local de archivos de partida.
## No interpreta reglas de gameplay ni modifica el estado activo.
##
## Las escrituras se preparan en un temporal, se validan como JSON y se
## reemplaza el archivo final conservando un respaldo recuperable.

var directorio: String = "user://partidas"


func configurar(ruta_directorio: String) -> void:
	directorio = ruta_directorio.strip_edges()
	if directorio.is_empty():
		directorio = "user://partidas"


func asegurar_directorio() -> bool:
	var error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directorio)
	)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error(
			"SaveFileRepository: no se pudo crear el directorio de partidas: "
			+ directorio
		)
		return false
	return true


func ruta_partida(id: String) -> String:
	if not _id_valido(id):
		return ""
	return directorio + "/" + id + ".json"


func leer_partida(id: String) -> Dictionary:
	var ruta := ruta_partida(id)
	if ruta.is_empty():
		return {}

	var datos := _leer_json_dictionary(ruta)
	if not datos.is_empty():
		return datos

	var ruta_respaldo := _ruta_respaldo(ruta)
	var respaldo := _leer_json_dictionary(ruta_respaldo)
	if respaldo.is_empty():
		return {}

	# Recupera el último save confirmado si el archivo final quedó truncado
	# o si el proceso se interrumpió durante el reemplazo.
	if FileAccess.file_exists(ruta):
		_eliminar_archivo(ruta)
	if _renombrar_archivo(ruta_respaldo, ruta):
		push_warning(
			"SaveFileRepository: partida recuperada desde respaldo → " + id
		)
	return respaldo


func escribir_partida(id: String, datos: Dictionary) -> bool:
	var ruta := ruta_partida(id)
	if ruta.is_empty() or datos.is_empty():
		return false

	if not asegurar_directorio():
		return false

	# Si una escritura anterior fue interrumpida, intenta restaurar primero
	# el respaldo antes de iniciar una nueva transacción.
	leer_partida(id)

	var ruta_temporal := _ruta_temporal(ruta)
	var ruta_respaldo := _ruta_respaldo(ruta)
	_eliminar_archivo(ruta_temporal)

	var archivo := FileAccess.open(ruta_temporal, FileAccess.WRITE)
	if archivo == null:
		push_error(
			"SaveFileRepository: no se pudo abrir el temporal de partida: "
			+ ruta_temporal
		)
		return false

	archivo.store_string(JSON.stringify(datos))
	archivo.flush()
	var error_escritura := archivo.get_error()
	archivo.close()

	if error_escritura != OK:
		_eliminar_archivo(ruta_temporal)
		push_error(
			"SaveFileRepository: error al escribir el temporal ("
			+ str(error_escritura)
			+ ")"
		)
		return false

	# Nunca se promueve un temporal que no pueda volver a leerse como JSON.
	if _leer_json_dictionary(ruta_temporal).is_empty():
		_eliminar_archivo(ruta_temporal)
		push_error(
			"SaveFileRepository: el temporal no superó la validación JSON."
		)
		return false

	_eliminar_archivo(ruta_respaldo)
	var habia_partida_previa := FileAccess.file_exists(ruta)
	if habia_partida_previa and not _renombrar_archivo(ruta, ruta_respaldo):
		_eliminar_archivo(ruta_temporal)
		push_error(
			"SaveFileRepository: no se pudo proteger la partida anterior."
		)
		return false

	if not _renombrar_archivo(ruta_temporal, ruta):
		if habia_partida_previa and FileAccess.file_exists(ruta_respaldo):
			_renombrar_archivo(ruta_respaldo, ruta)
		_eliminar_archivo(ruta_temporal)
		push_error(
			"SaveFileRepository: no se pudo promover el temporal al archivo final."
		)
		return false

	if _leer_json_dictionary(ruta).is_empty():
		_eliminar_archivo(ruta)
		if habia_partida_previa and FileAccess.file_exists(ruta_respaldo):
			_renombrar_archivo(ruta_respaldo, ruta)
		push_error(
			"SaveFileRepository: la partida final no superó la validación JSON."
		)
		return false

	_eliminar_archivo(ruta_respaldo)
	return true


func listar_ids_partidas() -> Array[String]:
	var resultado: Array[String] = []
	var entrada := DirAccess.open(directorio)
	if entrada == null:
		return resultado

	entrada.list_dir_begin()
	while true:
		var nombre_archivo := entrada.get_next()
		if nombre_archivo.is_empty():
			break
		if entrada.current_is_dir() or not nombre_archivo.ends_with(".json"):
			continue
		var id := nombre_archivo.trim_suffix(".json")
		if _id_valido(id):
			resultado.append(id)
	entrada.list_dir_end()
	return resultado


func eliminar_partida(id: String) -> bool:
	var ruta := ruta_partida(id)
	if ruta.is_empty():
		return false

	var existia_archivo := FileAccess.file_exists(ruta)
	var existia_respaldo := FileAccess.file_exists(_ruta_respaldo(ruta))
	var existia_temporal := FileAccess.file_exists(_ruta_temporal(ruta))
	if not existia_archivo and not existia_respaldo and not existia_temporal:
		return false

	var correcto := true
	if existia_archivo:
		correcto = _eliminar_archivo(ruta) and correcto
	if existia_respaldo:
		correcto = _eliminar_archivo(_ruta_respaldo(ruta)) and correcto
	if existia_temporal:
		correcto = _eliminar_archivo(_ruta_temporal(ruta)) and correcto
	return correcto


func _id_valido(id: String) -> bool:
	if id.is_empty():
		return false
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9_-]+$")
	return regex.search(id) != null


func _ruta_temporal(ruta: String) -> String:
	return ruta + ".tmp"


func _ruta_respaldo(ruta: String) -> String:
	return ruta + ".bak"


func _leer_json_dictionary(ruta: String) -> Dictionary:
	if ruta.is_empty() or not FileAccess.file_exists(ruta):
		return {}

	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return {}

	var texto := archivo.get_as_text()
	archivo.close()
	var datos: Variant = JSON.parse_string(texto)
	if not datos is Dictionary:
		return {}
	var resultado := (datos as Dictionary).duplicate(true)
	if resultado.is_empty():
		return {}
	return resultado


func _renombrar_archivo(origen: String, destino: String) -> bool:
	var error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(origen),
		ProjectSettings.globalize_path(destino)
	)
	return error == OK


func _eliminar_archivo(ruta: String) -> bool:
	if not FileAccess.file_exists(ruta):
		return true
	var error := DirAccess.remove_absolute(
		ProjectSettings.globalize_path(ruta)
	)
	if error != OK:
		push_error(
			"SaveFileRepository: no se pudo eliminar archivo ("
			+ str(error)
			+ "): "
			+ ruta
		)
		return false
	return true
