extends Node
class_name WorldStreamer


var _terrain: WorldTerrain
var _entity_spawner: WorldEntitySpawner

var _player: Node = null
var _render_manager: Node = null

const MAX_VISIBLE_CHUNKS: int = 9
const VISIBLE_RADIUS: int = 1
# Anillo barato de conocimiento del mundo. No crea TileMap ni entidades.
const DATA_RADIUS: int = 2
const MAX_DATA_CHUNKS: int = 25

var _load_radius: int = VISIBLE_RADIUS
var _unload_radius: int = VISIBLE_RADIUS
# El terreno visible se limita al chunk actual y, como máximo, a los
# vecinos necesarios para anticipar el movimiento. No mantener un 3x3
# completo: en TileMapDual cada celda genera trabajo de render.
# Test de rendimiento: terreno y entidades usan radios independientes.
# Las entidades pueden aparecer en el chunk del jugador y sus vecinos
# ya cargados. El terreno sigue siendo la autoridad: sólo se invoca al
# spawner después de que un chunk terminó de generarse.
var _prop_active_radius: int = 1
var _creature_active_radius: int = 0
var _cells_per_frame: int = 128
var _prefetch_margin_tiles: int = 28
var _last_player_position: Vector2 = Vector2.ZERO
var _player_direction: Vector2 = Vector2.ZERO
var _prefetch_chunk: Vector2i = Vector2i.ZERO
var _prefetch_activo: bool = false
var _centro_cache: Vector2i = Vector2i.ZERO
var _local_x_cache: int = 0
var _local_y_cache: int = 0
var _cerca_arriba_cache: bool = false
var _cerca_abajo_cache: bool = false
var _cerca_izquierda_cache: bool = false
var _cerca_derecha_cache: bool = false

var _player_chunk: Vector2i = Vector2i(
	999999,
	999999
)

var _queue: Array = []
var _data_chunk_cache: Dictionary = {}

# Estado logico de representacion por chunk.
const LOD_DATA: String = "DATA"
const LOD_TERRAIN: String = "TERRAIN"
const LOD_FULL: String = "FULL"
var _chunk_lod: Dictionary = {}
var _lod_counts: Dictionary = {LOD_DATA: 0, LOD_TERRAIN: 0, LOD_FULL: 0}


func configurar(
	terrain: WorldTerrain,
	entity_spawner: WorldEntitySpawner,
	load_radius: int,
	unload_radius: int,
	cells_per_frame: int
) -> void:
	_terrain = terrain
	_entity_spawner = entity_spawner

	_load_radius = clampi(load_radius, 0, VISIBLE_RADIUS)
	_unload_radius = VISIBLE_RADIUS
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

	# El streaming de terreno no puede quedar bloqueado por un unload.
	# Antes la descarga tenía prioridad absoluta y hacía:
	#   clear 1024 celdas -> return -> repetir
	# durante varios frames antes de permitir que el siguiente chunk avanzara.
	# Eso producía exactamente el síntoma actual: pantalla fluida, pero el
	# mundo que viene detrás del jugador tardaba demasiado en aparecer.
	#
	# La limpieza sigue teniendo presupuesto propio, pero se ejecuta después
	# de la generación. Así un chunk visible nunca espera a que termine de
	# borrarse otro que ya quedó atrás.
	var descarga_pendiente := _terrain.tiene_descarga_activa()

	var nuevo_chunk: Vector2i = (
		_world_to_chunk(
			_player.global_position
		)
	)

	_actualizar_direccion_jugador()

	if nuevo_chunk != _player_chunk:
		_player_chunk = nuevo_chunk

	_actualizar_streaming()
	_actualizar_data_lod(_player_chunk)
	_actualizar_lod_logico(_player_chunk)

	# El terreno base recibe el primer turno visual. Las variaciones son
	# decoración secundaria y nunca deben consumir el servicio reservado
	# antes del commit del suelo.
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
			# El chunk base ya terminó. Sólo ahora se permite trabajo secundario.
			_procesar_variaciones_si_hay_presupuesto()
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
				var lod_generado := obtener_lod_chunk(chunk_coord)
				if lod_generado == LOD_TERRAIN or lod_generado == LOD_FULL:
					_entity_spawner.spawn_props_chunk(chunk_coord)
				if lod_generado == LOD_FULL:
					_entity_spawner.spawn_chunk(chunk_coord)

		return

	# Si arrancamos un chunk nuevo este mismo frame, no mezclamos generación
	# y clear de TileMap. En el Celeron esto puede sumar dos trabajos caros
	# en el mismo frame y producir el tirón que todavía se observa aunque
	# el unload ya no bloquee la cola.
	var inicio_generacion := _iniciar_siguiente_chunk()
	if not inicio_generacion:
		# Si no hay generación activa, las decoraciones pendientes pueden usar
		# el presupuesto que quedó libre después del terreno base.
		_procesar_variaciones_si_hay_presupuesto()
	_procesar_entidades_si_hay_presupuesto()

	# Sólo cuando no arrancamos generación en este frame cedemos el frame al
	# unload. La limpieza sigue progresando, pero nunca compite con el primer
	# avance del siguiente chunk visible.
	if not inicio_generacion and descarga_pendiente and _terrain.tiene_descarga_activa():
		var presupuesto_descarga := _presupuesto_descarga()
		if presupuesto_descarga > 0:
			var descarga_inicio_usec := Time.get_ticks_usec()
			_terrain.procesar_descargas(presupuesto_descarga)
			if _render_manager != null:
				_render_manager.call(
					"registrar_trabajo",
					"terrain_clear",
					float(Time.get_ticks_usec() - descarga_inicio_usec) / 1000.0,
					maxi(presupuesto_descarga, 1)
				)



func _procesar_variaciones_si_hay_presupuesto() -> void:
	if _terrain == null or _terrain.visual == null:
		return

	# Las variaciones son decoración secundaria. Ahora usan el mismo
	# presupuesto adaptativo que el resto del trabajo visual, de modo que
	# pueden acelerarse cuando TileMapDual está barato y reducirse
	# automáticamente cuando set_cell() se encarece.
	var limite: int = 8
	if _render_manager != null:
		limite = int(_render_manager.call(
			"presupuesto_unidades_adaptativo",
			"terrain_variation",
			64,
			16,
			64,
			0.85
		))
	else:
		limite = 8

	limite = maxi(limite, 1)
	var inicio_usec := Time.get_ticks_usec()
	var terminado: bool = _terrain.visual.procesar_variaciones(limite)
	var ms := float(Time.get_ticks_usec() - inicio_usec) / 1000.0
	if _render_manager != null:
		_render_manager.call(
			"registrar_trabajo",
			"terrain_variation",
			ms,
			limite
		)

	# Si la cola se vació, el siguiente frame puede dedicar el presupuesto
	# liberado a entidades/streaming en lugar de volver a tocar variaciones.
	if terminado:
		return


func _procesar_entidades_si_hay_presupuesto() -> void:
	if _entity_spawner == null:
		return
	var limite := _presupuesto_entidades()
	if limite <= 0:
		return

	# Las criaturas son el LOD caro: primero se conserva el presupuesto para
	# el chunk donde está el jugador. Los props son decoración y avanzan en
	# una cola independiente.
	_entity_spawner.procesar_spawn_queue(1)
	if limite >= 2:
		_entity_spawner.procesar_prop_spawn_queue(1)

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
	if disponible < 1.0:
		return 0
	if disponible >= 3.0:
		return 3
	if disponible >= 2.0:
		return 2
	return 1


func _presupuesto_generacion() -> int:
	var base: int = maxi(_cells_per_frame, 1)

	# DATOS y PINTADO son trabajo de preparación del mundo, no FLUSH del
	# renderer. Antes ambos compartían el presupuesto visual de 5 ms y, en
	# frames donde el HUD/TileMap ya había consumido ese presupuesto,
	# terminábamos generando 1/8/16/32 celdas. Eso explica diagnósticos como
	# 33/1156 en DATOS: la cola no estaba lenta por Supabase ni por la lógica
	# de chunks, sino por una compuerta visual aplicada al generador.
	#
	# Mantener el límite en _cells_per_frame evita un bucle gigante, pero
	# permite que cada chunk avance de forma sostenida. FLUSH conserva su
	# presupuesto adaptativo porque ahí sí estamos tocando la composición
	# visible de TileMapDual.
	if _terrain != null:
		var estado: Dictionary = _terrain.obtener_estado_generacion()
		var etapa := str(estado.get("etapa", "IDLE"))
		if etapa == "DATOS":
			return mini(base, 128)
		if etapa == "PINTADO":
			return mini(base, 64)

	# FLUSH: aquí sí manda el presupuesto visual.
	if _render_manager == null:
		return mini(base, 96)

	var disponible: float = float(_render_manager.call("presupuesto_disponible_ms"))
	if disponible < 0.75:
		return 1
	if disponible < 1.5:
		return mini(base, 8)
	if disponible < 2.5:
		return mini(base, 16)
	if disponible < 4.0:
		return mini(base, 32)
	return mini(base, 96)


func _actualizar_streaming() -> void:
	if _player == null:
		return

	var centro: Vector2i = _world_to_chunk(_player.global_position)
	_player_chunk = centro
	_actualizar_cache_borde_jugador(centro)

	_terrain.cancelar_generacion_si_distante(centro, _load_radius)
	_terrain.descartar_generacion_pausada_si_distante(centro, _load_radius)

	# Mantener únicamente trabajo que todavía está dentro del radio.
	var cola_filtrada: Array = []
	for queued_variant in _queue:
		if not queued_variant is Vector2i:
			continue
		var queued: Vector2i = queued_variant
		if _distancia_chunk(queued, centro) <= _load_radius:
			cola_filtrada.append(queued)
	_queue = cola_filtrada

	# El radio visual es 1: centro + sus 8 vecinos = máximo 9 chunks.
	# No usamos histeresis visual: _loaded_chunks contiene representación
	# TileMap real y debe respetar un límite duro de 9.
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
	_ceder_generacion_si_hay_prioridad(centro)

	_descargar_lejanos(centro)
	_actualizar_data_lod(centro)
	_actualizar_lod_logico(centro)
	_actualizar_entidades_activas(centro)


func _actualizar_cache_borde_jugador(centro: Vector2i) -> void:
	_centro_cache = centro
	_cerca_arriba_cache = false
	_cerca_abajo_cache = false
	_cerca_izquierda_cache = false
	_cerca_derecha_cache = false

	if _player == null or _terrain == null:
		return

	var tamano_chunk_pixeles: float = float(
		_terrain.chunk_size_tiles * _terrain.tile_size
	)
	var margen_borde: int = clampi(
		_prefetch_margin_tiles,
		1,
		_terrain.chunk_size_tiles - 1
	)
	_local_x_cache = floori(
		fposmod(_player.global_position.x, tamano_chunk_pixeles)
		/ _terrain.tile_size
	)
	_local_y_cache = floori(
		fposmod(_player.global_position.y, tamano_chunk_pixeles)
		/ _terrain.tile_size
	)
	_cerca_arriba_cache = _local_y_cache < margen_borde
	_cerca_abajo_cache = _local_y_cache >= _terrain.chunk_size_tiles - margen_borde
	_cerca_izquierda_cache = _local_x_cache < margen_borde
	_cerca_derecha_cache = _local_x_cache >= _terrain.chunk_size_tiles - margen_borde


func _actualizar_direccion_jugador() -> void:
	if _player == null:
		return

	var posicion: Vector2 = _player.global_position
	var delta_posicion: Vector2 = posicion - _last_player_position
	_last_player_position = posicion

	# La fuente primaria es el input real del Player.
	var direccion := Vector2.ZERO
	if _player.has_method("obtener_direccion_movimiento"):
		var input_direccion: Variant = _player.call("obtener_direccion_movimiento")
		if input_direccion is Vector2 and input_direccion.length_squared() > 0.01:
			direccion = input_direccion

	# Fallback para jugadores/entidades sin interfaz de input.
	if direccion.length_squared() <= 0.01:
		direccion = delta_posicion
		if _player is CharacterBody2D:
			var velocidad: Vector2 = (_player as CharacterBody2D).velocity
			if velocidad.length_squared() > 4.0:
				direccion = velocidad

	if direccion.length_squared() > 0.25:
		_player_direction = direccion.normalized()


func _obtener_chunk_prefetch(centro: Vector2i) -> Vector2i:
	_prefetch_activo = false
	if _player == null or _player_direction.length_squared() <= 0.01:
		return Vector2i.ZERO

	# El cache de borde ya calculó estas coordenadas este mismo frame.
	# Reutilizarlas evita repetir fposmod/floori al decidir el prefetch.
	var tile_local_x: int = _local_x_cache
	var tile_local_y: int = _local_y_cache
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
		return Vector2i.ZERO
	_prefetch_activo = true
	return candidato


func _prioridad_chunk(chunk: Vector2i, centro: Vector2i) -> float:
	# La cola representa trabajo pendiente, no una orden fija de carga.
	# Se prepara primero el corredor que coincide con el movimiento.
	if chunk == centro:
		return 0.0

	var relativo := Vector2(chunk - centro)
	var distancia: float = float(_distancia_chunk(chunk, centro))
	if _player_direction.length_squared() <= 0.01:
		return distancia

	var alineacion: float = relativo.normalized().dot(_player_direction)
	var prioridad: float = distancia * 1.5 - alineacion * 1.75

	# Si el jugador avanza pegado a un borde perpendicular a su movimiento,
	# el vecino de ese borde también forma parte de la zona visible inmediata.
	# Ejemplo: movimiento horizontal junto al borde superior -> el chunk de
	# arriba no puede quedar detrás sólo porque el jugador no se mueve hacia él.
	if _player != null and _terrain != null:
		if _player_direction.x != 0.0:
			if _cerca_arriba_cache and chunk == centro + Vector2i.UP:
				prioridad -= 2.5
			elif _cerca_abajo_cache and chunk == centro + Vector2i.DOWN:
				prioridad -= 2.5

		if _player_direction.y != 0.0:
			if _cerca_izquierda_cache and chunk == centro + Vector2i.LEFT:
				prioridad -= 2.5
			elif _cerca_derecha_cache and chunk == centro + Vector2i.RIGHT:
				prioridad -= 2.5

	# Detrás queda como reserva, pero no consume el generador mientras
	# haya trabajo útil por delante.
	if alineacion < -0.25:
		prioridad += 2.0

	# El prefetch ayuda, pero nunca puede adelantar al chunk donde
	# está el jugador. Tampoco permitimos prioridades negativas para que
	# el centro (prioridad 0) sea siempre el primer trabajo real.
	if chunk == _prefetch_chunk:
		prioridad -= 0.75

	return maxf(prioridad, 0.10)


func _ceder_generacion_si_hay_prioridad(centro: Vector2i) -> void:
	if _terrain == null or not _terrain.tiene_generacion_activa():
		return
	if not _terrain.puede_pausar_generacion_actual():
		return
	if _queue.is_empty():
		return

	var activo: Vector2i = _terrain.obtener_chunk_en_generacion()
	var siguiente: Variant = _queue[0]
	if not siguiente is Vector2i:
		return
	var siguiente_chunk: Vector2i = siguiente

	# Sólo interrumpir cuando el siguiente chunk es claramente más útil.
	# Así evitamos alternar tareas por diferencias mínimas de prioridad.
	var prioridad_activo: float = _prioridad_chunk(activo, centro)
	var prioridad_siguiente: float = _prioridad_chunk(siguiente_chunk, centro)
	if prioridad_activo <= prioridad_siguiente + 0.50:
		return

	if _terrain.pausar_generacion_actual():
		print(
			"WorldStreamer: generacion pausada por prioridad | activo=",
			activo,
			" prioridad=",
			"%.2f" % prioridad_activo,
			" -> siguiente=",
			siguiente_chunk,
			" prioridad=",
			"%.2f" % prioridad_siguiente
		)


func _priorizar_prefetch(_centro: Vector2i) -> void:
	# La prioridad direccional ya se aplica al ordenar la cola.
	# No mover el prefetch a la fuerza al frente: evita tirones en el borde.
	return


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


func _iniciar_siguiente_chunk() -> bool:
	if _queue.is_empty():
		return false

	# Un unload debe liberar el slot antes de crear otro chunk visual.
	if _terrain.tiene_descarga_activa():
		return false

	# Límite duro: nunca más de 9 chunks visuales cargados.
	if _terrain.chunks_cargados().size() >= MAX_VISIBLE_CHUNKS:
		return false

	var chunk_coord: Vector2i = (
		_queue.pop_front()
	)

	if _terrain.chunk_cargado(
		chunk_coord
	):
		return false

	_terrain.configurar_prioridad_generacion(
		_player.global_position
	)
	_terrain.iniciar_generacion_chunk(
		chunk_coord
	)
	return _terrain.tiene_generacion_activa()


func _actualizar_data_lod(centro: Vector2i) -> void:
	if _terrain == null:
		return

	var necesarios: Dictionary = {}
	for dy in range(-DATA_RADIUS, DATA_RADIUS + 1):
		for dx in range(-DATA_RADIUS, DATA_RADIUS + 1):
			var coord := centro + Vector2i(dx, dy)
			necesarios[coord] = true
			if _data_chunk_cache.has(coord):
				continue
			_data_chunk_cache[coord] = _terrain.obtener_resumen_chunk(coord)

	var para_borrar: Array[Vector2i] = []
	for clave_variant in _data_chunk_cache.keys():
		if not clave_variant is Vector2i:
			continue
		var coord: Vector2i = clave_variant
		if not necesarios.has(coord):
			para_borrar.append(coord)

	for coord in para_borrar:
		_data_chunk_cache.erase(coord)

	while _data_chunk_cache.size() > MAX_DATA_CHUNKS:
		var primero: Variant = _data_chunk_cache.keys()[0]
		_data_chunk_cache.erase(primero)


func _actualizar_lod_logico(centro: Vector2i) -> void:
	_chunk_lod.clear()
	_lod_counts = {LOD_DATA: 0, LOD_TERRAIN: 0, LOD_FULL: 0}

	for coord_variant in _data_chunk_cache.keys():
		if not coord_variant is Vector2i:
			continue
		var coord: Vector2i = coord_variant
		var distancia := _distancia_chunk(coord, centro)
		var lod: String = LOD_DATA
		if distancia == 0:
			lod = LOD_FULL
		elif distancia <= VISIBLE_RADIUS:
			lod = LOD_TERRAIN
		_chunk_lod[coord] = lod
		_lod_counts[lod] = int(_lod_counts.get(lod, 0)) + 1


func obtener_lod_chunk(chunk_coord: Vector2i) -> String:
	return str(_chunk_lod.get(chunk_coord, LOD_DATA))


func obtener_estado_lod() -> Dictionary:
	return {
		"counts": _lod_counts.duplicate(),
		"chunks": _chunk_lod.duplicate(),
		"data_radius": DATA_RADIUS,
		"terrain_radius": VISIBLE_RADIUS,
		"full_radius": _creature_active_radius
	}


func _actualizar_entidades_activas(
	centro: Vector2i
) -> void:
	var claves: Array = _terrain.chunks_cargados()

	for chunk_variant in claves:
		if not chunk_variant is Vector2i:
			continue

		var chunk_coord: Vector2i = chunk_variant
		var lod := obtener_lod_chunk(chunk_coord)

		# TERRAIN y FULL pueden tener props visuales. DATA nunca crea Nodes.
		if lod == LOD_TERRAIN or lod == LOD_FULL:
			if _entity_spawner.has_method("materializar_props_datos_chunk") and _entity_spawner.materializar_props_datos_chunk(chunk_coord):
				pass
			else:
				_entity_spawner.spawn_props_chunk(chunk_coord)
		else:
			_entity_spawner.cancelar_prop_spawn_chunk(chunk_coord)
			_entity_spawner.despawn_props_chunk(chunk_coord)

		# Criaturas/IA sólo existen como Nodes en FULL.
		if lod == LOD_FULL:
			_entity_spawner.spawn_chunk(chunk_coord)
		else:
			_entity_spawner.cancelar_spawn_chunk(chunk_coord)
			_entity_spawner.despawn_criaturas_chunk(chunk_coord)


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

		# El streamer decide qué chunks ya no pertenecen al radio visible,
		# pero WorldTerrain ejecuta la descarga visual diferida.
		# Sin esta llamada, _loaded_chunks conserva los chunks viejos y el
		# límite de 9 bloquea permanentemente la entrada de nuevos chunks.
		_terrain.descargar_chunk(chunk_coord)

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
	var lod_data: int = int(_lod_counts.get(LOD_DATA, 0))
	var lod_terrain: int = int(_lod_counts.get(LOD_TERRAIN, 0))
	var lod_full: int = int(_lod_counts.get(LOD_FULL, 0))
	var lod_props: int = lod_terrain + lod_full


	return {
		"jugador": tiene_jugador(),
		"player_chunk": _player_chunk,
		"cola_chunks": _queue.size(),
		"cola": _queue.duplicate(),
		"cola_siguiente": _queue[0] if not _queue.is_empty() else null,
		"chunk_generando": _terrain.obtener_chunk_en_generacion() if _terrain != null and _terrain.tiene_generacion_activa() else null,
		"chunks_terrain": _terrain.chunks_cargados().size() if _terrain != null else 0,
		"chunks_terrain_coords": _terrain.chunks_cargados() if _terrain != null else [],
		"load_radius": _load_radius,
		"unload_radius": _unload_radius,
		"max_visible_chunks": MAX_VISIBLE_CHUNKS,
		"data_radius": DATA_RADIUS,
		"data_chunks": lod_data,
		"data_chunk_coords": _data_chunk_cache.keys(),
		"lod_data": lod_data,
		"lod_terrain": lod_terrain,
		"lod_props": lod_props,
		"lod_full": lod_full,
		"lod_logico": obtener_estado_lod(),
		"prop_active_radius": _prop_active_radius,
		"creature_active_radius": _creature_active_radius,
		"cells_per_frame": _cells_per_frame,
		"generando": _terrain != null and _terrain.tiene_generacion_activa(),
		"descargando": _terrain != null and _terrain.tiene_descarga_activa(),
		"player_direction": _player_direction,
		"prefetch_margin_tiles": _prefetch_margin_tiles,
		"prefetch_activo": _prefetch_activo,
		"prefetch_chunk": _prefetch_chunk if _prefetch_activo else null,
		"borde_cache": {
			"x": _local_x_cache,
			"y": _local_y_cache,
			"arriba": _cerca_arriba_cache,
			"abajo": _cerca_abajo_cache,
			"izquierda": _cerca_izquierda_cache,
			"derecha": _cerca_derecha_cache
		}
	}

func _registrar_debug() -> void:
	var debug := get_node_or_null("/root/GarliaDebug")
	if debug == null or not debug.has_method("registrar_proveedor"):
		return
	debug.registrar_proveedor("world_streamer", "WorldStreamer", self, "Cola de chunks, streaming y jugador.")
