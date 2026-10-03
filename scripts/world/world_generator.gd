extends Node2D
class_name WorldGenerator


signal mundo_generado


@export var map_seed: int = 0
@export var tile_size: int = 32
@export var chunk_size_tiles: int = 32
@export var load_radius_chunks: int = 2
@export var unload_radius_chunks: int = 3
@export var generation_cells_per_frame: int = 256


var terrain: WorldTerrain
var streamer: WorldStreamer
var entity_spawner: WorldEntitySpawner
var atmosphere: WorldAtmosphere

var _world_ready: bool = false


func _ready() -> void:
	add_to_group("world_generator")

	_crear_sistemas()

	if WorldData.esta_cargado():
		_inicializar_mundo()
	else:
		WorldData.mundo_listo.connect(
			_inicializar_mundo,
			CONNECT_ONE_SHOT
		)


func _process(_delta: float) -> void:
	if not _world_ready:
		return

	if streamer != null:
		streamer.procesar()


func _crear_sistemas() -> void:
	terrain = get_node_or_null(
		"WorldTerrain"
	) as WorldTerrain

	if terrain == null:
		terrain = WorldTerrain.new()
		terrain.name = "WorldTerrain"
		add_child(terrain)

	streamer = get_node_or_null(
		"WorldStreamer"
	) as WorldStreamer

	if streamer == null:
		streamer = WorldStreamer.new()
		streamer.name = "WorldStreamer"
		add_child(streamer)

	entity_spawner = get_node_or_null(
		"WorldEntitySpawner"
	) as WorldEntitySpawner

	if entity_spawner == null:
		entity_spawner = WorldEntitySpawner.new()
		entity_spawner.name = "WorldEntitySpawner"
		add_child(entity_spawner)

	atmosphere = get_node_or_null("WorldAtmosphere") as WorldAtmosphere
	if atmosphere == null:
		atmosphere = WorldAtmosphere.new()
		atmosphere.name = "WorldAtmosphere"
		add_child(atmosphere)


func _inicializar_mundo() -> void:
	if _world_ready:
		return

	if map_seed == 0:
		map_seed = randi()

	terrain.configurar(
		map_seed,
		tile_size,
		chunk_size_tiles
	)

	terrain.cargar_datos_mundo()

	entity_spawner.configurar(
		terrain
	)

	streamer.configurar(
		self,
		terrain,
		entity_spawner,
		load_radius_chunks,
		unload_radius_chunks,
		generation_cells_per_frame
	)

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

	streamer.registrar_jugador(
		player
	)


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
	var atmosfera := get_node_or_null("WorldAtmosphere")
	if atmosfera != null and atmosfera.has_method(
		"obtener_estacion_id"
	):
		estacion_id = str(
			atmosfera.call("obtener_estacion_id")
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

	var jugador := (
		get_tree().get_first_node_in_group(
			"player"
		)
	)

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
