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
