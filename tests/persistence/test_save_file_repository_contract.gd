extends Node

const RepositoryScript = preload("res://scripts/infrastructure/save_file_repository.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var directorio := "user://save_repository_contract"
	var repository := RepositoryScript.new() as SaveFileRepository
	repository.configurar(directorio)

	if not repository.asegurar_directorio():
		errores.append("No se pudo preparar el directorio aislado de prueba.")
		_finalizar(errores)
		return

	var id := "contract_save"
	var estado_inicial := {"id": id, "version": 1, "estado": {"vida": 80}}
	var estado_nuevo := {"id": id, "version": 2, "estado": {"vida": 45}}

	if not repository.escribir_partida(id, estado_inicial):
		errores.append("No se pudo escribir el primer guardado.")
	elif repository.leer_partida(id) != estado_inicial:
		errores.append("El primer guardado no se pudo leer de forma idéntica.")

	if not repository.escribir_partida(id, estado_nuevo):
		errores.append("No se pudo reemplazar un guardado existente.")
	elif repository.leer_partida(id) != estado_nuevo:
		errores.append("El reemplazo no dejó el estado nuevo como archivo final.")

	var ruta := repository.ruta_partida(id)
	if FileAccess.file_exists(ruta + ".bak"):
		errores.append("Quedó un respaldo temporal después de una escritura correcta.")
	if FileAccess.file_exists(ruta + ".tmp"):
		errores.append("Quedó un temporal después de una escritura correcta.")

	# Simula una interrupción después de dejar un archivo final corrupto,
	# pero conservando el último JSON válido en el respaldo.
	_escribir_texto(ruta + ".bak", JSON.stringify(estado_inicial))
	_escribir_texto(ruta, "{ JSON interrumpido")
	var recuperado := repository.leer_partida(id)
	if recuperado != estado_inicial:
		errores.append("No se recuperó el último guardado válido desde .bak.")
	if repository.leer_partida(id) != estado_inicial:
		errores.append("La recuperación no restauró un archivo final legible.")

	if not repository.ruta_partida("../fuera").is_empty():
		errores.append("Se aceptó un ID de partida con traversal de rutas.")
	if repository.escribir_partida("", estado_nuevo):
		errores.append("Se aceptó un ID vacío.")
	if repository.escribir_partida("empty_payload", {}):
		errores.append("Se aceptó un payload vacío.")

	# El borrado también limpia restos de una transacción interrumpida.
	_escribir_texto(ruta + ".tmp", "temporal")
	_escribir_texto(ruta + ".bak", JSON.stringify(estado_inicial))
	if not repository.eliminar_partida(id):
		errores.append("No se pudo eliminar la partida de prueba.")
	if (
		FileAccess.file_exists(ruta)
		or FileAccess.file_exists(ruta + ".tmp")
		or FileAccess.file_exists(ruta + ".bak")
	):
		errores.append("Eliminar la partida dejó archivos de transacción.")

	_eliminar_directorio(directorio)
	_finalizar(errores)


func _escribir_texto(ruta: String, contenido: String) -> void:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_error("SaveFileRepositoryContract: no se pudo crear " + ruta)
		return
	archivo.store_string(contenido)
	archivo.flush()
	archivo.close()


func _eliminar_directorio(ruta: String) -> void:
	var directorio_absoluto := ProjectSettings.globalize_path(ruta)
	if not DirAccess.dir_exists_absolute(directorio_absoluto):
		return
	DirAccess.remove_absolute(directorio_absoluto)


func _finalizar(errores: Array[String]) -> void:
	if not errores.is_empty():
		for error in errores:
			push_error("SaveFileRepositoryContract: FAIL: " + error)
		get_tree().quit(1)
		return
	print("SaveFileRepositoryContract: PASS")
	get_tree().quit(0)
