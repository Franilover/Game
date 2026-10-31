extends Node
## Coordina la presencia de jugadores en el único mundo global.
## El servidor calcula el movimiento; los clientes solo envían intención de movimiento.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player.tscn")
const INPUT_INTERVAL := 0.05
const SNAPSHOT_INTERVAL := 0.05
const MAX_USERNAME_LENGTH := 24

signal mundo_global_listo(semilla: int, tipo_zona: String, reinos_globales: Dictionary)
signal mundo_global_rechazado(mensaje: String)

var _servidor_inicializado := false
var _ultima_zona_servidor := ""
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
var _identidades_remotas_cliente: Dictionary = {}
var _objetivos_posicion_proxy: Dictionary = {}
var _objetivo_posicion_local := Vector2.ZERO
var _local_posicion_inicializada := false
const SNAPSHOT_INTERPOLATION_SPEED := 16.0
var _auth_pendiente: Dictionary = {}
var _sistemas_jugador_servidor: Dictionary = {}
var _ultima_accion_servidor: Dictionary = {}
var _ultimo_input_servidor: Dictionary = {}
var _reapariciones_pendientes: Dictionary = {}
var _eterium_runtime_global: Dictionary = {}
var _reglas_especies_eterium_global: Array = []
var _personaje_local: Dictionary = {}
var _estado_inicial_pendiente: Array = []
var _peer_local_id := 0
var _semilla_global := 0
var _input_elapsed := 0.0
var _snapshot_elapsed := 0.0
var _dash_local_pendiente := false
var _salto_local_pendiente := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not GarliaMultiplayer.connected_to_game.is_connected(_al_conectar_con_servidor):
		GarliaMultiplayer.connected_to_game.connect(_al_conectar_con_servidor)
	if not GarliaMultiplayer.peer_disconnected.is_connected(_al_desconectar_peer):
		GarliaMultiplayer.peer_disconnected.connect(_al_desconectar_peer)
	if not GarliaMultiplayer.server_disconnected.is_connected(_al_servidor_desconectado):
		GarliaMultiplayer.server_disconnected.connect(_al_servidor_desconectado)


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


func preparar_cambio_zona_servidor() -> void:
	if GarliaMultiplayer.es_servidor_dedicado():
		_mundo_listo = false


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
	var zone_manager_runtime := main.get_node_or_null("World/ZoneManager")
	var zona_nueva := str(zone_manager_runtime.call("obtener_tipo_actual")) if is_instance_valid(zone_manager_runtime) else ""
	var cambio_zona := _servidor_inicializado and zona_nueva != _ultima_zona_servidor
	_ultima_zona_servidor = zona_nueva
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
	for peer_variant in _jugadores_servidor.keys():
		var peer_id := int(peer_variant)
		var jugador_existente := _jugadores_servidor[peer_id] as Player
		if not is_instance_valid(jugador_existente):
			continue
		jugador_existente.configurar_dependencias(null, _world_context, _ium_manager, _entity_manager, _supabase_client, GameState)
		var sistemas: Dictionary = _sistemas_jugador_servidor.get(peer_id, {})
		var interaccion: InteractionSystem = sistemas.get("interaccion") as InteractionSystem
		if is_instance_valid(interaccion):
			var world_items: GarliaWorldItems = main.get_node_or_null("Systems/WorldItems") as GarliaWorldItems
			interaccion.configurar(jugador_existente, null, world_items, jugador_existente.input_gate, _entity_manager as WorldEntityManager)
		var combate: CombatSystem = sistemas.get("combate") as CombatSystem
		if is_instance_valid(combate):
			combate.configurar(jugador_existente, null, _world_context as WorldContext, main.get_node_or_null("CombatProjectiles"), GameState)
		if cambio_zona:
			jugador_existente.global_position = _world_anchor.global_position + Vector2(float((_jugadores_servidor.size() % 4) * 24), float(int(_jugadores_servidor.size() / 4) * 24))

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
	_local_posicion_inicializada = false
	_objetivos_posicion_proxy.clear()
	_local_player.visible = true
	_local_player.set_physics_process(true)
	if not _estado_inicial_pendiente.is_empty():
		_aplicar_snapshot(_estado_inicial_pendiente)
		_estado_inicial_pendiente.clear()
	print("GarliaWorldNetwork: cliente enlazado al mundo global.")


func _input(event: InputEvent) -> void:
	if not es_cliente_en_mundo_global() or not is_instance_valid(_local_player):
		return
	if _local_player.input_gate.esta_bloqueado():
		return
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_M and (event as InputEventKey).shift_pressed:
		_dash_local_pendiente = false
		return
	if event.is_action_pressed("dash"):
		if event is InputEventKey and (event as InputEventKey).echo:
			return
		_dash_local_pendiente = true
	if event.is_action_pressed("jump"):
		_salto_local_pendiente = true


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
	var sprint_eterium := Input.is_action_pressed("eterium_sprint")
	var dash := _dash_local_pendiente
	var salto := _salto_local_pendiente
	_dash_local_pendiente = false
	_salto_local_pendiente = false
	recibir_input_global.rpc_id(1, direccion.limit_length(1.0), correr, dash, sprint_eterium, salto)


func _process(delta: float) -> void:
	if GarliaMultiplayer.es_servidor_dedicado():
		if not _servidor_inicializado or get_tree().paused:
			return
		_limpiar_inputs_expirados()
		_revisar_reapariciones()
		_snapshot_elapsed += delta
		if _snapshot_elapsed >= SNAPSHOT_INTERVAL:
			_snapshot_elapsed = 0.0
			_actualizar_ancla_mundo()
			_difundir_estado()
		return
	if es_cliente_en_mundo_global():
		actualizar_input_local(delta)
		_actualizar_interpolacion_clientes(delta)


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
	solicitar_entrada_global.rpc_id(1, user_id, username, token, _obtener_identidad_visual_local())


@rpc("any_peer", "call_remote", "reliable")
func solicitar_entrada_global(user_id: String, _username: String, access_token: String, identidad_visual: Dictionary) -> void:
	if not GarliaMultiplayer.es_servidor_dedicado():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id <= 1 or _auth_pendiente.has(peer_id) or _jugadores_servidor.has(peer_id):
		return
	if _jugadores_servidor.size() + _auth_pendiente.size() >= GarliaMultiplayer.MAX_PLAYERS:
		rechazar_entrada_global.rpc_id(peer_id, "El mundo global alcanzó su límite de jugadores.")
		return
	_auth_pendiente[peer_id] = true

	var usuario_verificado := await _validar_token_supabase(access_token)
	_auth_pendiente.erase(peer_id)
	if not multiplayer.get_peers().has(peer_id):
		return
	if str(usuario_verificado.get("id", "")) != user_id or user_id.is_empty():
		rechazar_entrada_global.rpc_id(peer_id, "No se pudo verificar tu cuenta. Vuelve a iniciar sesión.")
		return

	# La conexión puede llegar mientras el servidor construye o cambia de zona.
	# El tiempo de espera está limitado para no retener indefinidamente el RPC.
	var intentos_espera := 0
	while not _mundo_listo and GarliaMultiplayer.es_servidor_dedicado() and intentos_espera < 100:
		await get_tree().create_timer(0.2, true, false).timeout
		intentos_espera += 1
	if not multiplayer.get_peers().has(peer_id):
		return
	if not _mundo_listo:
		rechazar_entrada_global.rpc_id(peer_id, "El mundo global aún no está disponible. Intenta de nuevo.")
		return

	var nombre_verificado := await _obtener_username_supabase(user_id, access_token)
	if nombre_verificado.is_empty():
		var correo_verificado := str(usuario_verificado.get("email", ""))
		nombre_verificado = correo_verificado.get_slice("@", 0) if "@" in correo_verificado else user_id.left(8)
	for jugador_existente_variant in _jugadores_servidor.values():
		var jugador_existente := jugador_existente_variant as Player
		if is_instance_valid(jugador_existente) and str(jugador_existente.get_meta("supabase_user_id", "")) == user_id:
			rechazar_entrada_global.rpc_id(peer_id, "Esa cuenta ya está conectada al mundo global.")
			return
	var identidad := _sanear_identidad_visual(identidad_visual, nombre_verificado)
	var especie_id := str(identidad_visual.get("especie_id", "")).strip_edges()
	var especie_canonica := await _obtener_especie_jugable_canonica(especie_id)
	if especie_canonica.is_empty():
		rechazar_entrada_global.rpc_id(peer_id, "No se pudo validar la especie seleccionada. Vuelve a crear tu personaje.")
		return
	var runtime_eterium := await _obtener_runtime_eterium(access_token)
	if runtime_eterium.is_empty():
		rechazar_entrada_global.rpc_id(peer_id, "No se pudo cargar el runtime de Eterium del mundo. Intenta entrar más tarde.")
		return
	var reglas_especies := await _obtener_reglas_eterium_especies(access_token)
	identidad["especie"] = especie_canonica

	get_tree().paused = false
	var jugador := PLAYER_SCENE.instantiate() as Player
	if jugador == null:
		rechazar_entrada_global.rpc_id(peer_id, "No se pudo crear tu personaje en el servidor.")
		return
	jugador.name = "JugadorRed_%d" % peer_id
	jugador.personaje_nombre = str(identidad.get("nombre", nombre_verificado)).left(MAX_USERNAME_LENGTH)
	jugador.aplicar_identidad_red(
		jugador.personaje_nombre,
		str(identidad.get("genero", "")),
		identidad.get("apariencia", {}) as Dictionary,
		especie_canonica
	)
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
	jugador.set_meta("supabase_user_id", user_id)
	jugador.aplicar_identidad_red(
		str(identidad.get("nombre", nombre_verificado)),
		str(identidad.get("genero", "")),
		identidad.get("apariencia", {}) as Dictionary,
		especie_canonica
	)
	jugador.aplicar_runtime_eterium_red(runtime_eterium, reglas_especies)
	_crear_sistemas_jugador_servidor(peer_id, jugador)
	var camara_jugador := jugador.get_node_or_null("Camera2D") as Camera2D
	if is_instance_valid(camara_jugador):
		camara_jugador.enabled = false
	var separacion := Vector2(float((_jugadores_servidor.size() % 4) * 24), float(int(_jugadores_servidor.size() / 4) * 24))
	jugador.global_position = _world_anchor.global_position + Vector2(28.0, 12.0) + separacion
	_jugadores_servidor[peer_id] = jugador
	recibir_identidad_jugador.rpc(peer_id, _crear_identidad_red(jugador))

	var snapshot := _crear_snapshot(true)
	var zone_manager := _main.get_node_or_null("World/ZoneManager")
	var tipo_zona := str(zone_manager.call("obtener_tipo_actual")) if is_instance_valid(zone_manager) else "mundo_abierto"
	recibir_inicio_red.rpc_id(peer_id, snapshot, peer_id, GameState.world_state.world_seed, tipo_zona, GameState.obtener_reinos_desbloqueados())
	_difundir_estado()
	print("GarliaWorldNetwork: jugador autenticado y añadido → ", nombre_verificado, " [", peer_id, "]")


func _obtener_identidad_visual_local() -> Dictionary:
	var nombre := str(_personaje_local.get("nombre", "")).strip_edges().left(MAX_USERNAME_LENGTH)
	var genero := str(_personaje_local.get("genero", "")).strip_edges().left(32)
	var apariencia_variant: Variant = _personaje_local.get("personalizacion", {})
	var apariencia: Dictionary = apariencia_variant.duplicate(true) if apariencia_variant is Dictionary else {}
	var especie_variant: Variant = _personaje_local.get("especie", {})
	var especie: Dictionary = especie_variant as Dictionary if especie_variant is Dictionary else {}
	return {
		"nombre": nombre,
		"genero": genero,
		"apariencia": apariencia,
		"especie_id": str(especie.get("id", "")).strip_edges()
	}


func _sanear_identidad_visual(identidad: Dictionary, nombre_verificado: String) -> Dictionary:
	var nombre := str(identidad.get("nombre", "")).strip_edges().left(MAX_USERNAME_LENGTH)
	if nombre.is_empty():
		nombre = nombre_verificado.strip_edges().left(MAX_USERNAME_LENGTH)
	var genero := str(identidad.get("genero", "")).strip_edges().left(32)
	var apariencia_resultado: Dictionary = {}
	var apariencia_variant: Variant = identidad.get("apariencia", {})
	if apariencia_variant is Dictionary:
		var apariencia := apariencia_variant as Dictionary
		for slot in CharacterAppearance.SLOTS:
			var pieza_variant: Variant = apariencia.get(slot, {})
			if not pieza_variant is Dictionary:
				continue
			var pieza := pieza_variant as Dictionary
			var prefijo := str(CharacterAppearance.SLOT_DIRECTORIES.get(slot, ""))
			var ruta := str(pieza.get("ruta", "")).strip_edges()
			var ruta_segura := ""
			if not prefijo.is_empty() and ruta.begins_with(prefijo) and ruta.get_extension().to_lower() in ["png", "webp"] and ResourceLoader.exists(ruta):
				ruta_segura = ruta
			var color := CharacterAppearance.color_a_html(pieza.get("color", "#ffffff"), Color.WHITE)
			apariencia_resultado[slot] = {"ruta": ruta_segura, "color": color}
	return {"nombre": nombre, "genero": genero, "apariencia": apariencia_resultado}


func _obtener_especie_jugable_canonica(especie_id: String) -> Dictionary:
	if especie_id.is_empty() or not is_instance_valid(_supabase_client):
		return {}
	var especies: Array = _supabase_client.obtener_especies_jugables()
	if especies.is_empty():
		_supabase_client.cargar_especies_jugables()
		for _intento in range(40):
			await get_tree().create_timer(0.2, true, false).timeout
			especies = _supabase_client.obtener_especies_jugables()
			if not especies.is_empty():
				break
	for especie_variant in especies:
		if not especie_variant is Dictionary:
			continue
		var especie := especie_variant as Dictionary
		if str(especie.get("id", "")).strip_edges() == especie_id:
			return especie.duplicate(true)
	return {}


func _obtener_runtime_eterium(token: String) -> Dictionary:
	if not _eterium_runtime_global.is_empty():
		return _eterium_runtime_global.duplicate(true)
	var request := HTTPRequest.new()
	request.timeout = 15.0
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(request)
	var headers := PackedStringArray([
		"apikey: " + GarliaAuth.SUPABASE_PUBLISHABLE_KEY,
		"Authorization: Bearer " + token,
		"Content-Type: application/json"
	])
	var url := GarliaAuth.SUPABASE_URL + "/rest/v1/rpc/get_eterium_runtime_v1"
	var error := request.request(url, headers, HTTPClient.METHOD_POST, "{}")
	if error != OK:
		request.queue_free()
		return {}
	var response: Array = await request.request_completed
	request.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) < 200 or int(response[1]) >= 300:
		push_warning("GarliaWorldNetwork: no se pudo obtener Eterium runtime para el servidor.")
		return {}
	var parsed: Variant = JSON.parse_string(PackedByteArray(response[3]).get_string_from_utf8())
	if not parsed is Dictionary:
		return {}
	var datos := parsed as Dictionary
	if not datos.get("reglas", {}) is Dictionary or not datos.get("organismos", []) is Array:
		return {}
	_eterium_runtime_global = datos.duplicate(true)
	return _eterium_runtime_global.duplicate(true)


func _obtener_reglas_eterium_especies(token: String) -> Array:
	if not _reglas_especies_eterium_global.is_empty():
		return _reglas_especies_eterium_global.duplicate(true)
	var request := HTTPRequest.new()
	request.timeout = 12.0
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(request)
	var headers := PackedStringArray([
		"apikey: " + GarliaAuth.SUPABASE_PUBLISHABLE_KEY,
		"Authorization: Bearer " + token
	])
	var url := GarliaAuth.SUPABASE_URL + "/rest/v1/especie_eterium_game?select=especie_eterium_id,vida_eterium_compartidos,recuperacion_eterium,eterium_inicial,activo,especie_eterium_v1!inner(especie_id,capacidad_base)&activo=eq.true"
	var error := request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		request.queue_free()
		return []
	var response: Array = await request.request_completed
	request.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) < 200 or int(response[1]) >= 300:
		push_warning("GarliaWorldNetwork: no se pudieron cargar reglas Eterium de especie.")
		return []
	var parsed: Variant = JSON.parse_string(PackedByteArray(response[3]).get_string_from_utf8())
	if not parsed is Array:
		return []
	for regla_variant in parsed as Array:
		if regla_variant is Dictionary:
			_reglas_especies_eterium_global.append((regla_variant as Dictionary).duplicate(true))
	return _reglas_especies_eterium_global.duplicate(true)


func _obtener_username_supabase(user_id: String, token: String) -> String:
	if user_id.is_empty() or token.is_empty():
		return ""
	var request := HTTPRequest.new()
	request.timeout = 8.0
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(request)
	var url := GarliaAuth.SUPABASE_URL + "/rest/v1/perfiles?select=username&id=eq." + user_id + "&limit=1"
	var headers := PackedStringArray([
		"apikey: " + GarliaAuth.SUPABASE_PUBLISHABLE_KEY,
		"Authorization: Bearer " + token
	])
	var error := request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		request.queue_free()
		return ""
	var response: Array = await request.request_completed
	request.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) < 200 or int(response[1]) >= 300:
		return ""
	var parsed: Variant = JSON.parse_string(PackedByteArray(response[3]).get_string_from_utf8())
	if not parsed is Array or (parsed as Array).is_empty():
		return ""
	var profile: Variant = (parsed as Array)[0]
	if profile is Dictionary:
		return str((profile as Dictionary).get("username", "")).strip_edges()
	return ""


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
func recibir_inicio_red(snapshot: Array, peer_id_local: int, semilla: int, tipo_zona: String, reinos_globales: Dictionary) -> void:
	if GarliaMultiplayer.es_servidor_dedicado():
		return
	_peer_local_id = peer_id_local
	_semilla_global = semilla
	_estado_inicial_pendiente = snapshot.duplicate(true)
	if is_instance_valid(_local_player):
		_aplicar_snapshot(_estado_inicial_pendiente)
		_estado_inicial_pendiente.clear()
	mundo_global_listo.emit(_semilla_global, tipo_zona, reinos_globales)


@rpc("authority", "call_remote", "reliable")
func rechazar_entrada_global(mensaje: String) -> void:
	_cliente_global_activado = false
	GarliaMultiplayer.cerrar_partida()
	mundo_global_rechazado.emit(mensaje)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func recibir_input_global(direccion: Vector2, correr: bool, dash: bool, sprint_eterium: bool, salto: bool) -> void:
	if not GarliaMultiplayer.es_servidor_dedicado():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var jugador: Player = _jugadores_servidor.get(peer_id) as Player
	if not is_instance_valid(jugador) or not direccion.is_finite():
		return
	var ahora := Time.get_ticks_msec()
	var anterior := int(_ultimo_input_servidor.get(peer_id, 0))
	if ahora - anterior < 20:
		return
	_ultimo_input_servidor[peer_id] = ahora
	jugador.establecer_input_red(direccion.limit_length(1.0), correr, dash, sprint_eterium, salto)



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


func notificar_reino_descubierto(clave: String) -> void:
	if not es_cliente_en_mundo_global():
		return
	var limpia := clave.strip_edges().to_lower()
	if not limpia.is_empty():
		registrar_descubrimiento_global.rpc_id(1, limpia)


@rpc("any_peer", "call_remote", "reliable")
func registrar_descubrimiento_global(clave: String) -> void:
	if not GarliaMultiplayer.es_servidor_dedicado():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _jugadores_servidor.has(peer_id) or not is_instance_valid(_world_context):
		return
	var limpia := clave.strip_edges().to_lower()
	if limpia.is_empty():
		return
	var jugador: Player = _jugadores_servidor[peer_id] as Player
	var presentes: Array = _world_context.call("get_reinos_at_position", jugador.global_position)
	var verificado := false
	for reino_variant in presentes:
		if reino_variant is Dictionary and str((reino_variant as Dictionary).get("clave", "")).strip_edges().to_lower() == limpia:
			verificado = true
			break
	if not verificado:
		return
	GameState.desbloquear_reino(limpia)
	print("GarliaWorldNetwork: reino descubierto validado en servidor → ", limpia)


@rpc("any_peer", "call_remote", "reliable")
func solicitar_viaje_global(destino: String) -> void:
	if not GarliaMultiplayer.es_servidor_dedicado():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _jugadores_servidor.has(peer_id) or not _mundo_listo:
		return
	var clave := destino.strip_edges().to_lower()
	if clave.is_empty():
		return
	if clave != "mundo_abierto":
		var desbloqueados: Dictionary = GameState.obtener_reinos_desbloqueados()
		if not bool(desbloqueados.get(clave, false)):
			return
		var regla := _supabase_client.obtener_reino_game(clave) if is_instance_valid(_supabase_client) else {}
		if regla.is_empty():
			return
	var zone_manager := _main.get_node_or_null("World/ZoneManager")
	if not is_instance_valid(zone_manager):
		return
	var zona_actual := str(zone_manager.call("obtener_tipo_actual"))
	var destino_actual := "mundo_abierto" if clave == "mundo_abierto" else "reino:" + clave
	if zona_actual == destino_actual or (clave == "torres" and zona_actual == "reino_torres"):
		return
	_mundo_listo = false
	if clave == "mundo_abierto":
		zone_manager.call("entrar_mundo_abierto")
	else:
		zone_manager.call("entrar_reino", clave)
	_confirmar_cambio_zona_global(clave)


func _confirmar_cambio_zona_global(destino: String) -> void:
	# No anunciar un destino hasta que Main haya reconstruido la zona en servidor.
	var intentos := 0
	while intentos < 200 and GarliaMultiplayer.es_servidor_dedicado() and not _mundo_listo:
		await get_tree().create_timer(0.05, true, false).timeout
		intentos += 1
	if not GarliaMultiplayer.es_servidor_dedicado() or not _mundo_listo:
		return
	cambiar_zona_global.rpc(destino)
	_difundir_estado()


@rpc("authority", "call_remote", "reliable")
func cambiar_zona_global(destino: String) -> void:
	if GarliaMultiplayer.es_servidor_dedicado():
		return
	var zone_manager := _main.get_node_or_null("World/ZoneManager") if is_instance_valid(_main) else null
	if not is_instance_valid(zone_manager):
		return
	if destino == "mundo_abierto":
		zone_manager.call("entrar_mundo_abierto")
	else:
		zone_manager.call("entrar_reino", destino)


func enviar_solicitud_viaje(destino: String) -> void:
	if not es_cliente_en_mundo_global():
		return
	var clave := destino.strip_edges().to_lower()
	if clave.is_empty():
		return
	solicitar_viaje_global.rpc_id(1, clave)


func solicitar_accion_local(accion: String) -> void:
	if not es_cliente_en_mundo_global():
		return
	if accion != "primary" and accion != "secondary":
		return
	solicitar_accion_global.rpc_id(1, accion)


@rpc("authority", "call_remote", "reliable")
func recibir_identidad_jugador(peer_id: int, identidad: Dictionary) -> void:
	if GarliaMultiplayer.es_servidor_dedicado() or peer_id <= 0:
		return
	_identidades_remotas_cliente[peer_id] = identidad.duplicate(true)
	if peer_id == _peer_local_id:
		if is_instance_valid(_local_player):
			_aplicar_identidad_snapshot(_local_player, identidad)
	elif _proxies_cliente.has(peer_id):
		var proxy: Player = _proxies_cliente[peer_id] as Player
		if is_instance_valid(proxy):
			_aplicar_identidad_snapshot(proxy, identidad)


func _aplicar_identidad_snapshot(jugador: Player, identidad: Dictionary) -> void:
	if not is_instance_valid(jugador):
		return
	jugador.aplicar_identidad_red(
		str(identidad.get("username", jugador.personaje_nombre)),
		str(identidad.get("gender", "")),
		identidad.get("appearance", {}) as Dictionary,
		identidad.get("species", {}) as Dictionary
	)


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


func _crear_identidad_red(jugador: Player) -> Dictionary:
	return {
		"username": jugador.personaje_nombre,
		"gender": jugador.personaje_genero,
		"appearance": jugador.personaje_apariencia.duplicate(true),
		"species": jugador.personaje_especie.duplicate(true)
	}


func _crear_snapshot(incluir_identidad: bool = false) -> Array:
	var resultado: Array = []
	for peer_variant in _jugadores_servidor.keys():
		var peer_id := int(peer_variant)
		var jugador: Player = _jugadores_servidor[peer_id] as Player
		if not is_instance_valid(jugador):
			continue
		var registro := {
			"peer_id": peer_id,
			"x": jugador.global_position.x,
			"y": jugador.global_position.y,
			"facing_x": jugador.facing.x,
			"facing_y": jugador.facing.y,
			"state": int(jugador.state),
			"health": int(jugador.health),
			"max_health": int(jugador.max_health),
			"mana": int(jugador.mana),
			"max_mana": int(jugador.max_mana),
			"stamina": float(jugador.stamina),
			"max_stamina": float(jugador.max_stamina),
			"is_alive": bool(jugador.is_alive)
		}
		if incluir_identidad:
			registro.merge(_crear_identidad_red(jugador), true)
		resultado.append(registro)
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
		if registro.has("username"):
			_identidades_remotas_cliente[peer_id] = {
				"username": registro.get("username", ""),
				"gender": registro.get("gender", ""),
				"appearance": registro.get("appearance", {}),
				"species": registro.get("species", {})
			}
		var posicion := Vector2(float(registro.get("x", 0.0)), float(registro.get("y", 0.0)))
		var direccion := Vector2(float(registro.get("facing_x", 0.0)), float(registro.get("facing_y", 1.0)))
		if peer_id == _peer_local_id:
			if is_instance_valid(_local_player):
				_objetivo_posicion_local = posicion
				if not _local_posicion_inicializada or _local_player.global_position.distance_to(posicion) > 320.0:
					_local_player.global_position = posicion
					_local_posicion_inicializada = true
				if direccion.length_squared() > 0.01:
					_local_player.facing = direccion.normalized()
					_local_player.call("_update_dir_marker")
				var identidad_local: Dictionary = _identidades_remotas_cliente.get(peer_id, {})
				if not identidad_local.is_empty():
					_aplicar_identidad_snapshot(_local_player, identidad_local)
				_actualizar_estado_jugador(_local_player, registro)
			continue
		var proxy: Player = _proxies_cliente.get(peer_id) as Player
		if not is_instance_valid(proxy):
			proxy = PLAYER_SCENE.instantiate() as Player
			if proxy == null:
				continue
			proxy.name = "JugadorRemoto_%d" % peer_id
			proxy.personaje_nombre = str(registro.get("username", "Explorador"))
			proxy.remove_from_group("player")
			proxy.collision_layer = 0
			proxy.collision_mask = 0
			var hurtbox_proxy := proxy.get_node_or_null("Hurtbox") as Area2D
			if is_instance_valid(hurtbox_proxy):
				hurtbox_proxy.collision_layer = 0
				hurtbox_proxy.collision_mask = 0
				hurtbox_proxy.monitoring = false
				hurtbox_proxy.monitorable = false
			proxy.set_physics_process(false)
			proxy.set_process(false)
			proxy.global_position = posicion
			_objetivos_posicion_proxy[peer_id] = posicion
			_entities.add_child(proxy)
			var camara_proxy := proxy.get_node_or_null("Camera2D") as Camera2D
			if is_instance_valid(camara_proxy):
				camara_proxy.enabled = false
			proxy.set_physics_process(false)
			proxy.set_process(false)
			_proxies_cliente[peer_id] = proxy
		_objetivos_posicion_proxy[peer_id] = posicion
		var identidad_proxy: Dictionary = _identidades_remotas_cliente.get(peer_id, {})
		if not identidad_proxy.is_empty():
			_aplicar_identidad_snapshot(proxy, identidad_proxy)
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
		_objetivos_posicion_proxy.erase(peer_id)
		_identidades_remotas_cliente.erase(peer_id)
		_objetivos_posicion_proxy.erase(peer_id)
		_identidades_remotas_cliente.erase(peer_id)


func _actualizar_interpolacion_clientes(delta: float) -> void:
	var factor := 1.0 - exp(-SNAPSHOT_INTERPOLATION_SPEED * delta)
	if is_instance_valid(_local_player) and _local_posicion_inicializada:
		if _local_player.global_position.distance_to(_objetivo_posicion_local) <= 320.0:
			_local_player.global_position = _local_player.global_position.lerp(_objetivo_posicion_local, factor)
	for peer_variant in _proxies_cliente.keys():
		var peer_id := int(peer_variant)
		var proxy: Player = _proxies_cliente[peer_id] as Player
		if not is_instance_valid(proxy) or not _objetivos_posicion_proxy.has(peer_id):
			continue
		var objetivo: Vector2 = _objetivos_posicion_proxy[peer_id]
		var distancia := proxy.global_position.distance_to(objetivo)
		if distancia > 320.0:
			proxy.global_position = objetivo
		else:
			proxy.global_position = proxy.global_position.lerp(objetivo, factor)


func _limpiar_inputs_expirados() -> void:
	var ahora := Time.get_ticks_msec()
	for peer_variant in _ultimo_input_servidor.keys():
		var peer_id := int(peer_variant)
		if ahora - int(_ultimo_input_servidor[peer_id]) <= 300:
			continue
		var jugador: Player = _jugadores_servidor.get(peer_id) as Player
		if is_instance_valid(jugador):
			jugador.establecer_input_red(Vector2.ZERO, false, false, false)
		_ultimo_input_servidor.erase(peer_id)


func _revisar_reapariciones() -> void:
	for peer_variant in _jugadores_servidor.keys():
		var peer_id := int(peer_variant)
		var jugador: Player = _jugadores_servidor[peer_id] as Player
		if not is_instance_valid(jugador) or jugador.is_alive or _reapariciones_pendientes.has(peer_id):
			continue
		_reapariciones_pendientes[peer_id] = true
		_reaparecer_despues(peer_id)


func _reaparecer_despues(peer_id: int) -> void:
	await get_tree().create_timer(2.5, true, false).timeout
	_reapariciones_pendientes.erase(peer_id)
	if not GarliaMultiplayer.es_servidor_dedicado() or not _jugadores_servidor.has(peer_id):
		return
	var jugador: Player = _jugadores_servidor[peer_id] as Player
	if not is_instance_valid(jugador) or jugador.is_alive:
		return
	var posicion := _world_anchor.global_position + Vector2(float((peer_id % 4) * 18), 12.0) if is_instance_valid(_world_anchor) else Vector2.ZERO
	jugador.reaparecer_en_red(posicion)
	_difundir_estado()


func _actualizar_estado_jugador(jugador: Player, registro: Dictionary) -> void:
	if not is_instance_valid(jugador):
		return
	var estaba_vivo := bool(jugador.is_alive)
	var vital := jugador.vital_state as VitalState
	if is_instance_valid(vital):
		vital.max_health = maxi(int(registro.get("max_health", vital.max_health)), 1)
		vital.max_mana = maxi(int(registro.get("max_mana", vital.max_mana)), 1)
		vital.health = clampi(int(registro.get("health", vital.health)), 0, vital.max_health)
		vital.mana = clampi(int(registro.get("mana", vital.mana)), 0, vital.max_mana)
		vital.is_alive = bool(registro.get("is_alive", vital.is_alive)) and vital.health > 0
		jugador.call("_sync_desde_vital")
	var estado_recibido := int(registro.get("state", int(jugador.state)))
	if estado_recibido >= Player.State.IDLE and estado_recibido <= Player.State.DASH and int(jugador.state) != estado_recibido:
		jugador.set("state", estado_recibido)
		jugador.call("_update_visual")
	jugador.visible = bool(jugador.is_alive)
	if jugador == _local_player and jugador.is_alive and not estaba_vivo:
		jugador.visible = true
		jugador.set_physics_process(true)
	jugador.max_stamina = clampf(float(registro.get("max_stamina", jugador.max_stamina)), 1.0, 5.0)
	if jugador.get("stamina_controller") != null:
		var stamina_controller: Variant = jugador.get("stamina_controller")
		if stamina_controller.has_method("establecer_maximo"):
			stamina_controller.call("establecer_maximo", jugador.max_stamina)
		if stamina_controller.has_method("establecer_actual"):
			stamina_controller.call("establecer_actual", clampf(float(registro.get("stamina", jugador.stamina)), 0.0, jugador.max_stamina))
		else:
			jugador.stamina = clampf(float(registro.get("stamina", jugador.stamina)), 0.0, jugador.max_stamina)
	if jugador.has_signal("health_changed"):
		jugador.health_changed.emit(int(jugador.health), int(jugador.max_health))
	if jugador.has_signal("mana_changed"):
		jugador.mana_changed.emit(int(jugador.mana), int(jugador.max_mana))
	if jugador.has_signal("stamina_changed"):
		jugador.stamina_changed.emit(float(jugador.stamina), float(jugador.max_stamina))


func _al_servidor_desconectado() -> void:
	_cliente_global_activado = false
	_dash_local_pendiente = false
	_salto_local_pendiente = false
	for proxy_variant in _proxies_cliente.values():
		var proxy := proxy_variant as Player
		if is_instance_valid(proxy):
			proxy.queue_free()
	_proxies_cliente.clear()
	_objetivos_posicion_proxy.clear()
	_identidades_remotas_cliente.clear()
	_local_posicion_inicializada = false
	_dash_local_pendiente = false
	_salto_local_pendiente = false
	_estado_inicial_pendiente.clear()
	_peer_local_id = 0
	if is_instance_valid(_local_player):
		_local_player.set_physics_process(true)
	Events.notification_pushed.emit("Se perdió la conexión con el mundo global.")


func _al_desconectar_peer(peer_id: int) -> void:
	if GarliaMultiplayer.es_servidor_dedicado():
		var jugador: Player = _jugadores_servidor.get(peer_id) as Player
		if is_instance_valid(jugador):
			jugador.queue_free()
		_jugadores_servidor.erase(peer_id)
		_sistemas_jugador_servidor.erase(peer_id)
		_ultima_accion_servidor.erase(peer_id)
		_ultimo_input_servidor.erase(peer_id)
		_reapariciones_pendientes.erase(peer_id)
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
