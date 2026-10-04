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


var is_host: bool = false
var is_connected: bool = false

var local_player_info: Dictionary = {}


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


func puede_usar_multijugador() -> bool:
	return GarliaAuth.esta_autenticado()


func crear_partida(
	puerto: int = DEFAULT_PORT
) -> bool:
	if not GarliaAuth.esta_autenticado():
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
		"user_id": GarliaAuth.obtener_user_id(),
		"username": GarliaAuth.obtener_username()
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
	if not GarliaAuth.esta_autenticado():
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
		"user_id": GarliaAuth.obtener_user_id(),
		"username": GarliaAuth.obtener_username()
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
	print(
		"GarliaMultiplayer: peer conectado → ",
		id
	)

	peer_connected.emit(id)


func _on_peer_disconnected(
	id: int
) -> void:
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
