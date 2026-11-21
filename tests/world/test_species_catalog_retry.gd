extends Node

const SupabaseClientScript = preload("res://scripts/infrastructure/supabase_client.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var cliente := SupabaseClientScript.new()
	var ruta_cache := "user://contracts/species_catalog_retry_cache.json"
	cliente.set("_ruta_cache_especies_jugables", ruta_cache)
	add_child(cliente)

	var emisiones: Array = []
	cliente.especies_jugables_cargadas.connect(func(especies: Array) -> void:
		emisiones.append(especies.duplicate(true))
	)

	var respuesta_valida := JSON.stringify([{
		"id": "especie-1",
		"clave": "humano",
		"nombre": "Humano",
		"orden": 1
	}]).to_utf8_buffer()
	cliente._al_completar_especies_jugables(
		HTTPRequest.RESULT_SUCCESS,
		200,
		PackedStringArray(),
		respuesta_valida
	)
	if cliente.obtener_especies_jugables().size() != 1:
		errores.append("La respuesta válida no se guardó en caché.")
	if emisiones.is_empty() or emisiones[0].size() != 1:
		errores.append("La respuesta válida no se notificó a las escenas.")

	# Simula un catálogo temporalmente vacío tras agotar los intentos rápidos.
	cliente._especies_jugables.clear()
	cliente._especies_jugables_remotas_cargadas = false
	cliente._intentos_especies_jugables = cliente.MAX_INTENTOS_INICIALES
	cliente._al_completar_especies_jugables(
		HTTPRequest.RESULT_SUCCESS,
		200,
		PackedStringArray(),
		"[]".to_utf8_buffer()
	)
	if not cliente._reintento_especies_programado:
		errores.append("Un catálogo vacío agotado no programó la comprobación de recuperación.")
	if emisiones.size() < 2 or not emisiones[emisiones.size() - 1].is_empty():
		errores.append("La escena no recibió el estado vacío mientras espera la recuperación.")

	cliente.queue_free()
	if FileAccess.file_exists(ruta_cache):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta_cache))
	if not errores.is_empty():
		for error in errores:
			push_error("SpeciesCatalogRetry: FAIL: " + error)
		get_tree().quit(1)
		return

	print("SpeciesCatalogRetry: PASS")
	get_tree().quit(0)
