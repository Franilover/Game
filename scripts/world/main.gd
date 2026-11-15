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
var _dialogue_system: DialogueSystem = null
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
@onready var _supabase_client: GarliaSupabaseClient = get_node_or_null("/root/SupabaseClient") as GarliaSupabaseClient
@onready var _ium_repository: IUMRepository = $Systems/IUMRepository
@onready var _combat_projectiles: Node2D = $CombatProjectiles
var _world_atmosphere: WorldAtmosphere = null
@onready var _world_climate_visuals: WorldClimateVisuals = $UI/FogOverlay
var _world_generator: WorldGenerator = null
@onready var _world_context: WorldContext = $Systems/WorldContext
@onready var _world_items: GarliaWorldItems = $Systems/WorldItems
const ZONE_MANAGER_SCRIPT = preload("res://scripts/world/zone_manager.gd")
const ETERIUM_RADIAL_MENU_SCENE: PackedScene = preload("res://scenes/ui/eterium_radial_menu.tscn")
const GARUMI_COMBAT_ARENA_SCRIPT = preload("res://scripts/gameplay/garumi_combat_arena.gd")
const GARUMI_BATTLE_PARTY_SCRIPT = preload("res://scripts/gameplay/garumi_battle_party.gd")
const CREATURE_SCENE: PackedScene = preload("res://scenes/creatures/creature.tscn")
const NPC_SCHEDULE_SYSTEM_SCRIPT = preload("res://scripts/world/npc_schedule_system.gd")
const NPC_CONVERSATION_SYSTEM_SCRIPT = preload("res://scripts/world/npc_conversation_system.gd")
const CUTSCENE_DIRECTOR_SCRIPT = preload("res://scripts/gameplay/cutscene_director.gd")

# Perfiles visuales locales por zona. Para habilitar uno en Aventura en el futuro,
# basta con añadir aquí su clave de zona sin alterar el sistema climático global.
const CLIMATE_PROFILES_BY_ZONE: Dictionary = {
	"historia:reserva_carmesi": "niebla_carmesi",
}
const PLAYER_INPUT_CONTROLLER_SCRIPT = preload("res://scripts/gameplay/player/player_input_controller.gd")
@onready var _zone_manager: Node2D = $World/ZoneManager
@onready var _realm_menu: Control = $UI/RealmMenu
@onready var _story_loading_overlay: Control = $UI/StoryLoadingOverlay
var _reino_descubrimiento_elapsed: float = 0.0
var _torres_rutina_elapsed: float = 0.0
var _npc_schedule_system: Node = null
var _npc_conversation_system: Node = null
var _datos_mundo_servidor_listos := false
var _reinos_game_servidor_listos := false
var _inicio_servidor_pendiente := false
var _carga_historia_activa := false
var _cutscene_director: Variant = null
var _bienvenida_torres_pendiente := false
var _bienvenida_torres_en_curso := false
var _cinematicas_pendientes: Array[Dictionary] = []
var _cinematica_proximidad_elapsed: float = 0.0
var _procesando_cinematica_pendiente: bool = false


func _ready() -> void:
	_carga_historia_activa = bool(GameState.world_state.flags.get("historia_iniciar_reserva_carmesi", false))
	_bienvenida_torres_pendiente = (
		not bool(GameState.world_state.flags.get("bienvenida_torres_vista", false))
		and not GameState.player_state.position_valida
	)
	if is_instance_valid(_story_loading_overlay):
		_story_loading_overlay.visible = _carga_historia_activa
	_registrar_diagnostico_ventana("_ready: inicio")
	call_deferred("_diagnostico_ventana_diferido")
	_dialogue_system = get_node_or_null("Systems/DialogueSystem") as DialogueSystem
	if not is_instance_valid(_dialogue_system):
		push_error("Main: Systems/DialogueSystem no tiene un DialogueSystem válido.")
		return
	if not is_instance_valid(_supabase_client):
		_supabase_client = get_node_or_null("/root/SupabaseClient") as GarliaSupabaseClient
	if not is_instance_valid(_supabase_client):
		push_error("Main: falta el autoload /root/SupabaseClient; no se puede iniciar el mundo.")
		return
	_supabase_client.configurar_dependencias(GarliaAuth)
	GarliaMultiplayer.configurar_dependencias(GarliaAuth)
	GarliaSalas.configurar_dependencias(GarliaAuth)

	WorldData.configurar_dependencias(_supabase_client)

	if not WorldData.mundo_listo.is_connected(_al_mundo_datos_listo_para_npcs):
		WorldData.mundo_listo.connect(_al_mundo_datos_listo_para_npcs)
	if not WorldData.mundo_actualizado.is_connected(_al_mundo_datos_listo_para_npcs):
		WorldData.mundo_actualizado.connect(_al_mundo_datos_listo_para_npcs)
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
		var climate_system := get_node_or_null("Systems/WorldAtmosphere/ClimateSystem") as WorldClimateSystem
		if climate_system != null:
			climate_system.configurar_dependencias(WorldData, _world_atmosphere, _world_context)
		else:
			push_error("Main: falta Systems/WorldAtmosphere/ClimateSystem; el clima no podrá simularse.")

	if not is_instance_valid(_supabase_client):
		push_error("Main: SupabaseClient no está disponible al activar el mundo.")
		return
	_supabase_client.establecer_mundo_activo(true)
	if not _supabase_client.relaciones_ecologicas_cargadas.is_connected(_al_cargar_relaciones_ecologicas):
		_supabase_client.relaciones_ecologicas_cargadas.connect(_al_cargar_relaciones_ecologicas)

	if _zone_manager == null:
		push_error("Main: falta World/ZoneManager.")
		return

	_npc_schedule_system = NPC_SCHEDULE_SYSTEM_SCRIPT.new() as Node
	if is_instance_valid(_npc_schedule_system):
		_npc_schedule_system.name = "NPCScheduleSystem"
		add_child(_npc_schedule_system)
		_npc_schedule_system.configurar(_world_atmosphere, _zone_manager, RelationshipSystem)
	else:
		push_error("Main: no se pudo inicializar NPCScheduleSystem.")

	_npc_conversation_system = NPC_CONVERSATION_SYSTEM_SCRIPT.new() as Node
	if is_instance_valid(_npc_conversation_system):
		_npc_conversation_system.name = "NPCConversationSystem"
		add_child(_npc_conversation_system)
		_npc_conversation_system.configurar(_world_atmosphere, _zone_manager, GameState, RelationshipSystem, MissionManager)
	else:
		push_error("Main: no se pudo inicializar NPCConversationSystem.")

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

	# La Reserva Carmesí es una escena local: no debe esperar el catálogo remoto
	# de reinos para comenzar el capítulo.
	var iniciar_historia := bool(GameState.world_state.flags.get("historia_iniciar_reserva_carmesi", false))
	if is_instance_valid(_story_loading_overlay):
		_story_loading_overlay.visible = iniciar_historia
	_supabase_client.cargar_reinos_game()
	_reinos_game_servidor_listos = not _supabase_client.obtener_reinos_game().is_empty()
	if GarliaMultiplayer.es_servidor_dedicado():
		_esperar_datos_mundo_servidor()
	elif iniciar_historia:
		_iniciar_zonas()
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
	# La zona de Historia puede haberse iniciado antes de que responda Supabase.
	# No volver a ejecutar ZoneManager.iniciar() ni sustituirla por Torres.
	if GameState.debe_iniciar_en_reino_torres() and _zone_manager.obtener_tipo_actual().is_empty() and not is_instance_valid(_zone_manager.obtener_zona_actual()):
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
	if _es_modo_historia() and event is InputEventKey:
		var tecla_historia := event as InputEventKey
		if tecla_historia.pressed and not tecla_historia.echo:
			var codigo := tecla_historia.keycode if tecla_historia.keycode != KEY_NONE else tecla_historia.physical_keycode
			if codigo in [KEY_M, KEY_G, KEY_T, KEY_F, KEY_F3, KEY_SLASH, KEY_KP_DIVIDE]:
				get_viewport().set_input_as_handled()
				return
	var input_controller = PLAYER_INPUT_CONTROLLER_SCRIPT.new()
	if is_instance_valid(_cutscene_director) and _cutscene_director.esta_activo() and input_controller.es_combinacion_viaje(event):
		get_viewport().set_input_as_handled()
		return
	if not input_controller.es_combinacion_viaje(event):
		return
	if _realm_menu == null or not is_instance_valid(_realm_menu):
		return
	if _realm_menu.has_method("alternar"):
		_realm_menu.call("alternar", _supabase_client, GameState, _zone_manager.obtener_tipo_actual())
		get_viewport().set_input_as_handled()


func _es_modo_historia() -> bool:
	return is_instance_valid(_zone_manager) and _zone_manager.obtener_tipo_actual() == "historia:reserva_carmesi"


func _al_solicitar_destino_reino(clave: String) -> void:
	var clave_normalizada := clave.strip_edges().to_lower()
	print("Main: destino solicitado desde RealmMenu → ", clave_normalizada)
	if _zone_manager == null or not is_instance_valid(_zone_manager):
		return

	# Torres es el destino local fijo de inicio. Debe resolverse aquí antes de
		# cualquier desvío de red o validación de desbloqueo/catálogo remoto.
	# También aceptamos los alias que pueden llegar desde registros antiguos.
	if clave_normalizada == "hogar":
		if GarliaMultiplayer.es_servidor_dedicado() or GarliaWorldNetwork.es_cliente_en_mundo_global():
			push_warning("Main: Hogar privado todavía no está habilitado dentro del mundo global multijugador.")
			return
		_zone_manager.entrar_hogar()
		return

	if clave_normalizada in ["torres", "reino_torres", "reino:torres"]:
		if _zone_manager.has_method("esta_en_expedicion") and _zone_manager.esta_en_expedicion():
			_zone_manager.salir_expedicion()
		else:
			_zone_manager.entrar_reino("torres")
		return

	if GarliaWorldNetwork.es_cliente_en_mundo_global():
		GarliaWorldNetwork.enviar_solicitud_viaje(clave_normalizada)
		return
	if _zone_manager.has_method("esta_en_expedicion") and _zone_manager.esta_en_expedicion():
		push_warning("Main: durante la expedición sólo está disponible el regreso a Torres.")
		return
	if clave_normalizada == "mundo_abierto":
		_zone_manager.entrar_mundo_abierto()
		return
	var desbloqueados: Dictionary = GameState.obtener_reinos_desbloqueados()
	if not bool(desbloqueados.get(clave_normalizada, false)):
		push_warning("Main: intento de viajar a un reino todavía no descubierto: " + clave_normalizada)
		return
	if _zone_manager.has_method("entrar_reino"):
		_zone_manager.call("entrar_reino", clave_normalizada)


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

	# Si el jugador cancela una escena, el director libera su estado aunque
	# la coroutine original estuviera esperando una animación ya interrumpida.
	if _procesando_cinematica_pendiente and is_instance_valid(_cutscene_director) and not _cutscene_director.esta_activo():
		_procesando_cinematica_pendiente = false
	_cinematica_proximidad_elapsed += delta
	if _cinematica_proximidad_elapsed >= 0.25:
		_cinematica_proximidad_elapsed = 0.0
		if not _procesando_cinematica_pendiente:
			call_deferred("_procesar_cinematicas_pendientes")

	_torres_rutina_elapsed += delta
	if _torres_rutina_elapsed >= 0.5:
		_torres_rutina_elapsed = 0.0
		_actualizar_rutinas_npcs_torres()

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
	_actualizar_limites_camara_zona(tipo)
	if is_instance_valid(_world_climate_visuals):
		_world_climate_visuals.establecer_perfil_climatico(str(CLIMATE_PROFILES_BY_ZONE.get(tipo, "")))
	var es_modo_historia := tipo == "historia:reserva_carmesi"
	if is_instance_valid(_inventory):
		_inventory.establecer_modo_historia(es_modo_historia)
	if is_instance_valid(_hud):
		_hud.establecer_modo_historia(es_modo_historia)
	if is_instance_valid(_pause_menu):
		_pause_menu.establecer_modo_historia(es_modo_historia)
	if es_modo_historia and _carga_historia_activa:
		_conectar_carga_visual_historia(_zona)

	if tipo == "mundo_abierto" or tipo == "expedicion:bosque":
		if _world_generator == null:
			push_error("Main: la zona procedural no contiene WorldGenerator.")
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


func _conectar_carga_visual_historia(zona: Node) -> void:
	var mapa: Node = zona.get_node_or_null("Map") if is_instance_valid(zona) else null
	if mapa == null or not mapa.has_signal("mapa_construido"):
		_al_mapa_historia_construido()
		return
	var callback := Callable(self, "_al_mapa_historia_construido")
	if not mapa.is_connected("mapa_construido", callback):
		mapa.connect("mapa_construido", callback, CONNECT_ONE_SHOT)
	if bool(mapa.get("mapa_listo")):
		_al_mapa_historia_construido()


func _al_mapa_historia_construido() -> void:
	_carga_historia_activa = false
	if is_instance_valid(_story_loading_overlay):
		_story_loading_overlay.visible = false


func _actualizar_limites_camara_zona(tipo: String) -> void:
	if not is_instance_valid(_camera):
		return
	if tipo == "reino_torres":
		_camera.limit_left = -1200
		_camera.limit_right = 1200
		_camera.limit_top = -700
		_camera.limit_bottom = 700
		_camera.limit_enabled = true
	elif tipo == "hogar":
		_camera.limit_left = -1200
		_camera.limit_right = 1200
		_camera.limit_top = -800
		_camera.limit_bottom = 800
		_camera.limit_enabled = true
	elif tipo == "expedicion:bosque":
		_camera.limit_left = 0
		_camera.limit_right = 5120
		_camera.limit_top = -1024
		_camera.limit_bottom = 1024
		_camera.limit_enabled = true
	elif tipo == "historia:reserva_carmesi":
		_camera.limit_left = -640
		_camera.limit_right = 6400
		_camera.limit_top = -1760
		_camera.limit_bottom = 1760
		_camera.limit_enabled = true
	else:
		_camera.limit_enabled = false


func _al_mundo_inicializado() -> void:
	_inicializar_runtime_de_zona()



func _inicializar_runtime_de_zona() -> void:
	_player = $Entities/Player as Player
	_retirar_npcs_reino_torres()

	if _player == null:
		push_error("Main: no se encontró Entities/Player.")
		return

	if GarliaMultiplayer.es_servidor_dedicado() and _world_generator != null:
		GlobalWorldStore.restaurar_estado_entidades(_world_generator.entity_manager, str(_zone_manager.obtener_tipo_actual()))

	if _world_generator != null:
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
	if not MissionManager.recompensa_disponible.is_connected(_al_recompensa_mision_disponible):
		MissionManager.recompensa_disponible.connect(_al_recompensa_mision_disponible)
	if not _inventory.inventory_changed.is_connected(_al_cambio_inventario_reintentar_recompensas):
		_inventory.inventory_changed.connect(_al_cambio_inventario_reintentar_recompensas)
	_configurar_social()
	_inicializar_ium()
	_configurar_admin()
	_configurar_pantalla()
	if _world_generator != null:
		call_deferred("_restaurar_garumis_vinculados")

	var tipo_zona_actual: String = str(_zone_manager.obtener_tipo_actual())
	if tipo_zona_actual == "hogar":
		if _zone_manager.has_method("consumir_entrada_hogar_desde_torres") and bool(_zone_manager.call("consumir_entrada_hogar_desde_torres")):
			_player.global_position = Vector2(1100.0, 0.0)
			_player.velocity = Vector2.ZERO
		else:
			var estado_hogar_variant: Variant = GameState.world_state.flags.get("hogar_estado", {})	
			var posicion_hogar := Vector2.ZERO
			var tiene_posicion_hogar := false
			if estado_hogar_variant is Dictionary:
				var jugador_hogar_variant: Variant = (estado_hogar_variant as Dictionary).get("jugador", {})
				if jugador_hogar_variant is Dictionary:
					var jugador_hogar := jugador_hogar_variant as Dictionary
					posicion_hogar = Vector2(float(jugador_hogar.get("x", 0.0)), float(jugador_hogar.get("y", 180.0)))
					tiene_posicion_hogar = jugador_hogar.has("x") and jugador_hogar.has("y")
			if tiene_posicion_hogar:
				_player.global_position = posicion_hogar
			elif str(GameState.world_state.flags.get("zona_actual_tipo", "")) == "hogar" and GameState.player_state.position_valida:
				# Respaldo sólo si la partida se guardó estando en Hogar. No reutilizar
				# coordenadas antiguas de Torres o Mundo Abierto al entrar por primera vez.
				_player.global_position = GameState.player_state.position
			else:
				var zona_hogar: Node = _zone_manager.obtener_zona_actual()
				var spawn_hogar: Node2D = zona_hogar.get_node_or_null("PlayerSpawn") as Node2D if is_instance_valid(zona_hogar) else null
				_player.global_position = spawn_hogar.global_position if is_instance_valid(spawn_hogar) else Vector2(0, 180)
	elif tipo_zona_actual == "historia:reserva_carmesi":
		var zona_reserva: Node = _zone_manager.obtener_zona_actual()
		var spawn_reserva: Node2D = zona_reserva.get_node_or_null("PlayerSpawn") as Node2D if is_instance_valid(zona_reserva) else null
		_player.global_position = spawn_reserva.global_position if is_instance_valid(spawn_reserva) else Vector2(0, 0)
	elif tipo_zona_actual == "reino_torres" or tipo_zona_actual.begins_with("reino:"):
		var zona_actual: Node = _zone_manager.obtener_zona_actual()
		if tipo_zona_actual == "reino_torres" and _zone_manager.has_method("consumir_retorno_hogar_a_torres") and bool(_zone_manager.call("consumir_retorno_hogar_a_torres")):
			_player.global_position = Vector2(-1120.0, 0.0)
			_player.velocity = Vector2.ZERO
		else:
			var punto_aparicion: Node2D = zona_actual.get_node_or_null("PlayerSpawn") as Node2D if is_instance_valid(zona_actual) else null
			_player.global_position = punto_aparicion.global_position if is_instance_valid(punto_aparicion) else Vector2(0, 120)
		# Una expedición conserva el punto exacto desde el que el jugador salió
		# de Torres. Se aplica después del spawn predeterminado del reino.
		if _zone_manager.has_method("consumir_retorno_expedicion"):
			var retorno: Dictionary = _zone_manager.call("consumir_retorno_expedicion")
			if bool(retorno.get("valido", false)):
				var posicion_retorno: Variant = retorno.get("posicion", Vector2.ZERO)
				if posicion_retorno is Vector2:
					_player.global_position = posicion_retorno
		print("Main: reino activo → ", tipo_zona_actual)
	else:
		print("Main: mundo abierto listo.")

	if tipo_zona_actual == "reino_torres":
		call_deferred("_materializar_npcs_reino_torres")

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


func _al_mundo_datos_listo_para_npcs() -> void:
	if is_instance_valid(_zone_manager) and _zone_manager.obtener_tipo_actual() == "reino_torres":
		call_deferred("_materializar_npcs_reino_torres")


func _retirar_npcs_reino_torres() -> void:
	for npc in get_tree().get_nodes_in_group("torres_game_npc"):
		if not is_instance_valid(npc):
			continue
		# Retirar la identidad del grupo inmediatamente: queue_free() difiere
		# la destrucción hasta el final del frame y otra materialización podría
		# encontrar todavía esta instancia durante ese intervalo.
		npc.remove_from_group("torres_game_npc")
		npc.remove_from_group("interactable")
		npc.queue_free()


func _deduplicar_npcs_reino_torres() -> void:
	var identidades_vistas: Dictionary = {}
	for npc_variant in get_tree().get_nodes_in_group("torres_game_npc"):
		if not npc_variant is Creature or not is_instance_valid(npc_variant):
			continue
		var npc := npc_variant as Creature
		var personaje_id := npc.get_personaje_game_id().strip_edges()
		var clave_local := str(npc.get_meta("habitante_local_clave", "")).strip_edges()
		var identidad := "personaje:" + personaje_id if not personaje_id.is_empty() else ("local:" + clave_local if not clave_local.is_empty() else "")
		if identidad.is_empty():
			continue
		if not identidades_vistas.has(identidad):
			identidades_vistas[identidad] = npc
			continue
		# Una identidad canónica o local sólo puede tener una instancia activa
		# dentro del reino. Se elimina del grupo antes de diferir su destrucción.
		npc.remove_from_group("torres_game_npc")
		npc.remove_from_group("interactable")
		npc.queue_free()


func _retirar_npcs_canonicos_ausentes() -> void:
	# El campo es opcional en snapshots antiguos. Su ausencia no demuestra que
	# todos los personajes hayan sido eliminados; sólo una lista explícita
	# puede actuar como catálogo autoritativo para retirar instancias.
	if not WorldData.mundo.has("personajes_game"):
		return
	var identidades_canonicas: Dictionary = {}
	for personaje_variant in WorldData.obtener_personajes_game():
		if not personaje_variant is Dictionary:
			continue
		var personaje := personaje_variant as Dictionary
		if str(personaje.get("reino_clave", "")).strip_edges().to_lower() != "torres":
			continue
		var personaje_id := str(personaje.get("id", "")).strip_edges()
		if not personaje_id.is_empty():
			identidades_canonicas[personaje_id] = true

	for npc_variant in get_tree().get_nodes_in_group("torres_game_npc"):
		if not npc_variant is Creature or not is_instance_valid(npc_variant):
			continue
		var npc := npc_variant as Creature
		var personaje_id := npc.get_personaje_game_id().strip_edges()
		if personaje_id.is_empty() or identidades_canonicas.has(personaje_id):
			continue
		# Los personajes locales sin registro canónico conservan su instancia;
		# sólo se retiran identidades que ya no pertenecen al catálogo de Torres.
		npc.remove_from_group("torres_game_npc")
		npc.remove_from_group("interactable")
		npc.queue_free()


func _materializar_npcs_reino_torres() -> void:
	if not is_instance_valid(_zone_manager) or _zone_manager.obtener_tipo_actual() != "reino_torres":
		return
	if not WorldData.cargado:
		return

	var zona: Node = _zone_manager.obtener_zona_actual() as Node2D
	if not is_instance_valid(zona):
		return

	_deduplicar_npcs_reino_torres()
	_retirar_npcs_canonicos_ausentes()
	var existentes: Dictionary = {}
	for npc_existente in get_tree().get_nodes_in_group("torres_game_npc"):
		if npc_existente is Creature and is_instance_valid(npc_existente):
			existentes[(npc_existente as Creature).get_personaje_game_id()] = npc_existente

	var creados := 0
	for personaje_variant in WorldData.obtener_personajes_game():
		if not personaje_variant is Dictionary:
			continue
		var personaje := personaje_variant as Dictionary
		if str(personaje.get("reino_clave", "")).strip_edges().to_lower() != "torres":
			continue

		var personaje_id := str(personaje.get("id", "")).strip_edges()
		if personaje_id.is_empty():
			continue

		var nombre := str(personaje.get("nombre", "NPC")).strip_edges()
		var ubicacion := str(personaje.get("ubicacion_clave", "")).strip_edges().to_lower()
		if ubicacion.is_empty() or ubicacion == "null" or not NPC_SCHEDULE_SYSTEM_SCRIPT.tiene_ubicacion(ubicacion):
			ubicacion = "plaza"
		var rutinas_variant: Variant = personaje.get("rutinas", [])
		var rutinas_actualizadas: Array = rutinas_variant.duplicate(true) if rutinas_variant is Array else []

		if existentes.has(personaje_id):
			var npc_existente := existentes[personaje_id] as Creature
			if is_instance_valid(npc_existente):
				npc_existente.datos["rutinas"] = rutinas_actualizadas
				npc_existente.datos["ubicacion_clave"] = ubicacion # Lugar de trabajo/respaldo, nunca el hogar.
				npc_existente.datos["hogar_clave"] = NPC_SCHEDULE_SYSTEM_SCRIPT.obtener_clave_hogar(npc_existente.get_nombre_visual(), "plaza")
				var hogar_existente := NPC_SCHEDULE_SYSTEM_SCRIPT.obtener_posicion_hogar(npc_existente.get_nombre_visual(), "plaza")
				npc_existente.datos["posicion_hogar_local"] = hogar_existente
				if not bool(npc_existente.get_meta("hogar_inicializado", false)):
					npc_existente.global_position = zona.to_global(hogar_existente)
					npc_existente.set_meta("hogar_inicializado", true)
				var dialogo_actualizado := WorldData.obtener_dialogo_game(personaje_id)
				if not dialogo_actualizado.is_empty():
					npc_existente.datos["dialogo"] = dialogo_actualizado
				npc_existente.set_meta("rutina_firma", "")
			continue

		var criatura_id := str(personaje.get("criatura_id", "")).strip_edges()
		var criatura_data := WorldData.obtener_criatura(criatura_id).duplicate(true)
		if criatura_data.is_empty():
			push_warning("Main: no se pudo resolver el cuerpo humano del NPC " + nombre)
			continue

		criatura_data["nombre_individual"] = nombre
		criatura_data["personaje_game_id"] = personaje_id
		criatura_data["reino_game_id"] = str(personaje.get("reino_game_id", ""))
		criatura_data["reino_nombre"] = "Torres"
		criatura_data["ubicacion_clave"] = ubicacion # Lugar de trabajo/respaldo, nunca el hogar.
		criatura_data["hogar_clave"] = NPC_SCHEDULE_SYSTEM_SCRIPT.obtener_clave_hogar(nombre, "plaza")
		criatura_data["rutinas"] = rutinas_actualizadas

		var dialogo := WorldData.obtener_dialogo_game(personaje_id)
		if not dialogo.is_empty():
			criatura_data["dialogo"] = dialogo

		var npc := CREATURE_SCENE.instantiate() as Creature
		if npc == null:
			push_warning("Main: no se pudo instanciar el NPC " + nombre)
			continue

		# Los NPC usan el movimiento del cuerpo CharacterBody2D, con máscara
		# para geometría estática. No bloquean al jugador ni entre sí.
		npc.move_speed = 48.0
		npc.collision_layer = 0
		npc.collision_mask = 1
		npc.mostrar_nombre_debug = false
		npc.configurar_dependencias(
			_dialogue_system,
			MissionManager,
			$Entities,
			_world_items,
			WorldData
		)
		npc.configurar(criatura_data)
		$Entities.add_child(npc)
		# Los NPC civiles ignoran al jugador y no participan en combate.
		if is_instance_valid(_player):
			npc.add_collision_exception_with(_player)
		npc.remove_from_group("creatures")
		npc.remove_from_group("damageable")
		var movimiento_inicial := npc.get_node_or_null("CreatureMovement") as CreatureMovement
		if movimiento_inicial != null:
			movimiento_inicial.detener_por_rutina()

		var desplazamiento_plaza := Vector2.ZERO
		if ubicacion == "plaza":
			desplazamiento_plaza = Vector2(
				float((creados % 3) - 1) * 28.0,
				float(int(creados / 3)) * 24.0
			)
		var hogar_clave := NPC_SCHEDULE_SYSTEM_SCRIPT.obtener_clave_hogar(nombre, "plaza")
		npc.datos["hogar_clave"] = hogar_clave
		var posicion_hogar_local: Vector2 = NPC_SCHEDULE_SYSTEM_SCRIPT.obtener_posicion_inicial(hogar_clave) + desplazamiento_plaza
		npc.datos["posicion_hogar_local"] = posicion_hogar_local
		npc.global_position = zona.to_global(posicion_hogar_local)
		npc.set_meta("hogar_inicializado", true)
		print("Main: NPC ", nombre, " | hogar=", hogar_clave, " | lugar_base=", ubicacion, " | rutinas=", rutinas_actualizadas.size())
		npc.set_meta("personaje_game_id", personaje_id)
		npc.add_to_group("torres_game_npc")
		if zona.has_method("registrar_npc_materializado"):
			zona.call("registrar_npc_materializado", npc)
		npc.remove_from_group("creatures")
		npc.remove_from_group("damageable")

		var ai := npc.get_node_or_null("AIController")
		if ai != null:
			ai.set_process(false)
			ai.set_physics_process(false)
		var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
		if movimiento != null:
			movimiento.detener_por_rutina()
			movimiento.set_process(false)
			movimiento.set_physics_process(false)

		existentes[personaje_id] = npc
		creados += 1

	_materializar_habitantes_sin_oficio(zona)
	if creados > 0:
		print("Main: NPC de Reino Torres materializados desde Supabase → ", creados)
	if _bienvenida_torres_pendiente:
		call_deferred("_iniciar_bienvenida_torres")


## Habitantes civiles de Torres. No tienen empleos ni registros canónicos
## en Supabase: sus hogares, preferencias y recorridos son datos locales.
func _materializar_habitantes_sin_oficio(zona: Node2D) -> void:
	if not is_instance_valid(zona):
		return
	var plantilla: Creature = null
	for npc_variant in get_tree().get_nodes_in_group("torres_game_npc"):
		if npc_variant is Creature and is_instance_valid(npc_variant):
			plantilla = npc_variant as Creature
			break

	# Los habitantes locales no deben depender de que Supabase haya entregado
	# primero otro NPC para servir de plantilla.
	var datos_plantilla: Dictionary = {
		"id": "habitante_local",
		"nombre": "Humano",
		"stats_dnd": {"hp_max": 20, "ac": 10}
	}
	if is_instance_valid(plantilla):
		datos_plantilla = plantilla.datos.duplicate(true)
		datos_plantilla["nombre"] = "Humano"

	var habitantes: Array[Dictionary] = [
		{
			"clave":"mara", "nombre":"Mara", "sprite":"Mara", "hogar":"vivienda_oeste_01",
			"personalidad":"Reservada, observadora y cautelosa. Es una refugiada política que llegó al reino para mantenerse a salvo. No rechaza la compañía, pero necesita tiempo y confianza antes de hablar de su pasado.",
			"historia":"Refugiada política que evita llamar la atención y protege su identidad.",
			"rutinas":[
				{"clave":"mara_manana_casa","hora_inicio":"07:00","hora_fin":"09:00","ubicacion_clave":"vivienda_oeste_01","actividad_clave":"quedarse_en_casa"},
				{"clave":"mara_compra_pan","hora_inicio":"09:00","hora_fin":"10:00","ubicacion_clave":"panaderia","actividad_clave":"comprar_pan"},
				{"clave":"mara_plaza","hora_inicio":"10:00","hora_fin":"12:00","ubicacion_clave":"plaza","actividad_clave":"pasear_y_observar"},
				{"clave":"mara_refugio_mediodia","hora_inicio":"12:00","hora_fin":"14:00","ubicacion_clave":"vivienda_oeste_01","actividad_clave":"descansar_en_casa"},
				{"clave":"mara_posada","hora_inicio":"14:00","hora_fin":"15:00","ubicacion_clave":"posada","actividad_clave":"comprar_comida"},
				{"clave":"mara_paseo_tarde","hora_inicio":"15:00","hora_fin":"17:00","ubicacion_clave":"plaza","actividad_clave":"saludar_a_conocidos"},
				{"clave":"mara_regreso","hora_inicio":"17:00","hora_fin":"23:00","ubicacion_clave":"vivienda_oeste_01","actividad_clave":"volver_a_casa"}
			]
		},
		{
			"clave":"ivo", "nombre":"Ivo", "sprite":"Ivo", "hogar":"vivienda_oeste_02",
			"personalidad":"Sociable, bromista y atento. Conoce a mucha gente y suele detenerse a conversar con cualquiera. Vive con una enfermedad que le provoca cansancio y le obliga a descansar a menudo; intenta que eso no sea lo único que los demás vean en él.",
			"historia":"Joven del reino con una enfermedad persistente y episodios de fatiga. Sus amistades buscan maneras de ayudarlo.",
			"rutinas":[
				{"clave":"ivo_paseo_manana","hora_inicio":"08:00","hora_fin":"09:00","ubicacion_clave":"plaza","actividad_clave":"saludar_a_todos"},
				{"clave":"ivo_descanso_manana","hora_inicio":"09:00","hora_fin":"10:00","ubicacion_clave":"vivienda_oeste_02","actividad_clave":"descansar_por_cansancio"},
				{"clave":"ivo_compra","hora_inicio":"10:00","hora_fin":"11:00","ubicacion_clave":"casa_comercio","actividad_clave":"comprar_mercaderia"},
				{"clave":"ivo_posada","hora_inicio":"11:00","hora_fin":"12:30","ubicacion_clave":"posada","actividad_clave":"conversar_y_comer"},
				{"clave":"ivo_descanso_mediodia","hora_inicio":"12:30","hora_fin":"14:00","ubicacion_clave":"vivienda_oeste_02","actividad_clave":"reposar_un_rato"},
				{"clave":"ivo_plaza_tarde","hora_inicio":"14:00","hora_fin":"16:00","ubicacion_clave":"plaza","actividad_clave":"visitar_amigos"},
				{"clave":"ivo_compra_pan","hora_inicio":"16:00","hora_fin":"17:00","ubicacion_clave":"panaderia","actividad_clave":"comprar_pan"},
				{"clave":"ivo_regreso","hora_inicio":"17:00","hora_fin":"23:00","ubicacion_clave":"vivienda_oeste_02","actividad_clave":"descansar_en_casa"}
			]
		},
		{
			"clave":"nima", "nombre":"Nima", "sprite":"Nima", "hogar":"vivienda_oeste_03",
			"personalidad":"Curiosa, independiente y entusiasta. Estudia fenómenos Oris por cuenta propia, toma notas y contrasta observaciones, pero también disfruta conversar, pasear, comer con amigos y enterarse de lo que ocurre en el reino.",
			"historia":"Joven investigadora independiente interesada en fenómenos Oris y otros temas naturales.",
			"rutinas":[
				{"clave":"nima_estudio_manana","hora_inicio":"08:00","hora_fin":"10:00","ubicacion_clave":"casa_estudio","actividad_clave":"estudiar_fenomenos_oris"},
				{"clave":"nima_archivo","hora_inicio":"10:00","hora_fin":"11:00","ubicacion_clave":"archivo_real","actividad_clave":"consultar_documentos"},
				{"clave":"nima_plaza","hora_inicio":"11:00","hora_fin":"13:00","ubicacion_clave":"plaza","actividad_clave":"reunirse_con_amigos"},
				{"clave":"nima_posada","hora_inicio":"12:30","hora_fin":"14:00","ubicacion_clave":"posada","actividad_clave":"comer_con_conocidos"},
				{"clave":"nima_plaza_tarde","hora_inicio":"14:00","hora_fin":"16:00","ubicacion_clave":"plaza","actividad_clave":"pasear_y_conversar"},
				{"clave":"nima_estudio_tarde","hora_inicio":"16:00","hora_fin":"17:30","ubicacion_clave":"casa_estudio","actividad_clave":"ordenar_notas"},
				{"clave":"nima_regreso","hora_inicio":"17:30","hora_fin":"23:00","ubicacion_clave":"vivienda_oeste_03","actividad_clave":"volver_a_casa"}
			]
		}
	]
	var nombres_canonicos_globales: Dictionary = {}
	for personaje_variant in WorldData.obtener_personajes_game():
		if not personaje_variant is Dictionary:
			continue
		var personaje := personaje_variant as Dictionary
		var nombre_canonico := str(personaje.get("nombre", "")).strip_edges().to_lower()
		if not nombre_canonico.is_empty():
			nombres_canonicos_globales[nombre_canonico] = true

	var existentes_locales: Dictionary = {}
	var existentes_por_nombre: Dictionary = {}
	for npc_variant in get_tree().get_nodes_in_group("torres_game_npc"):
		if npc_variant is Creature and is_instance_valid(npc_variant):
			var npc_existente := npc_variant as Creature
			var clave_existente := str(npc_existente.get_meta("habitante_local_clave", ""))
			if not clave_existente.is_empty():
				existentes_locales[clave_existente] = npc_existente
			var nombre_existente := npc_existente.get_nombre_visual().strip_edges().to_lower()
			if not nombre_existente.is_empty() and not existentes_por_nombre.has(nombre_existente):
				existentes_por_nombre[nombre_existente] = npc_existente

	for habitante in habitantes:
		var clave := str(habitante.get("clave", ""))
		if existentes_locales.has(clave):
			continue

		# Mara, Ivo y Nima ya pueden venir como personajes canónicos desde
		# Supabase. En ese caso se enriquece esa misma instancia con sus datos
		# sociales locales; nunca se crea una segunda copia del personaje.
		var nombre_habitante := str(habitante.get("nombre", "Habitante")).strip_edges().to_lower()
		var npc_canonico := existentes_por_nombre.get(nombre_habitante) as Creature
		if is_instance_valid(npc_canonico):
			npc_canonico.set_meta("habitante_local_clave", clave)
			npc_canonico.set_meta("habitante_sin_oficio", true)
			npc_canonico.set_meta("perfil_personalidad", str(habitante.get("personalidad", "")))
			npc_canonico.set_meta("historia_local", str(habitante.get("historia", "")))
			var rutinas_canonicas: Variant = npc_canonico.datos.get("rutinas", [])
			if not rutinas_canonicas is Array or (rutinas_canonicas as Array).is_empty():
				npc_canonico.datos["rutinas"] = habitante.get("rutinas", []).duplicate(true)
			if clave == "ivo":
				npc_canonico.set_meta("estado_salud", "enfermedad_cronica")
				npc_canonico.set_meta("fatiga_frecuente", true)
			elif clave == "mara":
				npc_canonico.set_meta("confianza_local", int(GameState.world_state.flags.get("confianza_mara", 0)))
				npc_canonico.set_meta("identidad_protegida", true)
			continue

		# Si el personaje tiene registro canónico en otro reino, no crear aquí
		# una segunda versión local sin ID que rompa sus relaciones persistentes.
		if nombres_canonicos_globales.has(nombre_habitante):
			continue

		var datos := datos_plantilla.duplicate(true)
		datos.erase("personaje_game_id")
		datos["nombre_individual"] = str(habitante.get("nombre", "Habitante"))
		datos["sprite_key"] = str(habitante.get("sprite", ""))
		datos["ubicacion_clave"] = "plaza"
		datos["hogar_clave"] = str(habitante.get("hogar", "plaza"))
		datos["rutinas"] = habitante.get("rutinas", []).duplicate(true)
		datos["dialogo"] = {
			"variantes": [{
				"clave": "principal",
				"lineas": [{
					"hablante": str(habitante.get("nombre", "Habitante")),
					"texto": _obtener_presentacion_habitante_local(clave)
				}]
			}]
		}
		var npc := CREATURE_SCENE.instantiate() as Creature
		if npc == null:
			continue
		npc.move_speed = 30.0 if clave == "ivo" else (43.0 if clave == "mara" else 48.0)
		npc.collision_layer = 0
		npc.collision_mask = 1
		npc.mostrar_nombre_debug = false
		npc.configurar_dependencias(_dialogue_system, MissionManager, $Entities, _world_items, WorldData)
		npc.configurar(datos)
		$Entities.add_child(npc)
		# Reintentar con el nodo ya dentro del árbol para asegurar que Godot
		# resuelva la textura importada del personaje.
		npc.call_deferred("_cargar_sprite")
		if is_instance_valid(_player):
			npc.add_collision_exception_with(_player)
		npc.remove_from_group("creatures")
		npc.remove_from_group("damageable")
		npc.add_to_group("torres_game_npc")
		if zona.has_method("registrar_npc_materializado"):
			zona.call("registrar_npc_materializado", npc)
		npc.set_meta("habitante_sin_oficio", true)
		npc.set_meta("perfil_personalidad", str(habitante.get("personalidad", "")))
		npc.set_meta("historia_local", str(habitante.get("historia", "")))
		if clave == "ivo":
			npc.set_meta("estado_salud", "enfermedad_cronica")
			npc.set_meta("fatiga_frecuente", true)
		elif clave == "mara":
			npc.set_meta("confianza_local", int(GameState.world_state.flags.get("confianza_mara", 0)))
			npc.set_meta("identidad_protegida", true)
		npc.set_meta("habitante_local_clave", clave)
		npc.set_meta("hogar_inicializado", true)
		var hogar_local := NPC_SCHEDULE_SYSTEM_SCRIPT.obtener_posicion_inicial(str(habitante.get("hogar", "plaza")))
		npc.datos["posicion_hogar_local"] = hogar_local
		npc.global_position = zona.to_global(hogar_local)
		var ai := npc.get_node_or_null("AIController")
		if ai != null:
			ai.set_process(false)
			ai.set_physics_process(false)
		var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
		if movimiento != null:
			movimiento.detener_por_rutina()
			movimiento.set_process(false)
			movimiento.set_physics_process(false)
		print("Main: habitante civil materializado → ", habitante.get("nombre", clave), " | hogar=", habitante.get("hogar", "plaza"))



func _obtener_presentacion_habitante_local(clave: String) -> String:
	match clave:
		"mara":
			return "Hola. Soy Mara. Suelo estar por aquí, aunque prefiero los lugares tranquilos. Si necesitas algo, puedes preguntarme."
		"ivo":
			return "¡Buenas! Soy Ivo. Si me ves sentado un rato, no te preocupes: a veces me canso más rápido de lo que quisiera. Pero siempre tengo tiempo para conversar."
		"nima":
			return "¡Hola! Soy Nima. Estoy investigando algunos fenómenos Oris por mi cuenta, aunque intento no pasarme el día encerrada entre apuntes. ¿Qué tal va todo?"
	return "Hola. Vivo por aquí."


## Primera llegada al reino: el guardia recibe al jugador y Elian lo acompaña
## en un recorrido por los barrios. Se ejecuta una sola vez en una partida nueva.
func _iniciar_bienvenida_torres() -> void:
	if _bienvenida_torres_en_curso or not is_instance_valid(_cutscene_director):
		return
	if not is_instance_valid(_player) or not is_instance_valid(_camera):
		return

	var guardia := _buscar_npc_bienvenida("darven")
	var elian := _buscar_npc_bienvenida("elian")
	if not is_instance_valid(guardia) or not is_instance_valid(elian):
		push_warning("Main: la bienvenida espera a que Darven y Elian estén disponibles.")
		return

	_bienvenida_torres_en_curso = true
	var posicion_inicial := _player.global_position
	var zoom_revelacion := clampf(_camera.zoom.x * 0.82, 1.15, 1.65)
	var pasos: Array[Dictionary] = [
		{"tipo":"camara","x":posicion_inicial.x,"y":posicion_inicial.y - 55.0,"zoom":zoom_revelacion,"duracion":1.1},
		{"tipo":"dialogo","datos":{"clave":"bienvenida_pensamientos_llegada","lineas":[
			{"hablante":"Pensamientos","texto":"Por fin llegué. Este debe ser el reino del que tanto había oído hablar."},
			{"hablante":"Pensamientos","texto":"Será mejor que averigüe dónde estoy antes de ponerme a recorrerlo."}
		]}},
		{"tipo":"preparar_npc","npc":"Darven","x":posicion_inicial.x + 42.0,"y":posicion_inicial.y + 8.0},
		{"tipo":"camara","x":posicion_inicial.x + 18.0,"y":posicion_inicial.y - 22.0,"zoom":zoom_revelacion * 1.08,"duracion":0.8},
		{"tipo":"mirar_npc","npc":"Darven","izquierda":true},
		{"tipo":"gesto_npc","npc":"Darven","gesto":"saludar","duracion":0.65},
		{"tipo":"dialogo","npc":"Darven","datos":_crear_dialogo_guardia_bienvenida()},
		{"tipo":"preparar_npc","npc":"Elian","x":posicion_inicial.x - 48.0,"y":posicion_inicial.y + 18.0},
		{"tipo":"camara","x":posicion_inicial.x - 12.0,"y":posicion_inicial.y - 25.0,"zoom":zoom_revelacion,"duracion":0.75},
		{"tipo":"mirar_npc","npc":"Elian","izquierda":false},
		{"tipo":"gesto_npc","npc":"Elian","gesto":"saludar","duracion":0.65},
		{"tipo":"dialogo","npc":"Elian","datos":_crear_dialogo_presentacion_elian()}
	]

	# Cada parada representa un barrio completo. Las casas sin habitantes
	# conocidos no se presentan ni se convierten en puntos del recorrido.
	_agregar_parada_tour_elian(pasos, "plaza", Vector2(0.0, -85.0),
		"Estamos en la plaza, uno de los puntos donde más gente se cruza. Desde aquí se llega al castillo, la panadería, la posada y la forja. La casa de Bruna queda cerca de la zona de trabajo.",
		[
			{"texto":"¿Qué hacen en el castillo?","jugador":"¿Qué hacen en el castillo?","respuesta":"Allí se atienden los asuntos principales del reino. Si necesitas resolver algo importante, probablemente tendrás que pasar por allí."},
			{"texto":"¿La posada recibe viajeros?","jugador":"¿La posada recibe viajeros?","respuesta":"Sí, es el lugar más práctico para descansar si todavía no tienes dónde quedarte."},
			{"texto":"¿Dónde queda la casa de Bruna?","jugador":"¿Dónde vive Bruna?","respuesta":"Su casa está junto a la zona de la forja. Es fácil encontrarla si sigues el camino hacia los talleres."}
		])
	_agregar_conversacion_tour_elian(pasos, "Bruna", Vector2(-235.0, 152.0), [
		{"hablante":"Elian","texto":"¡Bruna! Justo te estábamos mencionando. ¿Cómo va el trabajo?"},
		{"hablante":"Bruna","texto":"Hola, Elian. Bien, estoy terminando unas piezas. ¿Y tú? ¿Ya estás haciendo de guía?"},
		{"hablante":"Elian","texto":"¡Alguien tenía que enseñarle el lugar! Además, así aprovecho de saludarte."}
	], [
		{"texto":"¿Se conocen desde hace mucho?","jugador":"¿Ustedes se conocen desde hace mucho?","respuesta":"Desde hace bastante. Nos cruzamos seguido por el trabajo y la plaza.","clave":"bruna_conocerse"},
		{"texto":"¿Qué estás fabricando?","jugador":"Bruna, ¿qué estás preparando ahora?","respuesta":"Estoy terminando unas piezas para reparar herramientas. Si quedan bien, mañana podré entregarlas.","clave":"bruna_trabajo"},
		{"texto":"Se nota que se llevan bien","jugador":"Se nota que se conocen y se llevan bien.","respuesta":"¡Claro! Vivir en el mismo reino hace que uno termine conociendo a los demás.","clave":"bruna_amistad"}
	])
	_agregar_parada_tour_elian(pasos, "casa_bruna", Vector2(-235.0, 152.0),
		"Por aquí vive Bruna. Su casa queda cerca de la forja, donde suele pasar buena parte del día trabajando. Si la encuentras en casa, seguramente estará descansando o preparando sus próximos encargos.",
		[
			{"texto":"¿Bruna trabaja en la forja?","jugador":"¿Bruna trabaja en la forja que vimos antes?","respuesta":"Sí, suele estar allí ocupándose de sus trabajos. Es bastante dedicada y conoce muy bien sus herramientas."},
			{"texto":"¿Puedo visitarla?","jugador":"¿Puedo pasar a saludarla cuando esté en casa?","respuesta":"Si está en casa y no tiene algo urgente entre manos, claro. Siempre puedes acercarte y preguntar."},
			{"texto":"¿Hace mucho que vive aquí?","jugador":"¿Bruna lleva mucho tiempo viviendo en el reino?","respuesta":"Ya lleva un buen tiempo aquí. Se ha ganado un lugar entre los vecinos gracias a su trabajo."}
		])
	_agregar_conversacion_tour_elian(pasos, "Darven", Vector2(330.0, -70.0), [
		{"hablante":"Elian","texto":"¡Darven! ¿Todo tranquilo por la entrada?"},
		{"hablante":"Darven","texto":"Por ahora sí. Ya recibí a quien acaba de llegar y le indiqué que podía recorrer el reino."},
		{"hablante":"Elian","texto":"Perfecto, yo me encargo de que no se pierda. ¡Nos vemos luego!"}
	], [
		{"texto":"¿Siempre estás en la entrada?","jugador":"¿Siempre te toca vigilar la entrada?","respuesta":"Los turnos cambian, pero siempre hay alguien encargado de revisar el acceso y mantener el orden.","clave":"darven_turnos"},
		{"texto":"¿Es difícil ser guardia?","jugador":"¿Es difícil trabajar como guardia?","respuesta":"Hay que estar atento y saber cuándo intervenir. La mayoría de los días son tranquilos, y eso es bueno.","clave":"darven_guardia"},
		{"texto":"Gracias por recibirme","jugador":"Gracias por recibirme cuando llegué.","respuesta":"Es parte de mi trabajo. Me alegra que hayas podido empezar a conocer el reino.","clave":"darven_agradecer"}
	])
	_agregar_parada_tour_elian(pasos, "viviendas_oriente", Vector2(330.0, -70.0),
		"Por este lado están las casas de varios vecinos. La mía es la de allí; Darven vive un poco más al norte y Saira al otro lado del camino. Si los buscas, ya sabes dónde encontrarlos.",
		[
			{"texto":"¿Cuál es tu casa?","jugador":"¿Cuál de estas casas es la tuya?","respuesta":"La que está más cerca de la panadería y de este camino. Suelo estar entrando y saliendo por el trabajo."},
			{"texto":"¿Darven vive cerca?","jugador":"¿Darven vive cerca de aquí?","respuesta":"Sí, su casa queda hacia el norte. Aunque muchas veces lo encontrarás en sus rondas o atendiendo el puesto de guardia."},
			{"texto":"¿Y Saira?","jugador":"¿Dónde puedo encontrar a Saira?","respuesta":"Su casa está hacia el sur de este barrio. También puedes encontrarla en la casa de comercio cuando está trabajando."}
		])
	_agregar_conversacion_tour_elian(pasos, "Saira", Vector2(385.0, 118.0), [
		{"hablante":"Elian","texto":"¡Saira! ¿Cómo va todo por el comercio?"},
		{"hablante":"Saira","texto":"Bastante bien. Llegaron algunas mercancías nuevas y todavía estoy organizando los encargos."},
		{"hablante":"Elian","texto":"¡Eso suena a que no te faltará trabajo! Luego pasaré a mirar qué llegó."}
	], [
		{"texto":"¿Qué mercancías llegaron?","jugador":"¿Qué tipo de mercancías llegaron?","respuesta":"Un poco de todo. Todavía estoy revisando las cajas, así que prefiero no prometer nada hasta terminar el inventario.","clave":"saira_mercancias"},
		{"texto":"¿Necesitas ayuda?","jugador":"¿Te vendría bien una mano con los encargos?","respuesta":"Gracias por ofrecerte. Si surge algo que pueda hacerse sin interrumpir el inventario, te lo haré saber.","clave":"saira_ayuda"},
		{"texto":"¿Sueles hablar con Elian?","jugador":"¿Sueles encontrarte con Elian por aquí?","respuesta":"Sí, a menudo. Siempre aparece buscando algo para la panadería o preguntando qué novedades hay.","clave":"saira_elian"}
	])
	_agregar_parada_tour_elian(pasos, "casa_saira", Vector2(385.0, 118.0),
		"Y esta es la casa de Saira. Está cerca del camino que conecta las viviendas con la zona comercial. Cuando no está atendiendo el comercio, suele venir por aquí a descansar.",
		[
			{"texto":"¿Saira trabaja en el comercio?","jugador":"¿Saira es quien atiende la casa de comercio?","respuesta":"Sí, suele encargarse de buena parte de la actividad comercial. También está pendiente de los encargos y de la mercancía."},
			{"texto":"¿Es fácil encontrarla?","jugador":"¿Dónde puedo encontrar a Saira durante el día?","respuesta":"Lo más sencillo es buscarla en la casa de comercio cuando está trabajando. Si no está allí, probablemente haya salido a resolver algún asunto."},
			{"texto":"¿Puedo visitarla?","jugador":"¿Puedo pasar a saludarla cuando esté en casa?","respuesta":"Claro, siempre que no esté ocupada. Saira suele recibir bien a quienes se acercan con respeto."}
		])
	_agregar_parada_tour_elian(pasos, "barrio_norte", Vector2(-150.0, -570.0),
		"Este es el barrio de los asuntos públicos y el estudio. Aquí están el archivo real, la sala del consejo y la casa de estudio de Oris. Se viene a consultar documentos, tratar asuntos del reino o estudiar.",
		[
			{"texto":"¿Puedo consultar el archivo?","jugador":"¿Cualquiera puede consultar el archivo real?","respuesta":"Depende de los documentos. Algunos son de consulta general y otros requieren permiso. Lo mejor es preguntar antes de entrar."},
			{"texto":"¿Qué se hace en la sala del consejo?","jugador":"¿Para qué se usa la sala del consejo?","respuesta":"Allí se reúnen quienes tienen que discutir decisiones y asuntos que afectan al reino."},
			{"texto":"¿Qué se estudia en la casa de Oris?","jugador":"¿Qué se estudia en la casa de Oris?","respuesta":"Es un lugar dedicado al estudio de Oris. Si te interesa aprender, seguramente encontrarás a alguien dispuesto a orientarte."}
		])
	_agregar_parada_tour_elian(pasos, "barrio_comercial", Vector2(820.0, -235.0),
		"Este sector reúne varios servicios: la casa de comercio, el cuartel de la guardia y el registro de la puerta. Más adelante están el taller de reparaciones y la carpintería.",
		[
			{"texto":"¿Dónde se hacen los trámites de entrada?","jugador":"¿El registro sirve para los trámites de entrada?","respuesta":"Exactamente. Allí se lleva el registro relacionado con quienes entran y salen por la puerta."},
			{"texto":"¿Puedo hablar con la guardia?","jugador":"¿Puedo acudir al cuartel si necesito ayuda?","respuesta":"Claro. Si tienes un problema o necesitas informar de algo, el cuartel es un buen lugar para empezar."},
			{"texto":"¿Qué puedo reparar aquí?","jugador":"¿Qué puedo llevar al taller de reparaciones?","respuesta":"Depende del trabajo que necesites. En el taller pueden revisar objetos y encargarse de distintas reparaciones; la carpintería se ocupa de los trabajos de madera."}
		])
	_agregar_conversacion_tour_elian(pasos, "Narel", Vector2(-540.0, -245.0), [
		{"hablante":"Elian","texto":"¡Narel! ¿Sigues con tus apuntes? Estamos recorriendo el reino y pensé que quizá te encontraríamos por aquí."},
		{"hablante":"Narel","texto":"Hola, Elian. Sí, estoy ordenando unas observaciones. Aunque supongo que puedo hacer una pausa."},
		{"hablante":"Elian","texto":"Te presento a nuestro nuevo vecino. Si tiene curiosidad por tus estudios, seguro que le interesará escucharte."}
	], [
		{"texto":"¿Qué estás investigando?","jugador":"¿Qué estás investigando en estos apuntes?","respuesta":"Estoy comparando algunas observaciones. Todavía no tengo una conclusión, pero ya encontré patrones que vale la pena revisar.","clave":"narel_investigacion"},
		{"texto":"¿Dónde consigues información?","jugador":"¿Dónde consultas la información para tus estudios?","respuesta":"En el archivo real y en mis propias notas. También suelo hablar con quienes conocen bien cada zona.","clave":"narel_fuentes"},
		{"texto":"No quiero interrumpir","jugador":"No quiero interrumpir tu trabajo. Gracias por hablar conmigo.","respuesta":"No te preocupes. Una pausa breve también ayuda a ordenar las ideas.","clave":"narel_pausa"}
	])
	_agregar_parada_tour_elian(pasos, "barrio_oeste", Vector2(-540.0, -245.0),
		"Por el oeste hay viviendas y caminos más tranquilos. La casa de Narel está por aquí; suele estar ocupado con sus apuntes, pero si tienes curiosidad por sus investigaciones, puedes pasar a saludarlo.",
		[
			{"texto":"¿Narel vive aquí?","jugador":"¿Esta es la casa de Narel?","respuesta":"Sí, es la suya. A veces está dentro trabajando y otras veces sale a consultar documentos o tomar notas."},
			{"texto":"¿Es una zona muy habitada?","jugador":"¿Vive mucha gente por este barrio?","respuesta":"Hay varias viviendas, aunque no todos los vecinos llevan el mismo horario. Con el tiempo irás reconociendo quién suele estar por aquí."},
			{"texto":"¿Qué hay más al oeste?","jugador":"¿Qué hay siguiendo el camino hacia el oeste?","respuesta":"Más viviendas y caminos que conectan con la zona de trabajo agrícola. Podemos seguir hacia allí."}
		])
	_agregar_parada_tour_elian(pasos, "barrio_agricola", Vector2(-620.0, 430.0),
		"Y este es el sector agrícola. El granero sirve para guardar las cosechas, el molino ayuda a procesar el grano y los corrales reúnen a los animales. Los caminos de esta zona conectan con las tierras de cultivo.",
		[
			{"texto":"¿De dónde llega el grano?","jugador":"¿El grano llega desde los campos cercanos?","respuesta":"Sí, buena parte del trabajo empieza en las tierras de cultivo. Después se almacena o se procesa según lo que haga falta."},
			{"texto":"¿Para qué se usa el molino?","jugador":"¿Qué se hace exactamente en el molino?","respuesta":"Se procesa el grano para obtener harina y otros productos que luego se usan en el reino."},
			{"texto":"¿Quién cuida los corrales?","jugador":"¿Quién se encarga de los animales?","respuesta":"Los agricultores y quienes trabajan con ellos se ocupan de alimentarlos y mantener los corrales en buenas condiciones."}
		])

	pasos.append({"tipo":"dialogo","npc":"Elian","datos":{
		"clave":"bienvenida_elian_cierre",
		"lineas":[{"hablante":"Elian","texto":"¡Y eso es buena parte del reino! Seguro que todavía descubrirás rincones por tu cuenta. Si te pierdes o te surge alguna duda, puedes preguntarme cuando nos encontremos."}]
	}})
	pasos.append({"tipo":"dialogo","datos":{"clave":"bienvenida_pensamientos_cierre","lineas":[
		{"hablante":"Pensamientos","texto":"Ahora ya tengo una idea de cómo está organizado el reino. Será más fácil empezar a conocer a la gente y encontrar mi sitio por aquí."}
	]}})

	var completada: bool = await _cutscene_director.ejecutar("bienvenida_inicial_torres", pasos)
	_bienvenida_torres_en_curso = false
	if not completada:
		return
	_bienvenida_torres_pendiente = false
	GameState.world_state.flags["bienvenida_torres_vista"] = true
	if GameState.has_method("guardar_partida"):
		GameState.call_deferred("guardar_partida")


func _buscar_npc_bienvenida(nombre_buscado: String) -> Creature:
	var clave := nombre_buscado.strip_edges().to_lower()
	for nodo in get_tree().get_nodes_in_group("torres_game_npc"):
		if not nodo is Creature or not is_instance_valid(nodo):
			continue
		var npc := nodo as Creature
		if npc.get_nombre_visual().strip_edges().to_lower() == clave:
			return npc
	return null


func _crear_dialogo_guardia_bienvenida() -> Dictionary:
	return {
		"clave":"bienvenida_guardia_llegada",
		"lineas":[{"hablante":"Darven","texto":"¡Alto un momento! No te había visto antes. ¿Qué te trae por el reino?"}],
		"respuestas":[
			{"clave":"buscar_alojamiento","texto":"Busco un lugar donde quedarme","jugador":"Estoy buscando un lugar donde pueda quedarme.","respuesta":"Entiendo. La posada de la plaza recibe viajeros; allí puedes preguntar por una habitación.","despedida":true},
			{"clave":"conocer_reino","texto":"Vengo a conocer el reino","jugador":"Vine a conocer el reino. Es la primera vez que estoy aquí.","respuesta":"Entonces bienvenido. Procura familiarizarte con los caminos y, si necesitas orientación, puedes preguntar a los vecinos.","despedida":true},
			{"clave":"de_paso","texto":"Solo estoy de paso","jugador":"Solo estoy de paso. Quería descansar un momento antes de seguir.","respuesta":"De acuerdo. Puedes descansar en la posada y continuar cuando estés listo. No hay problema.","despedida":true},
			{"clave":"sin_plan","texto":"Todavía no lo tengo claro","jugador":"La verdad, todavía no lo tengo muy claro. Acabo de llegar.","respuesta":"No pasa nada. Tómate tu tiempo para conocer el lugar. Mientras no causes problemas, puedes recorrer el reino con tranquilidad.","despedida":true}
		]
	}


func _crear_dialogo_presentacion_elian() -> Dictionary:
	return {
		"clave":"bienvenida_elian_presentacion",
		"lineas":[{"hablante":"Elian","texto":"¡Hola! Soy Elian. Vi que acababas de llegar y pensé que quizá te vendría bien una mano. Conozco bastante bien el reino. ¿Te gustaría que te lo enseñara?"}],
		"respuestas":[
			{"clave":"aceptar_tour","texto":"Claro, me gustaría conocer el reino","jugador":"¡Claro! Me gustaría conocer el reino.","respuesta":"¡Genial! Vamos, te mostraré los lugares importantes y te presentaré cómo se organiza cada barrio.","despedida":true},
			{"clave":"orientarse","texto":"Me vendría bien orientarme","jugador":"Me vendría bien orientarme. Todavía no conozco los caminos.","respuesta":"Entonces llegaste en buen momento. Te enseñaré por dónde moverte y qué puedes encontrar en cada zona.","despedida":true},
			{"clave":"conocer_habitantes","texto":"Quiero conocer a sus habitantes","jugador":"También me gustaría saber quién vive y trabaja por aquí.","respuesta":"¡Eso se puede hacer! Te iré contando dónde viven algunos vecinos y qué suele hacer cada uno.","despedida":true},
			{"clave":"preguntar_elian","texto":"Antes, cuéntame un poco de ti","jugador":"Antes de salir, ¿me cuentas un poco de ti?","respuesta":"¡Por supuesto! Trabajo en la panadería. Me gusta conocer gente y siempre termino enterándome de alguna novedad. Ya tendremos tiempo de hablar más; por ahora, ¡vamos a dar una vuelta!","despedida":true}
		]
	}


func _agregar_parada_tour_elian(
	pasos: Array[Dictionary],
	clave: String,
	posicion: Vector2,
	explicacion: String,
	preguntas: Array[Dictionary]
) -> void:
	# Primero se revela el lugar; dejamos un instante para que el jugador
	# pueda reconocer los edificios antes de que Elian empiece a explicarlos.
	pasos.append({"tipo":"camara","x":posicion.x,"y":posicion.y - 75.0,"zoom":1.25,"duracion":1.1})
	pasos.append({"tipo":"esperar","segundos":0.65})
	pasos.append({"tipo":"mover_jugador","x":posicion.x,"y":posicion.y,"duracion":1.5})
	pasos.append({"tipo":"ruta_npc","npc":"Elian","puntos":[posicion + Vector2(42.0, 12.0)],"duracion_por_tramo":1.5})
	pasos.append({"tipo":"mirar_npc","npc":"Elian","izquierda":true})
	var respuestas: Array[Dictionary] = []
	for pregunta_variant in preguntas:
		if not pregunta_variant is Dictionary:
			continue
		var pregunta := (pregunta_variant as Dictionary).duplicate(true)
		pregunta["despedida"] = true
		pregunta["evento"] = "interesarse"
		respuestas.append(pregunta)
	respuestas.append({
		"clave":"continuar_%s" % clave,
		"texto":"Seguir con el recorrido",
		"jugador":"Gracias por explicármelo. Sigamos.",
		"respuesta":"¡Claro! Todavía nos quedan algunas cosas por ver.",
		"despedida":true
	})
	pasos.append({"tipo":"dialogo","npc":"Elian","datos":{
		"clave":"bienvenida_tour_%s" % clave,
		"lineas":[{"hablante":"Elian","texto":explicacion}],
		"respuestas":respuestas
	}})


func _agregar_conversacion_tour_elian(
	pasos: Array[Dictionary],
	nombre_npc: String,
	posicion: Vector2,
	lineas: Array[Dictionary],
	preguntas: Array[Dictionary]
) -> void:
	# Las conversaciones espontáneas también deben ocurrir en el sitio
	# que se está mostrando, nunca antes del desplazamiento de cámara.
	pasos.append({"tipo":"camara","x":posicion.x,"y":posicion.y - 75.0,"zoom":1.25,"duracion":1.0})
	pasos.append({"tipo":"esperar","segundos":0.55})
	pasos.append({"tipo":"mover_jugador","x":posicion.x,"y":posicion.y,"duracion":1.25})
	pasos.append({"tipo":"ruta_npc","npc":"Elian","puntos":[posicion + Vector2(42.0, 12.0)],"duracion_por_tramo":1.25})
	pasos.append({"tipo":"preparar_npc","npc":nombre_npc,"x":posicion.x - 42.0,"y":posicion.y + 12.0})
	pasos.append({"tipo":"mirar_npc","npc":nombre_npc,"hacia_npc":"Elian"})
	pasos.append({"tipo":"mirar_npc","npc":"Elian","hacia_npc":nombre_npc})
	pasos.append({"tipo":"gesto_npc","npc":nombre_npc,"gesto":"saludar","duracion":0.55})
	var respuestas: Array[Dictionary] = []
	for pregunta_variant in preguntas:
		if not pregunta_variant is Dictionary:
			continue
		var pregunta := (pregunta_variant as Dictionary).duplicate(true)
		pregunta["despedida"] = true
		pregunta["evento"] = "interesarse"
		respuestas.append(pregunta)
	respuestas.append({
		"clave":"dejar_conversar_%s" % nombre_npc.to_lower(),
		"texto":"Dejarlos seguir conversando",
		"jugador":"Los dejo conversar. Nos vemos luego.",
		"respuesta":"¡Hasta luego! Nos vemos por el reino.",
		"despedida":true
	})
	pasos.append({"tipo":"dialogo","npc":nombre_npc,"datos":{
		"clave":"bienvenida_conversacion_elian_%s" % nombre_npc.to_lower(),
		"lineas":lineas,
		"respuestas":respuestas
	}})


func _actualizar_rutinas_npcs_torres() -> void:
	if is_instance_valid(_npc_schedule_system):
		_npc_schedule_system.actualizar(0.5)
	if is_instance_valid(_npc_conversation_system):
		_npc_conversation_system.actualizar(0.5, _player, _dialogue_system, MissionManager)


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

	_camera = get_node_or_null("GameCamera") as Camera2D
	if not is_instance_valid(_camera):
		_camera = Camera2D.new()
		_camera.name = "GameCamera"
		add_child(_camera)
		push_warning("Main: no existía GameCamera en esta escena; se creó una cámara de respaldo.")

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
	elif tipo_zona == "expedicion:bosque":
		_camera.limit_left = 0
		_camera.limit_right = 5120
		_camera.limit_top = -1024
		_camera.limit_bottom = 1024
		_camera.limit_enabled = true
	elif tipo_zona == "historia:reserva_carmesi":
		_camera.limit_left = -640
		_camera.limit_right = 6400
		_camera.limit_top = -1760
		_camera.limit_bottom = 1760
		_camera.limit_enabled = true
	else:
		_camera.limit_enabled = false
	_camera.make_current()

	_seguir_jugador()


func _seguir_jugador() -> void:
	if _player == null or _camera == null:
		return
	if is_instance_valid(_cutscene_director) and _cutscene_director.esta_activo():
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
	# Instanciar directamente el script evita dejar un CanvasLayer sin script
	# si set_script no llega a aplicarlo durante la creación dinámica.
	_garumi_battle_party = GARUMI_BATTLE_PARTY_SCRIPT.new() as CanvasLayer
	if not is_instance_valid(_garumi_battle_party):
		push_error("Main: no se pudo instanciar GarumiBattleParty.")
		return
	_garumi_battle_party.name = "GarumiBattleParty"
	add_child(_garumi_battle_party)
	if not _garumi_battle_party.has_method("iniciar"):
		push_error("Main: GarumiBattleParty no expone iniciar(); se cancela el HUD.")
		_garumi_battle_party.queue_free()
		_garumi_battle_party = null
		return
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

	_interaction_system.configurar(_player, _inventory.inventory_controller if _inventory != null else null, _world_items, _player.input_gate, world_gen.entity_manager if world_gen != null else null)
	_interaction_system.configurar_conversaciones(_npc_conversation_system, _dialogue_system)

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

	_combat_system.configurar(_player, _inventory.inventory_controller if _inventory != null else null, world_context, _combat_projectiles, GameState)


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
	# El mapa recibe la zona activa después de configurar Player e inventario.
	# Así Torres (escena fija) y la expedición no conservan el mapa de la zona anterior.
	if _inventory.has_method("configurar_mapa_zona"):
		_inventory.configurar_mapa_zona(
			str(_zone_manager.obtener_tipo_actual()),
			_zone_manager.obtener_zona_actual(),
			_world_context
		)

	if _input_router != null:
		_inventory.configurar_input_router(_input_router)
	_pause_menu.configurar(_inventory)
	_death_menu.configurar(_player, _inventory)


func _configurar_dialogo() -> void:
	if _dialogue_system == null:
		push_error("Main: no se encontró Systems/DialogueSystem.")
		return

	_dialogue_system.configurar(_player, _hud, MissionManager, RelationshipSystem)
	_dialogue_system.configurar_inventario(_inventory.inventory_controller if is_instance_valid(_inventory) else null)
	if not is_instance_valid(_cutscene_director):
		_cutscene_director = CUTSCENE_DIRECTOR_SCRIPT.new()
		_cutscene_director.name = "CutsceneDirector"
		add_child(_cutscene_director)
	_cutscene_director.configurar(_player, _dialogue_system, _camera)
	if not _cutscene_director.evento_solicitado.is_connected(_al_evento_cinematica_solicitado):
		_cutscene_director.evento_solicitado.connect(_al_evento_cinematica_solicitado)
	var admin_tab := get_node_or_null("UI/Inventory/Window/Margin/Column/Tabs/Admin") as AdminInventory
	if is_instance_valid(admin_tab):
		admin_tab.call("configurar_narrativa", _dialogue_system, _cutscene_director, _npc_conversation_system)
	if is_instance_valid(_npc_conversation_system) and _npc_conversation_system.has_signal("cinematica_narrativa_solicitada"):
		var callback_narrativa := Callable(self, "_al_cinematica_narrativa_solicitada")
		if not _npc_conversation_system.is_connected("cinematica_narrativa_solicitada", callback_narrativa):
			_npc_conversation_system.connect("cinematica_narrativa_solicitada", callback_narrativa)
	if is_instance_valid(_npc_conversation_system) and _npc_conversation_system.has_signal("cinematica_acontecimiento_solicitada"):
		var callback_cinematica := Callable(self, "_al_cinematica_acontecimiento_solicitada")
		if not _npc_conversation_system.is_connected("cinematica_acontecimiento_solicitada", callback_cinematica):
			_npc_conversation_system.connect("cinematica_acontecimiento_solicitada", callback_cinematica)
	if is_instance_valid(_npc_conversation_system) and _npc_conversation_system.has_signal("cinematica_reunion_nocturna_solicitada"):
		var callback_reunion := Callable(self, "_al_cinematica_reunion_nocturna_solicitada")
		if not _npc_conversation_system.is_connected("cinematica_reunion_nocturna_solicitada", callback_reunion):
			_npc_conversation_system.connect("cinematica_reunion_nocturna_solicitada", callback_reunion)
	if _bienvenida_torres_pendiente and str(_zone_manager.obtener_tipo_actual()) == "reino_torres":
		call_deferred("_iniciar_bienvenida_torres")


func _al_evento_cinematica_solicitado(evento: String, datos: Dictionary) -> void:
	if not evento.begins_with("social:"):
		return
	var personaje_id := str(datos.get("personaje_game_id", "")).strip_edges()
	var accion_social := evento.trim_prefix("social:").strip_edges()
	if personaje_id.is_empty() or accion_social.is_empty():
		push_warning("Main: evento social de cinemática sin personaje o acción.")
		return
	var evento_id := str(datos.get("evento_id", "")).strip_edges()
	var contexto_variant: Variant = datos.get("contexto", {})
	var contexto: Dictionary = contexto_variant.duplicate(true) if contexto_variant is Dictionary else {}
	RelationshipSystem.registrar_evento_social(personaje_id, accion_social, evento_id, contexto)


## Las etapas de una relación entre NPC pueden cerrar con una escena visual propia.
## La conversación ya contiene el diálogo; esta secuencia añade puesta en escena sin repetirlo.
func _buscar_npc_cinematica(nombre: String) -> Creature:
	var buscado := nombre.strip_edges().to_lower()
	if buscado.is_empty():
		return null
	for nodo in get_tree().get_nodes_in_group("torres_game_npc"):
		if not nodo is Creature or not is_instance_valid(nodo):
			continue
		var npc := nodo as Creature
		if npc.get_nombre_visual().strip_edges().to_lower() == buscado:
			return npc
	return null


func _npc_libre_para_cinematica(npc: Creature, permitir_actividad_social: bool = false) -> bool:
	if not is_instance_valid(npc) or not npc.is_inside_tree() or not npc.is_visible_in_tree() or not npc.is_alive:
		return false
	if bool(npc.get_meta("rutina_en_edificio", false)):
		return false
	var actividad_social := permitir_actividad_social and bool(npc.get_meta("actividad_social_activa", false))
	if bool(npc.get_meta("acercamiento_social_activo", false)) and not actividad_social:
		return false
	if bool(npc.get_meta("conversacion_npc_bloqueada", false)) or bool(npc.get_meta("cinematica_npc_activa", false)):
		return false
	if bool(npc.get_meta("rutina_en_transito", false)) and not actividad_social:
		return false
	if not permitir_actividad_social and bool(npc.get_meta("actividad_social_activa", false)):
		return false
	return npc.velocity.length() <= 5.0


func _al_cinematica_narrativa_solicitada(
	clave: String,
	nombre_a: String,
	nombre_b: String,
	posicion_global: Vector2,
	etapa: int,
	desde_cola: bool = false
) -> void:
	if not desde_cola:
		_encolar_cinematica_proximidad("narrativa", clave, nombre_a, nombre_b, posicion_global, etapa)
		return
	if not is_instance_valid(_player) or not is_instance_valid(_camera):
		return
	if not is_instance_valid(_cutscene_director) or _cutscene_director.esta_activo():
		return
	if is_instance_valid(_dialogue_system) and _dialogue_system.esta_abierto():
		return
	if str(_zone_manager.obtener_tipo_actual()) != "reino_torres":
		return
	var npc_a := _buscar_npc_cinematica(nombre_a)
	var npc_b := _buscar_npc_cinematica(nombre_b)
	if not _npc_libre_para_cinematica(npc_a) or not _npc_libre_para_cinematica(npc_b):
		return
	if npc_a == npc_b or npc_a.global_position.distance_to(npc_b.global_position) > 180.0:
		return
	var centro_real := (npc_a.global_position + npc_b.global_position) * 0.5
	if _player.global_position.distance_to(centro_real) > 260.0:
		return

	var escenas: Dictionary = {
		"elian_saira_hornada": {"gesto_a":"asentir","gesto_b":"saludar"},
		"bruna_darven_camino": {"gesto_a":"negar","gesto_b":"asentir"},
		"bruna_narel_evidencia": {"gesto_a":"trabajar","gesto_b":"asentir"},
		"darven_saira_avisos": {"gesto_a":"asentir","gesto_b":"saludar"},
		"elian_narel_hornada": {"gesto_a":"saludar","gesto_b":"asentir"}
	}
	var escena_variant: Variant = escenas.get(clave, {"gesto_a":"asentir","gesto_b":"asentir"})
	var escena: Dictionary = escena_variant
	var zoom_actual := _camera.zoom.x
	await _ejecutar_cinematica_intercambio_social(
		"relacion_%s_etapa_%d" % [clave, etapa], nombre_a, nombre_b, centro_real,
		zoom_actual * (1.08 if etapa == 1 else 1.14),
		str(escena.get("gesto_a", "asentir")), str(escena.get("gesto_b", "asentir")),
		0.75, 0.25, 0.5, 0.6
	)



## Un acontecimiento cotidiano puede recibir un breve plano de presentación.
## Sólo se muestra si el jugador está cerca y no hay otra interfaz abierta.
func _al_cinematica_acontecimiento_solicitada(
	clave: String,
	nombre_a: String,
	nombre_b: String,
	posicion_global: Vector2,
	desde_cola: bool = false
) -> void:
	if not desde_cola:
		_encolar_cinematica_proximidad("acontecimiento", clave, nombre_a, nombre_b, posicion_global)
		return
	if not is_instance_valid(_player) or not is_instance_valid(_camera):
		return
	if not is_instance_valid(_cutscene_director) or _cutscene_director.esta_activo():
		return
	if is_instance_valid(_dialogue_system) and _dialogue_system.esta_abierto():
		return
	if str(_zone_manager.obtener_tipo_actual()) != "reino_torres":
		return
	var npc_a := _buscar_npc_cinematica(nombre_a)
	var npc_b := _buscar_npc_cinematica(nombre_b)
	if not _npc_libre_para_cinematica(npc_a, true) or not _npc_libre_para_cinematica(npc_b, true):
		return
	if not desde_cola and (not bool(npc_a.get_meta("actividad_social_activa", false)) or not bool(npc_b.get_meta("actividad_social_activa", false))):
		return
	if npc_a == npc_b or npc_a.global_position.distance_to(npc_b.global_position) > 110.0:
		return
	var centro_real := (npc_a.global_position + npc_b.global_position) * 0.5
	if _player.global_position.distance_to(centro_real) > 320.0:
		return

	var zoom_actual := _camera.zoom.x
	await _ejecutar_cinematica_intercambio_social(
		"acontecimiento_%s" % clave, nombre_a, nombre_b, centro_real,
		zoom_actual * 1.12, "asentir", "saludar", 0.9, 0.0, 0.45, 0.6
	)


## Escenas breves que acompañan algunas conversaciones de la reunión nocturna.
## Se ejecutan dentro del salón y no interrumpen el diálogo ambiental de las burbujas.
func _al_cinematica_reunion_nocturna_solicitada(
	clave: String,
	nombre_a: String,
	nombre_b: String,
	posicion_global: Vector2,
	desde_cola: bool = false
) -> void:
	if not desde_cola:
		_encolar_cinematica_proximidad("reunion", clave, nombre_a, nombre_b, posicion_global)
		return
	if not is_instance_valid(_player) or not is_instance_valid(_camera):
		return
	if not is_instance_valid(_cutscene_director) or _cutscene_director.esta_activo():
		return
	if is_instance_valid(_dialogue_system) and _dialogue_system.esta_abierto():
		return
	if not is_instance_valid(_zone_manager) or str(_zone_manager.obtener_tipo_actual()) != "reino_torres":
		return
	var zona: Node = _zone_manager.obtener_zona_actual()
	if not is_instance_valid(zona) or not bool(zona.get("_interior_activo")) or str(zona.get("_entrada_interior_id")) != "castillo":
		return
	var npc_a := _buscar_npc_cinematica(nombre_a)
	var npc_b := _buscar_npc_cinematica(nombre_b)
	if not is_instance_valid(npc_a) or not is_instance_valid(npc_b) or npc_a == npc_b:
		return
	for npc in [npc_a, npc_b]:
		if not bool(npc.get_meta("rutina_en_edificio", false)) or str(npc.get_meta("rutina_edificio_id", "")) != "castillo":
			return
		if not npc.is_visible_in_tree() or not npc.is_alive:
			return
	var centro := (npc_a.global_position + npc_b.global_position) * 0.5
	if _player.global_position.distance_to(centro) > 520.0:
		return
	var gesto_a := "asentir"
	var gesto_b := "asentir"
	match clave:
		"noche_darven_saira_rumores":
			gesto_a = "negar"
			gesto_b = "asentir"
		"noche_mara_darven_puerta":
			gesto_a = "sorpresa"
			gesto_b = "asentir"
		"noche_ivo_elian_mesa":
			gesto_a = "asentir"
			gesto_b = "saludar"
	var zoom_actual := _camera.zoom.x
	await _ejecutar_cinematica_intercambio_social(
		"reunion_nocturna_%s" % clave, nombre_a, nombre_b, centro,
		zoom_actual * 1.12, gesto_a, gesto_b, 0.8, 0.2, 0.35, 0.65
	)


func _buscar_tercero_cinematica(nombre_a: String, nombre_b: String, centro: Vector2) -> Creature:
	var npc_a := nombre_a.strip_edges().to_lower()
	var npc_b := nombre_b.strip_edges().to_lower()
	var mejor: Creature = null
	var distancia_mejor := 115.0
	for nodo in get_tree().get_nodes_in_group("torres_game_npc"):
		if not nodo is Creature or not is_instance_valid(nodo):
			continue
		var candidato := nodo as Creature
		var nombre := candidato.get_nombre_visual().strip_edges().to_lower()
		if nombre.is_empty() or nombre == npc_a or nombre == npc_b:
			continue
		if not _npc_libre_para_cinematica(candidato):
			continue
		var distancia := candidato.global_position.distance_to(centro)
		if distancia < distancia_mejor:
			distancia_mejor = distancia
			mejor = candidato
	return mejor


func _ejecutar_cinematica_intercambio_social(
	clave: String,
	nombre_a: String,
	nombre_b: String,
	centro: Vector2,
	zoom: float,
	gesto_a: String,
	gesto_b: String,
	duracion_camara: float,
	pausa_antes: float,
	pausa_despues: float,
	duracion_gesto: float
) -> void:
	if not is_instance_valid(_cutscene_director):
		return
	var es_encuentro_trio := clave.contains("encuentro_trio_mara_ivo_nima")
	var tercero: Creature
	if es_encuentro_trio:
		tercero = _buscar_npc_cinematica("nima")
		if not is_instance_valid(tercero) or tercero.global_position.distance_to(centro) > 150.0:
			tercero = null
	else:
		tercero = _buscar_tercero_cinematica(nombre_a, nombre_b, centro)
	var usar_tercero := is_instance_valid(tercero) and (es_encuentro_trio or posmod(hash(clave + "|" + nombre_a + "|" + nombre_b), 3) == 1)
	var usar_interrupcion := posmod(hash(clave + "|" + nombre_a + "|" + nombre_b), 3) == 0
	if es_encuentro_trio and is_instance_valid(tercero):
		var npc_a_grupo := _buscar_npc_cinematica(nombre_a)
		var npc_b_grupo := _buscar_npc_cinematica(nombre_b)
		var centro_grupo := (npc_a_grupo.global_position + npc_b_grupo.global_position + tercero.global_position) / 3.0
		var secuencia_grupo := load("res://resources/cutscenes/reunion_trio.tres") as CutsceneSequence
		if is_instance_valid(secuencia_grupo):
			await _cutscene_director.ejecutar_recurso(secuencia_grupo, {
				"clave": clave,
				"npc_a": nombre_a,
				"npc_b": nombre_b,
				"tercero": tercero.get_nombre_visual(),
				"x": centro_grupo.x,
				"y": centro_grupo.y,
				"zoom": zoom,
				"duracion_camara": duracion_camara
			}, "en_vivo")
			return
	var ruta_secuencia := "res://resources/cutscenes/intercambio_con_tercero.tres" if usar_tercero else ("res://resources/cutscenes/intercambio_interrumpido.tres" if usar_interrupcion else "res://resources/cutscenes/intercambio_social.tres")
	var invertir_turno := posmod(hash(nombre_a + "|" + nombre_b + "|" + clave), 2) == 1
	var interrumpe := nombre_a if invertir_turno else nombre_b
	var interrumpido := nombre_b if invertir_turno else nombre_a
	var secuencia := load(ruta_secuencia) as CutsceneSequence
	if not is_instance_valid(secuencia):
		push_warning("Main: no se pudo cargar la secuencia de intercambio social.")
		return
	var parametros := {
		"clave": clave,
		"npc_a": nombre_a,
		"npc_b": nombre_b,
		"interrumpe": interrumpe,
		"interrumpido": interrumpido,
		"x": centro.x,
		"y": centro.y,
		"zoom": zoom,
		"gesto_a": gesto_a,
		"gesto_b": gesto_b,
		"duracion_camara": duracion_camara,
		"pausa_antes": pausa_antes,
		"pausa_despues": pausa_despues,
		"duracion_gesto": duracion_gesto
	}
	if usar_tercero:
		var npc_a_obj := _buscar_npc_cinematica(nombre_a)
		var npc_b_obj := _buscar_npc_cinematica(nombre_b)
		var eje := (npc_b_obj.global_position - npc_a_obj.global_position).normalized()
		if eje.length_squared() < 0.01:
			eje = Vector2.RIGHT
		var lateral := Vector2(-eje.y, eje.x)
		var posicion_llegada := centro + lateral * 34.0
		var direccion_salida := (tercero.global_position - centro).normalized()
		if direccion_salida.length_squared() < 0.01:
			direccion_salida = lateral
		var posicion_salida := tercero.global_position + direccion_salida * 28.0
		parametros["tercero"] = tercero.get_nombre_visual()
		parametros["tercero_llegada_x"] = posicion_llegada.x
		parametros["tercero_llegada_y"] = posicion_llegada.y
		parametros["tercero_salida_x"] = posicion_salida.x
		parametros["tercero_salida_y"] = posicion_salida.y
	await _cutscene_director.ejecutar_recurso(secuencia, parametros, "en_vivo")


## Las señales cinematográficas no se descartan por estar el jugador lejos,
## ocupado en otra escena o entrando a un interior. Se conservan hasta que
## el jugador llega al lugar y los participantes siguen disponibles.
func _prioridad_cinematica(tipo: String) -> int:
	match tipo:
		"narrativa":
			return 3
		"reunion":
			return 2
		"acontecimiento":
			return 1
	return 0


func _caducidad_cinematica_ms(tipo: String) -> int:
	match tipo:
		"narrativa":
			return 180000
		"reunion":
			return 180000
		"acontecimiento":
			return 90000
	return 0


func _encolar_cinematica_proximidad(
	tipo: String,
	clave: String,
	nombre_a: String,
	nombre_b: String,
	posicion_global: Vector2,
	etapa: int = 0
) -> void:
	var clave_pendiente := "%s|%s|%s|%s|%d" % [
		tipo, clave, nombre_a.to_lower(), nombre_b.to_lower(), etapa
	]
	for pendiente in _cinematicas_pendientes:
		if str(pendiente.get("id", "")) == clave_pendiente:
			return
	var creada_ms := Time.get_ticks_msec()
	_cinematicas_pendientes.append({
		"id": clave_pendiente,
		"tipo": tipo,
		"clave": clave,
		"npc_a": nombre_a,
		"npc_b": nombre_b,
		"posicion": posicion_global,
		"etapa": etapa,
		"prioridad": _prioridad_cinematica(tipo),
		"creada_ms": creada_ms
	})
	# Si la cola se llena, conserva las escenas importantes y descarta primero
	# la petición menos prioritaria; entre iguales, la más antigua.
	while _cinematicas_pendientes.size() > 16:
		var indice_descartar := 0
		var prioridad_menor := 2147483647
		var mas_antigua := 2147483647
		for indice in range(_cinematicas_pendientes.size()):
			var candidata: Dictionary = _cinematicas_pendientes[indice]
			var prioridad := int(candidata.get("prioridad", 0))
			var momento := int(candidata.get("creada_ms", 0))
			if prioridad < prioridad_menor or (prioridad == prioridad_menor and momento < mas_antigua):
				prioridad_menor = prioridad
				mas_antigua = momento
				indice_descartar = indice
		_cinematicas_pendientes.remove_at(indice_descartar)


func _procesar_cinematicas_pendientes() -> void:
	if _procesando_cinematica_pendiente or _cinematicas_pendientes.is_empty():
		return
	if not is_instance_valid(_player) or not is_instance_valid(_camera):
		return
	if not is_instance_valid(_cutscene_director) or _cutscene_director.esta_activo():
		return
	if is_instance_valid(_dialogue_system) and _dialogue_system.esta_abierto():
		return
	if not is_instance_valid(_zone_manager) or str(_zone_manager.obtener_tipo_actual()) != "reino_torres":
		return

	var ahora_ms := Time.get_ticks_msec()
	var mejor_indice := -1
	var mejor_puntuacion := -INF
	var momento_mejor := 2147483647

	# Recorremos de atrás hacia delante para poder limpiar entradas sin alterar
	# los índices que todavía quedan por revisar.
	for indice in range(_cinematicas_pendientes.size() - 1, -1, -1):
		var pendiente: Dictionary = _cinematicas_pendientes[indice]
		var tipo := str(pendiente.get("tipo", ""))
		var creada_ms := int(pendiente.get("creada_ms", ahora_ms))
		var caducidad_ms := _caducidad_cinematica_ms(tipo)
		if caducidad_ms <= 0 or ahora_ms - creada_ms > caducidad_ms:
			_cinematicas_pendientes.remove_at(indice)
			continue

		var nombre_a := str(pendiente.get("npc_a", ""))
		var nombre_b := str(pendiente.get("npc_b", ""))
		var clave := str(pendiente.get("clave", ""))
		var posicion: Vector2 = pendiente.get("posicion", Vector2.ZERO)
		var npc_a := _buscar_npc_cinematica(nombre_a)
		var npc_b := _buscar_npc_cinematica(nombre_b)
		if not is_instance_valid(npc_a) or not is_instance_valid(npc_b) or npc_a == npc_b:
			_cinematicas_pendientes.remove_at(indice)
			continue

		var centro_actual := (npc_a.global_position + npc_b.global_position) * 0.5
		# La escena sólo sigue vigente mientras sus participantes permanezcan
		# cerca del lugar donde ocurrió el acontecimiento.
		if centro_actual.distance_to(posicion) > 240.0:
			_cinematicas_pendientes.remove_at(indice)
			continue

		var distancia_activacion := 0.0
		match tipo:
			"narrativa":
				if not _npc_libre_para_cinematica(npc_a) or not _npc_libre_para_cinematica(npc_b):
					continue
				if npc_a.global_position.distance_to(npc_b.global_position) > 180.0:
					continue
				distancia_activacion = 260.0
			"acontecimiento":
				if not _npc_libre_para_cinematica(npc_a, true) or not _npc_libre_para_cinematica(npc_b, true):
					continue
				if npc_a.global_position.distance_to(npc_b.global_position) > 110.0:
					continue
				distancia_activacion = 320.0
			"reunion":
				var zona: Node = _zone_manager.obtener_zona_actual()
				if not is_instance_valid(zona) or not bool(zona.get("_interior_activo")) or str(zona.get("_entrada_interior_id")) != "castillo":
					continue
				var participantes_validos := true
				for npc in [npc_a, npc_b]:
					if not bool(npc.get_meta("rutina_en_edificio", false)) or str(npc.get_meta("rutina_edificio_id", "")) != "castillo" or not npc.is_visible_in_tree() or not npc.is_alive:
						participantes_validos = false
						break
				if not participantes_validos:
					continue
				distancia_activacion = 520.0
			_:
				_cinematicas_pendientes.remove_at(indice)
				continue

		var distancia_jugador := _player.global_position.distance_to(posicion)
		if distancia_jugador > distancia_activacion:
			continue

		# La prioridad evita que una escena cotidiana tape una secuencia narrativa
		# importante. La distancia desempata para mostrar lo que sucede cerca.
		var puntuacion := float(int(pendiente.get("prioridad", _prioridad_cinematica(tipo)))) * 10000.0 - distancia_jugador
		if (
			puntuacion > mejor_puntuacion
			or (is_equal_approx(puntuacion, mejor_puntuacion) and creada_ms < momento_mejor)
		):
			mejor_puntuacion = puntuacion
			momento_mejor = creada_ms
			mejor_indice = indice

	if mejor_indice < 0:
		return

	var pendiente_elegida: Dictionary = _cinematicas_pendientes[mejor_indice]
	_cinematicas_pendientes.remove_at(mejor_indice)
	var tipo_elegido := str(pendiente_elegida.get("tipo", ""))
	var clave_elegida := str(pendiente_elegida.get("clave", ""))
	var nombre_a_elegido := str(pendiente_elegida.get("npc_a", ""))
	var nombre_b_elegido := str(pendiente_elegida.get("npc_b", ""))
	var posicion_elegida: Vector2 = pendiente_elegida.get("posicion", Vector2.ZERO)
	_procesando_cinematica_pendiente = true
	match tipo_elegido:
		"narrativa":
			await _al_cinematica_narrativa_solicitada(
				clave_elegida, nombre_a_elegido, nombre_b_elegido, posicion_elegida,
				int(pendiente_elegida.get("etapa", 0)), true
			)
		"acontecimiento":
			await _al_cinematica_acontecimiento_solicitada(
				clave_elegida, nombre_a_elegido, nombre_b_elegido, posicion_elegida, true
			)
		"reunion":
			await _al_cinematica_reunion_nocturna_solicitada(
				clave_elegida, nombre_a_elegido, nombre_b_elegido, posicion_elegida, true
			)
	_procesando_cinematica_pendiente = false



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
	var admin_tab := _inventory.get_node_or_null("Window/Margin/Column/Tabs/Admin") as AdminInventory
	if admin_tab != null:
		admin_tab.configurar_tiempo(_world_atmosphere)
		admin_tab.configurar_aldeanos(RelationshipSystem, _zone_manager)

func _configurar_pantalla() -> void:
	_registrar_diagnostico_ventana("antes de _configurar_pantalla")
	if not pantalla_completa:
		print("[VENTANA] pantalla_completa=false; no se modifica el modo.")
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_registrar_diagnostico_ventana("después de solicitar FULLSCREEN")


func _diagnostico_ventana_diferido() -> void:
	await get_tree().create_timer(1.0).timeout
	_registrar_diagnostico_ventana("1 segundo después de _ready")


func _registrar_diagnostico_ventana(etapa: String) -> void:
	var pantalla := DisplayServer.window_get_current_screen()
	var modo := DisplayServer.window_get_mode()
	var tamano_ventana := DisplayServer.window_get_size()
	var posicion_ventana := DisplayServer.window_get_position()
	var tamano_pantalla := DisplayServer.screen_get_size(pantalla)
	var area_util := DisplayServer.screen_get_usable_rect(pantalla)
	var tamano_viewport := get_viewport().get_visible_rect().size
	print("[VENTANA][", etapa, "] pid=", OS.get_process_id(),
		" window_id=", get_window().get_window_id(),
		" modo=", modo,
		" pantalla=", pantalla,
		" ventana=", tamano_ventana,
		" posicion=", posicion_ventana,
		" pantalla_size=", tamano_pantalla,
		" area_util=", area_util,
		" viewport=", tamano_viewport,
		" pantalla_completa_export=", pantalla_completa,
		" project_mode=", ProjectSettings.get_setting("display/window/size/mode", -1),
		" project_override=", Vector2i(
			ProjectSettings.get_setting("display/window/size/window_width_override", 0),
			ProjectSettings.get_setting("display/window/size/window_height_override", 0)
		))


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
	_eterium_radial_menu = ETERIUM_RADIAL_MENU_SCENE.instantiate() as Control
	if _eterium_radial_menu == null:
		push_error("Main: no se pudo instanciar eterium_radial_menu.tscn.")
		return
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


func _al_recompensa_mision_disponible(mision: Dictionary, _recompensas: Array[Dictionary]) -> void:
	if _inventory == null or not is_instance_valid(_inventory):
		return
	var mision_id := str(mision.get("id", "")).strip_edges()
	if mision_id.is_empty():
		return
	if MissionManager.entregar_recompensas(mision_id, _inventory):
		return
	Events.notification_pushed.emit("Inventario lleno o recompensa incompleta. La recompensa sigue pendiente.")


func _al_cambio_inventario_reintentar_recompensas() -> void:
	call_deferred("_reintentar_recompensas_misiones")


func _reintentar_recompensas_misiones() -> void:
	if _inventory == null or not is_instance_valid(_inventory):
		return
	MissionManager.reintentar_recompensas_pendientes(_inventory)


func _configurar_social() -> void:
	SocialRepository.configurar(_supabase_client)
	RelationshipSystem.configurar(SocialRepository, GameState, _world_atmosphere)


func _al_cargar_relaciones_ecologicas(relaciones: Array) -> void:
	if _world_generator == null:
		return
	_world_generator.actualizar_relaciones_ecologicas(relaciones)
