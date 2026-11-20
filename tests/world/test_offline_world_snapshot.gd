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
	if not ValidatorScript.is_valid(bundled.mundo):
		_fail("El snapshot incluido no supera el validador canónico.")
		return
	if bundled.get("_supabase_client") != null:
		_fail("La prueba offline conectó accidentalmente un cliente remoto.")
		return

	var biomas := bundled.mundo.get("biomas", [])
	var ecosistemas := bundled.mundo.get("ecosistemas", [])
	var criaturas := bundled.mundo.get("criaturas", [])
	if not biomas is Array or biomas.is_empty():
		_fail("El snapshot local no contiene biomas utilizables.")
		return
	if not ecosistemas is Array or ecosistemas.is_empty():
		_fail("El snapshot local no contiene ecosistemas utilizables.")
		return
	if not criaturas is Array or criaturas.is_empty():
		_fail("El snapshot local no contiene criaturas utilizables.")
		return

	var cache_dir := ProjectSettings.globalize_path("user://cache")
	if not DirAccess.dir_exists_absolute(cache_dir):
		DirAccess.make_dir_recursive_absolute(cache_dir)
	var cache_path := ProjectSettings.globalize_path("user://cache/world_initial.json")
	if FileAccess.file_exists("user://cache/world_initial.json"):
		DirAccess.remove_absolute(cache_path)

	var cache_only := WorldDataScript.new() as WorldDataService
	cache_only.name = "WorldDataCacheOnlyProbe"
	add_child(cache_only)
	var wrapper := {"mundo": bundled.mundo.duplicate(true)}
	var cache_file := FileAccess.open("user://cache/world_initial.json", FileAccess.WRITE)
	if cache_file == null:
		_fail("No se pudo preparar la caché local para probar la ruta alternativa.")
		return
	cache_file.store_string(JSON.stringify(wrapper))
	cache_file.close()

	var cache_loaded := WorldDataScript.new() as WorldDataService
	cache_loaded.name = "WorldDataCacheOnly"
	add_child(cache_loaded)
	var local_cache := cache_loaded._leer_mundo_local("user://cache/world_initial.json", true)
	if local_cache.is_empty() or not ValidatorScript.is_valid(local_cache):
		_fail("La lectura de caché local no aceptó el formato {mundo: ...}.")
		return

	print("OfflineWorldSnapshot: PASS bundled=true cache=true biomes=%d ecosystems=%d creatures=%d" % [biomas.size(), ecosistemas.size(), criaturas.size()])
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("OfflineWorldSnapshot: FAIL: " + message)
	get_tree().quit(1)
