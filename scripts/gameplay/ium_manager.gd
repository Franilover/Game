extends Node
## IUMManager — gestor del sistema de magia IUM.
## Carga IUMs y procesos desde Supabase, guarda configuraciones
## del jugador y ejecuta la simulación de cadenas IUM.

signal iums_cargados(iums: Array)
signal procesos_cargados(procesos: Array)
signal proceso_descubierto(proceso: Dictionary)
signal proceso_equipado_signal(proceso: Dictionary)
signal error_ium(mensaje: String)

const SUPABASE_URL := "https://ftdxthnizdosaaavjhah.supabase.co"
const SUPABASE_KEY := "sb_publishable_dZowBcHCW7PJ5tV8aDnAPQ_1URMyPbV"

# Datos cargados de Supabase
var iums_disponibles: Array = []        # Catálogo completo de IUMs
var procesos_conocidos: Array = []      # Procesos que el jugador ha descubierto
var proceso_equipado: Dictionary = {}   # Proceso activo para usar en combate

# Estado de la sesión
var _jugador_id: String = ""
var _http_iums: HTTPRequest = null
var _http_procesos: HTTPRequest = null
var _http_simular: HTTPRequest = null
var _http_registrar: HTTPRequest = null


func _ready() -> void:
	_http_iums = _crear_http()
	_http_procesos = _crear_http()
	_http_simular = _crear_http()
	_http_registrar = _crear_http()

	_http_iums.request_completed.connect(_al_cargar_iums)
	_http_procesos.request_completed.connect(_al_cargar_procesos)
	_http_simular.request_completed.connect(_al_simular_organizacion)
	_http_registrar.request_completed.connect(_al_registrar_intento)


func _crear_http() -> HTTPRequest:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	return http


# ================================================================
# INICIALIZACIÓN
# ================================================================

func inicializar(jugador_id: String) -> void:
	_jugador_id = jugador_id
	cargar_iums()
	cargar_procesos_descubiertos()


# ================================================================
# CARGA DE IUMs DESDE SUPABASE
# ================================================================

func cargar_iums() -> void:
	var headers := _headers()
	var url := SUPABASE_URL + "/rest/v1/rpc/get_iums_disponibles"

	var resultado := _http_iums.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		"{}"
	)

	if resultado != OK:
		error_ium.emit("No se pudo iniciar carga de IUMs.")


func _al_cargar_iums(
	resultado: int,
	codigo_http: int,
	_cabeceras: PackedStringArray,
	cuerpo: PackedByteArray
) -> void:
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo_http >= 300:
		# Fallback: intentar con REST directo si no existe la RPC
		_cargar_iums_rest()
		return

	var datos: Variant = _parsear_json(cuerpo)
	if datos == null:
		_cargar_iums_rest()
		return

	if datos is Array:
		iums_disponibles = datos
	elif datos is Dictionary and (datos as Dictionary).has("iums"):
		iums_disponibles = (datos as Dictionary)["iums"]

	iums_cargados.emit(iums_disponibles)


func _cargar_iums_rest() -> void:
	# Carga directa de la tabla iums via REST
	var headers := _headers()
	var url := SUPABASE_URL + "/rest/v1/iums?select=id,nombre,descripcion,oris,topologia,tipo,nivel_minimo&order=nombre"

	var http2 := HTTPRequest.new()
	http2.timeout = 15.0
	add_child(http2)
	http2.request_completed.connect(func(res, cod, _h, body):
		if res == HTTPRequest.RESULT_SUCCESS and cod < 300:
			var datos: Variant = _parsear_json(body)
			if datos is Array:
				iums_disponibles = datos
				iums_cargados.emit(iums_disponibles)
		http2.queue_free()
	)
	http2.request(url, headers, HTTPClient.METHOD_GET)


# ================================================================
# CARGA DE PROCESOS DESCUBIERTOS
# ================================================================

func cargar_procesos_descubiertos() -> void:
	if _jugador_id.is_empty():
		return

	var headers := _headers()
	var body := JSON.stringify({"jugador_id": _jugador_id})
	var url := SUPABASE_URL + "/rest/v1/rpc/get_procesos_jugador"

	var resultado := _http_procesos.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if resultado != OK:
		error_ium.emit("No se pudo cargar procesos del jugador.")


func _al_cargar_procesos(
	resultado: int,
	codigo_http: int,
	_cabeceras: PackedStringArray,
	cuerpo: PackedByteArray
) -> void:
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo_http >= 300:
		# Sin procesos descubiertos todavía — OK
		procesos_conocidos = []
		procesos_cargados.emit(procesos_conocidos)
		return

	var datos: Variant = _parsear_json(cuerpo)

	if datos is Array:
		procesos_conocidos = datos
	else:
		procesos_conocidos = []

	procesos_cargados.emit(procesos_conocidos)


# ================================================================
# SIMULACIÓN DE CADENA IUM
# ================================================================

func simular_organizacion(nodos: Array, enlaces: Array) -> void:
	## Nodos: [{ium_id, posicion_x, posicion_y}]
	## Enlaces: [{origen_id, destino_id, tipo_enlace}]

	if nodos.is_empty():
		error_ium.emit("No hay IUMs en la configuración.")
		return

	var payload := {
		"jugador_id": _jugador_id,
		"nodos": nodos,
		"enlaces": enlaces
	}

	var headers := _headers()
	var url := SUPABASE_URL + "/rest/v1/rpc/simular_organizacion_ium_v1"

	var resultado := _http_simular.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if resultado != OK:
		error_ium.emit("No se pudo iniciar simulación.")


func _al_simular_organizacion(
	resultado: int,
	codigo_http: int,
	_cabeceras: PackedStringArray,
	cuerpo: PackedByteArray
) -> void:
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo_http >= 300:
		var texto := cuerpo.get_string_from_utf8()
		error_ium.emit("Error al simular: %s" % texto)
		return

	var datos: Variant = _parsear_json(cuerpo)
	if datos == null:
		error_ium.emit("Respuesta inválida de la simulación.")
		return

	# La RPC puede devolver directamente el proceso o un array
	var proceso: Dictionary = {}

	if datos is Dictionary and (datos as Dictionary).has("proceso_id"):
		proceso = datos as Dictionary
	elif datos is Array and not (datos as Array).is_empty():
		proceso = (datos as Array)[0]

	if proceso.is_empty():
		# No coincidió con ningún proceso conocido — feedback al jugador
		error_ium.emit("La configuración no coincide con ningún proceso conocido.")
		return

	# Registrar el descubrimiento
	_registrar_descubrimiento(proceso)
	proceso_descubierto.emit(proceso)


# ================================================================
# REGISTRO DE DESCUBRIMIENTO
# ================================================================

func _registrar_descubrimiento(proceso: Dictionary) -> void:
	if _jugador_id.is_empty():
		return

	var payload := {
		"jugador_id": _jugador_id,
		"proceso_id": proceso.get("proceso_id", proceso.get("id", "")),
		"exitoso": true
	}

	var headers := _headers()
	var url := SUPABASE_URL + "/rest/v1/rpc/registrar_intento_simulador"

	_http_registrar.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	# Añadir a procesos conocidos localmente si no está ya
	var ya_conocido := false
	for p in procesos_conocidos:
		if p.get("id") == proceso.get("proceso_id", proceso.get("id")):
			ya_conocido = true
			break

	if not ya_conocido:
		procesos_conocidos.append(proceso)


func _al_registrar_intento(
	_resultado: int,
	_codigo_http: int,
	_cabeceras: PackedStringArray,
	_cuerpo: PackedByteArray
) -> void:
	pass  # Silencioso — el descubrimiento ya fue emitido


# ================================================================
# EQUIPAR PROCESO
# ================================================================

func equipar_proceso(proceso: Dictionary) -> void:
	proceso_equipado = proceso
	proceso_equipado_signal.emit(proceso)


func usar_proceso_equipado(objetivo: Node = null) -> void:
	if proceso_equipado.is_empty():
		error_ium.emit("No hay proceso equipado.")
		return

	var nombre: String = proceso_equipado.get("nombre", "Proceso desconocido")
	var efecto: String = proceso_equipado.get("efecto_tipo", "")
	var magnitud: float = float(proceso_equipado.get("magnitud", 10.0))

	# Aplicar efecto según tipo
	match efecto:
		"daño", "damage":
			if objetivo != null and objetivo.has_method("take_damage"):
				objetivo.take_damage(int(magnitud))
		"curar", "heal":
			var player := get_tree().get_first_node_in_group("player")
			if player != null and player.has_method("heal"):
				player.call("heal", int(magnitud))
		"slow":
			if objetivo != null and objetivo.has_method("aplicar_efecto_slow"):
				objetivo.call("aplicar_efecto_slow", magnitud)
		_:
			# Efecto genérico — emitir señal para que otros sistemas reaccionen
			pass

	Events.notification_pushed.emit("Proceso usado: " + nombre)


# ================================================================
# UTILIDADES
# ================================================================

func _headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json",
		"Accept: application/json"
	])


func _parsear_json(cuerpo: PackedByteArray) -> Variant:
	var texto := cuerpo.get_string_from_utf8()
	var json := JSON.new()
	var error := json.parse(texto)

	if error != OK:
		return null

	return json.data
