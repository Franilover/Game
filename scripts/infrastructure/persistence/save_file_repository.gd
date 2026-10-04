extends RefCounted
class_name SaveFileRepository

## Persistencia local de archivos de partida.
## No interpreta reglas de gameplay ni modifica el estado activo.

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
	return directorio + "/" + id + ".json"


func leer_partida(id: String) -> Dictionary:
	if id.is_empty():
		return {}

	var ruta := ruta_partida(id)
	if not FileAccess.file_exists(ruta):
		return {}

	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return {}

	var texto := archivo.get_as_text()
	archivo.close()

	var datos: Variant = JSON.parse_string(texto)
	if not datos is Dictionary:
		return {}

	return (datos as Dictionary).duplicate(true)


func escribir_partida(id: String, datos: Dictionary) -> bool:
	if id.is_empty():
		return false

	if not asegurar_directorio():
		return false

	var ruta := ruta_partida(id)
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_error(
			"SaveFileRepository: no se pudo abrir el archivo de partida: "
			+ ruta
		)
		return false

	archivo.store_string(JSON.stringify(datos))
	archivo.close()
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
		resultado.append(nombre_archivo.trim_suffix(".json"))
	entrada.list_dir_end()
	return resultado


func eliminar_partida(id: String) -> bool:
	if id.is_empty():
		return false

	var ruta := ruta_partida(id)
	if not FileAccess.file_exists(ruta):
		return false

	var error := DirAccess.remove_absolute(
		ProjectSettings.globalize_path(ruta)
	)
	if error != OK:
		push_error(
			"SaveFileRepository: no se pudo eliminar la partida "
			+ id
			+ " (error "
			+ str(error)
			+ ")"
		)
		return false
	return true
