extends Node


const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 8
const DEFAULT_TLS_CERT_PATH := "user://certs/garlia_server.crt"
const DEFAULT_TLS_KEY_PATH := "user://certs/garlia_server.key"


signal host_created
signal join_started
signal connected_to_game
signal connection_failed
signal server_disconnected

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

signal status_changed(message: String)
signal dedicated_server_started(port: int)
signal dedicated_server_empty
signal dedicated_server_has_players(count: int)


var is_host: bool = false
var is_connected: bool = false
var is_dedicated_server: bool = false
var _connected_peer_ids: Dictionary = {}
var _tls_cert_path: String = DEFAULT_TLS_CERT_PATH
var _tls_key_path: String = DEFAULT_TLS_KEY_PATH

var local_player_info: Dictionary = {}
var _auth: Node = null


func configurar_dependencias(auth: Node) -> void:
	_auth = auth


func _ready() -> void:
	# El listener TLS y el polling deben seguir activos aunque el mundo esté pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(
		_on_peer_connected
	)

	multiplayer.peer_disconnected.connect(
		_on_peer_disconnected
	)

	multiplayer.connected_to_server.connect(
		_on_connected_to_server
	)

	multiplayer.connection_failed.connect(
		_on_connection_failed
	)

	multiplayer.server_disconnected.connect(
		_on_server_disconnected
	)
	call_deferred("_leer_argumento_servidor")


## Inicia un servidor dedicado sin exigir una sesión de jugador.
## Uso: godot --headless --path . -- --garlia-server --port=7777
func iniciar_servidor_dedicado(puerto: int = DEFAULT_PORT) -> bool:
	cerrar_partida()
	var cert := X509Certificate.new()
	var cert_error := cert.load(_tls_cert_path)
	var key := CryptoKey.new()
	var key_error := key.load(_tls_key_path)
	if cert_error != OK or key_error != OK:
		var mensaje := "Falta el certificado TLS o la clave privada del servidor."
		push_error("GarliaMultiplayer: " + mensaje + " Cert: " + _tls_cert_path + " | Key: " + _tls_key_path)
		status_changed.emit(mensaje + " Revisa las rutas configuradas por argumentos.")
		return false

	var tls_options := TLSOptions.server(key, cert)
	var peer := WebSocketMultiplayerPeer.new()
	var error: Error = peer.create_server(puerto, "*", tls_options)
	if error != OK:
		push_error("GarliaMultiplayer: no se pudo iniciar servidor WSS. Error: %s" % error)
		status_changed.emit("No se pudo iniciar el servidor WSS. Error: " + str(error))
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_connected = true
	is_dedicated_server = true
	_connected_peer_ids.clear()
	status_changed.emit("Servidor WSS activo en puerto %d." % puerto)
	print("GarliaMultiplayer: servidor WSS escuchando en TCP ", puerto)
	dedicated_server_started.emit(puerto)
	return true

func obtener_cantidad_jugadores_remotos() -> int:
	return _connected_peer_ids.size()


func es_servidor_dedicado() -> bool:
	return is_dedicated_server and multiplayer.is_server()


func _leer_argumento_servidor() -> void:
	iniciar_servidor_dedicado_desde_argumentos()


func iniciar_servidor_dedicado_desde_argumentos() -> bool:
	var argumentos := OS.get_cmdline_user_args()
	var activar := false
	var puerto := DEFAULT_PORT
	_tls_cert_path = str(ProjectSettings.globalize_path(DEFAULT_TLS_CERT_PATH))
	_tls_key_path = str(ProjectSettings.globalize_path(DEFAULT_TLS_KEY_PATH))
	for argumento in argumentos:
		if argumento == "--garlia-server":
			activar = true
		elif argumento.begins_with("--port="):
			puerto = clampi(int(argumento.trim_prefix("--port=")), 1, 65535)
		elif argumento.begins_with("--tls-cert="):
			_tls_cert_path = argumento.trim_prefix("--tls-cert=")
		elif argumento.begins_with("--tls-key="):
			_tls_key_path = argumento.trim_prefix("--tls-key=")
	if not activar:
		return false
	if es_servidor_dedicado():
		return true
	return iniciar_servidor_dedicado(puerto)


func puede_usar_multijugador() -> bool:
	return _auth != null and _auth.esta_autenticado()


func crear_partida(
	_puerto: int = DEFAULT_PORT
) -> bool:
	status_changed.emit("El alojamiento entre jugadores está deshabilitado. Usa el servidor global seguro.")
	return false

func unirse_partida(
	direccion_ip: String,
	puerto: int = DEFAULT_PORT
) -> bool:
	if not puede_usar_multijugador():
		status_changed.emit("Debes iniciar sesión para unirte al mundo global.")
		return false

	var host := direccion_ip.strip_edges()
	if host.begins_with("wss://"):
		host = host.trim_prefix("wss://")
	elif host.contains("://"):
		status_changed.emit("La conexión debe usar WSS seguro.")
		return false
	if host.is_empty() or "/" in host or " " in host:
		status_changed.emit("Introduce un dominio o IP válido.")
		return false

	cerrar_partida()
	var url := "wss://%s:%d" % [host, clampi(puerto, 1, 65535)]
	var peer := WebSocketMultiplayerPeer.new()
	var error: Error = peer.create_client(url)
	if error != OK:
		status_changed.emit("No se pudo iniciar la conexión segura. Error: " + str(error))
		return false

	multiplayer.multiplayer_peer = peer
	is_host = false
	is_connected = false
	local_player_info = {
		"user_id": _auth.obtener_user_id(),
		"username": _auth.obtener_username()
	}
	status_changed.emit("Conectando mediante WSS seguro...")
	join_started.emit()
	print("GarliaMultiplayer: conectando mediante TLS a ", url)
	return true

func cerrar_partida() -> void:
	is_dedicated_server = false
	_connected_peer_ids.clear()
	if multiplayer.multiplayer_peer == null:
		is_host = false
		is_connected = false
		return

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	is_host = false
	is_connected = false

	local_player_info = {}

	status_changed.emit(
		"Multijugador desconectado."
	)


func obtener_id_local() -> int:
	return multiplayer.get_unique_id()


func soy_host() -> bool:
	return (
		multiplayer.multiplayer_peer != null
		and multiplayer.is_server()
	)


func obtener_ips_locales() -> Array[String]:
	var ips: Array[String] = []

	for direccion_variant in IP.get_local_addresses():
		var direccion: String = str(
			direccion_variant
		)

		if direccion.is_empty():
			continue

		if direccion == "127.0.0.1":
			continue

		if ":" in direccion:
			continue

		if direccion in ips:
			continue

		ips.append(direccion)

	return ips


func _on_peer_connected(
	id: int
) -> void:
	if is_dedicated_server:
		_connected_peer_ids[id] = true
		dedicated_server_has_players.emit(_connected_peer_ids.size())
	print(
		"GarliaMultiplayer: peer conectado → ",
		id
	)

	peer_connected.emit(id)


func _on_peer_disconnected(
	id: int
) -> void:
	if is_dedicated_server:
		_connected_peer_ids.erase(id)
		if _connected_peer_ids.is_empty():
			dedicated_server_empty.emit()
		else:
			dedicated_server_has_players.emit(_connected_peer_ids.size())
	print(
		"GarliaMultiplayer: peer desconectado → ",
		id
	)

	peer_disconnected.emit(id)


func _on_connected_to_server() -> void:
	is_connected = true

	status_changed.emit(
		"Conectado a la partida."
	)

	print(
		"GarliaMultiplayer: conexión establecida."
	)

	connected_to_game.emit()


func _on_connection_failed() -> void:
	is_connected = false
	is_host = false

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	status_changed.emit(
		"No se pudo conectar con la partida."
	)

	print(
		"GarliaMultiplayer: conexión fallida."
	)

	connection_failed.emit()


func _on_server_disconnected() -> void:
	is_connected = false
	is_host = false

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	status_changed.emit(
		"El servidor del mundo global se desconectó."
	)

	print(
		"GarliaMultiplayer: servidor desconectado."
	)

	server_disconnected.emit()
