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

@onready var _terrain_node: WorldTerrain = $WorldTerrain
@onready var _streamer_node: WorldStreamer = $WorldStreamer
@onready var _entity_spawner_node: WorldEntitySpawner = $WorldEntitySpawner
@onready var _entity_manager_node: WorldEntityManager = $WorldEntityManager
@onready var _entity_factory_node: WorldEntityFactory = $WorldEntityFactory
@onready var _spawn_rules_node: WorldSpawnRules = $WorldSpawnRules
@onready var _atmosphere_node: WorldAtmosphere = $WorldAtmosphere

var _world_ready: bool = false
var _entities_root: Node = null
var _player_ref: Node2D = null


func _ready() -> void:
	add_to_group("world_generator")

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
		self,
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
	if player is Node2D:
		_player_ref = player as Node2D
	if not _world_ready:
		return
	streamer.registrar_jugador(player)


func is_world_ready() -> bool:
	return _world_ready


func get_spawn_position() -> Vector2:
	if terrain == null:
		return Vector2.ZERO

	return terrain.get_spawn_position()


func is_walkable(
	tile: Vector2i
) -> bool:
	if terrain == null:
		return false

	return terrain.is_walkable(tile)


func get_bioma_at(
	tile: Vector2i
) -> Dictionary:
	if terrain == null:
		return {}

	return terrain.get_bioma_at(tile)


func get_reinos_at(tile: Vector2i) -> Array[Dictionary]:
	var bioma := get_bioma_at(tile)
	if bioma.is_empty():
		return []

	var bioma_id := str(bioma.get("id", ""))
	if bioma_id.is_empty():
		return []

	return WorldData.obtener_reinos_game_de_bioma(bioma_id)


func get_reinos_at_position(posicion_global: Vector2) -> Array[Dictionary]:
	return get_reinos_at(get_tile_at(posicion_global))

func buscar_posicion_reino(nombre: String) -> Vector2:
	if terrain == null or not _world_ready:
		return Vector2.INF

	var buscado := nombre.strip_edges().to_lower()
	if buscado.is_empty():
		return Vector2.INF

	var jugador := _player_ref
	if jugador == null:
		return Vector2.INF

	var centro := get_tile_at(jugador.global_position)
	var radio := 64

	for distancia in range(radio + 1):
		for dy in range(-distancia, distancia + 1):
			for dx in range(-distancia, distancia + 1):
				if maxi(abs(dx), abs(dy)) != distancia:
					continue

				var tile := centro + Vector2i(dx, dy)
				if not terrain.is_walkable(tile):
					continue

				for reino in get_reinos_at(tile):
					var clave := str(reino.get("clave", "")).to_lower()
					var nombre_reino := str(reino.get("nombre", "")).to_lower()
					if clave != buscado and nombre_reino != buscado:
						continue

					return Vector2(
						(float(tile.x) + 0.5) * tile_size,
						(float(tile.y) + 0.5) * tile_size
					)

	return Vector2.INF


func get_ecosistema_at(
	tile: Vector2i
) -> Dictionary:
	if terrain == null:
		return {}

	return terrain.get_ecosistema_at(tile)


func get_habitats_at(
	tile: Vector2i
) -> Array:
	if terrain == null:
		return []

	return terrain.get_habitats_at(tile)


func get_criaturas_at(
	tile: Vector2i
) -> Array:
	if terrain == null:
		return []

	return terrain.get_criaturas_at(tile)


func cambiar_zona_at(
	tile: Vector2i,
	nueva_zona: int
) -> bool:
	if terrain == null:
		return false
	return terrain.cambiar_zona_at(tile, nueva_zona)


func get_zona_at(
	tile: Vector2i
) -> int:
	if terrain == null:
		return -1

	return terrain.get_zona_at(tile)


func get_tile_at(
	posicion_global: Vector2
) -> Vector2i:
	if terrain == null:
		return Vector2i.ZERO

	var posicion_local: Vector2 = (
		terrain.to_local(posicion_global)
	)

	var tamano_tile: int = maxi(
		tile_size,
		1
	)

	return Vector2i(
		floori(
			posicion_local.x / float(tamano_tile)
		),
		floori(
			posicion_local.y / float(tamano_tile)
		)
	)


func get_tile_size() -> int:
	return maxi(tile_size, 1)


func get_contexto_at(
	posicion_global: Vector2
) -> Dictionary:
	if terrain == null:
		return {}

	if not _world_ready:
		return {}

	var posicion_local: Vector2 = (
		terrain.to_local(
			posicion_global
		)
	)

	var tamano_tile: int = maxi(
		tile_size,
		1
	)

	var tile := Vector2i(
		floori(
			posicion_local.x
			/ float(tamano_tile)
		),
		floori(
			posicion_local.y
			/ float(tamano_tile)
		)
	)

	var bioma: Dictionary = (
		terrain.get_bioma_at(tile)
	)

	var ecosistema: Dictionary = (
		terrain.get_ecosistema_at(tile)
	)

	var habitats: Array = (
		terrain.get_habitats_at(tile)
	)

	var contexto := {
		"bioma": _extraer_nombre(bioma),
		"ecosistema": _extraer_nombre(
			ecosistema
		),
		"habitat": _extraer_nombre_habitats(
			habitats
		),
		"clima": str(ecosistema.get(
			"clima",
			""
		)),
		"factores_abioticos": get_factores_ambientales_at(
			posicion_global
		)
	}

	return contexto


func get_factores_ambientales_at(
	posicion_global: Vector2
) -> Dictionary:
	if terrain == null or not _world_ready:
		return {}

	var posicion_local: Vector2 = terrain.to_local(
		posicion_global
	)

	var tamano_tile: int = maxi(tile_size, 1)
	var tile := Vector2i(
		floori(posicion_local.x / float(tamano_tile)),
		floori(posicion_local.y / float(tamano_tile))
	)

	var estacion_id := ""
	if atmosphere != null and atmosphere.has_method(
		"obtener_estacion_id"
	):
		estacion_id = str(
			atmosphere.call("obtener_estacion_id")
		)

	var habitats := terrain.get_habitats_at(tile)
	for habitat_variant in habitats:
		if not habitat_variant is Dictionary:
			continue

		var habitat := habitat_variant as Dictionary
		var habitat_id := str(habitat.get("id", ""))
		if habitat_id.is_empty():
			continue

		if not estacion_id.is_empty():
			var estacional := (
				WorldData.obtener_ambiente_estacional_habitat(
					estacion_id,
					habitat_id
				)
			)
			if not estacional.is_empty():
				return estacional

		var base_habitat := (
			WorldData.obtener_factores_ambientales_habitat(
				habitat_id
			)
		)
		if not base_habitat.is_empty():
			return base_habitat

	var ecosistema := terrain.get_ecosistema_at(tile)
	var ecosistema_id := str(ecosistema.get("id", ""))
	if ecosistema_id.is_empty():
		return {}

	if not estacion_id.is_empty():
		var estacional_ecosistema := (
			WorldData.obtener_ambiente_estacional_ecosistema(
				estacion_id,
				ecosistema_id
			)
		)
		if not estacional_ecosistema.is_empty():
			return estacional_ecosistema

	return WorldData.obtener_factores_ambientales_ecosistema(
		ecosistema_id
	)


func summon_criatura(
	nombre: String
) -> Dictionary:
	if not _world_ready:
		return {
			"ok": false,
			"mensaje": (
				"El mundo todavía no está listo."
			)
		}

	if entity_spawner == null:
		return {
			"ok": false,
			"mensaje": (
				"No existe WorldEntitySpawner."
			)
		}

	var jugador := _player_ref

	if jugador == null:
		return {
			"ok": false,
			"mensaje": (
				"No se encontró el jugador."
			)
		}

	if not jugador is Node2D:
		return {
			"ok": false,
			"mensaje": (
				"El jugador no es Node2D."
			)
		}

	var jugador_2d := jugador as Node2D

	var posicion: Vector2 = (
		jugador_2d.global_position
		+ Vector2(32.0, 0.0)
	)

	return entity_spawner.summon_criatura(
		nombre,
		posicion
	)


func _extraer_nombre(
	datos: Dictionary
) -> String:
	if datos.is_empty():
		return "—"

	var nombre := str(
		datos.get(
			"nombre",
			""
		)
	)

	if nombre.is_empty():
		return "—"

	return nombre


func _extraer_nombre_habitats(
	habitats: Array
) -> String:
	if habitats.is_empty():
		return "—"

	var nombres: Array[String] = []

	for habitat_variant in habitats:
		if not habitat_variant is Dictionary:
			continue

		var habitat: Dictionary = (
			habitat_variant
		)

		var nombre := str(
			habitat.get(
				"nombre",
				""
			)
		)

		if nombre.is_empty():
			var tipo_variant: Variant = (
				habitat.get(
					"tipo_habitat",
					{}
				)
			)

			if tipo_variant is Dictionary:
				var tipo: Dictionary = (
					tipo_variant
				)

				nombre = str(
					tipo.get(
						"nombre",
						""
					)
				)

				if nombre.is_empty():
					nombre = str(
						tipo.get(
							"clave",
							""
						)
					)

					if not nombre.is_empty():
						nombre = nombre.capitalize()

		if nombre.is_empty():
			continue

		if nombre in nombres:
			continue

		nombres.append(
			nombre
		)

	if nombres.is_empty():
		return "—"

	return " · ".join(
		nombres
	)
