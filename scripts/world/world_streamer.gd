extends Node
class_name WorldStreamer


var _terrain: WorldTerrain
var _entity_spawner: WorldEntitySpawner

var _player: Node = null
var _render_manager: Node = null

const MAX_VISIBLE_CHUNKS: int = 25
# TERRAIN visual mantiene 5x5; FULL lógico mantiene 3x3.
# TERRAIN ocupa 5x5. FULL ocupa 3x3 y DATA 7x7.
const VISIBLE_RADIUS: int = 2
const FULL_RADIUS: int = 1
const DATA_RADIUS: int = 3
const EDGE_PRIORITY_MARGIN_TILES: int = 6
const MAX_DATA_CHUNKS: int = 49

var _load_radius: int = VISIBLE_RADIUS
var _unload_radius: int = VISIBLE_RADIUS
# El terreno visible se limita al chunk actual y, como máximo, a los
# vecinos necesarios para anticipar el movimiento. No mantener un 3x3
# completo: en TileMapDual cada celda genera trabajo de render.
# Test de rendimiento: terreno y entidades usan radios independientes.
# Las entidades pueden aparecer en el chunk del jugador y sus vecinos
# ya cargados. El terreno sigue siendo la autoridad: sólo se invoca al
# spawner después de que un chunk terminó de generarse.
var _prop_active_radius: int = VISIBLE_RADIUS
var _creature_active_radius: int = FULL_RADIUS
var _cells_per_frame: int = 128
var _prefetch_margin_tiles: int = 28
var _last_player_position: Vector2 = Vector2.ZERO
var _player_direction: Vector2 = Vector2.ZERO
var _prefetch_chunk: Vector2i = Vector2i.ZERO
var _prefetch_activo: bool = false
var _last_priority_direction: Vector2 = Vector2.ZERO
var _diag_priority_queue_sorts: int = 0
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
var _data_entity_queue: Array[Vector2i] = []
var _data_entity_queued: Dictionary = {}
var _data_entity_generated: Dictionary = {}
var _diag_entity_data_calls: int = 0
var _diag_entity_data_ms_ultimo: float = 0.0
var _diag_entity_data_ms_maximo: float = 0.0
var _diag_creature_data_ms_maximo: float = 0.0
var _diag_prop_data_ms_maximo: float = 0.0
var _data_preparation_active: bool = false
var _data_preparing_coord: Vector2i = Vector2i(999999, 999999)

# Estado logico de representacion por chunk.
const LOD_DATA: String = "DATA"
const LOD_TERRAIN: String = "TERRAIN"
const LOD_FULL: String = "FULL"
var _chunk_lod: Dictionary = {}
var _lod_counts: Dictionary = {LOD_DATA: 0, LOD_TERRAIN: 0, LOD_FULL: 0}
var _last_lod_center: Vector2i = Vector2i(999999, 999999)
var _last_entity_lod_center: Vector2i = Vector2i(999999, 999999)
var _last_stream_center: Vector2i = Vector2i(999999, 999999)
# La activación de Nodes se distribuye: un chunk por turno, empezando por el más cercano.
var _entity_activation_queue: Array[Vector2i] = []
var _entity_activation_active: bool = false
# WorldTerrain sólo mantiene un unload visual activo; el streamer conserva el resto.
var _pending_unload_chunks: Array[Vector2i] = []
var _pending_unload_lookup: Dictionary = {}
var _diag_unload_entity_last_ms: float = 0.0
var _diag_unload_entity_max_ms: float = 0.0
var _diag_unload_entity_count: int = 0
var _diag_entity_activation_count: int = 0
var _diag_entity_activation_last_ms: float = 0.0
var _diag_entity_activation_max_ms: float = 0.0

# Perfil de trabajo síncrono al cruzar una frontera de chunk. Permite separar
# la cola/LOD de la materialización de Nodes, que puede concentrarse en un frame.
var _diag_transition_count: int = 0
var _diag_transition_last_ms: float = 0.0
var _diag_transition_max_ms: float = 0.0
var _diag_transition_unload_ms: float = 0.0
var _diag_transition_lod_ms: float = 0.0
var _diag_transition_entity_queue_ms: float = 0.0
var _diag_transition_data_queue_ms: float = 0.0


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
	var descarga_pendiente := _terrain.tiene_descarga_activa() or not _pending_unload_chunks.is_empty()

	var nuevo_chunk: Vector2i = (
		_world_to_chunk(
			_player.global_position
		)
	)

	_actualizar_direccion_jugador()

	if nuevo_chunk != _player_chunk:
		_player_chunk = nuevo_chunk

	_actualizar_streaming()
	_actualizar_prioridad_cola()

	# El terreno base recibe el primer turno visual. Las variaciones son
	# decoración secundaria y nunca deben consumir el servicio reservado
	# antes del commit del suelo.
	if _terrain.tiene_generacion_activa():
		# El clear de fase 0 mantiene exclusivo el lote visual. Pausar también
		# una generación ya iniciada: DATOS puede entrar en pintura parcial
		# cuando sus vecinos quedan listos, aunque su etapa siga siendo DATOS.
		if _terrain.tiene_descarga_activa() and not _terrain.puede_iniciar_generacion_durante_descarga():
			_procesar_descarga_si_hay_presupuesto()
			return

		var etapa_generacion := str(
			_terrain.obtener_estado_generacion().get("etapa", "IDLE")
		)
		var presupuesto_celdas := _presupuesto_generacion()
		if presupuesto_celdas <= 0:
			return
		var terminado: bool = (
			_terrain.procesar_generacion(
				presupuesto_celdas
			)
		)

		# DATOS también puede pintar celdas cercanas cuando sus vecinos ya
		# están listos. Sólo intercalar el clear si esta generación todavía no
		# inició pintura parcial; después, ambos trabajos visuales se serializan.
		if etapa_generacion == "DATOS" and descarga_pendiente and _terrain.puede_intercalar_descarga_durante_generacion():
			_procesar_descarga_si_hay_presupuesto()

		if terminado:
			# El chunk base ya terminó. Sólo ahora se permite trabajo secundario.
			_procesar_variaciones_si_hay_presupuesto()
			call_deferred("_procesar_entidades_si_hay_presupuesto")
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
				_encolar_descarga_chunk(chunk_coord, _player_chunk)
			else:
				var lod_generado := obtener_lod_chunk(chunk_coord)
				if lod_generado == LOD_TERRAIN or lod_generado == LOD_FULL:
					_entity_spawner.spawn_props_chunk(chunk_coord)
				if lod_generado == LOD_FULL:
					_entity_spawner.spawn_chunk(chunk_coord)

		return

	# No mezclar el borrado de celdas (fase 0 del unload) con generación.
	# La fase 1 sólo recompone dirty cells y puede avanzar durante DATOS; la
	# pintura del nuevo chunk seguirá teniendo su propio turno visual.
	var inicio_generacion := _iniciar_siguiente_chunk()
	if not inicio_generacion:
		# Si no hay generación activa, las decoraciones pendientes pueden usar
		# el presupuesto que quedó libre después del terreno base.
		_procesar_variaciones_si_hay_presupuesto()
	call_deferred("_procesar_entidades_si_hay_presupuesto")

	# Sólo cuando no arrancamos generación en este frame cedemos el frame al
	# unload. La limpieza sigue progresando, pero nunca compite con el primer
	# avance del siguiente chunk visible.
	if not inicio_generacion and descarga_pendiente:
		_procesar_descarga_si_hay_presupuesto()



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

	# Materializar o retirar entidades puede crear/destruir varios Nodes. Se
	# limita a un chunk por frame y se prioriza el más cercano al jugador.
	await _procesar_siguiente_chunk_entidades()

	# Primero construimos DATA para un chunk remoto. Esto no crea Nodes y deja
	# preparado el mundo para una futura transición instantánea a TERRAIN/FULL.
	# Mientras DATA espera al siguiente frame, las colas de entidades FULL/props
	# siguen recibiendo su pequeño turno para no retrasar criaturas cercanas.
	if not _data_preparation_active and not _data_entity_queue.is_empty():
		var data_coord: Vector2i = _data_entity_queue.pop_front()
		_data_entity_queued.erase(data_coord)
		_data_preparation_active = true
		_data_preparing_coord = data_coord
		var duracion_total_ms := 0.0
		if _entity_spawner.has_method("preparar_datos_criaturas_chunk"):
			var inicio_criaturas_usec := Time.get_ticks_usec()
			await _entity_spawner.preparar_datos_criaturas_chunk(data_coord)
			var criaturas_ms := float(Time.get_ticks_usec() - inicio_criaturas_usec) / 1000.0
			duracion_total_ms += criaturas_ms
			_diag_creature_data_ms_maximo = maxf(_diag_creature_data_ms_maximo, criaturas_ms)
			# La duración incluye esperas entre frames; no reportarla como CPU de un frame.
		if limite >= 2 and _entity_spawner.has_method("preparar_datos_props_chunk"):
			var inicio_props_usec := Time.get_ticks_usec()
			await _entity_spawner.preparar_datos_props_chunk(data_coord)
			var props_ms := float(Time.get_ticks_usec() - inicio_props_usec) / 1000.0
			duracion_total_ms += props_ms
			_diag_prop_data_ms_maximo = maxf(_diag_prop_data_ms_maximo, props_ms)
			# La duración incluye esperas entre frames; no reportarla como CPU de un frame.
		_data_preparation_active = false
		_data_preparing_coord = Vector2i(999999, 999999)
		_diag_entity_data_calls += 1
		_diag_entity_data_ms_ultimo = duracion_total_ms
		_diag_entity_data_ms_maximo = maxf(_diag_entity_data_ms_maximo, duracion_total_ms)
		_data_entity_generated[data_coord] = true
		return

	# Las criaturas son el LOD caro: primero se conserva el presupuesto para
	# el chunk donde está el jugador. Los props son decoración y avanzan en
	# una cola independiente.
	_entity_spawner.procesar_spawn_queue(1)
	if limite >= 2:
		_entity_spawner.procesar_prop_spawn_queue(1)

func _procesar_descarga_si_hay_presupuesto() -> void:
	if _terrain == null:
		return

	# WorldTerrain admite un único clear visual. Empezar como máximo uno por
	# frame evita que los chunks que salen del radio se descarguen en bloque.
	if not _terrain.tiene_descarga_activa():
		while not _pending_unload_chunks.is_empty():
			var chunk_coord: Vector2i = _pending_unload_chunks.pop_front()
			_pending_unload_lookup.erase(chunk_coord)
			if not _terrain.chunk_cargado(chunk_coord):
				continue
			if _distancia_chunk(chunk_coord, _player_chunk) <= _unload_radius:
				continue
			if _entity_spawner != null:
				var entity_unload_start_usec := Time.get_ticks_usec()
				_entity_spawner.despawn_chunk(chunk_coord)
				_diag_unload_entity_last_ms = float(Time.get_ticks_usec() - entity_unload_start_usec) / 1000.0
				_diag_unload_entity_max_ms = maxf(_diag_unload_entity_max_ms, _diag_unload_entity_last_ms)
				_diag_unload_entity_count += 1
			_terrain.descargar_chunk(chunk_coord)
			break

	if not _terrain.tiene_descarga_activa():
		return
	var presupuesto_descarga := _presupuesto_descarga()
	if presupuesto_descarga <= 0:
		return
	var chunk_descargado_variant: Variant = _terrain.obtener_chunk_en_descarga()
	var descarga_inicio_usec := Time.get_ticks_usec()
	var descarga_terminada := _terrain.procesar_descargas(presupuesto_descarga)
	if descarga_terminada and chunk_descargado_variant is Vector2i:
		var chunk_descargado := chunk_descargado_variant as Vector2i
		# Si el jugador regresó mientras el clear estaba activo, el chunk ya
		# no existe visualmente: volver a encolarlo para reconstruirlo.
		if _distancia_chunk(chunk_descargado, _player_chunk) <= _load_radius:
			var nuevos: Array = []
			_agregar_chunk_a_cola(chunk_descargado, nuevos)
			for nuevo_variant in nuevos:
				if nuevo_variant is Vector2i:
					_queue.append(nuevo_variant as Vector2i)
			_queue.sort_custom(
				func(a: Vector2i, b: Vector2i) -> bool:
					return _prioridad_chunk(a, _player_chunk) < _prioridad_chunk(b, _player_chunk)
			)
	if _render_manager != null:
		_render_manager.call(
			"registrar_trabajo",
			"terrain_clear",
			float(Time.get_ticks_usec() - descarga_inicio_usec) / 1000.0,
			maxi(presupuesto_descarga, 1)
		)


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
		if _render_manager != null and etapa == "DATOS":
			# DATOS también adelanta una tanda de PINTADO para las celdas cuyos
			# vecinos ya están listos. Repartir el objetivo entre ambas fases evita
			# que el presupuesto mida sólo la mitad del trabajo real del frame.
			var presupuesto_datos := int(_render_manager.call(
				"presupuesto_unidades_terreno", "terrain_data", base, 8, 64, 1.5
			))
			var presupuesto_pintado := int(_render_manager.call(
				"presupuesto_unidades_terreno", "terrain_paint", base, 8, 64, 1.5
			))
			return mini(presupuesto_datos, presupuesto_pintado)
		if _render_manager != null and etapa == "PINTADO":
			return int(_render_manager.call(
				"presupuesto_unidades_terreno", "terrain_paint", base, 8, 64, 3.0
			))

		if etapa == "DATOS":
			return mini(base, 64)
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

	var centro: Vector2i = _player_chunk
	var cambio_stream := centro != _last_stream_center

	# Mientras el jugador siga en el mismo chunk, la topología del streaming
	# no cambia: no hace falta recalcular bordes ni recorrer los 25 chunks.
	if not cambio_stream:
		return

	var transition_start_usec := Time.get_ticks_usec()
	_actualizar_cache_borde_jugador(centro)

	_last_stream_center = centro

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

	# TERRAIN mantiene un cuadrado 5x5: centro + 24 vecinos.
	# FULL es un LOD lógico más pequeño y no cambia el límite visual.
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

	var unload_start_usec := Time.get_ticks_usec()
	_descargar_lejanos(centro)
	_diag_transition_unload_ms = float(Time.get_ticks_usec() - unload_start_usec) / 1000.0

	var cambio_chunk := centro != _last_lod_center
	if cambio_chunk:
		var lod_start_usec := Time.get_ticks_usec()
		_actualizar_data_lod(centro)
		_actualizar_lod_logico(centro)
		_diag_transition_lod_ms = float(Time.get_ticks_usec() - lod_start_usec) / 1000.0
		_last_lod_center = centro

	if cambio_chunk or centro != _last_entity_lod_center:
		var entities_start_usec := Time.get_ticks_usec()
		_actualizar_entidades_activas(centro)
		_diag_transition_entity_queue_ms = float(Time.get_ticks_usec() - entities_start_usec) / 1000.0
		_last_entity_lod_center = centro

		var data_queue_start_usec := Time.get_ticks_usec()
		_actualizar_data_entidades(centro)
		_diag_transition_data_queue_ms = float(Time.get_ticks_usec() - data_queue_start_usec) / 1000.0

	_diag_transition_last_ms = float(Time.get_ticks_usec() - transition_start_usec) / 1000.0
	_diag_transition_max_ms = maxf(_diag_transition_max_ms, _diag_transition_last_ms)
	_diag_transition_count += 1


func _actualizar_prioridad_cola() -> void:
	if _player == null or _terrain == null:
		return

	# La topología de chunks sólo cambia al cruzar una frontera, pero la
	# predicción debe seguir la posición/dirección dentro del chunk. En
	# particular, un dash puede recorrer el margen de prefetch en pocos frames.
	_actualizar_cache_borde_jugador(_player_chunk)
	var prefetch_anterior := _prefetch_chunk if _prefetch_activo else Vector2i.ZERO
	var prefetch_nuevo := _obtener_chunk_prefetch(_player_chunk)
	var direccion_cambio := false
	if _player_direction.length_squared() <= 0.01:
		direccion_cambio = _last_priority_direction.length_squared() > 0.01
	elif _last_priority_direction.length_squared() <= 0.01:
		direccion_cambio = true
	else:
		direccion_cambio = _player_direction.dot(_last_priority_direction) < 0.995

	_prefetch_chunk = prefetch_nuevo
	if prefetch_nuevo != prefetch_anterior or direccion_cambio:
		_last_priority_direction = _player_direction
		if not _queue.is_empty():
			_queue.sort_custom(
				func(a: Vector2i, b: Vector2i) -> bool:
					var prioridad_a: float = _prioridad_chunk(a, _player_chunk)
					var prioridad_b: float = _prioridad_chunk(b, _player_chunk)
					return prioridad_a < prioridad_b
			)
			_diag_priority_queue_sorts += 1


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
	# El margen de prefetch puede abarcar casi todo el chunk para dar
	# tiempo al terreno. No reutilizarlo para los bordes perpendiculares:
	# con 28/32 tiles ambos lados quedaban marcados simultáneamente y la
	# cola perdía la prioridad del corredor de movimiento.
	var margen_borde: int = clampi(
		EDGE_PRIORITY_MARGIN_TILES,
		1,
		maxi(_terrain.chunk_size_tiles / 2, 1)
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

	# No conservar indefinidamente la última dirección: al detenerse,
	# la cola vuelve a priorizar cercanía en vez de preparar un corredor viejo.
	if direccion.length_squared() > 0.25:
		_player_direction = direccion.normalized()
	else:
		_player_direction = Vector2.ZERO


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

	# La fase CLEAR mantiene un lote visual bloqueado y no admite pintura
	# concurrente. En FLUSH el lote está liberado y puede empezar DATA del
	# siguiente chunk; como DATA también puede pintar celdas cercanas, el
	# servicio del unload sólo se intercala antes de esa pintura parcial.
	if not _terrain.puede_iniciar_generacion_durante_descarga():
		return false

	# Límite duro: nunca más de 25 chunks TERRAIN visuales cargados.
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
			_data_chunk_cache[coord] = {"chunk": coord, "lod": LOD_DATA}

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


func _actualizar_data_entidades(centro: Vector2i) -> void:
	# DATA prepara registros, nunca Nodes. Se procesa como cola para que ampliar
	# el radio no convierta 25 chunks en trabajo de un solo frame.
	var activos: Dictionary = {}
	for coord_variant in _chunk_lod.keys():
		if not coord_variant is Vector2i:
			continue
		var coord := coord_variant as Vector2i
		var lod := str(_chunk_lod.get(coord, LOD_DATA))
		if lod == LOD_DATA:
			activos[coord] = true
			if _data_entity_queued.has(coord) or _data_entity_generated.has(coord) or coord == _data_preparing_coord:
				continue
			_data_entity_queue.append(coord)
			_data_entity_queued[coord] = true
	var stale_generated: Array[Vector2i] = []
	for coord_variant in _data_entity_generated.keys():
		if coord_variant is Vector2i and not activos.has(coord_variant):
			stale_generated.append(coord_variant)
	for coord in stale_generated:
		_data_entity_generated.erase(coord)

	var stale_queued: Array[Vector2i] = []
	for coord_variant in _data_entity_queued.keys():
		if coord_variant is Vector2i and not activos.has(coord_variant):
			stale_queued.append(coord_variant)
	for coord in stale_queued:
		_data_entity_queued.erase(coord)
		_data_entity_queue.erase(coord)

	# DATA también tiene prioridad espacial. Los chunks más cercanos al jugador
	# se preparan primero; los remotos quedan como trabajo de fondo.
	_data_entity_queue.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			var distancia_a := _distancia_chunk(a, centro)
			var distancia_b := _distancia_chunk(b, centro)
			if distancia_a != distancia_b:
				return distancia_a < distancia_b
			if _player_direction.length_squared() <= 0.01:
				return false
			var relativo_a := Vector2(a - centro)
			var relativo_b := Vector2(b - centro)
			var alineacion_a := relativo_a.normalized().dot(_player_direction) if relativo_a.length_squared() > 0.0 else 0.0
			var alineacion_b := relativo_b.normalized().dot(_player_direction) if relativo_b.length_squared() > 0.0 else 0.0
			return alineacion_a > alineacion_b
			)

	if _entity_spawner != null and _entity_spawner.has_method("obtener_entity_manager"):
		var manager: Variant = _entity_spawner.call("obtener_entity_manager")
		if manager != null and manager.has_method("limpiar_datos_fuera_de_radio"):
			manager.call("limpiar_datos_fuera_de_radio", centro, DATA_RADIUS)

func _actualizar_lod_logico(centro: Vector2i) -> void:
	_chunk_lod.clear()
	_lod_counts = {LOD_DATA: 0, LOD_TERRAIN: 0, LOD_FULL: 0}

	for coord_variant in _data_chunk_cache.keys():
		if not coord_variant is Vector2i:
			continue
		var coord: Vector2i = coord_variant
		var distancia := _distancia_chunk(coord, centro)
		var lod: String = LOD_DATA
		if distancia <= FULL_RADIUS:
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
		"full_radius": _creature_active_radius,
		"data_queue": _data_entity_queue.size(),
		"data_preparing": _data_preparation_active,
		"data_preparing_chunk": _data_preparing_coord,
		"data_generated": _data_entity_generated.size(),
		"entity_data_calls": _diag_entity_data_calls,
		"entity_data_ms_ultimo": _diag_entity_data_ms_ultimo,
		"entity_data_ms_maximo": _diag_entity_data_ms_maximo,
		"creature_data_ms_maximo": _diag_creature_data_ms_maximo,
		"prop_data_ms_maximo": _diag_prop_data_ms_maximo
	}


func _actualizar_entidades_activas(
	centro: Vector2i
) -> void:
	# Sólo preparar la cola aquí. No crear/destruir Nodes durante el cambio
	# de frontera, que ocurre dentro del mismo frame del movimiento.
	_ordenar_cola_activacion_entidades(_terrain.chunks_cargados(), centro)


func _ordenar_cola_activacion_entidades(claves: Array, centro: Vector2i) -> void:
	_entity_activation_queue.clear()
	var manager: WorldEntityManager = null
	if _entity_spawner != null and _entity_spawner.has_method("obtener_entity_manager"):
		manager = _entity_spawner.obtener_entity_manager()
	for chunk_variant in claves:
		if not chunk_variant is Vector2i:
			continue
		var chunk_coord := chunk_variant as Vector2i
		var unloading_variant: Variant = _terrain.obtener_chunk_en_descarga()
		if (unloading_variant is Vector2i and unloading_variant == chunk_coord) or _pending_unload_lookup.has(chunk_coord) or _distancia_chunk(chunk_coord, centro) > _unload_radius:
			continue
		if manager != null:
			var lod := obtener_lod_chunk(chunk_coord)
			var necesita_props := lod == LOD_TERRAIN or lod == LOD_FULL
			var necesita_criaturas := lod == LOD_FULL
			var props_activos := manager.tiene_props_chunk(chunk_coord)
			var criaturas_activas := manager.tiene_criaturas_chunk(chunk_coord)
			# No volver a visitar chunks cuyo LOD ya coincide con sus entidades.
			# Esto evita recorrer DATA/materializar claves en cada frontera aunque
			# el chunk lleve varios segundos activo y no requiera ningún cambio.
			if necesita_props == props_activos and necesita_criaturas == criaturas_activas:
				continue
		_entity_activation_queue.append(chunk_coord)
	_entity_activation_queue.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			var distancia_a := _distancia_chunk(a, centro)
			var distancia_b := _distancia_chunk(b, centro)
			if distancia_a != distancia_b:
				return distancia_a < distancia_b
			var alineacion_a := Vector2(a - centro).dot(_player_direction)
			var alineacion_b := Vector2(b - centro).dot(_player_direction)
			return alineacion_a > alineacion_b
	)


func _procesar_siguiente_chunk_entidades() -> void:
	if _entity_activation_active or _entity_activation_queue.is_empty() or _entity_spawner == null or _terrain == null:
		return
	_entity_activation_active = true
	var chunk_coord: Vector2i = _entity_activation_queue.pop_front()
	# El jugador puede cambiar de chunk mientras la cola avanza. Ignorar
	# entradas que ya fueron descargadas o dejaron de pertenecer al terreno.
	if not _terrain.chunks_cargados().has(chunk_coord):
		_entity_activation_active = false
		return

	var inicio_usec := Time.get_ticks_usec()
	var lod := obtener_lod_chunk(chunk_coord)

	# Las funciones de materialización desde DATA ceden el frame cada dos
	# instancias. Esperarlas es esencial: invocarlas sin await las detenía
	# en su primer yield y podía dejar la materialización incompleta.
	var props_materializados := false
	if lod == LOD_TERRAIN or lod == LOD_FULL:
		if _entity_spawner.has_method("materializar_props_datos_chunk"):
			props_materializados = await _entity_spawner.materializar_props_datos_chunk(chunk_coord)

	var lod_despues_props := obtener_lod_chunk(chunk_coord)
	if lod_despues_props == LOD_TERRAIN or lod_despues_props == LOD_FULL:
		if not props_materializados:
			_entity_spawner.spawn_props_chunk(chunk_coord)
	else:
		_entity_spawner.cancelar_prop_spawn_chunk(chunk_coord)
		_entity_spawner.despawn_props_chunk(chunk_coord)

	# El jugador puede cruzar otra frontera mientras el lote anterior cede el
	# frame. Releer el LOD evita crear criaturas para un chunk que ya pasó a
	# TERRAIN/DATA durante la materialización de props.
	if not _terrain.chunks_cargados().has(chunk_coord):
		_entity_activation_active = false
		return
	lod = obtener_lod_chunk(chunk_coord)
	if lod == LOD_FULL:
		var criaturas_materializadas := false
		if _entity_spawner.has_method("materializar_criaturas_datos_chunk"):
			criaturas_materializadas = await _entity_spawner.materializar_criaturas_datos_chunk(chunk_coord)
		if not criaturas_materializadas and obtener_lod_chunk(chunk_coord) == LOD_FULL:
			_entity_spawner.spawn_chunk(chunk_coord)
	else:
		_entity_spawner.cancelar_spawn_chunk(chunk_coord)
		_entity_spawner.despawn_criaturas_chunk(chunk_coord)

	var duracion_ms := float(Time.get_ticks_usec() - inicio_usec) / 1000.0
	_diag_entity_activation_last_ms = duracion_ms
	_diag_entity_activation_max_ms = maxf(_diag_entity_activation_max_ms, duracion_ms)
	_diag_entity_activation_count += 1
	_entity_activation_active = false


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
	# Conservar sólo descargas que siguen fuera del radio. El jugador puede
	# invertir el dash mientras un chunk espera turno para su clear visual.
	var pendientes_validos: Array[Vector2i] = []
	for chunk_coord in _pending_unload_chunks:
		if _terrain.chunk_cargado(chunk_coord) and _distancia_chunk(chunk_coord, centro) > _unload_radius:
			pendientes_validos.append(chunk_coord)
		else:
			_pending_unload_lookup.erase(chunk_coord)
	_pending_unload_chunks = pendientes_validos

	for chunk_variant in _terrain.chunks_cargados():
		if chunk_variant is Vector2i:
			_encolar_descarga_chunk(chunk_variant as Vector2i, centro)


func _encolar_descarga_chunk(chunk_coord: Vector2i, centro: Vector2i) -> void:
	if not _terrain.chunk_cargado(chunk_coord):
		return
	var unloading_variant: Variant = _terrain.obtener_chunk_en_descarga()
	if unloading_variant is Vector2i and unloading_variant == chunk_coord:
		return
	if _distancia_chunk(chunk_coord, centro) <= _unload_radius:
		return
	if _pending_unload_lookup.has(chunk_coord):
		return
	_pending_unload_chunks.append(chunk_coord)
	_pending_unload_lookup[chunk_coord] = true

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
		"priority_queue_sorts": _diag_priority_queue_sorts,
		"entity_activation_queue": _entity_activation_queue.size(),
		"pending_unload_chunks": _pending_unload_chunks.size(),
		"pending_unload_queue": _pending_unload_chunks.duplicate(),
		"unload_entity_profile": {
			"count": _diag_unload_entity_count,
			"last_ms": _diag_unload_entity_last_ms,
			"max_ms": _diag_unload_entity_max_ms
		},
		"entity_activation_profile": {
			"count": _diag_entity_activation_count,
			"elapsed_last_ms": _diag_entity_activation_last_ms,
			"elapsed_max_ms": _diag_entity_activation_max_ms
		},
		"transition_profile": {
			"count": _diag_transition_count,
			"last_ms": _diag_transition_last_ms,
			"max_ms": _diag_transition_max_ms,
			"unload_schedule_ms": _diag_transition_unload_ms,
			"lod_update_ms": _diag_transition_lod_ms,
			"entity_queue_schedule_ms": _diag_transition_entity_queue_ms,
			"data_queue_ms": _diag_transition_data_queue_ms
		},
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
