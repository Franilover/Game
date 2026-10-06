extends Node
class_name WorldStreamer


var _terrain: WorldTerrain
var _entity_spawner: WorldEntitySpawner

var _player: Node = null
var _render_manager: Node = null

var _load_radius: int = 1
var _unload_radius: int = 1
# El terreno visible se limita al chunk actual y, como máximo, a los
# vecinos necesarios para anticipar el movimiento. No mantener un 3x3
# completo: en TileMapDual cada celda genera trabajo de render.
# Test de rendimiento: terreno y entidades usan radios independientes.
var _entity_active_radius: int = 0
var _cells_per_frame: int = 64
var _prefetch_margin_tiles: int = 8

var _player_chunk: Vector2i = Vector2i(
	999999,
	999999
)

var _queue: Array = []


func configurar(
	terrain: WorldTerrain,
	entity_spawner: WorldEntitySpawner,
	load_radius: int,
	unload_radius: int,
	cells_per_frame: int
) -> void:
	_terrain = terrain
	_entity_spawner = entity_spawner

	_load_radius = load_radius
	_unload_radius = unload_radius
	_cells_per_frame = cells_per_frame


func configurar_render_manager(render_manager: Node) -> void:
	_render_manager = render_manager


func registrar_jugador(
	player: Node
) -> void:
	_player = player

	_actualizar_streaming()


func procesar() -> void:
	if _player == null:
		return

	# Las descargas de terreno tienen prioridad y se reparten entre frames.
	# No mezclar limpieza pesada con la generación del siguiente chunk.
	if _terrain.tiene_descarga_activa():
		_terrain.procesar_descargas(mini(_cells_per_frame, 128))
		return

	var nuevo_chunk: Vector2i = (
		_world_to_chunk(
			_player.global_position
		)
	)

	if nuevo_chunk != _player_chunk:
		_player_chunk = nuevo_chunk

	_actualizar_streaming()

	# El terreno tiene prioridad: TileMapDual y su preparación son el trabajo
	# visual más caro. Las entidades sólo entran cuando queda presupuesto real.
	if _terrain.tiene_generacion_activa():
		var presupuesto_celdas := _presupuesto_generacion()
		if presupuesto_celdas <= 0:
			return
		var terminado: bool = (
			_terrain.procesar_generacion(
				presupuesto_celdas
			)
		)

		if terminado:
			_procesar_entidades_si_hay_presupuesto()
			var chunk_coord: Vector2i = (
				_terrain.ultimo_chunk_generado()
			)

			# El jugador puede alejarse mientras se genera un chunk.
			# No instanciar criaturas ni conservar terreno que ya quedó
			# fuera del radio de streaming durante esa generación.
			var distancia_chunk := maxi(
				abs(chunk_coord.x - _player_chunk.x),
				abs(chunk_coord.y - _player_chunk.y)
			)
			if distancia_chunk > _unload_radius:
				_terrain.descargar_chunk(chunk_coord)
			else:
				if _distancia_chunk(chunk_coord, _player_chunk) <= _entity_active_radius:
					_entity_spawner.spawn_chunk(chunk_coord)

		return

	_iniciar_siguiente_chunk()
	_procesar_entidades_si_hay_presupuesto()


func _procesar_entidades_si_hay_presupuesto() -> void:
	if _entity_spawner == null:
		return
	var limite := _presupuesto_entidades()
	if limite <= 0:
		return
	_entity_spawner.procesar_spawn_queue(limite)

func _presupuesto_entidades() -> int:
	if _render_manager == null:
		return 1
	var disponible: float = float(_render_manager.call("presupuesto_disponible_ms"))
	if disponible < 1.5:
		return 0
	return 1


func _presupuesto_generacion() -> int:
	var base: int = maxi(_cells_per_frame, 1)
	if _render_manager == null:
		return base
	var disponible: float = float(_render_manager.call("presupuesto_disponible_ms"))
	if disponible < 0.75:
		return 0
	if disponible < 1.5:
		return mini(base, 8)
	if disponible < 2.5:
		return mini(base, 16)
	if disponible < 4.0:
		return mini(base, 32)
	return base


func _actualizar_streaming() -> void:
	if _player == null:
		return

	var centro: Vector2i = (
		_world_to_chunk(
			_player.global_position
		)
	)

	_player_chunk = centro

	# No gastar más frames en un chunk que quedó fuera del radio de carga.
	_terrain.cancelar_generacion_si_distante(
		centro,
		_load_radius
	)

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

	# Prioridad absoluta: el chunk actual. El jugador no debe esperar a que
	# termine un vecino que quedó primero en la cola.
	_agregar_chunk_a_cola(centro, nuevos)

	# Sólo anticipamos los vecinos que realmente están cerca de entrar en
	# pantalla. Con esto evitamos cargar 9 chunks aunque el radio lógico sea 1.
	var tile_local_x: int = posmod(
		floori(_player.global_position.x / _terrain.tile_size),
		_terrain.chunk_size_tiles
	)
	var tile_local_y: int = posmod(
		floori(_player.global_position.y / _terrain.tile_size),
		_terrain.chunk_size_tiles
	)

	if tile_local_x < _prefetch_margin_tiles:
		_agregar_chunk_a_cola(
			Vector2i(centro.x - 1, centro.y),
			nuevos
		)
	elif tile_local_x >= _terrain.chunk_size_tiles - _prefetch_margin_tiles:
		_agregar_chunk_a_cola(
			Vector2i(centro.x + 1, centro.y),
			nuevos
		)

	if tile_local_y < _prefetch_margin_tiles:
		_agregar_chunk_a_cola(
			Vector2i(centro.x, centro.y - 1),
			nuevos
		)
	elif tile_local_y >= _terrain.chunk_size_tiles - _prefetch_margin_tiles:
		_agregar_chunk_a_cola(
			Vector2i(centro.x, centro.y + 1),
			nuevos
		)

	for chunk in nuevos:
		_queue.append(chunk)

	# Mantener primero el chunk más cercano al jugador.
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

	_actualizar_entidades_activas(centro)


func _agregar_chunk_a_cola(
	chunk: Vector2i,
	nuevos: Array
) -> void:
	if _terrain.chunk_cargado(chunk):
		return
	if _terrain.chunk_en_generacion(chunk):
		return
	if chunk in _queue:
		return
	if chunk in nuevos:
		return
	nuevos.append(chunk)


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


func _actualizar_entidades_activas(
	centro: Vector2i
) -> void:
	var claves: Array = _terrain.chunks_cargados()

	for chunk_variant in claves:
		if not chunk_variant is Vector2i:
			continue

		var chunk_coord: Vector2i = chunk_variant
		var distancia := _distancia_chunk(chunk_coord, centro)

		if distancia <= _entity_active_radius:
			_entity_spawner.spawn_chunk(chunk_coord)
		else:
			_entity_spawner.cancelar_spawn_chunk(chunk_coord)
			_entity_spawner.despawn_chunk(chunk_coord)


func _distancia_chunk(
	a: Vector2i,
	b: Vector2i
) -> int:
	return maxi(
		abs(a.x - b.x),
		abs(a.y - b.y)
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
