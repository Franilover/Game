extends Node
class_name WorldStreamer


var _world_generator: WorldGenerator
var _terrain: WorldTerrain
var _entity_spawner: WorldEntitySpawner

var _player: Node = null

var _load_radius: int = 1
var _unload_radius: int = 2
var _cells_per_frame: int = 512

var _player_chunk: Vector2i = Vector2i(
	999999,
	999999
)

var _queue: Array = []

var _initial_queue: Array = []
var _initializing: bool = false


func configurar(
	world_generator: WorldGenerator,
	terrain: WorldTerrain,
	entity_spawner: WorldEntitySpawner,
	load_radius: int,
	unload_radius: int,
	cells_per_frame: int
) -> void:
	_world_generator = world_generator
	_terrain = terrain
	_entity_spawner = entity_spawner

	_load_radius = load_radius
	_unload_radius = unload_radius
	_cells_per_frame = cells_per_frame


func registrar_jugador(
	player: Node
) -> void:
	_player = player

	_actualizar_streaming()


func iniciar_carga_inicial(
	centro: Vector2i,
	radio: int
) -> void:
	_initial_queue.clear()
	_initializing = true

	var nuevos: Array = []

	for dy in range(-radio, radio + 1):
		for dx in range(-radio, radio + 1):
			nuevos.append(
				centro + Vector2i(dx, dy)
			)

	nuevos.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			var da: int = (
				abs(a.x - centro.x)
				+ abs(a.y - centro.y)
			)

			var db: int = (
				abs(b.x - centro.x)
				+ abs(b.y - centro.y)
			)

			return da < db
	)

	_initial_queue.append_array(nuevos)


func procesar_carga_inicial() -> bool:
	if not _initializing:
		return true

	if _terrain.tiene_generacion_activa():
		var terminado: bool = (
			_terrain.procesar_generacion(
				_cells_per_frame * 2
			)
		)

		if terminado:
			var chunk_coord: Vector2i = (
				_terrain.ultimo_chunk_generado()
			)

			_entity_spawner.spawn_chunk(
				chunk_coord
			)

		return false

	if _initial_queue.is_empty():
		_initializing = false
		return true

	var chunk_coord: Vector2i = (
		_initial_queue.pop_front()
	)

	if _terrain.chunk_cargado(chunk_coord):
		return false

	_terrain.iniciar_generacion_chunk(
		chunk_coord
	)

	return false


func esta_cargando_inicio() -> bool:
	return _initializing


func procesar() -> void:
	if _player == null:
		return

	var nuevo_chunk: Vector2i = (
		_world_to_chunk(
			_player.global_position
		)
	)

	if nuevo_chunk != _player_chunk:
		_player_chunk = nuevo_chunk

		_actualizar_streaming()

	if _terrain.tiene_generacion_activa():
		var terminado: bool = (
			_terrain.procesar_generacion(
				_cells_per_frame
			)
		)

		if terminado:
			var chunk_coord: Vector2i = (
				_terrain.ultimo_chunk_generado()
			)

			_entity_spawner.spawn_chunk(
				chunk_coord
			)

		return

	_iniciar_siguiente_chunk()


func _actualizar_streaming() -> void:
	if _player == null:
		return

	var centro: Vector2i = (
		_world_to_chunk(
			_player.global_position
		)
	)

	_player_chunk = centro

	# Si el jugador cambió de chunk rápidamente, no sigamos cargando chunks
	# que ya quedaron fuera del radio de trabajo.
	var cola_filtrada: Array = []
	for queued_variant in _queue:
		if not queued_variant is Vector2i:
			continue
		var queued: Vector2i = queued_variant
		var distancia: int = maxi(
			abs(queued.x - centro.x),
			abs(queued.y - centro.y)
		)
		if distancia <= _load_radius:
			cola_filtrada.append(queued)
	_queue = cola_filtrada

	var nuevos: Array = []

	for dy in range(
		-_load_radius,
		_load_radius + 1
	):
		for dx in range(
			-_load_radius,
			_load_radius + 1
		):
			var chunk := Vector2i(
				centro.x + dx,
				centro.y + dy
			)

			if _terrain.chunk_cargado(
				chunk
			):
				continue

			if _terrain.chunk_en_generacion(
				chunk
			):
				continue

			if chunk in _queue:
				continue

			nuevos.append(
				chunk
			)

	nuevos.sort_custom(
		func(
			a: Vector2i,
			b: Vector2i
		) -> bool:
			var da: int = (
				abs(a.x - centro.x)
				+ abs(a.y - centro.y)
			)

			var db: int = (
				abs(b.x - centro.x)
				+ abs(b.y - centro.y)
			)

			return da < db
	)

	for i in range(nuevos.size()):
		_queue.append(
			nuevos[i]
		)

	_queue.sort_custom(
		func(
			a: Vector2i,
			b: Vector2i
		) -> bool:
			var da: int = (
				abs(a.x - centro.x)
				+ abs(a.y - centro.y)
			)

			var db: int = (
				abs(b.x - centro.x)
				+ abs(b.y - centro.y)
			)

			return da < db
	)

	_descargar_lejanos(
		centro
	)


func _iniciar_siguiente_chunk() -> void:
	if _queue.is_empty():
		return

	var chunk_coord: Vector2i = (
		_queue.pop_front()
	)

	if _terrain.chunk_cargado(
		chunk_coord
	):
		return

	_terrain.iniciar_generacion_chunk(
		chunk_coord
	)


func _descargar_lejanos(
	centro: Vector2i
) -> void:
	var para_descargar: Array = []

	var claves: Array = (
		_terrain.chunks_cargados()
	)

	for i in range(claves.size()):
		var chunk_variant: Variant = (
			claves[i]
		)

		if not chunk_variant is Vector2i:
			continue

		var chunk_coord: Vector2i = (
			chunk_variant
		)

		var distancia: int = maxi(
			abs(chunk_coord.x - centro.x),
			abs(chunk_coord.y - centro.y)
		)

		if distancia > _unload_radius:
			para_descargar.append(
				chunk_coord
			)

	for i in range(para_descargar.size()):
		var chunk_coord: Vector2i = (
			para_descargar[i]
		)

		_entity_spawner.despawn_chunk(
			chunk_coord
		)

		_terrain.descargar_chunk(
			chunk_coord
		)


func _world_to_chunk(
	position: Vector2
) -> Vector2i:
	var tile := Vector2i(
		floori(
			position.x
			/ _terrain.tile_size
		),
		floori(
			position.y
			/ _terrain.tile_size
		)
	)

	return Vector2i(
		floori(
			float(tile.x)
			/ _terrain.chunk_size_tiles
		),
		floori(
			float(tile.y)
			/ _terrain.chunk_size_tiles
		)
	)
