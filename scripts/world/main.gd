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
@onready var _debug_console: CanvasItem = $UI/DebugConsole
var _world_entity_spawner: WorldEntitySpawner = null
@onready var _supabase_client: GarliaSupabaseClient = SupabaseClient
@onready var _ium_repository: IUMRepository = $Systems/IUMRepository
@onready var _game_camera: Camera2D = $GameCamera
@onready var _combat_projectiles: Node2D = $CombatProjectiles
var _world_atmosphere: WorldAtmosphere = null
var _world_generator: WorldGenerator = null
@onready var _world_context: WorldContext = $Systems/WorldContext
@onready var _world_items: GarliaWorldItems = $Systems/WorldItems
const ZONE_MANAGER_SCRIPT = preload("res://scripts/world/zone_manager.gd")
@onready var _zone_manager: Node2D = $World/ZoneManager


func _ready() -> void:
	SupabaseClient.configurar_dependencias(GarliaAuth)
	GarliaMultiplayer.configurar_dependencias(GarliaAuth)
	GarliaSalas.configurar_dependencias(GarliaAuth)

	WorldData.configurar_dependencias(_supabase_client)

	_supabase_client.establecer_mundo_activo(true)
	if not _supabase_client.relaciones_ecologicas_cargadas.is_connected(_al_cargar_relaciones_ecologicas):
		_supabase_client.relaciones_ecologicas_cargadas.connect(_al_cargar_relaciones_ecologicas)

	if _zone_manager == null:
		push_error("Main: falta World/ZoneManager.")
		return

	if not _zone_manager.zona_cambiada.is_connected(_al_cambio_de_zona):
		_zone_manager.zona_cambiada.connect(_al_cambio_de_zona)
	if not _supabase_client.reinos_game_cargados.is_connected(_al_reinos_game_cargados):
		_supabase_client.reinos_game_cargados.connect(_al_reinos_game_cargados)

	_supabase_client.cargar_reinos_game()
	if not GameState.debe_iniciar_en_reino_torres():
		_iniciar_zonas()
	elif not _supabase_client.obtener_reinos_game().is_empty():
		_iniciar_zonas()


func _exit_tree() -> void:
	if is_instance_valid(_supabase_client):
		_supabase_client.establecer_mundo_activo(false)


func _al_reinos_game_cargados(_reinos: Array) -> void:
	if GameState.debe_iniciar_en_reino_torres():
		_iniciar_zonas()


func _iniciar_zonas() -> void:
	_zone_manager.configurar_dependencias(_supabase_client)
	_zone_manager.iniciar()


func _process(_delta: float) -> void:
	_seguir_jugador()


func _al_cambio_de_zona(tipo: String, _zona: Node) -> void:
	_world_generator = _zone_manager.obtener_world_generator()
	_world_entity_spawner = null
	_world_atmosphere = null

	if tipo == "mundo_abierto":
		if _world_generator == null:
			push_error("Main: MundoAbierto no contiene WorldGenerator.")
			return

		_world_entity_spawner = _world_generator.get_node_or_null("WorldEntitySpawner") as WorldEntitySpawner
		_world_atmosphere = _world_generator.get_node_or_null("WorldAtmosphere") as WorldAtmosphere
		_world_context.configurar(
			_world_generator.get_node_or_null("WorldTerrain") as WorldTerrain,
			_world_atmosphere,
			WorldData
		)
		_world_items.establecer_generacion_habilitada(true)

		_world_generator.configurar_dependencias(WorldData, GameState)
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
			if not _world_generator.mundo_generado.is_connected(_al_mundo_generado):
				_world_generator.mundo_generado.connect(_al_mundo_generado, CONNECT_ONE_SHOT)
			return
	else:
		# Reino Torres no crea WorldGenerator ni entidades procedurales.
		_world_context.configurar(null, null, WorldData)
		_world_items.establecer_generacion_habilitada(false)
		_inicializar_runtime_de_zona()


func _al_mundo_generado() -> void:
	_inicializar_runtime_de_zona()


func _inicializar_runtime_de_zona() -> void:
	_player = $Entities/Player as Player

	if _player == null:
		push_error("Main: no se encontró Entities/Player.")
		return

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

	if _zone_manager.obtener_tipo_actual() == "reino_torres":
		_player.global_position = Vector2(0, 120)
		print("Main: inicio en Reino Torres.")
	else:
		print("Main: mundo abierto listo.")


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
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	_camera.position = Vector2.ZERO
	_camera.offset = Vector2.ZERO
	_camera.position_smoothing_enabled = false
	_ultima_posicion_camara = Vector2.INF
	_camera.drag_horizontal_enabled = false
	_camera.drag_vertical_enabled = false
	_camera.limit_enabled = false
	_camera.make_current()

	_seguir_jugador()


func _seguir_jugador() -> void:
	if _player == null or _camera == null:
		return

	var posicion: Vector2 = _player.global_position
	if posicion == _ultima_posicion_camara:
		return

	_camera.global_position = posicion
	_ultima_posicion_camara = posicion


func _configurar_hud(world_context: WorldContext, world_gen: WorldGenerator = null) -> void:
	if _hud == null:
		push_error("Main: no se encontró UI/HUD.")
		return

	_hud.configurar(_player, world_context, MissionManager, world_gen.entity_manager if world_gen != null else null, _supabase_client, _inventory, WorldData, GameState)


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

	if not _ium_manager.proceso_equipado_signal.is_connected(_al_equipar_proceso):
		_ium_manager.proceso_equipado_signal.connect(_al_equipar_proceso)

	print("Main: IUMManager e IUMLab conectados.")

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
