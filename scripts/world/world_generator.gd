extends Node2D
class_name WorldGenerator


signal mundo_generado


@export var map_seed: int = 0
@export var tile_size: int = 32
@export var chunk_size_tiles: int = 32
@export var load_radius_chunks: int = 1
@export var unload_radius_chunks: int = 2
@export var generation_cells_per_frame: int = 64


var terrain: WorldTerrain
var streamer: WorldStreamer
var entity_spawner: WorldEntitySpawner
var entity_manager: WorldEntityManager
var entity_factory: WorldEntityFactory
var spawn_rules: WorldSpawnRules
var atmosphere: WorldAtmosphere
var context: WorldContext

@onready var _terrain_node: WorldTerrain = $WorldTerrain
@onready var _streamer_node: WorldStreamer = $WorldStreamer
@onready var _entity_spawner_node: WorldEntitySpawner = $WorldEntitySpawner
@onready var _entity_manager_node: WorldEntityManager = $WorldEntityManager
@onready var _entity_factory_node: WorldEntityFactory = $WorldEntityFactory
@onready var _spawn_rules_node: WorldSpawnRules = $WorldSpawnRules
@onready var _atmosphere_node: WorldAtmosphere = $WorldAtmosphere
@onready var _context_node: WorldContext = $WorldContext

var _world_ready: bool = false
var _entities_root: Node = null


func _ready() -> void:
	_crear_sistemas()

	if WorldData.esta_cargado():
		# Main inyecta el root de entidades durante su _ready().
		# Diferimos un ciclo para que la Composition Root complete
		# las dependencias antes de iniciar el mundo.
		call_deferred("_inicializar_mundo_si_corresponde")
	else:
		WorldData.mundo_listo.connect(
			_inicializar_mundo,
			CONNECT_ONE_SHOT
		)


func _inicializar_mundo_si_corresponde() -> void:
	if _world_ready:
		return
	_inicializar_mundo()

func configurar_entidades(root: Node) -> void:
	_entities_root = root
	if entity_manager == null or entity_spawner == null or entity_factory == null or spawn_rules == null:
		push_error("WorldGenerator: dependencias de entidades incompletas.")
		return
	entity_manager.configurar(_entities_root)
	spawn_rules.configurar(terrain)
	entity_spawner.configurar(terrain, entity_manager, entity_factory, spawn_rules)

func _process(_delta: float) -> void:
	if not _world_ready:
		return

	if streamer != null:
		streamer.procesar()


func _crear_sistemas() -> void:
	terrain = _terrain_node
	streamer = _streamer_node
	entity_spawner = _entity_spawner_node
	entity_manager = _entity_manager_node
	entity_factory = _entity_factory_node
	spawn_rules = _spawn_rules_node
	atmosphere = _atmosphere_node
	context = _context_node
	context.configurar(terrain, atmosphere)


func _inicializar_mundo() -> void:
	if _world_ready:
		return

	if GameState.tiene_semilla_mundo():
		map_seed = GameState.obtener_semilla_mundo()
	elif map_seed == 0:
		map_seed = randi()

		if not GameState.active_save_id.is_empty():
			GameState.establecer_semilla_mundo(map_seed)

	terrain.configurar(
		map_seed,
		tile_size,
		chunk_size_tiles
	)

	terrain.cargar_datos_mundo()

	if _entities_root == null or not is_instance_valid(_entities_root):
		push_error("WorldGenerator: no se configuró Entity root antes de iniciar el mundo.")
		return

	entity_manager.configurar(_entities_root)
	entity_spawner.configurar(
		terrain,
		entity_manager,
		entity_factory,
		spawn_rules
	)

	streamer.configurar(
		terrain,
		entity_spawner,
		load_radius_chunks,
		unload_radius_chunks,
		generation_cells_per_frame
	)

	# TileMapDual necesita completar su _ready() para inicializar el
	# compositor antes de que el primer chunk pinte sus celdas.
	# Sin este frame de espera, el chunk inicial puede quedar vacío,
	# mientras que los siguientes sí se generan correctamente.
	await get_tree().process_frame

	terrain.generar_chunk_completo(
		Vector2i.ZERO
	)

	_world_ready = true

	print(
		"WorldGenerator: mundo inicial listo."
	)

	mundo_generado.emit()


func registrar_jugador(
	player: Node
) -> void:
	if not _world_ready:
		return
	streamer.registrar_jugador(player)


func is_world_ready() -> bool:
	return _world_ready

