extends Node

# Genera códigos legibles: PALABRA-NÚMERO (ej: LUNA-4821)
const PALABRAS: Array[String] = [
	"ARBOL", "LUNA", "FUEGO", "ROCA", "VIENTO",
	"AGUA", "SOL", "NIEBLA", "RAYO", "TIERRA"
]

const TABLA: String = "/rest/v1/salas_multijugador"


signal sala_creada(codigo: String)
signal sala_unida(ip: String, puerto: int)
signal sala_no_encontrada
signal sala_llena
signal error_sala(mensaje: String)


var _codigo_activo: String = ""
var _request: HTTPRequest = null
var _request_busy: bool = false


func _ready() -> void:
	_crear_request()


func _crear_request() -> void:
	if _request != null:
		return

	_request = HTTPRequest.new()
	_request.name = "SalasRequest"
	add_child(_request)


# ============================================================
# API PÚBLICA
# ============================================================

func generar_codigo() -> String:
	var palabra: String = PALABRAS[randi() % PALABRAS.size()]
	var numero: int = randi_range(1000, 9999)
	return palabra + "-" + str(numero)


func publicar_sala(ip: String, puerto: int = 7777) -> void:
	if not GarliaAuth.esta_autenticado():
		error_sala.emit("Debes iniciar sesión para crear una sala.")
		return

	var codigo: String = generar_codigo()
	_codigo_activo = codigo

	var body: Dictionary = {
		"codigo": codigo,
		"ip": ip,
		"puerto": puerto,
		"host_id": GarliaAuth.obtener_user_id(),
		"host_username": GarliaAuth.obtener_username()
	}

	var resultado: Variant = await _hacer_peticion(
		GarliaAuth.SUPABASE_URL + TABLA,
		HTTPClient.METHOD_POST,
		_headers_auth(),
		JSON.stringify(body)
	)

	if resultado == null:
		error_sala.emit("No se pudo conectar con Supabase.")
		return

	var response_code: int = int(resultado.get("response_code", 0))

	# 201 = Created
	if response_code < 200 or response_code >= 300:
		var texto: String = str(resultado.get("body", ""))
		# Colisión de código único → reintenta
		if "unique" in texto.to_lower() or "duplicate" in texto.to_lower():
			await publicar_sala(ip, puerto)
			return
		error_sala.emit("No se pudo publicar la sala. (%d)" % response_code)
		return

	print("GarliaSalas: sala publicada con código ", codigo)
	sala_creada.emit(codigo)


func buscar_sala(codigo: String) -> void:
	if not GarliaAuth.esta_autenticado():
		error_sala.emit("Debes iniciar sesión para unirte a una sala.")
		return

	var codigo_limpio: String = codigo.strip_edges().to_upper()

	var url: String = (
		GarliaAuth.SUPABASE_URL
		+ TABLA
		+ "?select=ip,puerto,jugadores_actuales,max_jugadores"
		+ "&codigo=eq." + codigo_limpio
		+ "&activa=eq.true"
		+ "&limit=1"
	)

	var resultado: Variant = await _hacer_peticion(
		url,
		HTTPClient.METHOD_GET,
		_headers_auth()
	)

	if resultado == null:
		sala_no_encontrada.emit()
		return

	var response_code: int = int(resultado.get("response_code", 0))
	var texto: String = str(resultado.get("body", ""))

	if response_code < 200 or response_code >= 300:
		sala_no_encontrada.emit()
		return

	var json := JSON.new()
	if json.parse(texto) != OK:
		sala_no_encontrada.emit()
		return

	if not json.data is Array or (json.data as Array).is_empty():
		sala_no_encontrada.emit()
		return

	var sala: Dictionary = (json.data as Array)[0]

	var actuales: int = int(sala.get("jugadores_actuales", 0))
	var max_j: int = int(sala.get("max_jugadores", 8))

	if actuales >= max_j:
		sala_llena.emit()
		return

	var sala_ip: String = str(sala.get("ip", ""))
	var sala_puerto: int = int(sala.get("puerto", 7777))

	print("GarliaSalas: sala encontrada → ", sala_ip, ":", sala_puerto)
	sala_unida.emit(sala_ip, sala_puerto)


func cerrar_sala() -> void:
	if _codigo_activo.is_empty():
		return

	var url: String = (
		GarliaAuth.SUPABASE_URL
		+ TABLA
		+ "?codigo=eq." + _codigo_activo
	)

	var body: String = JSON.stringify({ "activa": false })

	await _hacer_peticion(
		url,
		HTTPClient.METHOD_PATCH,
		_headers_auth(),
		body
	)

	print("GarliaSalas: sala ", _codigo_activo, " cerrada.")
	_codigo_activo = ""


func obtener_codigo_activo() -> String:
	return _codigo_activo


# ============================================================
# INTERNO
# ============================================================

func _headers_auth() -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"apikey: " + GarliaAuth.SUPABASE_PUBLISHABLE_KEY,
		"Authorization: Bearer " + GarliaAuth.access_token,
		"Prefer: return=minimal"
	])


func _hacer_peticion(
	url: String,
	metodo: HTTPClient.Method,
	headers: PackedStringArray,
	cuerpo: String = ""
) -> Variant:
	if _request == null:
		_crear_request()

	if _request_busy:
		push_warning("GarliaSalas: petición en curso, se descartó la nueva.")
		return null

	_request_busy = true

	var error: Error

	if cuerpo.is_empty():
		error = _request.request(url, headers, metodo)
	else:
		error = _request.request(url, headers, metodo, cuerpo)

	if error != OK:
		_request_busy = false
		return null

	var resultado: Array = await _request.request_completed

	_request_busy = false

	return {
		"result_code": int(resultado[0]),
		"response_code": int(resultado[1]),
		"body": PackedByteArray(resultado[3]).get_string_from_utf8()
	}
