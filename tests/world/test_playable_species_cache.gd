extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var client := get_node_or_null("/root/SupabaseClient")
	if client == null:
		_fail("No existe el autoload SupabaseClient.")
		return

	var ruta := "user://contracts/playable_species_cache_contract.json"
	var ruta_absoluta := ProjectSettings.globalize_path(ruta)
	var directorio := DirAccess.make_dir_recursive_absolute(ruta_absoluta.get_base_dir())
	if directorio != OK and directorio != ERR_ALREADY_EXISTS:
		_fail("No se pudo preparar el directorio temporal.")
		return

	var originales: Array = client.call("obtener_especies_jugables")
	var remotas_original: bool = bool(client.get("_especies_jugables_remotas_cargadas"))
	var canonicas := [{
		"id": "offline_species_cache_probe",
		"clave": "humano",
		"nombre": "Humano",
		"clado_id": null,
		"orden": 1
	}]
	var entrada := canonicas.duplicate(true)
	entrada.append({"nombre": "Registro incompleto"})
	entrada.append("dato inválido")

	if not bool(client.call("_guardar_cache_especies_jugables", entrada, ruta)):
		_fail("No se pudo escribir la caché temporal de especies.")
		return

	client.set("_especies_jugables", [])
	if not bool(client.call("_cargar_cache_especies_jugables", ruta)):
		_fail("No se pudo recuperar el catálogo guardado.")
		return

	if bool(client.get("_especies_jugables_remotas_cargadas")):
		_fail("Leer la caché marcó el catálogo como sincronizado con Supabase.")
		return

	var recuperadas: Array = client.call("obtener_especies_jugables")
	if recuperadas.size() != 1:
		_fail("La caché no filtró los registros incompletos.")
		return
	var especie: Dictionary = recuperadas[0] as Dictionary
	if str(especie.get("id", "")) != "offline_species_cache_probe":
		_fail("La identidad de especie no sobrevivió a la caché.")
		return
	if str(especie.get("clave", "")) != "humano" or str(especie.get("nombre", "")) != "Humano":
		_fail("Los campos del catálogo no sobrevivieron a la caché.")
		return

	var corrupto := FileAccess.open(ruta, FileAccess.WRITE)
	if corrupto == null:
		_fail("No se pudo preparar el caso de caché corrupta.")
		return
	corrupto.store_string("{json inválido")
	corrupto.close()
	if bool(client.call("_cargar_cache_especies_jugables", ruta)):
		_fail("Se aceptó una caché JSON corrupta.")
		return
	var tras_corrupcion: Array = client.call("obtener_especies_jugables")
	if tras_corrupcion.size() != 1:
		_fail("Una caché corrupta borró el catálogo válido en memoria.")
		return

	client.set("_especies_jugables", originales)
	client.set("_especies_jugables_remotas_cargadas", remotas_original)
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ruta_absoluta)
	print("PlayableSpeciesCache: PASS roundtrip=true invalid_entries_filtered=true corrupt_cache_safe=true")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("PlayableSpeciesCache: FAIL: " + message)
	get_tree().quit(1)
