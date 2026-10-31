extends Node


const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 8


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

var local_player_info: Dictionary = {}
var _auth: Node = null


func configurar_dependencias(auth: Node) -> void:
	_auth = auth


func _ready() -> void:
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
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(puerto, MAX_PLAYERS)
	if error != OK:
		push_error("GarliaMultiplayer: no se pudo iniciar servidor dedicado. Error: %s" % error)
		status_changed.emit("No se pudo iniciar el servidor dedicado. Error: " + str(error))
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_connected = true
	is_dedicated_server = true
	_connected_peer_ids.clear()
	status_changed.emit("Servidor dedicado activo en puerto %d." % puerto)
	print("GarliaMultiplayer: servidor dedicado escuchando en UDP ", puerto)
	dedicated_server_started.emit(puerto)
	return true


func obtener_cantidad_jugadores_remotos() -> int:
	return _connected_peer_ids.size()


func es_servidor_dedicado() -> bool:
	return is_dedicated_server and multiplayer.is_server()


func _leer_argumento_servidor() -> void:
	var argumentos := OS.get_cmdline_user_args()
	var activar := false
	var puerto := DEFAULT_PORT
	for argumento in argumentos:
		if argumento == "--garlia-server":
			activar = true
		elif argumento.begins_with("--port="):
			puerto = clampi(int(argumento.trim_prefix("--port=")), 1, 65535)
	if activar:
		iniciar_servidor_dedicado(puerto)


func puede_usar_multijugador() -> bool:
	return _auth != null and _auth.esta_autenticado()


func crear_partida(
	puerto: int = DEFAULT_PORT
) -> bool:
	if not puede_usar_multijugador():
		status_changed.emit(
			"Debes iniciar sesión para crear una partida."
		)

		return false

	cerrar_partida()

	var peer := ENetMultiplayerPeer.new()

	var error: Error = peer.create_server(
		puerto,
		MAX_PLAYERS - 1
	)

	if error != OK:
		status_changed.emit(
			"No se pudo crear la partida. Error: "
			+ str(error)
		)

		return false

	multiplayer.multiplayer_peer = peer

	is_host = true
	is_connected = true

	local_player_info = {
		"user_id": _auth.obtener_user_id(),
		"username": _auth.obtener_username()
	}

	status_changed.emit(
		"Partida creada. Esperando jugadores..."
	)

	host_created.emit()

	print(
		"GarliaMultiplayer: servidor creado en puerto ",
		puerto
	)

	print(
		"GarliaMultiplayer: jugador host → ",
		local_player_info.get("username", "")
	)

	return true


func unirse_partida(
	direccion_ip: String,
	puerto: int = DEFAULT_PORT
) -> bool:
	if not puede_usar_multijugador():
		status_changed.emit(
			"Debes iniciar sesión para unirte a una partida."
		)

		return false

	var ip: String = direccion_ip.strip_edges()

	if ip.is_empty():
		status_changed.emit(
			"Introduce la dirección IP de la partida."
		)

		return false

	cerrar_partida()

	var peer := ENetMultiplayerPeer.new()

	var error: Error = peer.create_client(
		ip,
		puerto
	)

	if error != OK:
		status_changed.emit(
			"No se pudo iniciar la conexión. Error: "
			+ str(error)
		)

		return false

	multiplayer.multiplayer_peer = peer

	is_host = false
	is_connected = false

	local_player_info = {
		"user_id": _auth.obtener_user_id(),
		"username": _auth.obtener_username()
	}

	status_changed.emit(
		"Conectando con la partida..."
	)

	join_started.emit()

	print(
		"GarliaMultiplayer: conectando a ",
		ip,
		":",
		puerto
	)

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
		"El anfitrión cerró la partida."
	)

	print(
		"GarliaMultiplayer: servidor desconectado."
	)

	server_disconnected.emit()
