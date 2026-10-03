extends Node


signal mundo_cargado(datos: Dictionary)
signal eterium_runtime_cargado(datos: Dictionary)
signal especies_jugables_cargadas(especies: Array)
signal especie_eterium_game_cargado(reglas: Array)
signal personaje_social_cargado(reglas: Array)
signal personaje_regalos_cargados(regalos: Array)
signal error_conexion(mensaje: String)


const SUPABASE_URL := (
	"https://ftdxthnizdosaaavjhah.supabase.co"
)

const RPC_MUNDO := (
	"/rest/v1/rpc/get_mundo_inicial_ambiental_v2"
)

const SUPABASE_KEY := (
	"sb_publishable_dZowBcHCW7PJ5tV8aDnAPQ_1URMyPbV"
)

const HTTP_TIMEOUT: float = 15.0
const MAX_INTENTOS_INICIALES: int = 3
const RETRASO_REINTENTO: float = 1.5
const INTERVALO_SINCRONIZACION: float = 60.0
const RPC_ETERIUM_RUNTIME := (
	"/rest/v1/rpc/get_eterium_runtime_v1"
)
const API_ESPECIES_JUGABLES := (
	"/rest/v1/especies_jugables?select=id,clave,nombre,clado_id,orden&activo=eq.true&order=orden.asc"
)
const API_PERSONAJE_REGALOS := (
	"/rest/v1/personaje_regalos_v1?select=id,personaje_game_id,item_id,reaccion,amistad,confianza,respeto,afecto,activo&activo=eq.true"
)
const API_PERSONAJE_SOCIAL := (
	"/rest/v1/personaje_social_v1?select=personaje_game_id,amistad_inicial,confianza_inicial,respeto_inicial,afecto_inicial,sociabilidad,curiosidad,generosidad,prudencia,agresividad,activo,personajes_game!inner(nombre)&activo=eq.true"
)
const API_ESPECIE_ETERIUM_GAME := (
	"/rest/v1/especie_eterium_game?select=especie_eterium_id,vida_eterium_compartidos,recuperacion_eterium,activo,especie_eterium_v1!inner(especie_id,capacidad_base)&activo=eq.true"
)


var _http: HTTPRequest
var _http_eterium: HTTPRequest
var _http_especies: HTTPRequest
var _http_especie_eterium_game: HTTPRequest
var _http_personaje_social: HTTPRequest
var _http_personaje_regalos: HTTPRequest
var _timer: Timer
var _solicitud_en_curso: bool = false
var _intento_actual: int = 0
var _sincronizacion_inicial_realizada: bool = false
var _eterium_runtime: Dictionary = {}
var _especie_eterium_game: Array = []
var _personaje_social: Array = []
var _personaje_regalos: Array = []


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = HTTP_TIMEOUT

	add_child(_http)

	_http.request_completed.connect(
		_al_completar_solicitud
	)

	_http_eterium = HTTPRequest.new()
	_http_eterium.timeout = HTTP_TIMEOUT
	add_child(_http_eterium)
	_http_eterium.request_completed.connect(
		_al_completar_eterium_runtime
	)

	_http_especies = HTTPRequest.new()
	_http_especies.timeout = HTTP_TIMEOUT
	add_child(_http_especies)
	_http_especies.request_completed.connect(
		_al_completar_especies_jugables
	)

	_http_especie_eterium_game = HTTPRequest.new()
	_http_especie_eterium_game.timeout = HTTP_TIMEOUT
	add_child(_http_especie_eterium_game)
	_http_especie_eterium_game.request_completed.connect(
		_al_completar_especie_eterium_game
	)

	_http_personaje_social = HTTPRequest.new()
	_http_personaje_social.timeout = HTTP_TIMEOUT
	add_child(_http_personaje_social)
	_http_personaje_social.request_completed.connect(
		_al_completar_personaje_social
	)

	_http_personaje_regalos = HTTPRequest.new()
	_http_personaje_regalos.timeout = HTTP_TIMEOUT
	add_child(_http_personaje_regalos)
	_http_personaje_regalos.request_completed.connect(
		_al_completar_personaje_regalos
	)

	call_deferred("cargar_eterium_runtime")
	call_deferred("cargar_especie_eterium_game")
	call_deferred("cargar_personaje_social")
	call_deferred("cargar_personaje_regalos")
	call_deferred("cargar_especies_jugables")

	_timer = Timer.new()
	_timer.wait_time = INTERVALO_SINCRONIZACION
	_timer.one_shot = true
	add_child(_timer)

	_timer.timeout.connect(
		_al_timer_sincronizacion
	)


func cargar_especies_jugables() -> void:
	if _http_especies == null:
		return

	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json",
		"Accept: application/json"
	])

	var resultado := _http_especies.request(
		SUPABASE_URL + API_ESPECIES_JUGABLES,
		headers,
		HTTPClient.METHOD_GET
	)

	if resultado != OK:
		print("SupabaseClient: no se pudo solicitar especies jugables → ", resultado)


func _al_completar_especies_jugables(
	resultado: int,
	codigo_http: int,
	_cabeceras: PackedStringArray,
	cuerpo: PackedByteArray
) -> void:
	if resultado != HTTPRequest.RESULT_SUCCESS:
		print("SupabaseClient: error de red cargando especies jugables.")
		return

	if codigo_http < 200 or codigo_http >= 300:
		print(
			"SupabaseClient: HTTP ",
			codigo_http,
			" cargando especies jugables → ",
			cuerpo.get_string_from_utf8()
		)
		return

	var json := JSON.new()
	if json.parse(cuerpo.get_string_from_utf8()) != OK:
		print("SupabaseClient: especies jugables no son JSON válido.")
		return

	if not json.data is Array:
		print("SupabaseClient: especies jugables no son una lista.")
		return

	var especies: Array = []
	for especie_variant in json.data as Array:
		if especie_variant is Dictionary:
			especies.append((especie_variant as Dictionary).duplicate(true))

	print("SupabaseClient: especies jugables cargadas → ", especies.size())
	especies_jugables_cargadas.emit(especies)


func cargar_personaje_regalos() -> void:
	if not _personaje_regalos.is_empty() or _http_personaje_regalos == null:
		return
	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json",
		"Accept: application/json"
	])
	var resultado := _http_personaje_regalos.request(
		SUPABASE_URL + API_PERSONAJE_REGALOS,
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
	if not _personaje_social.is_empty() or _http_personaje_social == null:
		return

	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json",
		"Accept: application/json"
	])

	var resultado := _http_personaje_social.request(
		SUPABASE_URL + API_PERSONAJE_SOCIAL,
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
	if not _especie_eterium_game.is_empty():
		return
	if _http_especie_eterium_game == null:
		return
	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json",
		"Accept: application/json"
	])
	var resultado := _http_especie_eterium_game.request(
		SUPABASE_URL + API_ESPECIE_ETERIUM_GAME,
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
	print("SupabaseClient: reglas Eterium de especies cargadas → ", _especie_eterium_game.size())
	especie_eterium_game_cargado.emit(_especie_eterium_game.duplicate(true))


func tiene_especie_eterium_game() -> bool:
	return not _especie_eterium_game.is_empty()


func obtener_especie_eterium_game() -> Array:
	return _especie_eterium_game.duplicate(true)


func cargar_eterium_runtime() -> void:
	if not _eterium_runtime.is_empty():
		return

	if _http_eterium == null:
		return

	if SUPABASE_KEY == "PEGA_AQUI_TU_CLAVE_PUBLICA":
		return

	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json",
		"Accept: application/json"
	])

	var resultado := _http_eterium.request(
		SUPABASE_URL + RPC_ETERIUM_RUNTIME,
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

	if SUPABASE_KEY == "PEGA_AQUI_TU_CLAVE_PUBLICA":
		error_conexion.emit(
			"Falta configurar la clave pública de Supabase."
		)

		_programar_siguiente_sincronizacion()
		return

	if _intento_actual >= MAX_INTENTOS_INICIALES:
		_solicitud_en_curso = false
		_programar_siguiente_sincronizacion()
		return

	_intento_actual += 1
	_solicitud_en_curso = true

	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json",
		"Accept: application/json"
	])

	var resultado := _http.request(
		SUPABASE_URL + RPC_MUNDO,
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
	if not datos.has("biomas"):
		return false

	if not datos["biomas"] is Array:
		return false

	return true


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
	var escena := get_tree().current_scene
	if escena != null and escena.get_node_or_null(
		"World/WorldGenerator"
	) != null:
		_programar_siguiente_sincronizacion()
		return

	_intento_actual = 0
	_solicitar_mundo()
