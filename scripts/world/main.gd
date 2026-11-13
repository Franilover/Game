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
@onready var _world_climate_visuals: WorldClimateVisuals = $UI/FogOverlay
var _world_generator: WorldGenerator = null
@onready var _world_context: WorldContext = $Systems/WorldContext
@onready var _world_items: GarliaWorldItems = $Systems/WorldItems
const ZONE_MANAGER_SCRIPT = preload("res://scripts/world/zone_manager.gd")
const ETERIUM_RADIAL_MENU_SCENE: PackedScene = preload("res://scenes/ui/eterium_radial_menu.tscn")
const GARUMI_COMBAT_ARENA_SCRIPT = preload("res://scripts/gameplay/garumi_combat_arena.gd")
const GARUMI_BATTLE_PARTY_SCRIPT = preload("res://scripts/gameplay/garumi_battle_party.gd")
const CREATURE_SCENE: PackedScene = preload("res://scenes/creatures/creature.tscn")
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
var _datos_mundo_servidor_listos := false
var _reinos_game_servidor_listos := false
var _inicio_servidor_pendiente := false
var _carga_historia_activa := false
var _cutscene_director: CutsceneDirector = null


func _ready() -> void:
	_carga_historia_activa = bool(GameState.world_state.flags.get("historia_iniciar_reserva_carmesi", false))
	if is_instance_valid(_story_loading_overlay):
		_story_loading_overlay.visible = _carga_historia_activa
	_registrar_diagnostico_ventana("_ready: inicio")
	call_deferred("_diagnostico_ventana_diferido")
	SupabaseClient.configurar_dependencias(GarliaAuth)
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
	_configurar_social()
	_inicializar_ium()
	_configurar_admin()
	_configurar_pantalla()
	if _world_generator != null:
		call_deferred("_restaurar_garumis_vinculados")

	var tipo_zona_actual: String = str(_zone_manager.obtener_tipo_actual())
	if tipo_zona_actual == "hogar":
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
		if is_instance_valid(npc):
			npc.queue_free()


func _materializar_npcs_reino_torres() -> void:
	if not is_instance_valid(_zone_manager) or _zone_manager.obtener_tipo_actual() != "reino_torres":
		return
	if not WorldData.cargado:
		return

	var zona := _zone_manager.obtener_zona_actual() as Node2D
	if not is_instance_valid(zona):
		return

	# Posiciones locales frente a los edificios de trabajo de la escena fija.
	var posiciones := {
		"Elian": Vector2(-205.0, -78.0),
		"Bruna": Vector2(-320.0, -122.0),
		"Darven": Vector2(690.0, -248.0),
		"Saira": Vector2(890.0, -260.0),
		"Narel": Vector2(-370.0, -482.0)
	}

	var existentes: Dictionary = {}
	for npc_existente in get_tree().get_nodes_in_group("torres_game_npc"):
		if npc_existente is Creature and is_instance_valid(npc_existente):
			existentes[(npc_existente as Creature).get_personaje_game_id()] = true

	var creados := 0
	for personaje_variant in WorldData.obtener_personajes_game():
		if not personaje_variant is Dictionary:
			continue
		var personaje := personaje_variant as Dictionary
		var nombre := str(personaje.get("nombre", "")).strip_edges()
		if not posiciones.has(nombre):
			continue
		if str(personaje.get("reino_clave", "")).to_lower() != "torres":
			continue

		var personaje_id := str(personaje.get("id", "")).strip_edges()
		if personaje_id.is_empty() or existentes.has(personaje_id):
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
		criatura_data["ubicacion_clave"] = str(personaje.get("ubicacion_clave", ""))
		var rutinas_variant: Variant = personaje.get("rutinas", [])
		criatura_data["rutinas"] = rutinas_variant.duplicate(true) if rutinas_variant is Array else []

		var dialogo := WorldData.obtener_dialogo_game(personaje_id)
		if not dialogo.is_empty():
			criatura_data["dialogo"] = dialogo

		var npc := CREATURE_SCENE.instantiate() as Creature
		if npc == null:
			push_warning("Main: no se pudo instanciar el NPC " + nombre)
			continue

		npc.move_speed = 0.0
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
		npc.global_position = zona.to_global(posiciones[nombre])
		npc.set_meta("personaje_game_id", personaje_id)
		npc.add_to_group("torres_game_npc")
		npc.remove_from_group("damageable")

		var ai := npc.get_node_or_null("AIController")
		if ai != null:
			ai.set_process(false)
			ai.set_physics_process(false)
		var movimiento := npc.get_node_or_null("CreatureMovement")
		if movimiento != null:
			if movimiento.has_method("detener"):
				movimiento.call("detener")
			movimiento.set_process(false)
			movimiento.set_physics_process(false)
		existentes[personaje_id] = true
		creados += 1

	if creados > 0:
		print("Main: NPC de Reino Torres materializados desde Supabase → ", creados)


func _convertir_hora_rutina_a_minutos(valor: Variant) -> int:
	var partes := str(valor).strip_edges().split(":")
	if partes.size() < 2:
		return -1
	return clampi(int(partes[0]), 0, 23) * 60 + clampi(int(partes[1]), 0, 59)


func _actualizar_rutinas_npcs_torres() -> void:
	if not is_instance_valid(_zone_manager) or _zone_manager.obtener_tipo_actual() != "reino_torres":
		return
	if not is_instance_valid(_world_atmosphere):
		return

	var tiempo := _world_atmosphere.obtener_tiempo()
	if not bool(tiempo.get("calendario_cargado", false)):
		return
	var zona := _zone_manager.obtener_zona_actual() as Node2D
	if not is_instance_valid(zona):
		return

	var dia_semana := posmod(int(tiempo.get("dia", 1)) - 1, 7)
	var minutos_actuales := int(round(float(tiempo.get("hora_del_dia", 0.0)) * 60.0))
	var posiciones := {
		"panaderia": Vector2(-205.0, -78.0),
		"forja": Vector2(-320.0, -122.0),
		"cuartel": Vector2(690.0, -248.0),
		"registro": Vector2(690.0, -170.0),
		"casa_comercio": Vector2(890.0, -260.0),
		"casa_estudio": Vector2(-370.0, -482.0),
		"archivo_real": Vector2(-130.0, -572.0)
	}

	for npc_variant in get_tree().get_nodes_in_group("torres_game_npc"):
		if not npc_variant is Creature or not is_instance_valid(npc_variant):
			continue
		var npc := npc_variant as Creature
		var rutinas_variant: Variant = npc.datos.get("rutinas", [])
		if not rutinas_variant is Array:
			continue

		var rutina_actual: Dictionary = {}
		var prioridad_actual := -2147483648
		for rutina_variant in rutinas_variant as Array:
			if not rutina_variant is Dictionary:
				continue
			var rutina := rutina_variant as Dictionary
			var dias_variant: Variant = rutina.get("dias_semana", [])
			if dias_variant is Array and not (dias_variant as Array).is_empty() and dia_semana not in (dias_variant as Array):
				continue
			var inicio := _convertir_hora_rutina_a_minutos(rutina.get("hora_inicio", ""))
			var fin := _convertir_hora_rutina_a_minutos(rutina.get("hora_fin", ""))
			if inicio < 0 or fin <= inicio or minutos_actuales < inicio or minutos_actuales >= fin:
				continue
			var prioridad := int(rutina.get("prioridad", 0))
			if rutina_actual.is_empty() or prioridad > prioridad_actual:
				rutina_actual = rutina
				prioridad_actual = prioridad

		var clave_rutina := str(rutina_actual.get("clave", "descanso"))
		var ubicacion := str(rutina_actual.get("ubicacion_clave", npc.datos.get("ubicacion_clave", "")))
		var actividad := str(rutina_actual.get("actividad_clave", "descansar"))
		if str(npc.get_meta("rutina_actual", "")) == clave_rutina and str(npc.get_meta("rutina_ubicacion", "")) == ubicacion:
			continue
		npc.set_meta("rutina_actual", clave_rutina)
		npc.set_meta("rutina_ubicacion", ubicacion)
		npc.datos["actividad_actual"] = actividad

		if not posiciones.has(ubicacion):
			continue
		var destino := zona.to_global(posiciones[ubicacion])
		var distancia := npc.global_position.distance_to(destino)
		if distancia <= 6.0:
			npc.global_position = destino
			continue

		var tween_previo: Variant = npc.get_meta("rutina_tween", null)
		if tween_previo is Tween and (tween_previo as Tween).is_running():
			(tween_previo as Tween).kill()
		var tween := npc.create_tween()
		npc.set_meta("rutina_tween", tween)
		var duracion := clampf(distancia / 90.0, 0.6, 3.5)
		tween.tween_property(npc, "global_position", destino, duracion).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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
	if not is_instance_valid(_cutscene_director):
		_cutscene_director = CUTSCENE_DIRECTOR_SCRIPT.new() as CutsceneDirector
		_cutscene_director.name = "CutsceneDirector"
		add_child(_cutscene_director)
	_cutscene_director.configurar(_player, _dialogue_system, _camera)


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


func _configurar_social() -> void:
	SocialRepository.configurar(_supabase_client)
	RelationshipSystem.configurar(SocialRepository, GameState)


func _al_cargar_relaciones_ecologicas(relaciones: Array) -> void:
	if _world_generator == null:
		return
	_world_generator.actualizar_relaciones_ecologicas(relaciones)
