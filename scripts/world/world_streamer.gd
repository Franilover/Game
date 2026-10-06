extends Node
class_name WorldStreamer


var _terrain: WorldTerrain
var _entity_spawner: WorldEntitySpawner

var _player: Node = null
var _render_manager: Node = null

var _load_radius: int = 2
var _unload_radius: int = 2
# El terreno visible se limita al chunk actual y, como máximo, a los
# vecinos necesarios para anticipar el movimiento. No mantener un 3x3
# completo: en TileMapDual cada celda genera trabajo de render.
# Test de rendimiento: terreno y entidades usan radios independientes.
var _entity_active_radius: int = 0
var _cells_per_frame: int = 128
var _prefetch_margin_tiles: int = 28
var _last_player_position: Vector2 = Vector2.ZERO
var _player_direction: Vector2 = Vector2.ZERO
var _prefetch_chunk: Vector2i = Vector2i(999999, 999999)

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
	_registrar_debug()


func registrar_jugador(
	player: Node
) -> void:
	_player = player
	_last_player_position = _player.global_position
	_player_direction = Vector2.ZERO

	_actualizar_streaming()


func procesar() -> void:
	if _player == null:
		return

	# Las descargas de terreno tienen prioridad y se reparten entre frames.
	# No mezclar limpieza pesada con la generación del siguiente chunk.
	if _terrain.tiene_descarga_activa():
		var presupuesto_descarga := _presupuesto_descarga()
		if presupuesto_descarga <= 0:
			return
		var descarga_inicio_usec := Time.get_ticks_usec()
		var descarga_terminada := _terrain.procesar_descargas(presupuesto_descarga)
		if _render_manager != null:
			_render_manager.call(
				"registrar_trabajo",
				"terrain_clear",
				float(Time.get_ticks_usec() - descarga_inicio_usec) / 1000.0,
				maxi(presupuesto_descarga, 1)
			)
		if not descarga_terminada:
			return

	var nuevo_chunk: Vector2i = (
		_world_to_chunk(
			_player.global_position
		)
	)

	_actualizar_direccion_jugador()

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

func _presupuesto_descarga() -> int:
	var base := mini(_cells_per_frame, 128)
	if _render_manager == null:
		return maxi(base, 1)
	var presupuesto := int(_render_manager.call(
		"presupuesto_unidades_adaptativo",
		"terrain_clear",
		base,
		8,
		128,
		0.60
	))
	return presupuesto

func _presupuesto_entidades() -> int:
	if _render_manager == null:
		return 1
	var disponible: float = float(_render_manager.call("presupuesto_disponible_ms"))
	if disponible < 1.5:
		return 0
	return 1


func _presupuesto_generacion() -> int:
	var base: int = maxi(_cells_per_frame, 1)
	if _prefetch_chunk.x != 999999 and _terrain != null and _terrain.chunk_en_generacion(_prefetch_chunk):
		# La generación predictiva se reparte más fina para evitar el tirón.
		# Arranca lejos del borde y aumenta sólo cuando el jugador se acerca.
		var local_x: int = floori(fposmod(_player.global_position.x, float(_terrain.chunk_size_tiles * _terrain.tile_size)) / _terrain.tile_size)
		var local_y: int = floori(fposmod(_player.global_position.y, float(_terrain.chunk_size_tiles * _terrain.tile_size)) / _terrain.tile_size)
		var distancia_borde: int = mini(local_x, _terrain.chunk_size_tiles - 1 - local_x)
		distancia_borde = mini(distancia_borde, mini(local_y, _terrain.chunk_size_tiles - 1 - local_y)) if _player_direction.y != 0.0 else distancia_borde
		if distancia_borde > 10:
			base = mini(base, 24)
		else:
			base = mini(base, 48)
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

	var centro: Vector2i = _world_to_chunk(_player.global_position)
	_player_chunk = centro

	_terrain.cancelar_generacion_si_distante(centro, _load_radius)

	# Mantener únicamente trabajo que todavía está dentro del radio.
	var cola_filtrada: Array = []
	for queued_variant in _queue:
		if not queued_variant is Vector2i:
			continue
		var queued: Vector2i = queued_variant
		if _distancia_chunk(queued, centro) <= _load_radius:
			cola_filtrada.append(queued)
	_queue = cola_filtrada

	# El radio 2 permite preparar terreno por delante con más margen.
	# La prioridad sigue siendo direccional para no generar todo el anillo a la vez.
	var nuevos: Array = []
	_agregar_chunk_a_cola(centro, nuevos)

	for dy in range(-_load_radius, _load_radius + 1):
		for dx in range(-_load_radius, _load_radius + 1):
			var offset := Vector2i(dx, dy)
			if offset == Vector2i.ZERO:
				continue
			if _distancia_chunk(centro + offset, centro) <= _load_radius:
				_agregar_chunk_a_cola(centro + offset, nuevos)

	for chunk in nuevos:
		_queue.append(chunk)

	# Calcular el destino predictivo antes de ordenar: la prioridad debe
	# usar la dirección y posición del frame actual, no la del frame anterior.
	_prefetch_chunk = _obtener_chunk_prefetch(centro)

	_queue.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			var prioridad_a: float = _prioridad_chunk(a, centro)
			var prioridad_b: float = _prioridad_chunk(b, centro)
			return prioridad_a < prioridad_b
	)

	_priorizar_prefetch(centro)

	_descargar_lejanos(centro)
	_actualizar_entidades_activas(centro)


func _actualizar_direccion_jugador() -> void:
	if _player == null:
		return

	var posicion: Vector2 = _player.global_position
	var delta_posicion: Vector2 = posicion - _last_player_position
	_last_player_position = posicion

	var direccion := delta_posicion
	if _player is CharacterBody2D:
		var velocidad: Vector2 = (_player as CharacterBody2D).velocity
		if velocidad.length_squared() > 4.0:
			direccion = velocidad

	if direccion.length_squared() > 0.25:
		_player_direction = direccion.normalized()


func _obtener_chunk_prefetch(centro: Vector2i) -> Vector2i:
	if _player == null or _player_direction.length_squared() <= 0.01:
		return Vector2i(999999, 999999)

	var tile_local_x: int = floori(fposmod(_player.global_position.x, float(_terrain.chunk_size_tiles * _terrain.tile_size)) / _terrain.tile_size)
	var tile_local_y: int = floori(fposmod(_player.global_position.y, float(_terrain.chunk_size_tiles * _terrain.tile_size)) / _terrain.tile_size)
	var margen: int = clampi(_prefetch_margin_tiles, 1, _terrain.chunk_size_tiles - 1)

	var candidato := centro
	var distancia_borde: int = _terrain.chunk_size_tiles

	if _player_direction.x > 0.15 and tile_local_x >= _terrain.chunk_size_tiles - margen:
		candidato = centro + Vector2i.RIGHT
		distancia_borde = _terrain.chunk_size_tiles - 1 - tile_local_x
	elif _player_direction.x < -0.15 and tile_local_x < margen:
		candidato = centro + Vector2i.LEFT
		distancia_borde = tile_local_x

	if _player_direction.y > 0.15 and tile_local_y >= _terrain.chunk_size_tiles - margen:
		if abs(_player_direction.y) >= abs(_player_direction.x):
			candidato = centro + Vector2i.DOWN
			distancia_borde = _terrain.chunk_size_tiles - 1 - tile_local_y
	elif _player_direction.y < -0.15 and tile_local_y < margen:
		if abs(_player_direction.y) >= abs(_player_direction.x):
			candidato = centro + Vector2i.UP
			distancia_borde = tile_local_y

	if candidato == centro or distancia_borde > margen:
		return Vector2i(999999, 999999)
	return candidato


func _prioridad_chunk(chunk: Vector2i, centro: Vector2i) -> float:
	var distancia: float = float(_distancia_chunk(chunk, centro))
	if chunk == _prefetch_chunk:
		# El chunk que queda directamente en la trayectoria se adelanta,
		# pero no se fuerza al frente: debe poder prepararse con anticipación.
	if _player_direction.length_squared() > 0.01:
		var relativo := Vector2(chunk - centro)
		var alineacion: float = relativo.normalized().dot(_player_direction) if relativo.length_squared() > 0.01 else 0.0
		return distancia - alineacion * 0.75
	return distancia


func _priorizar_prefetch(centro: Vector2i) -> void:
	if _prefetch_chunk.x == 999999:
		return
	if _terrain.chunk_cargado(_prefetch_chunk) or _terrain.chunk_en_generacion(_prefetch_chunk):
		return
	var indice: int = _queue.find(_prefetch_chunk)
	if indice > 0:
		_queue.remove_at(indice)
		_queue.push_front(_prefetch_chunk)


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


func tiene_jugador() -> bool:
	return _player != null and is_instance_valid(_player)

func obtener_diagnostico() -> Dictionary:
	return {
		"jugador": tiene_jugador(),
		"player_chunk": _player_chunk,
		"cola_chunks": _queue.size(),
		"cola": _queue.duplicate(),
		"load_radius": _load_radius,
		"unload_radius": _unload_radius,
		"cells_per_frame": _cells_per_frame,
		"generando": _terrain != null and _terrain.tiene_generacion_activa(),
		"descargando": _terrain != null and _terrain.tiene_descarga_activa(),
		"player_direction": _player_direction,
		"prefetch_margin_tiles": _prefetch_margin_tiles,
		"prefetch_chunk": _prefetch_chunk
	}

func _registrar_debug() -> void:
	var debug := get_node_or_null("/root/GarliaDebug")
	if debug == null or not debug.has_method("registrar_proveedor"):
		return
	debug.registrar_proveedor("world_streamer", "WorldStreamer", self, "Cola de chunks, streaming y jugador.")
