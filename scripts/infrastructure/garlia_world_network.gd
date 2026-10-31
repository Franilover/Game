extends Node
## Coordina la presencia de jugadores en el único mundo global.
## El servidor calcula el movimiento; los clientes solo envían intención de movimiento.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player.tscn")
const INPUT_INTERVAL := 0.05
const SNAPSHOT_INTERVAL := 0.05
const MAX_USERNAME_LENGTH := 24

signal mundo_global_listo(semilla: int, tipo_zona: String)
signal mundo_global_rechazado(mensaje: String)

var _servidor_inicializado := false
var _mundo_listo := false
var _cliente_global_activado := false
var _main: Node = null
var _entities: Node2D = null
var _world_anchor: Player = null
var _local_player: Player = null
var _world_context: Node = null
var _entity_manager: Node = null
var _ium_manager: Node = null
var _supabase_client: Node = null

var _jugadores_servidor: Dictionary = {}
var _proxies_cliente: Dictionary = {}
var _auth_pendiente: Dictionary = {}
var _sistemas_jugador_servidor: Dictionary = {}
var _ultima_accion_servidor: Dictionary = {}
var _personaje_local: Dictionary = {}
var _estado_inicial_pendiente: Array = []
var _peer_local_id := 0
var _semilla_global := 0
var _input_elapsed := 0.0
var _snapshot_elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not GarliaMultiplayer.connected_to_game.is_connected(_al_conectar_con_servidor):
		GarliaMultiplayer.connected_to_game.connect(_al_conectar_con_servidor)
	if not GarliaMultiplayer.peer_disconnected.is_connected(_al_desconectar_peer):
		GarliaMultiplayer.peer_disconnected.connect(_al_desconectar_peer)


func configurar_personaje_local(datos: Dictionary) -> void:
	_personaje_local = datos.duplicate(true)


func conectar_a_servidor_global(ip: String, puerto: int = GarliaMultiplayer.DEFAULT_PORT) -> bool:
	if not GarliaAuth.esta_autenticado():
		mundo_global_rechazado.emit("Inicia sesión antes de entrar al mundo global.")
		return false
	var direccion := ip.strip_edges()
	if direccion.is_empty():
		mundo_global_rechazado.emit("Introduce la IP o dominio del servidor global.")
		return false
	_cliente_global_activado = true
	return GarliaMultiplayer.unirse_partida(direccion, clampi(puerto, 1, 65535))


func es_cliente_en_mundo_global() -> bool:
	return _cliente_global_activado and GarliaMultiplayer.is_connected and not GarliaMultiplayer.es_servidor_dedicado()


func controla_jugador_local(jugador: Player) -> bool:
	return es_cliente_en_mundo_global() and is_instance_valid(_local_player) and jugador == _local_player


func inicializar_mundo_servidor(
	main: Node,
	entities: Node2D,
	world_anchor: Player,
	world_context: Node,
	entity_manager: Node,
	ium_manager: Node,
	supabase_client: Node
) -> void:
	if not GarliaMultiplayer.es_servidor_dedicado():
		return
	_main = main
	_entities = entities
	_world_anchor = world_anchor
	_world_context = world_context
	_entity_manager = entity_manager
	_ium_manager = ium_manager
	_supabase_client = supabase_client
	_servidor_inicializado = true
	_mundo_listo = true
	GlobalWorldStore.configurar_runtime(main)

	# Main conserva este Player como ancla de generación y composición de sistemas.
	# No representa a una persona y no debe atraer criaturas ni moverse.
	if is_instance_valid(_world_anchor):
		_world_anchor.visible = false
		_world_anchor.set_physics_process(false)
		_world_anchor.remove_from_group("player")
		_world_anchor.collision_layer = 0
		_world_anchor.collision_mask = 0

	# Si Main cambia de zona, los jugadores existentes deben apuntar a los
	# sistemas de entidades de la zona recién activada.
	for jugador_variant in _jugadores_servidor.values():
		var jugador_existente := jugador_variant as Player
		if is_instance_valid(jugador_existente):
			jugador_existente.configurar_dependencias(null, _world_context, _ium_manager, _entity_manager, _supabase_client, GameState)

	if GarliaMultiplayer.obtener_cantidad_jugadores_remotos() > 0:
		get_tree().paused = false
	else:
		GlobalWorldStore.guardar_y_pausar()
	print("GarliaWorldNetwork: mundo global del servidor preparado.")


func configurar_mundo_cliente(main: Node, entities: Node2D, local_player: Player) -> void:
	if not es_cliente_en_mundo_global():
		return
	_main = main
	_entities = entities
	_local_player = local_player
	_local_player.visible = true
	_local_player.set_physics_process(true)
	if not _estado_inicial_pendiente.is_empty():
		_aplicar_snapshot(_estado_inicial_pendiente)
		_estado_inicial_pendiente.clear()
	print("GarliaWorldNetwork: cliente enlazado al mundo global.")


func actualizar_input_local(delta: float) -> void:
	if not is_instance_valid(_local_player) or not es_cliente_en_mundo_global():
		return
	_input_elapsed += delta
	if _input_elapsed < INPUT_INTERVAL:
		return
	_input_elapsed = 0.0
	var direccion := Vector2.ZERO
	if not _local_player.input_gate.esta_bloqueado():
		direccion = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var correr := Input.is_action_pressed("run")
	recibir_input_global.rpc_id(1, direccion.limit_length(1.0), correr)


func _process(delta: float) -> void:
	if GarliaMultiplayer.es_servidor_dedicado():
		if not _servidor_inicializado or get_tree().paused:
			return
		_snapshot_elapsed += delta
		if _snapshot_elapsed >= SNAPSHOT_INTERVAL:
			_snapshot_elapsed = 0.0
			_actualizar_ancla_mundo()
			_difundir_estado()
		return


func _al_conectar_con_servidor() -> void:
	if GarliaMultiplayer.es_servidor_dedicado() or not _cliente_global_activado:
		return
	var user_id := GarliaAuth.obtener_user_id()
	var username := GarliaAuth.obtener_username()
	var token := str(GarliaAuth.access_token)
	if user_id.is_empty() or token.is_empty():
		mundo_global_rechazado.emit("La sesión no contiene credenciales válidas.")
		GarliaMultiplayer.cerrar_partida()
		return
	solicitar_entrada_global.rpc_id(1, user_id, username, token)


@rpc("any_peer", "call_remote", "reliable")
func solicitar_entrada_global(user_id: String, username: String, access_token: String) -> void:
	if not GarliaMultiplayer.es_servidor_dedicado():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id <= 1 or _auth_pendiente.has(peer_id) or _jugadores_servidor.has(peer_id):
		return
	_auth_pendiente[peer_id] = true

	var usuario_verificado := await _validar_token_supabase(access_token)
	_auth_pendiente.erase(peer_id)
	if not multiplayer.get_peers().has(peer_id):
		return
	if str(usuario_verificado.get("id", "")) != user_id or user_id.is_empty():
		rechazar_entrada_global.rpc_id(peer_id, "No se pudo verificar tu cuenta. Vuelve a iniciar sesión.")
		return

	# La conexión puede llegar mientras el servidor todavía construye la primera zona.
	while not _mundo_listo and GarliaMultiplayer.es_servidor_dedicado():
		await get_tree().create_timer(0.2).timeout
	if not _mundo_listo or not multiplayer.get_peers().has(peer_id):
		return

	get_tree().paused = false
	var jugador := PLAYER_SCENE.instantiate() as Player
	if jugador == null:
		rechazar_entrada_global.rpc_id(peer_id, "No se pudo crear tu personaje en el servidor.")
		return
	jugador.name = "JugadorRed_%d" % peer_id
	jugador.personaje_nombre = username.strip_edges().left(MAX_USERNAME_LENGTH)
	jugador.configurar_control_remoto_servidor()
	jugador.configurar_dependencias(
		null,
		_world_context,
		_ium_manager,
		_entity_manager,
		_supabase_client,
		GameState
	)
	_entities.add_child(jugador)
	_crear_sistemas_jugador_servidor(peer_id, jugador)
	var camara_jugador := jugador.get_node_or_null("Camera2D") as Camera2D
	if is_instance_valid(camara_jugador):
		camara_jugador.enabled = false
	var separacion := Vector2(float((_jugadores_servidor.size() % 4) * 24), float(int(_jugadores_servidor.size() / 4) * 24))
	jugador.global_position = _world_anchor.global_position + Vector2(28.0, 12.0) + separacion
	_jugadores_servidor[peer_id] = jugador

	var snapshot := _crear_snapshot()
	var zone_manager := _main.get_node_or_null("World/ZoneManager")
	var tipo_zona := str(zone_manager.call("obtener_tipo_actual")) if is_instance_valid(zone_manager) else "mundo_abierto"
	recibir_inicio_red.rpc_id(peer_id, snapshot, peer_id, GameState.world_state.world_seed, tipo_zona)
	_difundir_estado()
	print("GarliaWorldNetwork: jugador autenticado y añadido → ", username, " [", peer_id, "]")


func _validar_token_supabase(token: String) -> Dictionary:
	if token.is_empty():
		return {}
	var request := HTTPRequest.new()
	request.timeout = 12.0
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(request)
	var headers := PackedStringArray([
		"apikey: " + GarliaAuth.SUPABASE_PUBLISHABLE_KEY,
		"Authorization: Bearer " + token
	])
	var error := request.request(GarliaAuth.SUPABASE_URL + "/auth/v1/user", headers, HTTPClient.METHOD_GET)
	if error != OK:
		request.queue_free()
		return {}
	var response: Array = await request.request_completed
	request.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS:
		return {}
	var code := int(response[1])
	if code < 200 or code >= 300:
		return {}
	var parsed: Variant = JSON.parse_string(PackedByteArray(response[3]).get_string_from_utf8())
	return parsed as Dictionary if parsed is Dictionary else {}


@rpc("authority", "call_remote", "reliable")
func recibir_inicio_red(snapshot: Array, peer_id_local: int, semilla: int, tipo_zona: String) -> void:
	if GarliaMultiplayer.es_servidor_dedicado():
		return
	_peer_local_id = peer_id_local
	_semilla_global = semilla
	_estado_inicial_pendiente = snapshot.duplicate(true)
	if is_instance_valid(_local_player):
		_aplicar_snapshot(_estado_inicial_pendiente)
		_estado_inicial_pendiente.clear()
	mundo_global_listo.emit(_semilla_global, tipo_zona)


@rpc("authority", "call_remote", "reliable")
func rechazar_entrada_global(mensaje: String) -> void:
	_cliente_global_activado = false
	GarliaMultiplayer.cerrar_partida()
	mundo_global_rechazado.emit(mensaje)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func recibir_input_global(direccion: Vector2, correr: bool) -> void:
	if not GarliaMultiplayer.es_servidor_dedicado():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var jugador: Player = _jugadores_servidor.get(peer_id) as Player
	if not is_instance_valid(jugador):
		return
	jugador.establecer_input_red(direccion.limit_length(1.0), correr)



func _crear_sistemas_jugador_servidor(peer_id: int, jugador: Player) -> void:
	if not is_instance_valid(jugador):
		return
	var contenedor := Node.new()
	contenedor.name = "SistemasRed_%d" % peer_id
	jugador.add_child(contenedor)

	var interaccion := InteractionSystem.new()
	interaccion.name = "InteraccionServidor"
	contenedor.add_child(interaccion)
	var world_items: GarliaWorldItems = _main.get_node_or_null("Systems/WorldItems") as GarliaWorldItems
	interaccion.configurar(jugador, null, world_items, jugador.input_gate, _entity_manager as WorldEntityManager)

	var combate := CombatSystem.new()
	combate.name = "CombateServidor"
	contenedor.add_child(combate)
	var proyectiles := _main.get_node_or_null("CombatProjectiles")
	combate.configurar(jugador, null, _world_context as WorldContext, proyectiles, GameState)

	_sistemas_jugador_servidor[peer_id] = {
		"interaccion": interaccion,
		"combate": combate
	}


@rpc("any_peer", "call_remote", "reliable")
func solicitar_accion_global(accion: String) -> void:
	if not GarliaMultiplayer.es_servidor_dedicado():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _jugadores_servidor.has(peer_id):
		return
	if accion != "primary" and accion != "secondary":
		return
	var ahora := Time.get_ticks_msec()
	var anterior := int(_ultima_accion_servidor.get(peer_id, 0))
	if ahora - anterior < 100:
		return
	_ultima_accion_servidor[peer_id] = ahora

	var sistemas: Dictionary = _sistemas_jugador_servidor.get(peer_id, {})
	var interaccion: InteractionSystem = sistemas.get("interaccion") as InteractionSystem
	var combate: CombatSystem = sistemas.get("combate") as CombatSystem
	if accion == "primary":
		if is_instance_valid(interaccion) and interaccion.procesar_accion_primaria():
			return
		if is_instance_valid(combate):
			combate.procesar_accion_primaria()
	else:
		if is_instance_valid(interaccion) and interaccion.procesar_accion_secundaria():
			return
		if is_instance_valid(combate):
			combate.procesar_accion_secundaria()


func solicitar_accion_local(accion: String) -> void:
	if not es_cliente_en_mundo_global():
		return
	if accion != "primary" and accion != "secondary":
		return
	solicitar_accion_global.rpc_id(1, accion)


@rpc("authority", "call_remote", "unreliable_ordered")
func recibir_estado_red(snapshot: Array) -> void:
	if GarliaMultiplayer.es_servidor_dedicado():
		return
	if not is_instance_valid(_local_player):
		_estado_inicial_pendiente = snapshot.duplicate(true)
		return
	_aplicar_snapshot(snapshot)


func _actualizar_ancla_mundo() -> void:
	if not is_instance_valid(_world_anchor) or _jugadores_servidor.is_empty():
		return
	var centro := Vector2.ZERO
	var cantidad := 0
	for jugador_variant in _jugadores_servidor.values():
		var jugador := jugador_variant as Player
		if not is_instance_valid(jugador):
			continue
		centro += jugador.global_position
		cantidad += 1
	if cantidad > 0:
		# WorldStreamer sigue un único punto. El centroide mantiene cargada la
		# región compartida mientras el grupo se desplaza unido.
		_world_anchor.global_position = centro / float(cantidad)


func _crear_snapshot() -> Array:
	var resultado: Array = []
	for peer_variant in _jugadores_servidor.keys():
		var peer_id := int(peer_variant)
		var jugador: Player = _jugadores_servidor[peer_id] as Player
		if not is_instance_valid(jugador):
			continue
		resultado.append({
			"peer_id": peer_id,
			"username": jugador.personaje_nombre,
			"x": jugador.global_position.x,
			"y": jugador.global_position.y,
			"facing_x": jugador.facing.x,
			"facing_y": jugador.facing.y,
			"health": int(jugador.health),
			"max_health": int(jugador.max_health),
			"mana": int(jugador.mana),
			"max_mana": int(jugador.max_mana),
			"stamina": float(jugador.stamina),
			"max_stamina": float(jugador.max_stamina),
			"is_alive": bool(jugador.is_alive)
		})
	return resultado


func _difundir_estado() -> void:
	if _jugadores_servidor.is_empty():
		return
	recibir_estado_red.rpc(_crear_snapshot())


func _aplicar_snapshot(snapshot: Array) -> void:
	var vistos: Dictionary = {}
	for registro_variant in snapshot:
		if not registro_variant is Dictionary:
			continue
		var registro := registro_variant as Dictionary
		var peer_id := int(registro.get("peer_id", 0))
		if peer_id <= 0:
			continue
		vistos[peer_id] = true
		var posicion := Vector2(float(registro.get("x", 0.0)), float(registro.get("y", 0.0)))
		var direccion := Vector2(float(registro.get("facing_x", 0.0)), float(registro.get("facing_y", 1.0)))
		if peer_id == _peer_local_id:
			if is_instance_valid(_local_player):
				_local_player.global_position = posicion
				if direccion.length_squared() > 0.01:
					_local_player.facing = direccion.normalized()
					_local_player.call("_update_dir_marker")
				_actualizar_estado_jugador(_local_player, registro)
			continue
		var proxy: Player = _proxies_cliente.get(peer_id) as Player
		if not is_instance_valid(proxy):
			proxy = PLAYER_SCENE.instantiate() as Player
			if proxy == null:
				continue
			proxy.name = "JugadorRemoto_%d" % peer_id
			proxy.personaje_nombre = str(registro.get("username", "Explorador"))
			proxy.set_physics_process(false)
			proxy.set_process(false)
			_entities.add_child(proxy)
			var camara_proxy := proxy.get_node_or_null("Camera2D") as Camera2D
			if is_instance_valid(camara_proxy):
				camara_proxy.enabled = false
			proxy.set_physics_process(false)
			proxy.set_process(false)
			_proxies_cliente[peer_id] = proxy
		proxy.global_position = posicion
		proxy.personaje_nombre = str(registro.get("username", proxy.personaje_nombre))
		_actualizar_estado_jugador(proxy, registro)
		if direccion.length_squared() > 0.01:
			proxy.facing = direccion.normalized()
			proxy.call("_update_dir_marker")

	var eliminar: Array = []
	for peer_variant in _proxies_cliente.keys():
		if not vistos.has(int(peer_variant)):
			eliminar.append(int(peer_variant))
	for peer_id in eliminar:
		var proxy: Player = _proxies_cliente[peer_id] as Player
		if is_instance_valid(proxy):
			proxy.queue_free()
		_proxies_cliente.erase(peer_id)


func _actualizar_estado_jugador(jugador: Player, registro: Dictionary) -> void:
	if not is_instance_valid(jugador):
		return
	jugador.set("is_alive", bool(registro.get("is_alive", true)))
	jugador.set("health", clampi(int(registro.get("health", jugador.health)), 0, int(registro.get("max_health", jugador.max_health))))
	jugador.set("mana", clampi(int(registro.get("mana", jugador.mana)), 0, int(registro.get("max_mana", jugador.max_mana))))
	jugador.set("stamina", clampf(float(registro.get("stamina", jugador.stamina)), 0.0, float(registro.get("max_stamina", jugador.max_stamina))))
	if jugador.has_signal("health_changed"):
		jugador.health_changed.emit(int(jugador.health), int(jugador.max_health))
	if jugador.has_signal("mana_changed"):
		jugador.mana_changed.emit(int(jugador.mana), int(jugador.max_mana))
	if jugador.has_signal("stamina_changed"):
		jugador.stamina_changed.emit(float(jugador.stamina), float(jugador.max_stamina))


func _al_desconectar_peer(peer_id: int) -> void:
	if GarliaMultiplayer.es_servidor_dedicado():
		var jugador: Player = _jugadores_servidor.get(peer_id) as Player
		if is_instance_valid(jugador):
			jugador.queue_free()
		_jugadores_servidor.erase(peer_id)
		_sistemas_jugador_servidor.erase(peer_id)
		_ultima_accion_servidor.erase(peer_id)
		if _jugadores_servidor.is_empty() and _servidor_inicializado:
			GlobalWorldStore.guardar_y_pausar()
		else:
			_difundir_estado()
		return

	if _proxies_cliente.has(peer_id):
		var proxy: Player = _proxies_cliente[peer_id] as Player
		if is_instance_valid(proxy):
			proxy.queue_free()
		_proxies_cliente.erase(peer_id)
