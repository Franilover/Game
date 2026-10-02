extends Node


signal mundo_listo
signal mundo_actualizado
signal error_mundo(mensaje: String)


const BUNDLED_WORLD_PATH := (
	"res://data/world_initial.json"
)

const USER_CACHE_PATH := (
	"user://cache/world_initial.json"
)


var mundo: Dictionary = {}
var cargado: bool = false

var _mundo_bloqueado: bool = false
var _mundo_pendiente: Dictionary = {}
var _firma_actual: String = ""


# Índices rápidos.
var _biomas_por_id: Dictionary = {}
var _ecosistemas_por_id: Dictionary = {}
var _habitats_por_id: Dictionary = {}
var _criaturas_por_id: Dictionary = {}


func _ready() -> void:
	if not SupabaseClient.mundo_cargado.is_connected(
		_al_mundo_remoto
	):
		SupabaseClient.mundo_cargado.connect(
			_al_mundo_remoto
		)

	if not SupabaseClient.error_conexion.is_connected(
		_al_error_remoto
	):
		SupabaseClient.error_conexion.connect(
			_al_error_remoto
		)

	_cargar_fuente_local()

	call_deferred(
		"_solicitar_actualizacion_remota"
	)


func _cargar_fuente_local() -> void:
	var cache := _leer_mundo_local(
		USER_CACHE_PATH,
		true
	)

	var incluido := _leer_mundo_local(
		BUNDLED_WORLD_PATH,
		false
	)

	if cache.is_empty() and incluido.is_empty():
		print(
			"WorldData: no existe snapshot local. "
			+ "Esperando Supabase."
		)
		return

	var elegido: Dictionary = incluido
	var origen := "snapshot incluido en el build"

	if elegido.is_empty():
		elegido = cache
		origen = "cache del jugador"
	elif not cache.is_empty():
		var fecha_cache := str(
			cache.get(
				"generado_en",
				""
			)
		)

		var fecha_incluido := str(
			elegido.get(
				"generado_en",
				""
			)
		)

		if (
			fecha_cache > fecha_incluido
			or fecha_cache == fecha_incluido
		):
			elegido = cache
			origen = "cache del jugador"

	_aplicar_mundo(
		elegido,
		origen,
		false
	)


func _leer_mundo_local(
	ruta: String,
	es_cache: bool
) -> Dictionary:
	if not FileAccess.file_exists(ruta):
		return {}

	var archivo := FileAccess.open(
		ruta,
		FileAccess.READ
	)

	if archivo == null:
		return {}

	var texto := archivo.get_as_text()
	archivo.close()

	var datos = JSON.parse_string(texto)

	if not datos is Dictionary:
		return {}

	var diccionario := datos as Dictionary

	# Los caches nuevos se guardan dentro de {"mundo": ...}.
	# También aceptamos el formato antiguo de cache directo.
	if es_cache and diccionario.has("mundo"):
		var mundo_cache: Variant = diccionario.get(
			"mundo",
			null
		)

		if mundo_cache is Dictionary:
			diccionario = mundo_cache as Dictionary

	if not _mundo_valido(diccionario):
		return {}

	return diccionario.duplicate(true)


func _solicitar_actualizacion_remota() -> void:
	SupabaseClient.iniciar_sincronizacion()


func _al_mundo_remoto(
	mundo_remoto: Dictionary
) -> void:
	if not _mundo_valido(mundo_remoto):
		return

	var firma := _calcular_firma(
		mundo_remoto
	)

	# Siempre guardamos una versión remota nueva para que
	# el siguiente arranque pueda usarla incluso offline.
	if firma != _firma_actual:
		_guardar_cache(
			mundo_remoto
		)

	if _mundo_bloqueado or _partida_activa():
		if firma == _firma_actual:
			return

		_mundo_pendiente = mundo_remoto.duplicate(true)

		print(
			"WorldData: actualización remota guardada "
			+ "para la próxima sesión."
		)

		return

	if firma == _firma_actual:
		return

	_aplicar_mundo(
		mundo_remoto,
		"Supabase",
		true
	)


func _partida_activa() -> bool:
	var escena := get_tree().current_scene

	if escena == null:
		return false

	return escena.get_node_or_null("World/WorldGenerator") != null


func _al_error_remoto(
	_mensaje: String
) -> void:
	# No se considera error de arranque si ya tenemos
	# un mundo local válido.
	if cargado:
		return

	error_mundo.emit(
		"No existe una copia local del mundo y "
		+ "Supabase no está disponible."
	)


func _aplicar_mundo(
	mundo_nuevo: Dictionary,
	origen: String,
	es_actualizacion: bool
) -> void:
	mundo = mundo_nuevo.duplicate(true)

	_construir_indices()

	_firma_actual = _calcular_firma(
		mundo
	)

	var era_cargado := cargado
	cargado = true

	print(
		"WorldData: mundo cargado desde ",
		origen,
		". Biomas = ",
		_biomas_por_id.size(),
		" | Ecosistemas = ",
		_ecosistemas_por_id.size(),
		" | Habitats = ",
		_habitats_por_id.size(),
		" | Criaturas = ",
		_criaturas_por_id.size()
	)

	if not era_cargado:
		mundo_listo.emit()
	elif es_actualizacion:
		mundo_actualizado.emit()


func _guardar_cache(
	datos: Dictionary
) -> void:
	var directorio := ProjectSettings.globalize_path(
		"user://cache"
	)

	DirAccess.make_dir_recursive_absolute(
		directorio
	)

	var archivo := FileAccess.open(
		USER_CACHE_PATH,
		FileAccess.WRITE
	)

	if archivo == null:
		print(
			"WorldData: no se pudo guardar el cache local."
		)
		return

	var envoltorio := {
		"guardado_en": Time.get_datetime_string_from_system(
			true
		),
		"mundo": datos.duplicate(true)
	}

	archivo.store_string(
		JSON.stringify(envoltorio)
	)

	archivo.close()

	print(
		"WorldData: cache local actualizado."
	)


func _mundo_valido(
	datos: Dictionary
) -> bool:
	if not datos.has("biomas"):
		return false

	if not datos["biomas"] is Array:
		return false

	return true


func _calcular_firma(
	datos: Dictionary
) -> String:
	var copia := datos.duplicate(true)

	copia.erase("generado_en")

	return JSON.stringify(
		copia
	)


func bloquear_actualizaciones() -> void:
	_mundo_bloqueado = true

	print(
		"WorldData: actualizaciones remotas bloqueadas "
		+ "para la sesión actual."
	)


func desbloquear_actualizaciones() -> void:
	_mundo_bloqueado = false

	if _mundo_pendiente.is_empty():
		return

	var pendiente := _mundo_pendiente.duplicate(true)
	_mundo_pendiente.clear()

	var firma := _calcular_firma(
		pendiente
	)

	if firma == _firma_actual:
		return

	_aplicar_mundo(
		pendiente,
		"Supabase pendiente",
		true
	)


func esta_bloqueado() -> bool:
	return _mundo_bloqueado


func _exit_tree() -> void:
	_mundo_bloqueado = false


# =========================================================
# CONSTRUCCIÓN DE ÍNDICES
# =========================================================

func _construir_indices() -> void:
	_biomas_por_id.clear()
	_ecosistemas_por_id.clear()
	_habitats_por_id.clear()
	_criaturas_por_id.clear()

	for bioma in obtener_biomas():
		if bioma is Dictionary:
			_indexar_bioma(bioma)

	for ecosistema in obtener_ecosistemas_sin_bioma():
		if ecosistema is Dictionary:
			_indexar_ecosistema(ecosistema)


func _indexar_bioma(
	bioma: Dictionary
) -> void:
	var bioma_id: String = str(
		bioma.get("id", "")
	)

	if bioma_id.is_empty():
		return

	_biomas_por_id[bioma_id] = bioma

	var ecosistemas: Array = bioma.get(
		"ecosistemas",
		[]
	)

	for ecosistema in ecosistemas:
		if ecosistema is Dictionary:
			_indexar_ecosistema(ecosistema)


func _indexar_ecosistema(
	ecosistema: Dictionary
) -> void:
	var ecosistema_id: String = str(
		ecosistema.get("id", "")
	)

	if ecosistema_id.is_empty():
		return

	_ecosistemas_por_id[ecosistema_id] = ecosistema

	var habitats: Array = ecosistema.get(
		"habitats",
		[]
	)

	for habitat in habitats:
		if habitat is Dictionary:
			_indexar_habitat(habitat)


func _indexar_habitat(
	habitat: Dictionary
) -> void:
	var habitat_id: String = str(
		habitat.get("id", "")
	)

	if habitat_id.is_empty():
		return

	_habitats_por_id[habitat_id] = habitat

	var criaturas: Array = habitat.get(
		"criaturas",
		[]
	)

	for criatura in criaturas:
		if criatura is Dictionary:
			_indexar_criatura(criatura)


func _indexar_criatura(
	criatura: Dictionary
) -> void:
	var criatura_id: String = str(
		criatura.get("id", "")
	)

	if criatura_id.is_empty():
		return

	_criaturas_por_id[criatura_id] = criatura


# =========================================================
# CONSULTAS
# =========================================================

func obtener_biomas() -> Array:
	return mundo.get(
		"biomas",
		[]
	)


func obtener_ecosistemas_sin_bioma() -> Array:
	return mundo.get(
		"ecosistemas_sin_bioma",
		[]
	)


func obtener_bioma(
	bioma_id: String
) -> Dictionary:
	return _biomas_por_id.get(
		bioma_id,
		{}
	)


func obtener_ecosistema(
	ecosistema_id: String
) -> Dictionary:
	return _ecosistemas_por_id.get(
		ecosistema_id,
		{}
	)


func obtener_habitat(
	habitat_id: String
) -> Dictionary:
	return _habitats_por_id.get(
		habitat_id,
		{}
	)


func obtener_criatura(
	criatura_id: String
) -> Dictionary:
	return _criaturas_por_id.get(
		criatura_id,
		{}
	)


func obtener_criaturas() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []

	for criatura_variant in _criaturas_por_id.values():
		if not criatura_variant is Dictionary:
			continue

		resultado.append(
			(criatura_variant as Dictionary).duplicate(true)
		)

	return resultado


func buscar_criatura_por_nombre(
	nombre: String
) -> Dictionary:
	var buscado := nombre.strip_edges().to_lower()

	if buscado.is_empty():
		return {}

	for criatura_variant in _criaturas_por_id.values():
		if not criatura_variant is Dictionary:
			continue

		var criatura := criatura_variant as Dictionary

		var nombre_criatura := str(
			criatura.get(
				"nombre",
				""
			)
		)

		if nombre_criatura.to_lower() == buscado:
			return criatura.duplicate(true)

	return {}


func obtener_ecosistemas_de_bioma(
	bioma_id: String
) -> Array:
	var bioma := obtener_bioma(bioma_id)

	if bioma.is_empty():
		return []

	return bioma.get(
		"ecosistemas",
		[]
	)


func obtener_habitats_de_ecosistema(
	ecosistema_id: String
) -> Array:
	var ecosistema := obtener_ecosistema(
		ecosistema_id
	)

	if ecosistema.is_empty():
		return []

	return ecosistema.get(
		"habitats",
		[]
	)


func obtener_criaturas_de_habitat(
	habitat_id: String
) -> Array:
	var habitat := obtener_habitat(
		habitat_id
	)

	if habitat.is_empty():
		return []

	return habitat.get(
		"criaturas",
		[]
	)


func esta_cargado() -> bool:
	return cargado
