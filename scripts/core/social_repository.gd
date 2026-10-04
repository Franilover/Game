extends Node
## SocialRepository — acceso de infraestructura para reglas sociales.
## RelationshipSystem recibe datos; no conoce HTTP ni Supabase REST.

signal reglas_cargadas(reglas: Array)
signal regalos_cargados(regalos: Array)
signal error_repositorio(mensaje: String)

var _client: SupabaseClient = null
var _requests: Dictionary = {}


func configurar(client: SupabaseClient) -> void:
	_client = client


func cargar_reglas() -> void:
	_request("reglas", func(datos: Variant) -> void:
		var resultado: Array = datos if datos is Array else []
		reglas_cargadas.emit(resultado)
	)


func cargar_regalos() -> void:
	_request("regalos", func(datos: Variant) -> void:
		var resultado: Array = datos if datos is Array else []
		regalos_cargados.emit(resultado)
	)


func _request(tipo: String, callback: Callable) -> void:
	if _client == null:
		error_repositorio.emit("SocialRepository: SupabaseClient no configurado.")
		return

	var request_id := -1
	match tipo:
		"reglas":
			request_id = _client.get_rest(
				"personajes_game",
				"select=id,personalidad_social,amistad_inicial,confianza_inicial,respeto_inicial,afecto_inicial"
			)
		"regalos":
			request_id = _client.get_rest(
				"personaje_regalos",
				"select=*"
			)

	if request_id < 0:
		error_repositorio.emit("SocialRepository: no se pudo crear la petición.")
		return

	_requests[request_id] = {
		"tipo": tipo,
		"callback": callback
	}


func _ready() -> void:
	if not SupabaseClient.request_completed.is_connected(_al_request_completed):
		SupabaseClient.request_completed.connect(_al_request_completed)


func _al_request_completed(
	request_id: int,
	resultado: int,
	codigo_http: int,
	_cabeceras: PackedStringArray,
	cuerpo: PackedByteArray
) -> void:
	if not _requests.has(request_id):
		return

	var pendiente: Dictionary = _requests[request_id]
	_requests.erase(request_id)

	if resultado != HTTPRequest.RESULT_SUCCESS or codigo_http < 200 or codigo_http >= 300:
		error_repositorio.emit(
			"SocialRepository: HTTP "
			+ str(codigo_http)
			+ " para "
			+ str(pendiente.get("tipo", "petición"))
		)
		return

	var texto := cuerpo.get_string_from_utf8()
	var datos: Variant = JSON.parse_string(texto)
	if datos == null:
		error_repositorio.emit("SocialRepository: respuesta JSON inválida.")
		return

	var callback_variant: Variant = pendiente.get("callback")
	if callback_variant is Callable:
		(callback_variant as Callable).call(datos)
