extends Node

const WorldDataScript = preload("res://scripts/world/world_data.gd")
const ValidatorScript = preload("res://scripts/state/world_snapshot_validator.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if not FileAccess.file_exists("res://data/world_initial.json"):
		_fail("El build no incluye data/world_initial.json.")
		return

	var bundled := WorldDataScript.new() as WorldDataService
	if bundled == null:
		_fail("No se pudo instanciar WorldDataService.")
		return
	add_child(bundled)
	bundled._cargar_fuente_local()
	if not bundled.esta_cargado():
		_fail("WorldData no cargó el snapshot incluido sin depender de Supabase.")
		return
	if not ValidatorScript.es_valido(bundled.mundo):
		_fail("El snapshot incluido no supera el validador canónico.")
		return
	if bundled.get("_supabase_client") != null:
		_fail("La prueba offline conectó accidentalmente un cliente remoto.")
		return

	var biomas_variant: Variant = bundled.mundo.get("biomas", [])
	if not biomas_variant is Array or (biomas_variant as Array).is_empty():
		_fail("El snapshot local no contiene biomas utilizables.")
		return
	var biomas: Array = biomas_variant as Array
	var ecosistemas := 0
	var criaturas := 0
	for bioma_variant in biomas:
		if not bioma_variant is Dictionary:
			continue
		for ecosistema_variant in (bioma_variant as Dictionary).get("ecosistemas", []):
			if not ecosistema_variant is Dictionary:
				continue
			ecosistemas += 1
			for habitat_variant in (ecosistema_variant as Dictionary).get("habitats", []):
				if habitat_variant is Dictionary:
					criaturas += ((habitat_variant as Dictionary).get("criaturas", []) as Array).size()
	if ecosistemas <= 0:
		_fail("El snapshot local no contiene ecosistemas utilizables.")
		return
	if criaturas <= 0:
		_fail("El snapshot local no contiene criaturas utilizables.")
		return

	var contract_dir := ProjectSettings.globalize_path("user://contracts")
	DirAccess.make_dir_recursive_absolute(contract_dir)
	var cache_path := "user://contracts/offline_world_snapshot_cache.json"
	var cache_file := FileAccess.open(cache_path, FileAccess.WRITE)
	if cache_file == null:
		_fail("No se pudo preparar la caché local temporal.")
		return
	cache_file.store_string(JSON.stringify({"mundo": bundled.mundo.duplicate(true)}))
	cache_file.close()

	var cache_loaded := WorldDataScript.new() as WorldDataService
	cache_loaded.name = "WorldDataCacheOnly"
	add_child(cache_loaded)
	var local_cache := cache_loaded._leer_mundo_local(cache_path, true)
	if local_cache.is_empty() or not ValidatorScript.es_valido(local_cache):
		_fail("La lectura de caché local no aceptó el formato {mundo: ...}.")
		return

	DirAccess.remove_absolute(ProjectSettings.globalize_path(cache_path))
	print("OfflineWorldSnapshot: PASS bundled=true cache=true biomes=%d ecosystems=%d creatures=%d" % [biomas.size(), ecosistemas, criaturas])
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("OfflineWorldSnapshot: FAIL: " + message)
	get_tree().quit(1)
