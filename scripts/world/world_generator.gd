extends Node2D
class_name WorldGenerator

const RENDER_MANAGER_SCRIPT = preload("res://scripts/world/render/garlia_render_manager.gd")


signal mundo_generado
signal mundo_inicializado


@export var map_seed: int = 0
@export var tile_size: int = 32
@export var chunk_size_tiles: int = 32
@export var load_radius_chunks: int = 1
@export var unload_radius_chunks: int = 1
@export var generation_cells_per_frame: int = 128


var terrain: WorldTerrain
var streamer: WorldStreamer
var entity_spawner: WorldEntitySpawner
var entity_manager: WorldEntityManager
var entity_factory: WorldEntityFactory
var spawn_rules: WorldSpawnRules
var atmosphere: WorldAtmosphere
var context: WorldContext
var render_manager: Node

@onready var _terrain_node: WorldTerrain = $WorldTerrain
@onready var _streamer_node: WorldStreamer = $WorldStreamer
@onready var _entity_spawner_node: WorldEntitySpawner = $WorldEntitySpawner
@onready var _entity_manager_node: WorldEntityManager = $WorldEntityManager
@onready var _entity_factory_node: WorldEntityFactory = $WorldEntityFactory
@onready var _spawn_rules_node: WorldSpawnRules = $WorldSpawnRules
@onready var _atmosphere_node: WorldAtmosphere = $WorldAtmosphere
@onready var _context_node: WorldContext = get_node_or_null("WorldContext") as WorldContext

var _world_ready: bool = false
var _entities_root: Node = null
var _world_data: WorldDataService = null
var _game_state: GameStateService = null
var _dependencias_configuradas: bool = false
var _mundo_inicial_listo_emitido: bool = false


func _ready() -> void:
	_crear_sistemas()
	_registrar_debug()


func configurar_dependencias(
	world_data: WorldDataService,
	game_state: GameStateService
) -> void:
	_world_data = world_data
	_game_state = game_state
	if context != null:
		context.configurar(terrain, atmosphere, _world_data)
	if atmosphere != null:
		atmosphere.configurar_dependencias(_world_data)
	_dependencias_configuradas = _world_data != null and _game_state != null
	if not _dependencias_configuradas:
		push_error("WorldGenerator: WorldDataService y GameState son obligatorios.")
		return
	if _world_data.esta_cargado():
		call_deferred("_inicializar_mundo_si_corresponde")
	elif not _world_data.mundo_listo.is_connected(_inicializar_mundo):
		_world_data.mundo_listo.connect(_inicializar_mundo, CONNECT_ONE_SHOT)


func _inicializar_mundo_si_corresponde() -> void:
	if _world_ready or not _dependencias_configuradas:
		return
	_inicializar_mundo()

func configurar_contexto_compartido(world_context: WorldContext) -> void:
	if world_context == null:
		return
	context = world_context
	context.configurar(terrain, atmosphere, _world_data)


func configurar_entidades(
	root: Node,
	jugador: Node = null,
	inventario: GarliaInventory = null,
	combat_system: CombatSystem = null,
	dialogue_system: DialogueSystem = null,
	mission_manager: MissionManagerService = null,
	world_context: WorldContext = null,
	world_items: GarliaWorldItems = null,
	relaciones_ecologicas: Array = []
) -> void:
	_entities_root = root
	if entity_manager == null or entity_spawner == null or entity_factory == null or spawn_rules == null:
		push_error("WorldGenerator: dependencias de entidades incompletas.")
		return
	entity_manager.configurar(_entities_root, entity_factory)
	spawn_rules.configurar(terrain)
	entity_factory.configurar_dependencias(
		jugador,
		entity_manager,
		inventario,
		combat_system,
		dialogue_system,
		mission_manager,
		_entities_root,
		world_context,
		world_items,
		_world_data,
		relaciones_ecologicas,
		atmosphere
	)
	entity_spawner.configurar(terrain, entity_manager, entity_factory, spawn_rules, _world_data)

func _process(_delta: float) -> void:
	if render_manager != null:
		render_manager.call("iniciar_frame")

	if not _world_ready:
		if render_manager != null:
			render_manager.call("finalizar_frame")
		return

	# Una vez que el jugador está registrado, WorldStreamer es el único
	# orquestador del pipeline de terreno. Esto permite que pueda evaluar
	# prioridades y pausar una tarea FLUSH antes de consumir más celdas.
	# Antes WorldGenerator procesaba el terreno directamente y el streamer
	# sólo recibía turno cuando la tarea terminaba, haciendo imposible la
	# preempción.
	if streamer != null and streamer.tiene_jugador():
		streamer.procesar()
	elif terrain != null and terrain.tiene_generacion_activa():
		# Fallback para el breve intervalo anterior al registro del jugador.
		var presupuesto_inicial: int = generation_cells_per_frame
		if render_manager != null:
			var disponible: float = float(render_manager.call("presupuesto_disponible_ms"))
			if disponible < 4.0:
				presupuesto_inicial = mini(presupuesto_inicial, 32)
			if disponible < 2.5:
				presupuesto_inicial = mini(presupuesto_inicial, 16)
			if disponible < 1.5:
				presupuesto_inicial = 8
		terrain.procesar_generacion(maxi(presupuesto_inicial, 1))
	else:
		if streamer != null:
			streamer.procesar()

	if render_manager != null:
		render_manager.call("finalizar_frame")


func _crear_sistemas() -> void:
	render_manager = get_node_or_null("GarliaRenderManager")
	if render_manager == null:
		render_manager = RENDER_MANAGER_SCRIPT.new()
		render_manager.name = "GarliaRenderManager"
	add_child(render_manager)

	terrain = _terrain_node
	streamer = _streamer_node
	entity_spawner = _entity_spawner_node
	entity_manager = _entity_manager_node
	entity_factory = _entity_factory_node
	spawn_rules = _spawn_rules_node
	atmosphere = _atmosphere_node
	context = _context_node


func _inicializar_mundo() -> void:
	if _world_ready:
		return

	if _game_state.tiene_semilla_mundo():
		map_seed = _game_state.obtener_semilla_mundo()
	elif map_seed == 0:
		map_seed = randi()

		if not _game_state.active_save_id.is_empty():
			_game_state.establecer_semilla_mundo(map_seed)

	terrain.configurar(
		map_seed,
		tile_size,
		chunk_size_tiles,
		_world_data
	)

	terrain.configurar_render_manager(render_manager)

	terrain.cargar_datos_mundo()

	if _entities_root == null or not is_instance_valid(_entities_root):
		push_error("WorldGenerator: no se configuró Entity root antes de iniciar el mundo.")
		return

	entity_manager.configurar(_entities_root)
	entity_spawner.configurar(
		terrain,
		entity_manager,
		entity_factory,
		spawn_rules,
		_world_data
	)
	entity_spawner.configurar_render_manager(render_manager)

	streamer.configurar(
		terrain,
		entity_spawner,
		load_radius_chunks,
		unload_radius_chunks,
		generation_cells_per_frame
	)

	streamer.configurar_render_manager(render_manager)

	# TileMapDual necesita completar su _ready() para inicializar el
	# compositor antes de que el primer chunk pinte sus celdas.
	# Sin este frame de espera, el chunk inicial puede quedar vacío,
	# mientras que los siguientes sí se generan correctamente.
	await get_tree().process_frame

	# El chunk inicial también entra al pipeline incremental. No usar
	# generar_chunk_completo() aquí: esa función es síncrona y puede mantener
	# el mismo frame ocupado mientras el presupuesto de render ya está agotado.
	# El WorldStreamer continuará la generación en frames sucesivos.
	terrain.iniciar_generacion_chunk(Vector2i.ZERO)

	_world_ready = true
	_mundo_inicial_listo_emitido = false

	# Señal de estructura lista: Main puede registrar al jugador y activar el
	# streamer sin esperar a que el primer chunk termine su flush visual.
	mundo_inicializado.emit()

	print(
		"WorldGenerator: mundo inicial iniciado; generación incremental activa."
	)


func registrar_jugador(
	player: Node
) -> void:
	if not _world_ready:
		return
	streamer.registrar_jugador(player)


func get_spawn_position() -> Vector2:
	if terrain == null:
		return Vector2.ZERO

	# El spawn inicial pertenece al chunk origen, que es el primer chunk generado.
	# Buscamos una celda caminable usando las reglas canónicas de spawn.
	if spawn_rules != null and _world_data != null:
		var bioma_ids: Array = []
		for bioma_variant in _world_data.obtener_biomas():
			if bioma_variant is Dictionary:
				var bioma_id := str((bioma_variant as Dictionary).get("id", ""))
				if not bioma_id.is_empty():
					bioma_ids.append(bioma_id)

		var rng := RandomNumberGenerator.new()
		rng.seed = map_seed if map_seed != 0 else 1
		var tile := spawn_rules.buscar_tile_para_personaje(Vector2i.ZERO, bioma_ids, rng)
		if tile.x != 2147483647:
			return Vector2(
				tile.x * tile_size + tile_size * 0.5,
				tile.y * tile_size + tile_size * 0.5
			)

	# Fallback seguro: centro del chunk inicial.
	var centro := float(chunk_size_tiles * tile_size) * 0.5
	return Vector2(centro, centro)


func is_world_ready() -> bool:
	return _world_ready



func actualizar_relaciones_ecologicas(relaciones_ecologicas: Array) -> void:
	if entity_factory == null:
		return
	entity_factory.configurar_relaciones_ecologicas(relaciones_ecologicas)

func _registrar_debug() -> void:
	var debug := get_node_or_null("/root/GarliaDebug")
	if debug == null or not debug.has_method("registrar_proveedor"):
		return
	debug.registrar_proveedor("world_generator", "WorldGenerator", self, "Orquestación de generación, streaming y entidades.")

func obtener_diagnostico() -> Dictionary:
	var etapa := "IDLE"
	var cursor := 0
	var total := chunk_size_tiles * chunk_size_tiles
	if terrain != null and terrain.tiene_generacion_activa():
		var task: Dictionary = terrain.obtener_estado_generacion()
		etapa = str(task.get("etapa", "GENERANDO"))
		cursor = int(task.get("cursor", 0))
		if int(task.get("total", 0)) > 0:
			total = int(task.get("total", total))
	return {
		"ready": _world_ready,
		"dependencias": _dependencias_configuradas,
		"seed": map_seed,
		"chunk_generando": terrain.obtener_chunk_en_generacion() if terrain != null and terrain.tiene_generacion_activa() else null,
		"chunk_generado": terrain.ultimo_chunk_generado() if terrain != null else Vector2i.ZERO,
		"generacion_activa": terrain.tiene_generacion_activa() if terrain != null else false,
		"etapa": etapa,
		"progreso": "%d/%d" % [cursor, total],
		"jugador_registrado": streamer != null and streamer.tiene_jugador() if streamer != null else false
	}
