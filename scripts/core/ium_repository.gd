extends Node
class_name IUMRepository

signal iums_cargados(datos: Array)
signal procesos_cargados(datos: Array)
signal simulacion_completada(proceso: Dictionary)
signal simulacion_fallida(mensaje: String)
signal registro_completado()

var _client: SupabaseClient
var _requests: Dictionary = {}

func configurar(client: SupabaseClient) -> void:
	_client = client
	if _client != null and not _client.request_completed.is_connected(_al_request):
		_client.request_completed.connect(_al_request)

func cargar_iums() -> void:
	if _client == null:
		return
	_registrar(_client.rpc("get_iums_disponibles"), "iums")

func cargar_procesos(jugador_id: String) -> void:
	if _client == null or jugador_id.is_empty():
		return
	_registrar(_client.rpc("get_procesos_jugador", {"jugador_id": jugador_id}), "procesos")

func simular(jugador_id: String, nodos: Array, enlaces: Array) -> void:
	if _client == null:
		simulacion_fallida.emit("Repositorio IUM no configurado.")
		return
	_registrar(_client.rpc("simular_organizacion_ium_v1", {
		"jugador_id": jugador_id,
		"nodos": nodos,
		"enlaces": enlaces
	}), "simular")

func registrar_intento(jugador_id: String, proceso_id: String) -> void:
	if _client == null or jugador_id.is_empty():
		return
	_registrar(_client.rpc("registrar_intento_simulador", {
		"jugador_id": jugador_id,
		"proceso_id": proceso_id,
		"exitoso": true
	}), "registrar")

func _registrar(request_id: int, tipo: String) -> void:
	_requests[request_id] = tipo

func _al_request(request_id: int, resultado: int, codigo_http: int, _cabeceras: PackedStringArray, cuerpo: PackedByteArray) -> void:
	var tipo := str(_requests.get(request_id, ""))
	_requests.erase(request_id)

	if resultado != HTTPRequest.RESULT_SUCCESS or codigo_http >= 300:
		if tipo == "iums":
			_registrar(_client.get_rest("iums", "select=id,nombre,descripcion,oris,topologia,tipo,nivel_minimo&order=nombre"), "iums_fallback")
		elif tipo == "procesos":
			procesos_cargados.emit([])
		elif tipo == "simular":
			simulacion_fallida.emit("Error al simular IUM: " + cuerpo.get_string_from_utf8())
		return

	var datos: Variant = _parsear_json(cuerpo)
	match tipo:
		"iums":
			if datos is Array:
				iums_cargados.emit(datos)
			elif datos is Dictionary and (datos as Dictionary).has("iums"):
				iums_cargados.emit((datos as Dictionary)["iums"])
			else:
				_registrar(_client.get_rest("iums", "select=id,nombre,descripcion,oris,topologia,tipo,nivel_minimo&order=nombre"), "iums_fallback")
		"iums_fallback":
			if datos is Array:
				iums_cargados.emit(datos)
			else:
				iums_cargados.emit([])
		"procesos":
			if datos is Array:
				procesos_cargados.emit(datos)
			else:
				procesos_cargados.emit([])
		"simular":
			var proceso := _extraer_proceso(datos)
			if proceso.is_empty():
				simulacion_fallida.emit("La configuración no coincide con ningún proceso conocido.")
			else:
				simulacion_completada.emit(proceso)
		"registrar":
			registro_completado.emit()

func _extraer_proceso(datos: Variant) -> Dictionary:
	if datos is Dictionary and (datos as Dictionary).has("proceso_id"):
		return datos as Dictionary
	if datos is Array and not (datos as Array).is_empty() and (datos as Array)[0] is Dictionary:
		return (datos as Array)[0] as Dictionary
	return {}

func _parsear_json(cuerpo: PackedByteArray) -> Variant:
	var json := JSON.new()
	if json.parse(cuerpo.get_string_from_utf8()) != OK:
		return null
	return json.data
