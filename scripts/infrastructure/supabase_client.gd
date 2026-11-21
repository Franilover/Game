extends Node
class_name GarliaSupabaseClient

const WorldSnapshotValidatorScript = preload("res://scripts/state/world_snapshot_validator.gd")

signal relaciones_ecologicas_cargadas(relaciones: Array)
signal reinos_game_cargados(reinos: Array)
signal mundo_cargado(datos: Dictionary)
signal eterium_runtime_cargado(datos: Dictionary)
signal especies_jugables_cargadas(especies: Array)
signal especie_eterium_game_cargado(reglas: Array)
signal personaje_social_cargado(reglas: Array)
signal personaje_regalos_cargados(regalos: Array)
signal error_conexion(mensaje: String)
signal request_completed(request_id: int, resultado: int, codigo_http: int, cabeceras: PackedStringArray, cuerpo: PackedByteArray)



const RPC_MUNDO := (
	"/rest/v1/rpc/get_mundo_inicial_ambiental_v3"
)


const HTTP_TIMEOUT: float = 20.0
const MAX_INTENTOS_INICIALES: int = 3
const RETRASO_REINTENTO: float = 1.5
const INTERVALO_REINTENTO_ESPECIES: float = 30.0
const INTERVALO_SINCRONIZACION: float = 60.0
const RPC_ETERIUM_RUNTIME := (
	"/rest/v1/rpc/get_eterium_runtime_v1"
)
const API_ESPECIES_JUGABLES := (
	"/rest/v1/especies_jugables?select=id,clave,nombre,clado_id,orden&activo=eq.true&order=orden.asc"
)
const CACHE_ESPECIES_JUGABLES_PATH := "user://cache/especies_jugables.json"
const CACHE_ESPECIES_JUGABLES_VERSION := 1
const API_PERSONAJE_REGALOS := (
	"/rest/v1/personaje_regalos_v1?select=id,personaje_game_id,item_id,reaccion,amistad,confianza,respeto,afecto,activo&activo=eq.true"
)
const API_PERSONAJE_SOCIAL := (
	"/rest/v1/personaje_social_v1?select=personaje_game_id,amistad_inicial,confianza_inicial,respeto_inicial,afecto_inicial,sociabilidad,curiosidad,generosidad,prudencia,agresividad,activo,personajes_game(nombre)&activo=eq.true"
)
const API_ESPECIE_ETERIUM_GAME := (
	"/rest/v1/especie_eterium_game?select=especie_eterium_id,vida_eterium_compartidos,recuperacion_eterium,eterium_inicial,activo,especie_eterium_v1!inner(especie_id,capacidad_base)&activo=eq.true"
)
const API_REINOS_GAME := (
	"/rest/v1/reinos_game?select=id,reino_id,clave,activo,orden,propiedades&activo=eq.true&order=orden.asc"
)
const API_RELACIONES_ECOLOGICAS := (
	"/rest/v1/ecosistema_relaciones_criaturas?select=ecosistema_id,criatura_origen_id,criatura_destino_id,tipo_relacion,descripcion,origen,"
	+ "criatura_origen:criaturas!ecosistema_relaciones_criaturas_criatura_origen_id_fkey(id,nombre),"
	+ "criatura_destino:criaturas!ecosistema_relaciones_criaturas_criatura_destino_id_fkey(id,nombre)"
)


var _http: HTTPRequest
var _http_eterium: HTTPRequest
var _http_especies: HTTPRequest
var _http_especie_eterium_game: HTTPRequest
var _http_personaje_social: HTTPRequest
var _http_personaje_regalos: HTTPRequest
var _http_relaciones_ecologicas: HTTPRequest
var _http_reinos_game: HTTPRequest
var _next_request_id: int = 1
var _timer: Timer
var _solicitud_en_curso: bool = false
var _intento_actual: int = 0
var _sincronizacion_inicial_realizada: bool = false
var _eterium_runtime: Dictionary = {}
var _especie_eterium_game: Array = []
var _especie_eterium_game_cargado: bool = false
var _especies_jugables: Array = []
var _intentos_especies_jugables: int = 0
var _reintento_especies_programado: bool = false
var _personaje_social: Array = []
var _personaje_regalos: Array = []
var _relaciones_ecologicas: Array = []
var _reinos_game: Array = []
var _mundo_activo_en_escena: bool = false
var _auth: GarliaAuth = null


func configurar_dependencias(auth: GarliaAuth) -> void:
	_auth = auth
	if not _auth.login_succeeded.is_connected(_al_login_succeeded):
		_auth.login_succeeded.connect(_al_login_succeeded)
	if not _auth.session_restored.is_connected(_al_session_restored):
		_auth.session_restored.connect(_al_session_restored)

	# La dependencia puede inyectarse después del _ready del autoload.
	# La sesión puede terminar de restaurarse después de que los primeros
	# intentos de carga hayan salido; cubrimos también ese orden de arranque.
	if is_inside_tree():
		call_deferred("cargar_especies_jugables")
		if _auth.esta_autenticado():
			call_deferred("_cargar_catalogos_autenticados")


func _al_login_succeeded(_perfil: Dictionary) -> void:
	_cargar_catalogos_autenticados()


func _al_session_restored() -> void:
	_cargar_catalogos_autenticados()


func _cargar_catalogos_autenticados() -> void:
	if _auth == null or not _auth.esta_autenticado():
		return

	cargar_eterium_runtime()
	cargar_especie_eterium_game()
	cargar_personaje_social()
	cargar_personaje_regalos()
	cargar_relaciones_ecologicas()
	cargar_reinos_game()


func establecer_mundo_activo(activo: bool) -> void:
	_mundo_activo_en_escena = activo


func _ready() -> void:
	_http = _crear_http_request()
	_http.request_completed.connect(_al_completar_solicitud)

	_http_eterium = _crear_http_request()
	_http_eterium.request_completed.connect(_al_completar_eterium_runtime)

	_http_especies = _crear_http_request()
	_http_especies.request_completed.connect(_al_completar_especies_jugables)

	_http_especie_eterium_game = _crear_http_request()
	_http_especie_eterium_game.request_completed.connect(_al_completar_especie_eterium_game)

	_http_personaje_social = _crear_http_request()
	_http_personaje_social.request_completed.connect(_al_completar_personaje_social)

	_http_personaje_regalos = _crear_http_request()
	_http_personaje_regalos.request_completed.connect(_al_completar_personaje_regalos)

	_http_relaciones_ecologicas = _crear_http_request()
	_http_relaciones_ecologicas.request_completed.connect(_al_completar_relaciones_ecologicas)

	_http_reinos_game = _crear_http_request()
	_http_reinos_game.request_completed.connect(_al_completar_reinos_game)

	_cargar_cache_especies_jugables()
	call_deferred("cargar_eterium_runtime")
	call_deferred("cargar_especie_eterium_game")
	call_deferred("cargar_personaje_social")
	call_deferred("cargar_personaje_regalos")
	call_deferred("cargar_especies_jugables")
	call_deferred("cargar_relaciones_ecologicas")
	call_deferred("cargar_reinos_game")

	_timer = Timer.new()
	_timer.wait_time = INTERVALO_SINCRONIZACION
	_timer.one_shot = true
	add_child(_timer)

	_timer.timeout.connect(
		_al_timer_sincronizacion
	)


func _crear_headers() -> PackedStringArray:
	if _auth == null:
		return PackedStringArray()

	return PackedStringArray([
		"apikey: " + _auth.SUPABASE_PUBLISHABLE_KEY,
		"Content-Type: application/json",
		"Accept: application/json"
	])


func _crear_http_request() -> HTTPRequest:
	var request := HTTPRequest.new()
	request.timeout = HTTP_TIMEOUT
	add_child(request)
	return request


## Transporte REST/RPC compartido para repositories.
func solicitar_rpc(nombre: String, payload: Dictionary = {}) -> int:
	if not _esta_configurado():
		push_error("SupabaseClient: GarliaAuth no configurado.")
		return -1

	return _request_compartido("/rest/v1/rpc/" + nombre, HTTPClient.METHOD_POST, JSON.stringify(payload))

func get_rest(recurso: String, query: String = "") -> int:
	var path := "/rest/v1/" + recurso
	if not query.is_empty():
		path += "?" + query
	return _request_compartido(path, HTTPClient.METHOD_GET, "")

func _request_compartido(path: String, method: int, body: String) -> int:
	if not _esta_configurado():
		push_error("SupabaseClient: no se puede realizar la solicitud sin GarliaAuth.")
		return -1

	var request_id := _next_request_id
	_next_request_id += 1
	var http := HTTPRequest.new()
	http.timeout = HTTP_TIMEOUT
	add_child(http)
	var callback := func(resultado: int, codigo_http: int, cabeceras: PackedStringArray, cuerpo: PackedByteArray) -> void:
		request_completed.emit(request_id, resultado, codigo_http, cabeceras, cuerpo)
		http.queue_free()
	http.request_completed.connect(callback, CONNECT_ONE_SHOT)
	var resultado := http.request(_auth.SUPABASE_URL + path, _crear_headers(), method, body)
	if resultado != OK:
		http.queue_free()
		call_deferred("_emitir_request_fallida", request_id)
	return request_id

func _emitir_request_fallida(request_id: int) -> void:
	request_completed.emit(request_id, HTTPRequest.RESULT_REQUEST_FAILED, 0, PackedStringArray(), PackedByteArray())


func obtener_diagnostico_debug() -> Dictionary:
	var auth_ok: bool = _auth != null
	var configurado: bool = _esta_configurado()
	var autenticado: bool = _auth != null and _auth.esta_autenticado()
	var solicitudes: Array[Dictionary] = []
	for par in [
		["mundo", _http],
		["eterium", _http_eterium],
		["especies", _http_especies],
		["especie_eterium_game", _http_especie_eterium_game],
		["personaje_social", _http_personaje_social],
		["personaje_regalos", _http_personaje_regalos],
		["relaciones_ecologicas", _http_relaciones_ecologicas],
		["reinos_game", _http_reinos_game]
	]:
		var nombre: String = str(par[0])
		var request: HTTPRequest = par[1] as HTTPRequest
		solicitudes.append({
			"nombre": nombre,
			"existe": is_instance_valid(request),
			"estado": request.get_http_client_status() if is_instance_valid(request) else -1
		})
	return {
		"auth_node": auth_ok,
		"configurado": configurado,
		"autenticado": autenticado,
		"url_configurada": _auth != null and not _auth.SUPABASE_URL.is_empty(),
		"publishable_key_configurada": _auth != null and not _auth.SUPABASE_PUBLISHABLE_KEY.is_empty(),
		"supabase_url": _auth.SUPABASE_URL if _auth != null else "<sin auth>",
		"requests": solicitudes,
		"cache": {
			"reinos_game": _reinos_game.size(),
			"especies_jugables": _especies_jugables.size(),
			"especie_eterium_game": _especie_eterium_game.size(),
			"personaje_social": _personaje_social.size(),
			"personaje_regalos": _personaje_regalos.size(),
			"relaciones_ecologicas": _relaciones_ecologicas.size(),
			"eterium_runtime": not _eterium_runtime.is_empty(),
			"mundo_activo": _mundo_activo_en_escena
		}
	}

func probar_conexion_debug() -> int:
	if not _esta_configurado():
		return -1
	return get_rest("reinos_game", "select=id,clave,activo,orden&activo=eq.true&limit=1")

func _esta_configurado() -> bool:
	return _auth != null and not _auth.SUPABASE_URL.is_empty() and not _auth.SUPABASE_PUBLISHABLE_KEY.is_empty()


func cargar_relaciones_ecologicas() -> void:
	if _auth == null or not _auth.esta_autenticado():
		return
	if _http_relaciones_ecologicas == null:
		return
	if _http_relaciones_ecologicas.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	var headers := _crear_headers()

	var resultado := _http_relaciones_ecologicas.request(
		_auth.SUPABASE_URL + API_RELACIONES_ECOLOGICAS,
		headers,
		HTTPClient.METHOD_GET
	)

	if resultado != OK:
		print(
			"SupabaseClient: no se pudo solicitar relaciones ecológicas → ",
			resultado
		)


func _al_completar_relaciones_ecologicas(
	resultado: int,
	codigo_http: int,
	_cabeceras: PackedStringArray,
	cuerpo: PackedByteArray
) -> void:
	if resultado != HTTPRequest.RESULT_SUCCESS:
		print("SupabaseClient: error de red cargando relaciones ecológicas.")
		return

	if codigo_http < 200 or codigo_http >= 300:
		print(
			"SupabaseClient: HTTP ",
			codigo_http,
			" cargando relaciones ecológicas → ",
			cuerpo.get_string_from_utf8()
		)
		return

	var json := JSON.new()
	if json.parse(cuerpo.get_string_from_utf8()) != OK:
		print("SupabaseClient: relaciones ecológicas no son JSON válido.")
		return

	if not json.data is Array:
		print("SupabaseClient: relaciones ecológicas no son una lista.")
		return

	_relaciones_ecologicas.clear()

	for relacion_variant in json.data as Array:
		if relacion_variant is Dictionary:
			_relaciones_ecologicas.append(
				(relacion_variant as Dictionary).duplicate(true)
			)

	print(
		"SupabaseClient: relaciones ecológicas cargadas → ",
		_relaciones_ecologicas.size()
	)

	relaciones_ecologicas_cargadas.emit(_relaciones_ecologicas.duplicate(true))



func obtener_relaciones_ecologicas() -> Array:
	return _relaciones_ecologicas.duplicate(true)


func cargar_reinos_game() -> void:
	if _auth == null:
		return
	if _http_reinos_game == null:
		return
	if not _reinos_game.is_empty():
		return
	if _http_reinos_game.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	var headers := _crear_headers()
	var resultado := _http_reinos_game.request(
		_auth.SUPABASE_URL + API_REINOS_GAME,
		headers,
		HTTPClient.METHOD_GET
	)

	if resultado != OK:
		print("SupabaseClient: no se pudo solicitar reinos_game → ", resultado)


func _al_completar_reinos_game(
	resultado: int,
	codigo_http: int,
	_cabeceras: PackedStringArray,
	cuerpo: PackedByteArray
) -> void:
	if resultado != HTTPRequest.RESULT_SUCCESS:
		print("SupabaseClient: error de red cargando reinos_game.")
		return
	if codigo_http < 200 or codigo_http >= 300:
		print("SupabaseClient: HTTP ", codigo_http, " cargando reinos_game → ", cuerpo.get_string_from_utf8())
		return

	var json := JSON.new()
	if json.parse(cuerpo.get_string_from_utf8()) != OK or not json.data is Array:
		print("SupabaseClient: reinos_game no son una lista JSON válida.")
		return

	_reinos_game.clear()
	for reino_variant in json.data as Array:
		if reino_variant is Dictionary:
			_reinos_game.append((reino_variant as Dictionary).duplicate(true))

	print("SupabaseClient: reinos_game cargados → ", _reinos_game.size())
	reinos_game_cargados.emit(_reinos_game.duplicate(true))


func obtener_reinos_game() -> Array:
	return _reinos_game.duplicate(true)


func obtener_reino_game(clave: String) -> Dictionary:
	for reino_variant in _reinos_game:
		if not reino_variant is Dictionary:
			continue
		var reino := reino_variant as Dictionary
		if str(reino.get("clave", "")) == clave:
			return reino.duplicate(true)
	return {}


func cargar_especies_jugables() -> void:
	# Las especies jugables son catálogo público del juego.
	# Supabase RLS permite SELECT a anon y authenticated; no requieren sesión.
	if _auth == null:
		return

	# Reemitir el caché permite que escenas creadas más tarde reciban el catálogo.
	if not _especies_jugables.is_empty():
		especies_jugables_cargadas.emit(_especies_jugables.duplicate(true))
		return

	if _http_especies == null:
		return
	if _http_especies.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	_intentos_especies_jugables += 1
	var headers := _crear_headers()
	var resultado := _http_especies.request(
		_auth.SUPABASE_URL + API_ESPECIES_JUGABLES,
		headers,
		HTTPClient.METHOD_GET
	)

	if resultado != OK:
		print("SupabaseClient: no se pudo solicitar especies jugables → ", resultado)
		_reintentar_carga_especies_jugables("inicio de solicitud " + str(resultado))
	else:
		print("SupabaseClient: solicitando especies jugables → intento %d/%d" % [_intentos_especies_jugables, MAX_INTENTOS_INICIALES])


func _al_completar_especies_jugables(
	resultado: int,
	codigo_http: int,
	_cabeceras: PackedStringArray,
	cuerpo: PackedByteArray
) -> void:
	if resultado != HTTPRequest.RESULT_SUCCESS:
		print("SupabaseClient: error de red cargando especies jugables. Resultado: ", resultado)
		_reintentar_carga_especies_jugables("resultado de red " + str(resultado))
		return

	if codigo_http < 200 or codigo_http >= 300:
		if codigo_http == 408 or codigo_http == 425 or codigo_http == 429 or codigo_http >= 500:
			_reintentar_carga_especies_jugables("HTTP " + str(codigo_http))
		else:
			print("SupabaseClient: HTTP ", codigo_http, " cargando especies jugables → ", cuerpo.get_string_from_utf8())
		return

	var json := JSON.new()
	if json.parse(cuerpo.get_string_from_utf8()) != OK:
		print("SupabaseClient: especies jugables no son JSON válido.")
		_reintentar_carga_especies_jugables("respuesta JSON inválida")
		return

	if not json.data is Array:
		print("SupabaseClient: especies jugables no son una lista.")
		_reintentar_carga_especies_jugables("formato de respuesta inesperado")
		return

	var especies := _normalizar_especies_jugables(json.data as Array)

	if especies.is_empty():
		# Una respuesta vacía no debe borrar un catálogo válido que ya se
		# recuperó de la caché local. Sin caché, conservamos el reintento normal.
		print("SupabaseClient: Supabase respondió sin especies activas.")
		if _especies_jugables.is_empty():
			especies_jugables_cargadas.emit([])
			_reintentar_carga_especies_jugables("catálogo vacío")
		return

	_intentos_especies_jugables = 0
	_especies_jugables = especies
	_guardar_cache_especies_jugables(especies)
	print("SupabaseClient: especies jugables cargadas → ", especies.size())
	especies_jugables_cargadas.emit(especies.duplicate(true))



func _normalizar_especies_jugables(datos: Array) -> Array:
	var especies: Array = []
	for item_variant in datos:
		if not item_variant is Dictionary:
			continue
		var item := (item_variant as Dictionary).duplicate(true)
		if str(item.get("id", "")).strip_edges().is_empty():
			continue
		if str(item.get("clave", "")).strip_edges().is_empty():
			continue
		if str(item.get("nombre", "")).strip_edges().is_empty():
			continue
		especies.append(item)
	return especies


func _cargar_cache_especies_jugables(
	ruta: String = CACHE_ESPECIES_JUGABLES_PATH
) -> bool:
	if not FileAccess.file_exists(ruta):
		return false
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return false
	var contenido := archivo.get_as_text()
	archivo.close()
	var json := JSON.new()
	if json.parse(contenido) != OK or not json.data is Dictionary:
		push_warning("SupabaseClient: caché local de especies inválida; se solicitará el catálogo remoto.")
		return false
	var raiz := json.data as Dictionary
	if int(raiz.get("version", 0)) != CACHE_ESPECIES_JUGABLES_VERSION:
		push_warning("SupabaseClient: versión de caché de especies no compatible.")
		return false
	var datos_variant: Variant = raiz.get("especies", [])
	if not datos_variant is Array:
		return false
	var especies := _normalizar_especies_jugables(datos_variant as Array)
	if especies.is_empty():
		return false
	_especies_jugables = especies
	print("SupabaseClient: especies jugables recuperadas de caché local → ", especies.size())
	especies_jugables_cargadas.emit(especies.duplicate(true))
	return true


func _guardar_cache_especies_jugables(
	especies: Array,
	ruta: String = CACHE_ESPECIES_JUGABLES_PATH
) -> bool:
	var normalizadas := _normalizar_especies_jugables(especies)
	if normalizadas.is_empty():
		return false
	var directorio := ProjectSettings.globalize_path(ruta).get_base_dir()
	var error_directorio := DirAccess.make_dir_recursive_absolute(directorio)
	if error_directorio != OK and error_directorio != ERR_ALREADY_EXISTS:
		push_warning("SupabaseClient: no se pudo crear el directorio de caché de especies.")
		return false
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_warning("SupabaseClient: no se pudo escribir la caché local de especies.")
		return false
	archivo.store_string(JSON.stringify({
		"version": CACHE_ESPECIES_JUGABLES_VERSION,
		"especies": normalizadas
	}))
	archivo.close()
	return true


func _reintentar_carga_especies_jugables(motivo: String) -> void:
	if _reintento_especies_programado or not _especies_jugables.is_empty():
		return
	var espera := RETRASO_REINTENTO * float(maxi(_intentos_especies_jugables, 1))
	if _intentos_especies_jugables >= MAX_INTENTOS_INICIALES:
		# Tras los intentos rápidos iniciales, conservar recuperación automática
		# sin martillar el endpoint: una comprobación cada 30 segundos.
		_intentos_especies_jugables = 0
		espera = INTERVALO_REINTENTO_ESPECIES

	_reintento_especies_programado = true
	print("SupabaseClient: reintentando especies jugables en %.1fs (%s)." % [espera, motivo])
	await get_tree().create_timer(espera).timeout
	_reintento_especies_programado = false
	if not is_inside_tree() or not _especies_jugables.is_empty():
		return
	cargar_especies_jugables()

func obtener_especies_jugables() -> Array:
	return _especies_jugables.duplicate(true)

func cargar_personaje_regalos() -> void:
	if _auth == null or not _auth.esta_autenticado():
		return

	if not _personaje_regalos.is_empty() or _http_personaje_regalos == null:
		return
	if _http_personaje_regalos.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var headers := _crear_headers()
	var resultado := _http_personaje_regalos.request(
		_auth.SUPABASE_URL + API_PERSONAJE_REGALOS,
		headers,
		HTTPClient.METHOD_GET
	)
	if resultado != OK:
		print("SupabaseClient: no se pudo solicitar preferencias de regalos → ", resultado)


func _al_completar_personaje_regalos(
	resultado: int,
	codigo_http: int,
	_cabeceras: PackedStringArray,
	cuerpo: PackedByteArray
) -> void:
	if resultado != HTTPRequest.RESULT_SUCCESS:
		print("SupabaseClient: error de red cargando preferencias de regalos.")
		return
	if codigo_http < 200 or codigo_http >= 300:
		print("SupabaseClient: HTTP ", codigo_http, " cargando preferencias de regalos → ", cuerpo.get_string_from_utf8())
		return
	var json := JSON.new()
	if json.parse(cuerpo.get_string_from_utf8()) != OK or not json.data is Array:
		print("SupabaseClient: preferencias de regalos no son JSON válido.")
		return
	_personaje_regalos.clear()
	for regalo_variant in json.data as Array:
		if regalo_variant is Dictionary:
			_personaje_regalos.append((regalo_variant as Dictionary).duplicate(true))
	print("SupabaseClient: preferencias de regalos cargadas → ", _personaje_regalos.size())
	personaje_regalos_cargados.emit(_personaje_regalos.duplicate(true))


func obtener_personaje_regalos() -> Array:
	return _personaje_regalos.duplicate(true)


func cargar_personaje_social() -> void:
	if _auth == null or not _auth.esta_autenticado():
		return

	if not _personaje_social.is_empty() or _http_personaje_social == null:
		return
	if _http_personaje_social.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	var headers := _crear_headers()

	var resultado := _http_personaje_social.request(
		_auth.SUPABASE_URL + API_PERSONAJE_SOCIAL,
		headers,
		HTTPClient.METHOD_GET
	)

	if resultado != OK:
		print("SupabaseClient: no se pudo solicitar reglas sociales → ", resultado)


func _al_completar_personaje_social(
	resultado: int,
	codigo_http: int,
	_cabeceras: PackedStringArray,
	cuerpo: PackedByteArray
) -> void:
	if resultado != HTTPRequest.RESULT_SUCCESS:
		print("SupabaseClient: error de red cargando reglas sociales.")
		return
	if codigo_http < 200 or codigo_http >= 300:
		print("SupabaseClient: HTTP ", codigo_http, " cargando reglas sociales → ", cuerpo.get_string_from_utf8())
		return
	var json := JSON.new()
	if json.parse(cuerpo.get_string_from_utf8()) != OK or not json.data is Array:
		print("SupabaseClient: reglas sociales no son una lista JSON válida.")
		return
	_personaje_social.clear()
	for regla_variant in json.data as Array:
		if regla_variant is Dictionary:
			_personaje_social.append((regla_variant as Dictionary).duplicate(true))
	print("SupabaseClient: reglas sociales cargadas → ", _personaje_social.size())
	personaje_social_cargado.emit(_personaje_social.duplicate(true))


func obtener_personaje_social() -> Array:
	return _personaje_social.duplicate(true)


func obtener_regla_social_personaje(personaje_id: String) -> Dictionary:
	for regla_variant in _personaje_social:
		if not regla_variant is Dictionary:
			continue
		var regla := regla_variant as Dictionary
		if str(regla.get("personaje_game_id", "")) == personaje_id:
			return regla.duplicate(true)
	return {}


func cargar_especie_eterium_game() -> void:
	if _auth == null or not _auth.esta_autenticado():
		return

	if not _especie_eterium_game.is_empty():
		return
	if _http_especie_eterium_game == null:
		return
	if _http_especie_eterium_game.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var headers := _crear_headers()
	var resultado := _http_especie_eterium_game.request(
		_auth.SUPABASE_URL + API_ESPECIE_ETERIUM_GAME,
		headers,
		HTTPClient.METHOD_GET
	)
	if resultado != OK:
		print("SupabaseClient: no se pudo solicitar reglas Eterium de especies → ", resultado)


func _al_completar_especie_eterium_game(
	resultado: int,
	codigo_http: int,
	_cabeceras: PackedStringArray,
	cuerpo: PackedByteArray
) -> void:
	if resultado != HTTPRequest.RESULT_SUCCESS:
		print("SupabaseClient: error de red cargando reglas Eterium de especies.")
		return
	if codigo_http < 200 or codigo_http >= 300:
		print("SupabaseClient: HTTP ", codigo_http, " cargando reglas Eterium de especies → ", cuerpo.get_string_from_utf8())
		return
	var json := JSON.new()
	if json.parse(cuerpo.get_string_from_utf8()) != OK or not json.data is Array:
		print("SupabaseClient: reglas Eterium de especies no son una lista JSON válida.")
		return
	_especie_eterium_game.clear()
	for regla_variant in json.data as Array:
		if regla_variant is Dictionary:
			_especie_eterium_game.append((regla_variant as Dictionary).duplicate(true))
	_especie_eterium_game_cargado = true
	print("SupabaseClient: reglas Eterium de especies cargadas → ", _especie_eterium_game.size())
	especie_eterium_game_cargado.emit(_especie_eterium_game.duplicate(true))


func tiene_especie_eterium_game() -> bool:
	return not _especie_eterium_game.is_empty()


func especie_eterium_game_esta_cargado() -> bool:
	return _especie_eterium_game_cargado


func obtener_especie_eterium_game() -> Array:
	return _especie_eterium_game.duplicate(true)


func cargar_eterium_runtime() -> void:
	if _auth == null or not _auth.esta_autenticado():
		return

	if not _eterium_runtime.is_empty():
		return

	if _http_eterium == null:
		return
	if _http_eterium.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	if _auth.SUPABASE_PUBLISHABLE_KEY.is_empty():
		return

	var headers := _crear_headers()

	var resultado := _http_eterium.request(
		_auth.SUPABASE_URL + RPC_ETERIUM_RUNTIME,
		headers,
		HTTPClient.METHOD_POST,
		"{}"
	)

	if resultado != OK:
		print(
			"SupabaseClient: no se pudo iniciar carga de Eterium → ",
			resultado
		)


func _al_completar_eterium_runtime(
	resultado: int,
	codigo_http: int,
	_cabeceras: PackedStringArray,
	cuerpo: PackedByteArray
) -> void:
	if resultado != HTTPRequest.RESULT_SUCCESS:
		print("SupabaseClient: error de red cargando Eterium.")
		return

	if codigo_http < 200 or codigo_http >= 300:
		print(
			"SupabaseClient: HTTP ",
			codigo_http,
			" cargando Eterium → ",
			cuerpo.get_string_from_utf8()
		)
		return

	var json := JSON.new()
	if json.parse(cuerpo.get_string_from_utf8()) != OK:
		print("SupabaseClient: respuesta Eterium no es JSON válido.")
		return

	if not json.data is Dictionary:
		print("SupabaseClient: respuesta Eterium no es un objeto JSON.")
		return

	var datos := json.data as Dictionary
	var reglas_variant: Variant = datos.get("reglas", {})
	var organismos_variant: Variant = datos.get("organismos", [])

	if not reglas_variant is Dictionary:
		print("SupabaseClient: faltan las reglas canónicas de Eterium.")
		return

	if not organismos_variant is Array:
		print("SupabaseClient: faltan los perfiles canónicos de organismos.")
		return

	_eterium_runtime = datos.duplicate(true)

	print(
		"SupabaseClient: Eterium runtime cargado. Organismos = ",
		(organismos_variant as Array).size()
	)

	eterium_runtime_cargado.emit(
		_eterium_runtime.duplicate(true)
	)


func tiene_eterium_runtime() -> bool:
	return not _eterium_runtime.is_empty()


func obtener_eterium_reglas() -> Dictionary:
	var reglas_variant: Variant = _eterium_runtime.get(
		"reglas",
		{}
	)

	if reglas_variant is Dictionary:
		return (reglas_variant as Dictionary).duplicate(true)

	return {}


func obtener_eterium_organismos() -> Array:
	var organismos_variant: Variant = _eterium_runtime.get(
		"organismos",
		[]
	)

	if organismos_variant is Array:
		return (organismos_variant as Array).duplicate(true)

	return []


func obtener_eterium_organismo(organismo_id: String) -> Dictionary:
	if organismo_id.is_empty():
		return {}

	for organismo_variant in obtener_eterium_organismos():
		if not organismo_variant is Dictionary:
			continue

		var organismo := organismo_variant as Dictionary
		if str(organismo.get("organismo_id", "")) == organismo_id:
			return organismo.duplicate(true)

	return {}


func esta_conectado() -> bool:
	return _sincronizacion_inicial_realizada

func iniciar_sincronizacion() -> void:
	if _solicitud_en_curso:
		return

	_intento_actual = 0
	_solicitar_mundo()


func cargar_mundo_inicial() -> void:
	iniciar_sincronizacion()


func solicitar_actualizacion() -> void:
	if _solicitud_en_curso:
		return

	_intento_actual = 0
	_solicitar_mundo()


func _solicitar_mundo() -> void:
	if _solicitud_en_curso:
		return

	if not _esta_configurado():
		error_conexion.emit(
			"Falta configurar las credenciales públicas de Supabase."
		)

		_programar_siguiente_sincronizacion()
		return

	if _intento_actual >= MAX_INTENTOS_INICIALES:
		_solicitud_en_curso = false
		_programar_siguiente_sincronizacion()
		return

	_intento_actual += 1
	_solicitud_en_curso = true

	var headers := _crear_headers()

	var resultado := _http.request(
		_auth.SUPABASE_URL + RPC_MUNDO,
		headers,
		HTTPClient.METHOD_POST,
		"{}"
	)

	if resultado != OK:
		_solicitud_en_curso = false
		_manejar_error(
			"No se pudo iniciar la solicitud HTTP: "
			+ str(resultado)
		)


func _al_completar_solicitud(
	resultado: int,
	codigo_http: int,
	_cabeceras: PackedStringArray,
	cuerpo: PackedByteArray
) -> void:
	_solicitud_en_curso = false

	if resultado != HTTPRequest.RESULT_SUCCESS:
		_manejar_error(
			"Error de red: "
			+ str(resultado)
		)
		return

	var texto := cuerpo.get_string_from_utf8()

	if codigo_http < 200 or codigo_http >= 300:
		_manejar_error(
			"HTTP "
			+ str(codigo_http)
			+ ": "
			+ texto
		)
		return

	var json := JSON.new()
	var error_parseo := json.parse(texto)

	if error_parseo != OK:
		_manejar_error(
			"La respuesta no es JSON válido."
		)
		return

	if not json.data is Dictionary:
		_manejar_error(
			"La respuesta del mundo no es un objeto JSON."
		)
		return

	var datos: Dictionary = json.data

	if not _mundo_valido(datos):
		_manejar_error(
			"La respuesta no contiene los datos "
			+ "necesarios del mundo."
		)
		return

	_sincronizacion_inicial_realizada = true

	print(
		"SupabaseClient: mundo remoto recibido. "
		+ "Biomas = "
		+ str(datos["biomas"].size())
	)

	mundo_cargado.emit(
		datos
	)

	_programar_siguiente_sincronizacion()


func _mundo_valido(
	datos: Dictionary
) -> bool:
	return WorldSnapshotValidatorScript.es_valido(datos)


func _manejar_error(
	mensaje: String
) -> void:
	print(
		"SupabaseClient: ",
		mensaje
	)

	if _intento_actual < MAX_INTENTOS_INICIALES:
		await get_tree().create_timer(
			RETRASO_REINTENTO
		).timeout

		if not is_inside_tree():
			return

		_solicitar_mundo()
		return

	error_conexion.emit(
		mensaje
	)

	_programar_siguiente_sincronizacion()


func _programar_siguiente_sincronizacion() -> void:
	if _timer == null:
		return

	if not is_inside_tree():
		return

	_timer.start(
		INTERVALO_SINCRONIZACION
	)


func _al_timer_sincronizacion() -> void:
	if _solicitud_en_curso:
		_programar_siguiente_sincronizacion()
		return

	# El mundo completo (~0.86 MB actualmente) no se necesita en tiempo real
	# durante una partida. Evitamos descargar y parsear ese snapshot mientras
	# el jugador está jugando para no provocar picos de CPU/IO.
	if _mundo_activo_en_escena:
		_programar_siguiente_sincronizacion()
		return

	_intento_actual = 0
	_solicitar_mundo()
