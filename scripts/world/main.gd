extends Node2D

@export var pantalla_completa: bool = true
@export var camera_zoom: float = 2.0

var _player: Player = null
var _camera: Camera2D = null
var _ultima_posicion_camara: Vector2 = Vector2.INF
@onready var _input_router: GameplayInputRouter = $Systems/GameplayInputRouter

@onready var _hud: HUD = $UI/HUD
@onready var _inventory: GarliaInventory = $UI/Inventory
@onready var _interaction_system: InteractionSystem = $Systems/InteractionSystem
@onready var _combat_system: CombatSystem = $Systems/CombatSystem
@onready var _dialogue_system: DialogueSystem = $Systems/DialogueSystem
@onready var _ium_manager: IUMManager = $Systems/IUMManager
@onready var _ium_lab: IUMLab = $UI/IUMLab
@onready var _admin_console: AdminConsole = $UI/AdminConsole
@onready var _admin_player_editor: Control = $UI/AdminPlayerEditor
@onready var _pause_menu: PauseMenu = $UI/PauseMenu
@onready var _death_menu: DeathMenu = $UI/DeathMenu
@onready var _debug_console: Node = $UI/DebugConsole
var _world_entity_spawner: WorldEntitySpawner = null
var _eterium_radial_menu: Control = null
var _garumi_combat_arena: Node2D = null
var _garumi_battle_party: Node = null
@onready var _supabase_client: GarliaSupabaseClient = SupabaseClient
@onready var _ium_repository: IUMRepository = $Systems/IUMRepository
@onready var _game_camera: Camera2D = $GameCamera
@onready var _combat_projectiles: Node2D = $CombatProjectiles
var _world_atmosphere: WorldAtmosphere = null
var _world_generator: WorldGenerator = null
@onready var _world_context: WorldContext = $Systems/WorldContext
@onready var _world_items: GarliaWorldItems = $Systems/WorldItems
const ZONE_MANAGER_SCRIPT = preload("res://scripts/world/zone_manager.gd")
const ETERIUM_RADIAL_MENU_SCRIPT = preload("res://scripts/ui/eterium_radial_menu.gd")
const GARUMI_COMBAT_ARENA_SCRIPT = preload("res://scripts/gameplay/garumi_combat_arena.gd")
const GARUMI_BATTLE_PARTY_SCRIPT = preload("res://scripts/gameplay/garumi_battle_party.gd")
@onready var _zone_manager: Node2D = $World/ZoneManager
@onready var _realm_menu: Control = $UI/RealmMenu
var _reino_descubrimiento_elapsed: float = 0.0
var _datos_mundo_servidor_listos := false
var _reinos_game_servidor_listos := false
var _inicio_servidor_pendiente := false


func _ready() -> void:
	SupabaseClient.configurar_dependencias(GarliaAuth)
	GarliaMultiplayer.configurar_dependencias(GarliaAuth)
	GarliaSalas.configurar_dependencias(GarliaAuth)

	WorldData.configurar_dependencias(_supabase_client)
	if GarliaMultiplayer.es_servidor_dedicado():
		GlobalWorldStore.restaurar_en_game_state(GameState)

	_world_atmosphere = $Systems/WorldAtmosphere as WorldAtmosphere
	if not is_instance_valid(_world_atmosphere):
		push_error("Main: falta Systems/WorldAtmosphere; el reloj global no puede iniciar.")
	else:
		# El calendario pertenece al runtime principal y sigue activo en reinos e interiores.
		_world_atmosphere.configurar_dependencias(WorldData)
		var tiempo_guardado: Variant = GameState.world_state.flags.get("tiempo_mundo", {})
		if tiempo_guardado is Dictionary and not (tiempo_guardado as Dictionary).is_empty():
			_world_atmosphere.establecer_estado_guardado(tiempo_guardado as Dictionary)

	_supabase_client.establecer_mundo_activo(true)
	if not _supabase_client.relaciones_ecologicas_cargadas.is_connected(_al_cargar_relaciones_ecologicas):
		_supabase_client.relaciones_ecologicas_cargadas.connect(_al_cargar_relaciones_ecologicas)

	if _zone_manager == null:
		push_error("Main: falta World/ZoneManager.")
		return

	if not _zone_manager.zona_cambiada.is_connected(_al_cambio_de_zona):
		_zone_manager.zona_cambiada.connect(_al_cambio_de_zona)
	if is_instance_valid(_realm_menu) and _realm_menu.has_signal("destino_solicitado"):
		var callback_viaje := Callable(self, "_al_solicitar_destino_reino")
		if not _realm_menu.is_connected("destino_solicitado", callback_viaje):
			_realm_menu.connect("destino_solicitado", callback_viaje)
	if not _supabase_client.reinos_game_cargados.is_connected(_al_reinos_game_cargados):
		_supabase_client.reinos_game_cargados.connect(_al_reinos_game_cargados)

	# El Player existe en Main desde el primer frame. No debemos esperar a que
	# termine la generación del mundo para vincularlo al HUD/cámara; esa espera
	# hacía que F3 mostrara "Sin jugador" durante la inicialización.
	_player = get_node_or_null("Entities/Player") as Player
	if _player == null:
		push_error("Main: Entities/Player existe en la escena pero no pudo obtenerse como Player.")
	else:
		_configurar_camara()
		_configurar_hud(_world_context, null)

	_supabase_client.cargar_reinos_game()
	_reinos_game_servidor_listos = not _supabase_client.obtener_reinos_game().is_empty()
	if GarliaMultiplayer.es_servidor_dedicado():
		_esperar_datos_mundo_servidor()
	elif not GameState.debe_iniciar_en_reino_torres():
		_iniciar_zonas()
	elif not _supabase_client.obtener_reinos_game().is_empty():
		_iniciar_zonas()
	else:
		call_deferred("_verificar_inicio_de_zona")


func _esperar_datos_mundo_servidor() -> void:
	_inicio_servidor_pendiente = true
	_datos_mundo_servidor_listos = WorldData.esta_cargado()
	_reinos_game_servidor_listos = _reinos_game_servidor_listos or not _supabase_client.obtener_reinos_game().is_empty()
	if not _datos_mundo_servidor_listos:
		if not WorldData.mundo_listo.is_connected(_al_datos_mundo_servidor_listos):
			WorldData.mundo_listo.connect(_al_datos_mundo_servidor_listos, CONNECT_ONE_SHOT)
		_supabase_client.cargar_mundo_inicial()
	_intentar_iniciar_servidor_global()


func _al_datos_mundo_servidor_listos() -> void:
	if not GarliaMultiplayer.es_servidor_dedicado():
		return
	_datos_mundo_servidor_listos = true
	_intentar_iniciar_servidor_global()


func _intentar_iniciar_servidor_global() -> void:
	if not GarliaMultiplayer.es_servidor_dedicado() or not _inicio_servidor_pendiente:
		return
	if not _datos_mundo_servidor_listos or not _reinos_game_servidor_listos:
		return
	_inicio_servidor_pendiente = false
	_iniciar_zonas()


func _exit_tree() -> void:
	if GarliaMultiplayer.es_servidor_dedicado():
		GlobalWorldStore.guardar_desde_runtime()
	if is_instance_valid(_supabase_client):
		_supabase_client.establecer_mundo_activo(false)


func _al_reinos_game_cargados(_reinos: Array) -> void:
	if GarliaMultiplayer.es_servidor_dedicado():
		_reinos_game_servidor_listos = true
		_intentar_iniciar_servidor_global()
		return
	if GameState.debe_iniciar_en_reino_torres():
		_iniciar_zonas()

func _verificar_inicio_de_zona() -> void:
	if _zone_manager == null:
		return
	if _zone_manager.obtener_tipo_actual() != "" or is_instance_valid(_zone_manager.obtener_zona_actual()):
		return
	var reinos: Array = _supabase_client.obtener_reinos_game()
	if not reinos.is_empty():
		_iniciar_zonas()
		return
	await get_tree().create_timer(0.5).timeout
	if is_inside_tree():
		_verificar_inicio_de_zona()


func _iniciar_zonas() -> void:
	_zone_manager.configurar_dependencias(_supabase_client)
	_zone_manager.iniciar()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var tecla := event as InputEventKey
	if not tecla.pressed or tecla.echo or tecla.keycode != KEY_M or not tecla.shift_pressed:
		return
	if _realm_menu == null or not is_instance_valid(_realm_menu):
		return
	if _realm_menu.has_method("alternar"):
		_realm_menu.call("alternar", _supabase_client, GameState, _zone_manager.obtener_tipo_actual())
		get_viewport().set_input_as_handled()


func _al_solicitar_destino_reino(clave: String) -> void:
	print("Main: destino solicitado desde RealmMenu → ", clave)
	if GarliaWorldNetwork.es_cliente_en_mundo_global():
		GarliaWorldNetwork.enviar_solicitud_viaje(clave)
		return
	if _zone_manager == null or not is_instance_valid(_zone_manager):
		return
	if clave == "mundo_abierto":
		_zone_manager.entrar_mundo_abierto()
		return
	var desbloqueados: Dictionary = GameState.obtener_reinos_desbloqueados()
	if not bool(desbloqueados.get(clave.strip_edges().to_lower(), false)):
		push_warning("Main: intento de viajar a un reino todavía no descubierto: " + clave)
		return
	if _zone_manager.has_method("entrar_reino"):
		_zone_manager.call("entrar_reino", clave)


func _process(delta: float) -> void:
	# La cámara debe seguir funcionando aunque la zona tarde en terminar de inicializar.
	if _player == null:
		var jugador_en_escena: Player = get_node_or_null("Entities/Player") as Player
		if jugador_en_escena != null:
			_player = jugador_en_escena
	if _camera == null:
		var camara_en_escena: Camera2D = get_node_or_null("GameCamera") as Camera2D
		if camara_en_escena != null:
			_camera = camara_en_escena
			_configurar_camara()
	_seguir_jugador()

	_reino_descubrimiento_elapsed += delta
	if _reino_descubrimiento_elapsed >= 0.5:
		_reino_descubrimiento_elapsed = 0.0
		_detectar_reinos_descubiertos()


func _detectar_reinos_descubiertos() -> void:
	# En servidor dedicado el Player de Main es un ancla técnica oculta.
	# Los descubrimientos se validan por RPC usando la posición del jugador real.
	if GarliaMultiplayer.es_servidor_dedicado():
		return
	if _zone_manager == null or _zone_manager.obtener_tipo_actual() != "mundo_abierto":
		return
	if not is_instance_valid(_player) or _world_context == null or not _world_context.tiene_mundo_activo():
		return
	if _supabase_client == null:
		return
	for reino_variant in _world_context.get_reinos_at_position(_player.global_position):
		if not reino_variant is Dictionary:
			continue
		var reino := reino_variant as Dictionary
		var clave := str(reino.get("clave", "")).strip_edges().to_lower()
		if clave.is_empty():
			continue
		var regla := _supabase_client.obtener_reino_game(clave)
		if regla.is_empty():
			continue
		var propiedades_variant: Variant = regla.get("propiedades", {})
		if not propiedades_variant is Dictionary:
			continue
		var propiedades := propiedades_variant as Dictionary
		if str(propiedades.get("tipo_zona", "")) != "escena_fija":
			continue
		if bool(propiedades.get("usa_world_generator", false)) or bool(propiedades.get("generacion_procedural", false)):
			continue
		var escena := str(propiedades.get("escena", "")).strip_edges()
		if escena.is_empty() or not ResourceLoader.exists(escena):
			continue
		if GarliaWorldNetwork.es_cliente_en_mundo_global():
			# El servidor valida la posición y difunde el desbloqueo confirmado.
			if not bool(GameState.obtener_reinos_desbloqueados().get(clave, false)):
				GarliaWorldNetwork.notificar_reino_descubierto(clave)
		else:
			GameState.desbloquear_reino(clave)


func _al_cambio_de_zona(tipo: String, _zona: Node) -> void:
	if GarliaMultiplayer.es_servidor_dedicado():
		GarliaWorldNetwork.preparar_cambio_zona_servidor()
	_world_generator = _zone_manager.obtener_world_generator()
	_world_entity_spawner = null

	if tipo == "mundo_abierto":
		if _world_generator == null:
			push_error("Main: MundoAbierto no contiene WorldGenerator.")
			return

		_world_entity_spawner = _world_generator.get_node_or_null("WorldEntitySpawner") as WorldEntitySpawner
		_world_generator.configurar_atmosfera_compartida(_world_atmosphere)
		_world_context.configurar(
			_world_generator.get_node_or_null("WorldTerrain") as WorldTerrain,
			_world_atmosphere,
			WorldData
		)
		_world_items.establecer_generacion_habilitada(true)

		_world_generator.configurar_dependencias(WorldData, GameState)
		# La nueva instancia de WorldAtmosphere debe recuperar el calendario
		# compartido, incluso si se pasó un tiempo en un reino de escena fija.
		if is_instance_valid(_world_atmosphere):
			var tiempo_guardado: Variant = GameState.world_state.flags.get("tiempo_mundo", {})
			if tiempo_guardado is Dictionary and not (tiempo_guardado as Dictionary).is_empty():
				_world_atmosphere.establecer_estado_guardado((tiempo_guardado as Dictionary).duplicate(true))
		_world_generator.configurar_contexto_compartido(_world_context)
		_world_generator.configurar_entidades(
			$Entities,
			$Entities/Player,
			_inventory,
			_combat_system,
			_dialogue_system,
			MissionManager,
			_world_context,
			_world_items,
			_supabase_client.obtener_relaciones_ecologicas()
		)

		if _world_generator.is_world_ready():
			_inicializar_runtime_de_zona()
		else:
			# El runtime no debe esperar a que el primer chunk termine de
			# renderizar. El jugador y el streamer se enlazan apenas el mundo
			# queda estructuralmente listo; la generación visual continúa aparte.
			if not _world_generator.mundo_inicializado.is_connected(_al_mundo_inicializado):
				_world_generator.mundo_inicializado.connect(_al_mundo_inicializado, CONNECT_ONE_SHOT)
			return
	else:
		# Reino Torres no crea WorldGenerator ni entidades procedurales.
		_world_context.configurar(null, null, WorldData)
		_world_items.establecer_generacion_habilitada(false)
		_inicializar_runtime_de_zona()


func _al_mundo_inicializado() -> void:
	_inicializar_runtime_de_zona()



func _inicializar_runtime_de_zona() -> void:
	_player = $Entities/Player as Player

	if _player == null:
		push_error("Main: no se encontró Entities/Player.")
		return

	if GarliaMultiplayer.es_servidor_dedicado() and _world_generator != null:
		GlobalWorldStore.restaurar_estado_entidades(_world_generator.entity_manager, str(_zone_manager.obtener_tipo_actual()))

	if _zone_manager.obtener_tipo_actual() == "mundo_abierto" and _world_generator != null:
		if _zone_manager.consumir_salida_reino_pendiente():
			_player.global_position = Vector2(560, 120)
		else:
			_player.set_spawn_from_world(_world_generator)
		_world_generator.registrar_jugador(_player)

	_world_items.configurar_dependencias(
		$Entities/Player,
		_inventory,
		$Entities,
		_world_generator.entity_manager if _world_generator != null else null,
		_world_context,
		MissionManager
	)

	_player.configurar_dependencias(
		_inventory,
		_world_context,
		_ium_manager,
		_world_generator.entity_manager if _world_generator != null else null,
		_supabase_client,
		GameState
	)

	_configurar_camara()
	_configurar_hud(_world_context, _world_generator)
	_configurar_input_router()
	_configurar_interaccion(_world_generator)
	_configurar_combate(_world_context, _world_generator)
	_configurar_inventario()
	GameState.configurar_dependencias(
		_inventory,
		_player,
		_world_context,
		_world_atmosphere,
		MissionManager,
		WorldData
	)
	_configurar_dialogo()
	MissionManager.configurar_dependencias(
		_world_generator.entity_manager if _world_generator != null else null,
		WorldData
	)
	_configurar_social()
	_inicializar_ium()
	_configurar_admin()
	_configurar_pantalla()
	if _zone_manager.obtener_tipo_actual() == "mundo_abierto" and _world_generator != null:
		call_deferred("_restaurar_garumis_vinculados")

	var tipo_zona_actual: String = str(_zone_manager.obtener_tipo_actual())
	if tipo_zona_actual == "reino_torres" or tipo_zona_actual.begins_with("reino:"):
		var zona_actual: Node = _zone_manager.obtener_zona_actual()
		var punto_aparicion: Node2D = zona_actual.get_node_or_null("PlayerSpawn") as Node2D if is_instance_valid(zona_actual) else null
		_player.global_position = punto_aparicion.global_position if is_instance_valid(punto_aparicion) else Vector2(0, 120)
		print("Main: reino activo → ", tipo_zona_actual)
	else:
		print("Main: mundo abierto listo.")

	if GarliaMultiplayer.es_servidor_dedicado():
		GarliaWorldNetwork.inicializar_mundo_servidor(
			self,
			$Entities,
			_player,
			_world_context,
			_world_generator.entity_manager if _world_generator != null else null,
			_ium_manager,
			_supabase_client
		)
	elif GarliaWorldNetwork.es_cliente_en_mundo_global():
		GarliaWorldNetwork.configurar_mundo_cliente(
			self,
			$Entities,
			_player,
			_world_generator.entity_manager if _world_generator != null else null,
			tipo_zona_actual
		)


## Reconstruye las instancias vinculadas después de cargar el estado de la partida.
func _restaurar_garumis_vinculados() -> void:
	if not is_instance_valid(_player) or _world_generator == null:
		return
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null or not game_state.has_method("obtener_garumis_vinculados"):
		return
	var entity_manager: WorldEntityManager = _world_generator.entity_manager
	var entity_factory: WorldEntityFactory = _world_generator.entity_factory
	if entity_manager == null or entity_factory == null:
		push_warning("Main: no se pudieron restaurar Garumis: falta EntityManager o EntityFactory.")
		return
	var registros_variant: Variant = game_state.call("obtener_garumis_vinculados")
	if not registros_variant is Array:
		return
	var restaurados := 0
	for registro_variant in registros_variant as Array:
		if not registro_variant is Dictionary:
			continue
		var registro := (registro_variant as Dictionary).duplicate(true)
		var id_instancia := str(registro.get("garumi_instancia_id", "")).strip_edges()
		var especie_id := str(registro.get("id", registro.get("criatura_id", ""))).strip_edges()
		if id_instancia.is_empty() or especie_id.is_empty():
			push_warning("Main: se omitió un Garumi guardado sin ID de instancia o especie.")
			continue
		var clave_persistente := "garumi_vinculado:" + id_instancia
		if entity_manager.existe_persistente(clave_persistente):
			continue
		registro["categoria_entidad"] = "garumi"
		registro["vinculado"] = true
		registro["garumi_instancia_id"] = id_instancia
		var garumi := entity_factory.crear_criatura(registro) as Garumi
		if garumi == null:
			push_warning("Main: no se pudo reconstruir el Garumi " + especie_id)
			continue
		var posicion_guardada := Vector2(
			float(registro.get("position_x", _player.global_position.x + 42.0)),
			float(registro.get("position_y", _player.global_position.y + 20.0))
		)
		var esta_guardado := bool(registro.get("guardado", false))
		# Si quedó libre lejos del jugador al cerrar el juego, vuelve a su lado.
		if not esta_guardado and posicion_guardada.distance_to(_player.global_position) > 520.0:
			posicion_guardada = _player.global_position + Vector2(42.0, 20.0)
		garumi.global_position = posicion_guardada
		if not entity_manager.registrar_global(garumi, clave_persistente):
			entity_factory.reciclar_criatura(garumi)
			continue
		garumi.restaurar_vinculo_persistido(_player, esta_guardado, posicion_guardada)
		if is_instance_valid(_hud) and _hud.has_method("registrar_garumi_restaurado"):
			_hud.call("registrar_garumi_restaurado", garumi)
		restaurados += 1
	if restaurados > 0:
		print("Main: Garumis vinculados restaurados desde la partida: ", restaurados)


func _configurar_camara() -> void:
	var camara_actual: Camera2D = get_viewport().get_camera_2d()

	if camara_actual != null:
		camara_actual.enabled = false

	_camera = _game_camera

	if _camera == null:
		push_error("Main: falta GameCamera en la escena.")
		return

	_camera.enabled = true
	_camera.zoom = Vector2(camera_zoom, camera_zoom)
	_camera.position = Vector2.ZERO
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	_camera.offset = Vector2.ZERO
	_camera.position_smoothing_enabled = false
	_ultima_posicion_camara = Vector2.INF
	_camera.drag_horizontal_enabled = false
	_camera.drag_vertical_enabled = false
	var tipo_zona: String = str(_zone_manager.obtener_tipo_actual()) if is_instance_valid(_zone_manager) else ""
	if tipo_zona == "reino_torres":
		# Límites del Ground de reino_torres.tscn; Camera2D calcula el área
		# visible según el zoom para no mostrar fuera del borde del reino.
		_camera.limit_left = -1200
		_camera.limit_right = 1200
		_camera.limit_top = -700
		_camera.limit_bottom = 700
		_camera.limit_enabled = true
	else:
		_camera.limit_enabled = false
	_camera.make_current()

	_seguir_jugador()


func _seguir_jugador() -> void:
	if _player == null or _camera == null:
		return
	if is_instance_valid(_garumi_combat_arena) and _garumi_combat_arena.call("esta_activa"):
		_camera.global_position = _garumi_combat_arena.call("obtener_centro")
		_ultima_posicion_camara = _camera.global_position
		return

	var posicion: Vector2 = _player.global_position
	if posicion == _ultima_posicion_camara:
		return

	_camera.global_position = posicion
	_ultima_posicion_camara = posicion


func iniciar_arena_garumi(garumi: Node, jugador: Node) -> void:
	if not garumi is Node2D or not jugador is Node2D:
		return
	if is_instance_valid(_garumi_combat_arena):
		_garumi_combat_arena.call("terminar")
	_garumi_combat_arena = Node2D.new()
	_garumi_combat_arena.name = "GarumiCombatArena"
	_garumi_combat_arena.set_script(GARUMI_COMBAT_ARENA_SCRIPT)
	add_child(_garumi_combat_arena)
	_garumi_combat_arena.call("iniciar", jugador, garumi)
	_ultima_posicion_camara = Vector2.INF
	_seguir_jugador()
	print("Main: arena de combate iniciada; cámara fijada y perímetro activado.")


func iniciar_combate_garumi(garumi: Node, jugador: Node) -> void:
	if not garumi is Garumi or not jugador is Node2D:
		return
	if is_instance_valid(_garumi_battle_party):
		_garumi_battle_party.call("finalizar")
	_garumi_battle_party = CanvasLayer.new()
	_garumi_battle_party.name = "GarumiBattleParty"
	_garumi_battle_party.set_script(GARUMI_BATTLE_PARTY_SCRIPT)
	add_child(_garumi_battle_party)
	_garumi_battle_party.call("iniciar", jugador, garumi)


func terminar_arena_garumi(garumi: Node = null) -> void:
	if is_instance_valid(_garumi_combat_arena):
		if garumi != null and _garumi_combat_arena.get("garumi") != garumi:
			return
	elif not is_instance_valid(_garumi_battle_party):
		return
	if is_instance_valid(_garumi_battle_party):
		_garumi_battle_party.call("finalizar")
		_garumi_battle_party = null
	if is_instance_valid(_garumi_combat_arena):
		_garumi_combat_arena.call("terminar")
	_garumi_combat_arena = null
	_ultima_posicion_camara = Vector2.INF
	_seguir_jugador()
	print("Main: arena de combate cerrada; cámara liberada.")


func _configurar_hud(world_context: WorldContext, world_gen: WorldGenerator = null) -> void:
	if _hud == null:
		push_error("Main: no se encontró UI/HUD.")
		return

	_hud.configurar(_player, world_context, MissionManager, world_gen.entity_manager if world_gen != null else null, _supabase_client, _inventory, WorldData, GameState)
	if is_instance_valid(_world_atmosphere):
		_hud.configurar_reloj_calendario(_world_atmosphere)


func _configurar_interaccion(world_gen: WorldGenerator = null) -> void:
	if _interaction_system == null:
		push_error("Main: no se encontró Systems/InteractionSystem.")
		return

	if not _interaction_system.objetivo_cambiado.is_connected(_al_cambio_objetivo_interaccion):
		_interaction_system.objetivo_cambiado.connect(_al_cambio_objetivo_interaccion)

	_interaction_system.configurar(_player, _inventory, _world_items, _player.input_gate, world_gen.entity_manager if world_gen != null else null)

func _al_cambio_objetivo_interaccion(objetivo: Node) -> void:
	if _hud == null:
		return

	if objetivo == null or not is_instance_valid(objetivo):
		_hud.ocultar_interaccion()
		return

	var texto: String = _interaction_system.obtener_texto_interaccion()
	_hud.mostrar_interaccion(texto)


func _configurar_combate(world_context: WorldContext, world_gen: WorldGenerator = null) -> void:
	if _combat_system == null:
		push_error("Main: no se encontró Systems/CombatSystem.")
		return

	_combat_system.configurar(_player, _inventory, world_context, _combat_projectiles, GameState)


func _configurar_input_router() -> void:
	if _input_router == null:
		push_error("Main: no se encontró GameplayInputRouter.")
		return
	_input_router.configurar_sistemas(_interaction_system, _combat_system)
	_input_router.configurar_bloqueos(_inventory, _admin_console, _dialogue_system, _hud, _debug_console)
	if _player != null:
		_player.input_gate.configurar_router(_input_router)

func _configurar_inventario() -> void:
	if _inventory == null:
		push_error("Main: no se encontró UI/Inventory.")
		return

	_inventory.configurar(_player, _world_entity_spawner, _world_context, RelationshipSystem, _world_items)

	if _input_router != null:
		_inventory.configurar_input_router(_input_router)
	_pause_menu.configurar(_inventory)
	_death_menu.configurar(_player, _inventory)


func _configurar_dialogo() -> void:
	if _dialogue_system == null:
		push_error("Main: no se encontró Systems/DialogueSystem.")
		return

	_dialogue_system.configurar(_player, _hud, MissionManager, RelationshipSystem)


func _configurar_admin() -> void:
	if _admin_console == null:
		push_error("Main: no se encontró UI/AdminConsole.")
		return
	_admin_console.configurar(
			_world_context,
			_world_entity_spawner,
			_world_atmosphere,
			_player,
			_inventory,
			_world_generator.entity_manager if _world_generator != null else null,
			_admin_player_editor,
			_world_items
	)

func _configurar_pantalla() -> void:
	if not pantalla_completa:
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# ============================================================
# IUM LAB
# ============================================================

func _inicializar_ium() -> void:
	# Compatibilidad de entrada: el sistema ya pertenece a la escena.
	# Main sólo compone dependencias; no crea sistemas dinámicamente.
	if _ium_manager == null:
		push_error("Main: no se encontró Systems/IUMManager.")
		return

	if _supabase_client == null or _ium_repository == null:
		push_error("Main: falta infraestructura Supabase/IUMRepository.")
		return

	_ium_repository.configurar(_supabase_client)
	_ium_manager.configurar(_ium_repository, _player)

	if _ium_lab == null:
		push_error("Main: no se encontró UI/IUMLab.")
		return

	_ium_lab.configurar(_ium_manager, _admin_console)
	_configurar_menu_radial_eterium()
	# Configurar no inicia las consultas: inicializamos el catálogo explícitamente.
	_ium_manager.inicializar(_player.get_jugador_id() if _player != null else "")

	if not _ium_manager.proceso_equipado_signal.is_connected(_al_equipar_proceso):
		_ium_manager.proceso_equipado_signal.connect(_al_equipar_proceso)

	print("Main: IUMManager e IUMLab conectados.")

func _configurar_menu_radial_eterium() -> void:
	if _eterium_radial_menu != null and is_instance_valid(_eterium_radial_menu):
		return
	var contenedor_ui := get_node_or_null("UI")
	if contenedor_ui == null or _player == null:
		push_error("Main: no se pudo inicializar el menú radial de Eterium.")
		return
	_eterium_radial_menu = Control.new()
	_eterium_radial_menu.name = "EteriumRadialMenu"
	_eterium_radial_menu.set_script(ETERIUM_RADIAL_MENU_SCRIPT)
	contenedor_ui.add_child(_eterium_radial_menu)
	_eterium_radial_menu.call(
		"configurar",
		_player,
		_ium_lab,
		_ium_manager,
		_inventory,
		_admin_console
	)

func _al_equipar_proceso(proceso: Dictionary) -> void:
	# Guardar en player para que pueda usarlo con R
	if _player != null:
		_player.equipar_proceso_ium(proceso)
	else:
		# Guardar en game_state como fallback
		GameState.establecer_proceso_ium_equipado(proceso)

	var nombre: String = proceso.get("nombre", "Proceso")
	print("Main: Proceso IUM equipado → ", nombre)


func _configurar_social() -> void:
	SocialRepository.configurar(_supabase_client)
	RelationshipSystem.configurar(SocialRepository, GameState)


func _al_cargar_relaciones_ecologicas(relaciones: Array) -> void:
	if _world_generator == null:
		return
	_world_generator.actualizar_relaciones_ecologicas(relaciones)
