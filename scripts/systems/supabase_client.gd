
extends Node

signal mundo_cargado(datos: Dictionary)
signal error_conexion(mensaje: String)

const SUPABASE_URL := "https://ftdxthnizdosaaavjhah.supabase.co"
const RPC_MUNDO := "/rest/v1/rpc/get_mundo_inicial"

# Reemplaza esto por tu clave pública de Supabase.
# Nunca uses la service_role ni una clave secreta aquí.
const SUPABASE_KEY := "sb_publishable_dZowBcHCW7PJ5tV8aDnAPQ_1URMyPbV"

var _http: HTTPRequest
var _solicitud_en_curso := false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 30.0
	add_child(_http)
	_http.request_completed.connect(_al_completar_solicitud)

	_test_conexion()

func cargar_mundo_inicial() -> void:
	if _solicitud_en_curso:
		push_warning("Ya hay una solicitud en curso.")
		return

	if SUPABASE_KEY == "PEGA_AQUI_TU_CLAVE_PUBLICA":
		error_conexion.emit("Falta configurar la clave pública de Supabase.")
		return

	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json",
		"Accept: application/json"
	])

	_solicitud_en_curso = true

	var resultado := _http.request(
		SUPABASE_URL + RPC_MUNDO,
		headers,
		HTTPClient.METHOD_POST,
		"{}"
	)

	if resultado != OK:
		_solicitud_en_curso = false
		error_conexion.emit("No se pudo iniciar la solicitud HTTP: %s" % resultado)


func _al_completar_solicitud(
	resultado: int,
	codigo_http: int,
	_cabeceras: PackedStringArray,
	cuerpo: PackedByteArray
) -> void:
	_solicitud_en_curso = false

	if resultado != HTTPRequest.RESULT_SUCCESS:
		error_conexion.emit("Error de red: %s" % resultado)
		return

	var texto := cuerpo.get_string_from_utf8()

	if codigo_http < 200 or codigo_http >= 300:
		error_conexion.emit("HTTP %s: %s" % [codigo_http, texto])
		return

	var json := JSON.new()
	var error_parseo := json.parse(texto)

	if error_parseo != OK:
		error_conexion.emit("La respuesta no es JSON válido.")
		return

	if not json.data is Dictionary:
		error_conexion.emit("La respuesta del mundo no es un objeto JSON.")
		return

	var datos: Dictionary = json.data

	if not datos.has("biomas") or not datos["biomas"] is Array:
		error_conexion.emit("La respuesta no contiene una lista de biomas.")
		return

	print("Supabase conectado correctamente.")
	print("Biomas recibidos: ", datos["biomas"].size())
	print(
		"Ecosistemas sin bioma: ",
		datos.get("ecosistemas_sin_bioma", []).size()
	)

	mundo_cargado.emit(datos)

func _test_conexion() -> void:
	cargar_mundo_inicial()
	
