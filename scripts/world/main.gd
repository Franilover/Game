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
@onready var _world_entity_spawner: WorldEntitySpawner = $World/WorldGenerator/WorldEntitySpawner
@onready var _supabase_client: GarliaSupabaseClient = SupabaseClient
@onready var _ium_repository: IUMRepository = $Systems/IUMRepository
@onready var _game_camera: Camera2D = $GameCamera
@onready var _combat_projectiles: Node2D = $CombatProjectiles
@onready var _world_atmosphere: WorldAtmosphere = $World/WorldGenerator/WorldAtmosphere
@onready var _world_generator: WorldGenerator = $World/WorldGenerator
@onready var _world_context: WorldContext = $World/WorldGenerator/WorldContext
@onready var _world_items: GarliaWorldItems = $Systems/WorldItems
@onready var _reino_torres: Node2D = $World/ReinoTorres


func _ready() -> void:
	SupabaseClient.configurar_dependencias(GarliaAuth)
	GarliaMultiplayer.configurar_dependencias(GarliaAuth)
	GarliaSalas.configurar_dependencias(GarliaAuth)

	WorldData.configurar_dependencias(_supabase_client)

	_supabase_client.establecer_mundo_activo(true)
	if not _supabase_client.relaciones_ecologicas_cargadas.is_connected(_al_cargar_relaciones_ecologicas):
		_supabase_client.relaciones_ecologicas_cargadas.connect(_al_cargar_relaciones_ecologicas)
	var world_gen: WorldGenerator = _world_generator
	world_gen.configurar_dependencias(WorldData, GameState)
	world_gen.configurar_entidades($Entities, $Entities/Player, _inventory, _combat_system, _dialogue_system, MissionManager, _world_context, _world_items, _supabase_client.obtener_relaciones_ecologicas())
	_world_items.configurar_dependencias(
		$Entities/Player,
		_inventory,
		$Entities,
		world_gen.entity_manager,
		_world_context,
		MissionManager
	)

	if world_gen.is_world_ready():
		_inicializar_jugador(world_gen)
	else:
		world_gen.mundo_generado.connect(
			_inicializar_jugador.bind(world_gen),
			CONNECT_ONE_SHOT
		)


func _exit_tree() -> void:
	if is_instance_valid(_supabase_client):
		_supabase_client.establecer_mundo_activo(false)


func _process(_delta: float) -> void:
	_seguir_jugador()


func _inicializar_jugador(world_gen: WorldGenerator) -> void:
	_player = $Entities/Player as Player

	if _player == null:
		push_error("Main: no se encontró Entities/Player.")
		return

	_player.set_spawn_from_world(world_gen)

	world_gen.registrar_jugador(_player)

	_player.configurar_dependencias(_inventory, _world_context, _ium_manager, world_gen.entity_manager, _supabase_client, GameState)

	_configurar_camara()
	_configurar_hud(_world_context, world_gen)
	_configurar_input_router()
	_configurar_interaccion(world_gen)
	_configurar_combate(_world_context, world_gen)
	_configurar_inventario()
	GameState.configurar_dependencias(_inventory, _player, _world_context, _world_atmosphere, MissionManager, WorldData)
	_configurar_dialogo()
	MissionManager.configurar_dependencias(world_gen.entity_manager, WorldData)
	_configurar_social()
	_inicializar_ium()
	_configurar_admin()
	_configurar_pantalla()
	_configurar_reino_torres()

	# Inicializar IUM con jugador (jugador_id puede venir de auth en el futuro)
	if _ium_manager != null:
		var jugador_id: String = ""
		jugador_id = _player.get_jugador_id()
		_ium_manager.inicializar(jugador_id)


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


func _configurar_hud(world_context: WorldContext, world_gen: WorldGenerator) -> void:
	if _hud == null:
		push_error("Main: no se encontró UI/HUD.")
		return

	_hud.configurar(_player, world_context, MissionManager, world_gen.entity_manager, _supabase_client, _inventory, WorldData, GameState)


func _configurar_interaccion(world_gen: WorldGenerator) -> void:
	if _interaction_system == null:
		push_error("Main: no se encontró Systems/InteractionSystem.")
		return

	if not _interaction_system.objetivo_cambiado.is_connected(_al_cambio_objetivo_interaccion):
		_interaction_system.objetivo_cambiado.connect(_al_cambio_objetivo_interaccion)

	_interaction_system.configurar(_player, _inventory, _world_items, _player.input_gate, world_gen.entity_manager)

func _al_cambio_objetivo_interaccion(objetivo: Node) -> void:
	if _hud == null:
		return

	if objetivo == null or not is_instance_valid(objetivo):
		_hud.ocultar_interaccion()
		return

	var texto: String = _interaction_system.obtener_texto_interaccion()
	_hud.mostrar_interaccion(texto)


func _configurar_combate(world_context: WorldContext, world_gen: WorldGenerator) -> void:
	if _combat_system == null:
		push_error("Main: no se encontró Systems/CombatSystem.")
		return

	_combat_system.configurar(_player, _inventory, world_context, _combat_projectiles, GameState)


func _configurar_input_router() -> void:
	if _input_router == null:
		push_error("Main: no se encontró GameplayInputRouter.")
		return
	_input_router.configurar_sistemas(_interaction_system, _combat_system)
	_input_router.configurar_bloqueos(_inventory, _admin_console, _dialogue_system, _hud)
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
			_world_generator.entity_manager,
			_admin_player_editor,
			_world_items
	)

func _configurar_reino_torres() -> void:
	if _reino_torres == null or not is_instance_valid(_reino_torres):
		push_error("Main: falta World/ReinoTorres.")
		return

	if _reino_torres.has_signal("salida_solicitada"):
		var callback := Callable(self, "_al_salir_reino_torres")
		if not _reino_torres.salida_solicitada.is_connected(callback):
			_reino_torres.salida_solicitada.connect(callback)

	if GameState.debe_iniciar_en_reino_torres():
		_player.global_position = Vector2(0, 120)
		print("Main: inicio canónico en Reino Torres.")
	else:
		print("Main: partida continúa fuera de Reino Torres.")


func _al_salir_reino_torres() -> void:
	if _player == null or not is_instance_valid(_player):
		return

	GameState.marcar_reino_torres_visitado()

	# Transición de zona dentro del mismo runtime: no se destruye HUD,
	# inventario, sistemas ni la escena canónica.
	_player.global_position = Vector2(560, 120)
	print("Main: Reino Torres → mundo abierto.")


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
