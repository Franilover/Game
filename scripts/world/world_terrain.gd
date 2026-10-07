extends Node2D
class_name WorldTerrain


const CHUNK_PADDING: int = 1


enum Zone {
	GRASS,
	DIRT,
	STONE,
	SAND,
	WATER,
	DEEP_WATER,
	SHORE,
	ICE,
	FOREST,
	DESERT
}


var map_seed: int = 0
var tile_size: int = 32
var chunk_size_tiles: int = 32


var visual: WorldTerrainVisual
var areas: WorldTerrainAreas


var _world_data: WorldDataService = null
var _render_manager: Node = null
var _biomas: Array = []
var _bioma_nombres: PackedStringArray = PackedStringArray()
var _bioma_texturas: PackedStringArray = PackedStringArray()
var _ecosistemas: Array = []

var _ecosistema_indices: Dictionary = {}

var _loaded_chunks: Dictionary = {}
# Caché de datos ya generados. No contiene lógica alternativa: conserva
# exactamente las matrices producidas por este WorldTerrain para evitar
# recalcular ruido/biomas/ecosistemas al volver a una zona reciente.
@export var chunk_cache_max: int = 8
var _chunk_cache: Dictionary = {}
var _chunk_cache_order: Array[Vector2i] = []

var _generation_task: Dictionary = {}
# Una sola tarea puede quedar pausada para ceder el generador al chunk prioritario.
var _paused_generation_task: Dictionary = {}
var _unload_task: Dictionary = {}
var _pintado_desde_flush: int = 0
@export var visual_flush_cells: int = 256

var _ultimo_chunk_generado: Vector2i = Vector2i.ZERO
var _prioridad_generacion_posicion: Vector2 = Vector2.ZERO

# Perfilador interno del pipeline de generación.
var _profiler_data_ms: float = 0.0
var _profiler_paint_ms: float = 0.0
var _profiler_flush_ms: float = 0.0
var _profiler_data_calls: int = 0
var _profiler_paint_calls: int = 0
var _profiler_flushes: int = 0
var _profiler_biome_ms: float = 0.0
var _profiler_ecosystem_ms: float = 0.0
var _profiler_zone_ms: float = 0.0
var _profiler_data_max_ms: float = 0.0
var _profiler_paint_max_ms: float = 0.0
var _profiler_flush_max_ms: float = 0.0
var _profiler_chunk_start_usec: int = 0
var _profiler_first_commit_ms: float = -1.0
var _profiler_visible_25_ms: float = -1.0
var _profiler_visible_50_ms: float = -1.0
var _profiler_visible_100_ms: float = -1.0
var _profiler_visible_cells: int = 0


func configurar(
	nuevo_seed: int,
	nuevo_tile_size: int,
	nuevo_chunk_size: int,
	nuevo_world_data: WorldDataService = null
) -> void:
	# WorldTerrain es una capa puramente visual de suelo. Nunca debe
	# quedar por encima de entidades aunque el padre tenga otro z_index.
	z_as_relative = false
	z_index = -4096

	_world_data = nuevo_world_data
	if _world_data == null:
		push_error("WorldTerrain: WorldDataService inválido.")
		return

	map_seed = nuevo_seed
	tile_size = nuevo_tile_size
	chunk_size_tiles = nuevo_chunk_size

	areas = WorldTerrainAreas.new()
	areas.configurar(map_seed)

	_crear_capas()
	visual.configurar(tile_size)
func configurar_render_manager(render_manager: Node) -> void:
	_render_manager = render_manager


func cargar_datos_mundo() -> void:
	_biomas.clear()
	_ecosistemas.clear()
	_ecosistema_indices.clear()

	if _world_data == null:
		push_error("WorldTerrain: WorldDataService no configurado.")
		return

	_biomas = _world_data.obtener_biomas()
	_bioma_nombres = PackedStringArray()
	_bioma_texturas = PackedStringArray()
	_bioma_nombres.resize(_biomas.size())
	_bioma_texturas.resize(_biomas.size())
	for i in range(_biomas.size()):
		var bioma_nombre_variant: Variant = _biomas[i]
		if bioma_nombre_variant is Dictionary:
			var bioma_datos := bioma_nombre_variant as Dictionary
			_bioma_nombres[i] = str(bioma_datos.get("nombre", ""))
			var generacion_variant: Variant = bioma_datos.get("generacion", {})
			if generacion_variant is Dictionary:
				_bioma_texturas[i] = str((generacion_variant as Dictionary).get("textura", ""))

	for i in range(_biomas.size()):
		var bioma_variant: Variant = _biomas[i]

		if not bioma_variant is Dictionary:
			continue

		var bioma: Dictionary = bioma_variant

		var ecosistemas_variant: Variant = (
			bioma.get("ecosistemas", [])
		)

		if not ecosistemas_variant is Array:
			continue

		var ecosistemas: Array = ecosistemas_variant

		for j in range(ecosistemas.size()):
			var ecosistema_variant: Variant = (
				ecosistemas[j]
			)

			if not ecosistema_variant is Dictionary:
				continue

			var ecosistema: Dictionary = ecosistema_variant

			var ecosistema_id: String = str(
				ecosistema.get("id", "")
			)

			if ecosistema_id.is_empty():
				continue

			if _ecosistema_indices.has(
				ecosistema_id
			):
				continue

			_ecosistema_indices[ecosistema_id] = (
				_ecosistemas.size()
			)

			_ecosistemas.append(
				ecosistema
			)

	var sin_bioma: Array = (
		_world_data.obtener_ecosistemas_sin_bioma()
	)

	for i in range(sin_bioma.size()):
		var ecosistema_variant: Variant = (
			sin_bioma[i]
		)

		if not ecosistema_variant is Dictionary:
			continue

		var ecosistema: Dictionary = ecosistema_variant

		var ecosistema_id: String = str(
			ecosistema.get("id", "")
		)

		if ecosistema_id.is_empty():
			continue

		if _ecosistema_indices.has(
			ecosistema_id
		):
			continue

		_ecosistema_indices[ecosistema_id] = (
			_ecosistemas.size()
		)

		_ecosistemas.append(
			ecosistema
		)

	areas.cargar_datos(
		_biomas,
		_ecosistemas,
		_ecosistema_indices
	)

	print(
		"WorldTerrain: biomas = ",
		_biomas.size()
	)

	print(
		"WorldTerrain: ecosistemas = ",
		_ecosistemas.size()
	)


func _crear_capas() -> void:
	visual = get_node_or_null("WorldTerrainVisual") as WorldTerrainVisual
	if visual == null:
		push_error("WorldTerrain: falta el nodo WorldTerrainVisual en la escena.")
func obtener_contexto_data_at(tile: Vector2i) -> Dictionary:
	# Los chunks visuales ya contienen exactamente los índices canónicos calculados
	# durante su generación. Reutilizarlos evita volver a evaluar FastNoiseLite
	# para cada intento de spawn de entidades.
	var chunk_coord := _tile_to_chunk(tile)
	var datos_variant: Variant = _loaded_chunks.get(chunk_coord, null)
	if datos_variant is Dictionary:
		var datos := datos_variant as Dictionary
		var local := _tile_to_local(tile)
		var x := local.x + CHUNK_PADDING
		var y := local.y + CHUNK_PADDING
		var biomas_variant: Variant = datos.get("biomas", [])
		var ecosistemas_variant: Variant = datos.get("ecosistemas", [])
		var zonas_variant: Variant = datos.get("zonas", [])
		if biomas_variant is Array and ecosistemas_variant is Array and zonas_variant is Array:
			var biomas_array := biomas_variant as Array
			var ecosistemas_array := ecosistemas_variant as Array
			var zonas_array := zonas_variant as Array
			if y >= 0 and y < biomas_array.size() and y < ecosistemas_array.size() and y < zonas_array.size():
				if x >= 0 and x < biomas_array[y].size() and x < ecosistemas_array[y].size() and x < zonas_array[y].size():
					return _construir_contexto_data(
						tile,
						int(biomas_array[y][x]),
						int(ecosistemas_array[y][x]),
						int(zonas_array[y][x])
					)

	# DATA puro para chunks que todavía no están materializados visualmente.
	var bioma_index: int = _bioma_index_at_tile(tile)
	var ecosistema_index: int = _ecosistema_index_at_tile(tile, bioma_index)
	var zona: int = _zona_base_at_tile(tile, bioma_index, ecosistema_index)
	return _construir_contexto_data(tile, bioma_index, ecosistema_index, zona)


func _construir_contexto_data(
	tile: Vector2i,
	bioma_index: int,
	ecosistema_index: int,
	zona: int
) -> Dictionary:
	var bioma: Dictionary = {}
	var ecosistema: Dictionary = {}
	if bioma_index >= 0 and bioma_index < _biomas.size():
		var bioma_variant: Variant = _biomas[bioma_index]
		if bioma_variant is Dictionary:
			bioma = bioma_variant as Dictionary
	if ecosistema_index >= 0 and ecosistema_index < _ecosistemas.size():
		var ecosistema_variant: Variant = _ecosistemas[ecosistema_index]
		if ecosistema_variant is Dictionary:
			ecosistema = ecosistema_variant as Dictionary
	var habitats: Array = []
	var habitats_variant: Variant = ecosistema.get("habitats", [])
	if habitats_variant is Array:
		habitats = habitats_variant as Array
	return {
		"tile": tile,
		"bioma": bioma,
		"ecosistema": ecosistema,
		"habitats": habitats,
		"zona": zona,
		"walkable": zona != Zone.WATER and zona != Zone.DEEP_WATER and zona != Zone.SHORE and zona != Zone.ICE
	}

func obtener_resumen_chunk(chunk_coord: Vector2i) -> Dictionary:
	# LOD DATA: muestreo determinista pequeño. No genera matrices, no toca
	# TileMap y no crea entidades. Es la base para conocer el mundo más allá
	# del radio visual sin pagar el coste de un chunk completo.
	var muestras: int = 0
	var conteo_biomas: Dictionary = {}
	var conteo_ecosistemas: Dictionary = {}
	var paso: int = maxi(chunk_size_tiles / 4, 1)

	for local_y in range(0, chunk_size_tiles, paso):
		for local_x in range(0, chunk_size_tiles, paso):
			var tile := Vector2i(
				chunk_coord.x * chunk_size_tiles + local_x,
				chunk_coord.y * chunk_size_tiles + local_y
			)
			var bioma_index: int = _bioma_index_at_tile(tile)
			var ecosistema_index: int = _ecosistema_index_at_tile(tile, bioma_index)
			conteo_biomas[bioma_index] = int(conteo_biomas.get(bioma_index, 0)) + 1
			conteo_ecosistemas[ecosistema_index] = int(conteo_ecosistemas.get(ecosistema_index, 0)) + 1
			muestras += 1

	return {
		"chunk": chunk_coord,
		"lod": "DATA",
		"muestras": muestras,
		"biomas": conteo_biomas,
		"ecosistemas": conteo_ecosistemas
	}


func configurar_prioridad_generacion(posicion_mundo: Vector2) -> void:
	_prioridad_generacion_posicion = posicion_mundo


func iniciar_generacion_chunk(
	chunk_coord: Vector2i
) -> void:
	if _loaded_chunks.has(chunk_coord):
		return

	# Reanudar exactamente el estado que fue pausado por prioridad.
	if not _paused_generation_task.is_empty() and _generation_task.is_empty():
		var paused_coord: Vector2i = _paused_generation_task.get("coord", Vector2i.ZERO)
		if paused_coord == chunk_coord:
			_generation_task = _paused_generation_task
			_paused_generation_task.clear()
			return

	_profiler_data_ms = 0.0
	_profiler_paint_ms = 0.0
	_profiler_flush_ms = 0.0
	_profiler_data_calls = 0
	_profiler_paint_calls = 0
	_profiler_flushes = 0
	_profiler_biome_ms = 0.0
	_profiler_ecosystem_ms = 0.0
	_profiler_zone_ms = 0.0
	_profiler_data_max_ms = 0.0
	_profiler_paint_max_ms = 0.0
	_profiler_flush_max_ms = 0.0
	_profiler_chunk_start_usec = Time.get_ticks_usec()
	_profiler_first_commit_ms = -1.0
	_profiler_visible_25_ms = -1.0
	_profiler_visible_50_ms = -1.0
	_profiler_visible_100_ms = -1.0
	_profiler_visible_cells = 0
	if visual != null:
		visual.iniciar_profiler()

	if not _generation_task.is_empty():
		return

	# Volver a un chunk reciente reutiliza sus datos canónicos. Sólo hay que
	# reconstruir la representación visual, que puede haber sido descargada.
	if _chunk_cache.has(chunk_coord):
		var cache_data: Variant = _chunk_cache[chunk_coord]
		if cache_data is Dictionary:
			var datos: Dictionary = cache_data as Dictionary
			var orden_pintado_cache := _crear_orden_generacion(
				chunk_size_tiles,
				chunk_coord,
				false
			)
			_generation_task = {
				"coord": chunk_coord,
				"stage": 1,
				"cursor": 0,
				"orden_pintado": orden_pintado_cache,
				"zonas_base": datos.get("zonas_base", []),
				"zonas": datos.get("zonas", []),
				"biomas": datos.get("biomas", []),
				"ecosistemas": datos.get("ecosistemas", [])
			}
			_chunk_cache.erase(chunk_coord)
			_chunk_cache_order.erase(chunk_coord)
			return

	var padded_size: int = (
		chunk_size_tiles
		+ CHUNK_PADDING * 2
	)

	var zonas_base: Array = []
	var zonas: Array = []
	var biomas: Array = []
	var ecosistemas: Array = []

	for y in range(padded_size):
		var fila_zonas_base: Array = []
		var fila_zonas: Array = []
		var fila_biomas: Array = []
		var fila_ecosistemas: Array = []

		for x in range(padded_size):
			fila_zonas_base.append(Zone.GRASS)
			fila_zonas.append(Zone.GRASS)
			fila_biomas.append(-1)
			fila_ecosistemas.append(-1)

		zonas_base.append(fila_zonas_base)
		zonas.append(fila_zonas)
		biomas.append(fila_biomas)
		ecosistemas.append(fila_ecosistemas)

	_pintado_desde_flush = 0

	var orden_datos := _crear_orden_generacion(padded_size, chunk_coord, true)
	var orden_pintado := _crear_orden_generacion(chunk_size_tiles, chunk_coord, false)

	_generation_task = {
		"coord": chunk_coord,
		"stage": 0,
		"cursor": 0,
		"orden_datos": orden_datos,
		"orden_pintado": orden_pintado,
		"zonas_base": zonas_base,
		"zonas": zonas,
		"biomas": biomas,
		"ecosistemas": ecosistemas
	}


func procesar_generacion(
	cells: int
) -> bool:
	if _generation_task.is_empty():
		return false

	var stage: int = int(
		_generation_task["stage"]
	)

	if stage == 0:
		return _procesar_datos_chunk(
			cells
		)

	if stage == 1:
		return _procesar_pintado_chunk(
			cells
		)

	return _procesar_flush_chunk(
		cells
	)


func _copiar_dato_borde_vecino(
	tile: Vector2i,
	local_x: int,
	local_y: int,
	biomas: Array,
	ecosistemas: Array,
	zonas_base: Array
) -> bool:
	# El padding de un chunk coincide con tiles interiores de sus vecinos.
	# Si ese vecino ya fue generado, reutilizamos exactamente sus datos en
	# vez de volver a ejecutar todos los FastNoiseLite para esas coordenadas.
	if not (
		local_x == 0
		or local_x == chunk_size_tiles + 1
		or local_y == 0
		or local_y == chunk_size_tiles + 1
	):
		return false

	var vecino_coord: Vector2i = _tile_to_chunk(tile)
	var datos_variant: Variant = _loaded_chunks.get(vecino_coord, null)
	if datos_variant == null:
		datos_variant = _chunk_cache.get(vecino_coord, null)
	if not datos_variant is Dictionary:
		return false

	var datos: Dictionary = datos_variant as Dictionary
	var vecino_local: Vector2i = _tile_to_local(tile)
	var vecino_x: int = vecino_local.x + CHUNK_PADDING
	var vecino_y: int = vecino_local.y + CHUNK_PADDING

	var vecino_biomas_variant: Variant = datos.get("biomas", [])
	var vecino_ecosistemas_variant: Variant = datos.get("ecosistemas", [])
	var vecino_zonas_variant: Variant = datos.get("zonas_base", [])
	if not vecino_biomas_variant is Array:
		return false
	if not vecino_ecosistemas_variant is Array:
		return false
	if not vecino_zonas_variant is Array:
		return false

	var vecino_biomas: Array = vecino_biomas_variant as Array
	var vecino_ecosistemas: Array = vecino_ecosistemas_variant as Array
	var vecino_zonas: Array = vecino_zonas_variant as Array
	if (
		vecino_y < 0
		or vecino_y >= vecino_biomas.size()
		or vecino_y >= vecino_ecosistemas.size()
		or vecino_y >= vecino_zonas.size()
	):
		return false
	if (
		vecino_x < 0
		or vecino_x >= vecino_biomas[vecino_y].size()
		or vecino_x >= vecino_ecosistemas[vecino_y].size()
		or vecino_x >= vecino_zonas[vecino_y].size()
	):
		return false

	biomas[local_y][local_x] = vecino_biomas[vecino_y][vecino_x]
	ecosistemas[local_y][local_x] = vecino_ecosistemas[vecino_y][vecino_x]
	zonas_base[local_y][local_x] = vecino_zonas[vecino_y][vecino_x]
	return true


func _procesar_datos_chunk(
	cells: int
) -> bool:
	var profiler_start_usec: int = Time.get_ticks_usec()

	var coord: Vector2i = (
		_generation_task["coord"]
	)

	var zonas_base: Array = (
		_generation_task["zonas_base"]
	)

	var biomas: Array = (
		_generation_task["biomas"]
	)

	var ecosistemas: Array = (
		_generation_task["ecosistemas"]
	)

	var size: int = (
		chunk_size_tiles
		+ CHUNK_PADDING * 2
	)

	var total: int = (
		size * size
	)

	var cursor: int = int(
		_generation_task["cursor"]
	)
	var orden: Array = _generation_task["orden_datos"]

	if cursor == 0 and visual != null:
		visual.comenzar_lote()

	var limite: int = mini(
		cursor + cells,
		total
	)

	while cursor < limite:
		var indice: int = int(orden[cursor])
		var local_y: int = (
			indice / size
		)

		var local_x: int = (
			indice % size
		)

		var global_x: int = (
			coord.x
			* chunk_size_tiles
			+ local_x
			- CHUNK_PADDING
		)

		var global_y: int = (
			coord.y
			* chunk_size_tiles
			+ local_y
			- CHUNK_PADDING
		)

		var tile := Vector2i(
			global_x,
			global_y
		)

		# El borde puede ser una coordenada que ya pertenece al chunk vecino.
		# Reutilizarlo elimina trabajo duplicado sin cambiar ningún resultado.
		if _copiar_dato_borde_vecino(
			tile,
			local_x,
			local_y,
			biomas,
			ecosistemas,
			zonas_base
		):
			cursor += 1
			continue

		# Este es el camino caliente del generador. No medir cada llamada a
		# FastNoiseLite: tres get_ticks_usec() por celda añadían miles de
		# llamadas al profiler y contaminaban precisamente el rendimiento que
		# estamos intentando medir. El costo total de DATOS se mide una vez
		# por lote más abajo.
		var bioma_index: int = _bioma_index_at_tile(tile)
		var ecosistema_index: int = _ecosistema_index_at_tile(
			tile,
			bioma_index
		)
		var zona: int = _zona_base_at_tile(
			tile,
			bioma_index,
			ecosistema_index
		)

		biomas[local_y][local_x] = (
			bioma_index
		)

		ecosistemas[local_y][local_x] = (
			ecosistema_index
		)

		zonas_base[local_y][local_x] = (
			zona
		)

		cursor += 1

	_generation_task["cursor"] = cursor

	var data_ms_this_step := float(Time.get_ticks_usec() - profiler_start_usec) / 1000.0
	_profiler_data_ms += data_ms_this_step
	_profiler_data_max_ms = maxf(_profiler_data_max_ms, data_ms_this_step)
	_profiler_data_calls += 1

	if cursor < total:
		return false

	_generation_task["stage"] = 1
	_generation_task["cursor"] = 0

	return false


func _procesar_pintado_chunk(
	cells: int
) -> bool:
	var profiler_start_usec: int = Time.get_ticks_usec()

	var coord: Vector2i = (
		_generation_task["coord"]
	)

	var zonas_base: Array = (
		_generation_task["zonas_base"]
	)

	var zonas: Array = (
		_generation_task["zonas"]
	)

	var biomas: Array = (
		_generation_task["biomas"]
	)

	var ecosistemas: Array = (
		_generation_task["ecosistemas"]
	)

	var total: int = (
		chunk_size_tiles
		* chunk_size_tiles
	)

	var cursor: int = int(
		_generation_task["cursor"]
	)
	var orden: Array = _generation_task["orden_pintado"]
	var cursor_inicio_lote: int = cursor

	var limite: int = mini(
		cursor + cells,
		total
	)

	if visual != null:
		visual.comenzar_lote()

	while cursor < limite:
		var indice: int = int(orden[cursor])
		var local_y: int = (
			indice / chunk_size_tiles
		)

		var local_x: int = (
			indice % chunk_size_tiles
		)

		var padded_x: int = (
			local_x + CHUNK_PADDING
		)

		var padded_y: int = (
			local_y + CHUNK_PADDING
		)

		var global_x: int = (
			coord.x
			* chunk_size_tiles
			+ local_x
		)

		var global_y: int = (
			coord.y
			* chunk_size_tiles
			+ local_y
		)

		var tile := Vector2i(
			global_x,
			global_y
		)

		var zona_base: int = int(
			zonas_base[padded_y][padded_x]
		)

		var zona_final: int = (
			_zona_final_desde_array(
				zonas_base,
				padded_x,
				padded_y,
				zona_base
			)
		)

		zonas[padded_y][padded_x] = (
			zona_final
		)

		_pintar_tile(
			tile,
			zona_final,
			int(biomas[padded_y][padded_x])
		)

		cursor += 1

	_generation_task["cursor"] = cursor

	if visual != null:
		visual.terminar_lote()
		visual.marcar_region_generada_dirty(
			coord,
			orden,
			chunk_size_tiles,
			cursor_inicio_lote,
			cursor
		)

	var paint_ms_this_step := float(Time.get_ticks_usec() - profiler_start_usec) / 1000.0
	_profiler_paint_ms += paint_ms_this_step
	_profiler_paint_max_ms = maxf(_profiler_paint_max_ms, paint_ms_this_step)
	_profiler_paint_calls += 1

	# El commit visual de este lote ocurre en el mismo frame que el pintado.
	# Así la generación deja de tener una barrera artificial entre PINTADO y
	# FLUSH, sin declarar terminado el chunk hasta que todas sus celdas estén
	# realmente compuestas.
	_procesar_flush_incremental()

	if cursor < total:
		return false

	if visual != null:
		visual.marcar_chunk_generado_dirty(
			coord,
			chunk_size_tiles
		)

	_pintado_desde_flush = 0
	_generation_task["stage"] = 2
	_generation_task["cursor"] = 0

	return false


func _procesar_flush_incremental() -> void:
	if visual == null or not visual.tiene_flush_pendiente():
		return

	var flush_cells := mini(_cells_presupuesto_flush_incremental(), visual_flush_cells)
	if flush_cells <= 0:
		return

	var inicio_usec := Time.get_ticks_usec()
	visual.procesar_flush(flush_cells)
	var flush_ms := float(Time.get_ticks_usec() - inicio_usec) / 1000.0
	_profiler_flush_ms += flush_ms
	_profiler_flushes += 1
	if visual != null:
		var visual_profiler: Dictionary = visual.obtener_profiler()
		var visible_cells_now := int(visual_profiler.get("flush_cells", 0))
		if visible_cells_now > _profiler_visible_cells:
			_profiler_visible_cells = visible_cells_now
			var elapsed_ms := float(Time.get_ticks_usec() - _profiler_chunk_start_usec) / 1000.0
			if _profiler_first_commit_ms < 0.0:
				_profiler_first_commit_ms = elapsed_ms
			if _profiler_visible_25_ms < 0.0 and visible_cells_now >= 256:
				_profiler_visible_25_ms = elapsed_ms
			if _profiler_visible_50_ms < 0.0 and visible_cells_now >= 512:
				_profiler_visible_50_ms = elapsed_ms
			if _profiler_visible_100_ms < 0.0 and visible_cells_now >= 1024:
				_profiler_visible_100_ms = elapsed_ms
	if _render_manager != null:
		_render_manager.call(
			"registrar_trabajo",
			"terrain_flush",
			flush_ms,
			maxi(flush_cells, 1)
		)


func _cells_presupuesto_flush_incremental() -> int:
	if _render_manager == null:
		return 8
	return int(_render_manager.call(
		"presupuesto_unidades_terreno",
		"terrain_flush",
		256,
		32,
		visual_flush_cells,
		3.0
	))


func _procesar_flush_chunk(
	cells: int
) -> bool:
	if visual == null:
		_finalizar_chunk()
		return true

	var flush_start_usec: int = Time.get_ticks_usec()
	# TileMapDual no escala linealmente: mantener micro-lotes y dejar que
	# el RenderManager corte el trabajo antes de consumir el frame.
	# El objetivo es reducir la latencia del terreno visible sin quitarle al
	# RenderManager la capacidad de recortar el trabajo cuando el frame está caro.
	var flush_cells: int = mini(cells, visual_flush_cells)
	if _render_manager != null:
		flush_cells = int(_render_manager.call(
			"presupuesto_unidades_terreno",
			"terrain_flush",
			maxi(flush_cells, 32),
			16,
			visual_flush_cells,
			2.0
		))
		flush_cells = mini(flush_cells, visual_flush_cells)
	var terminado: bool = visual.procesar_flush(flush_cells)
	var visual_profiler: Dictionary = visual.obtener_profiler()
	var visible_cells_now := int(visual_profiler.get("flush_cells", 0))
	if visible_cells_now > _profiler_visible_cells:
		_profiler_visible_cells = visible_cells_now
		var elapsed_ms := float(Time.get_ticks_usec() - _profiler_chunk_start_usec) / 1000.0
		if _profiler_first_commit_ms < 0.0:
			_profiler_first_commit_ms = elapsed_ms
		if _profiler_visible_25_ms < 0.0 and visible_cells_now >= 256:
			_profiler_visible_25_ms = elapsed_ms
		if _profiler_visible_50_ms < 0.0 and visible_cells_now >= 512:
			_profiler_visible_50_ms = elapsed_ms
		if _profiler_visible_100_ms < 0.0 and visible_cells_now >= 1024:
			_profiler_visible_100_ms = elapsed_ms
	var flush_ms := float(Time.get_ticks_usec() - flush_start_usec) / 1000.0
	_profiler_flush_ms += flush_ms
	_profiler_flush_max_ms = maxf(_profiler_flush_max_ms, flush_ms)
	_profiler_flushes += 1
	if _render_manager != null:
		_render_manager.call("registrar_trabajo", "terrain_flush", flush_ms, max(flush_cells, 1))

	if not terminado:
		return false

	_finalizar_chunk()
	return true


func generar_chunk_completo(
	chunk_coord: Vector2i
) -> void:
	iniciar_generacion_chunk(
		chunk_coord
	)

	while not _generation_task.is_empty():
		procesar_generacion(
			100000
		)


func _finalizar_chunk() -> void:
	var coord: Vector2i = (
		_generation_task["coord"]
	)

	_loaded_chunks[coord] = {
		"zonas": _generation_task["zonas"],
		"zonas_base": _generation_task["zonas_base"],
		"biomas": _generation_task["biomas"],
		"ecosistemas": _generation_task["ecosistemas"]
	}
	# Si el chunk venía de caché, mantenerlo como "más reciente" sólo después
	# de que haya terminado de pintarse correctamente.
	_chunk_cache.erase(coord)
	_chunk_cache_order.erase(coord)

	_ultimo_chunk_generado = coord

	var total_ms: float = _profiler_data_ms + _profiler_paint_ms
	var visual_profile: Dictionary = visual.obtener_profiler() if visual != null else {}
	print(
		"World Profiler | chunk ",
		coord,
		" | total=",
		"%.2f" % total_ms,
		" ms | datos=",
		"%.2f" % _profiler_data_ms,
		" ms total / max_step=",
		"%.2f" % _profiler_data_max_ms,
		" ms (",
		_profiler_data_calls,
		" pasos) | bioma=",
		"%.2f" % _profiler_biome_ms,
		" ms | ecosistema=",
		"%.2f" % _profiler_ecosystem_ms,
		" ms | zona=",
		"%.2f" % _profiler_zone_ms,
		" ms | pintura=",
		"%.2f" % _profiler_paint_ms,
		" ms total / max_step=",
		"%.2f" % _profiler_paint_max_ms,
		" ms (",
		_profiler_paint_calls,
		" pasos) | flush=",
		"%.2f" % _profiler_flush_ms,
		" ms total / max_step=",
		"%.2f" % _profiler_flush_max_ms,
		" ms / ",
		_profiler_flushes,
		" | visual_set_zone=",
		"%.2f" % float(visual_profile.get("set_zone_ms", 0.0)),
		" ms/", int(visual_profile.get("set_zone_calls", 0)), " llamadas",
		" | visual_set_cell=",
		"%.2f" % float(visual_profile.get("set_cell_ms", 0.0)),
		" ms/", int(visual_profile.get("set_cell_calls", 0)), " llamadas",
		" | visual_variaciones_dirty=",
		"%.2f" % float(visual_profile.get("variation_ms", 0.0)),
		" ms | visual_dirty=",
		"%.2f" % float(visual_profile.get("dirty_ms", 0.0)),
		" ms | flush_convert=",
		"%.2f" % float(visual_profile.get("flush_convert_ms", 0.0)),
		" ms | flush_update=",
		"%.2f" % float(visual_profile.get("flush_update_ms", 0.0)),
		" ms/", int(visual_profile.get("flush_update_calls", 0)), " updates/", int(visual_profile.get("flush_regions", 0)), " regiones/", int(visual_profile.get("flush_cells", 0)), " celdas",
		" | flush_variaciones=",
		"%.2f" % float(visual_profile.get("flush_variation_ms", 0.0)),
		" ms/", int(visual_profile.get("flush_variation_cells", 0)), " celdas",
		" | MAX set_zone=", "%.2f" % float(visual_profile.get("set_zone_max_ms", 0.0)),
		" ms | MAX flush=", "%.2f" % float(visual_profile.get("flush_max_ms", 0.0)),
		" ms | MAX flush_update=", "%.2f" % float(visual_profile.get("flush_update_max_ms", 0.0)),
		" ms | MAX variaciones=", "%.2f" % float(visual_profile.get("variation_max_ms", 0.0)),
		" ms",
	)

	_generation_task.clear()
func tiene_generacion_activa() -> bool:
	return not _generation_task.is_empty()


func obtener_chunk_en_generacion() -> Vector2i:
	if _generation_task.is_empty():
		return Vector2i(999999, 999999)
	return _generation_task.get("coord", Vector2i(999999, 999999))


func puede_pausar_generacion_actual() -> bool:
	# La preempción de FLUSH queda desactivada deliberadamente.
	# FLUSH es la última barrera que convierte el chunk en cargado; si se
	# interrumpe aquí, el chunk actual nunca entra en _loaded_chunks y el
	# streamer puede encadenar pausas antes de mostrar terreno.
	# La prioridad ya se aplica al ORDEN DE LA COLA antes de iniciar cada
	# chunk. Eso mantiene el camino estable sin sacrificar visibilidad.
	return false


func pausar_generacion_actual() -> bool:
	if not puede_pausar_generacion_actual():
		return false
	_paused_generation_task = _generation_task
	_generation_task = {}
	return true


func tiene_generacion_pausada() -> bool:
	return not _paused_generation_task.is_empty()


func descartar_generacion_pausada_si_distante(
	centro: Vector2i,
	radio_maximo: int
) -> bool:
	if _paused_generation_task.is_empty():
		return false
	var coord: Vector2i = _paused_generation_task.get("coord", Vector2i.ZERO)
	var distancia := maxi(abs(coord.x - centro.x), abs(coord.y - centro.y))
	if distancia <= radio_maximo:
		return false
	_paused_generation_task.clear()
	return true


func cancelar_generacion_si_distante(
	centro: Vector2i,
	radio_maximo: int
) -> bool:
	if _generation_task.is_empty():
		return false

	var coord: Vector2i = _generation_task.get(
		"coord",
		Vector2i.ZERO
	)
	var distancia := maxi(
		abs(coord.x - centro.x),
		abs(coord.y - centro.y)
	)
	if distancia <= radio_maximo:
		return false

	# La generación puede haber pintado parte del chunk antes de que
	# el jugador se alejara. Retirar esas celdas evita terreno fantasma.
	# La retirada también debe ser diferible: cancelar una generación no
	# puede convertir un frame de streaming en un flush de 1024 celdas.
	if visual != null:
		visual.terminar_lote()
		visual.iniciar_clear_chunk(coord, chunk_size_tiles)
		_unload_task = {
			"coord": coord,
		}
	_generation_task.clear()
	_pintado_desde_flush = 0
	return true


func chunk_en_generacion(
	chunk_coord: Vector2i
) -> bool:
	if _generation_task.is_empty():
		return false
	return _generation_task.get("coord") == chunk_coord


func chunk_cargado(
	chunk_coord: Vector2i
) -> bool:
	return _loaded_chunks.has(
		chunk_coord
	)


func chunks_cargados() -> Array:
	return _loaded_chunks.keys()


func ultimo_chunk_generado() -> Vector2i:
	return _ultimo_chunk_generado


func descargar_chunk(
	chunk_coord: Vector2i
) -> void:
	if not _loaded_chunks.has(chunk_coord):
		return
	if not _unload_task.is_empty():
		return

	_unload_task = {
		"coord": chunk_coord,
	}
	if visual != null:
		visual.iniciar_clear_chunk(chunk_coord, chunk_size_tiles)


func procesar_descargas(cells: int) -> bool:
	if _unload_task.is_empty():
		return true

	if visual == null:
		_loaded_chunks.erase(_unload_task["coord"])
		_unload_task.clear()
		return true

	var terminado: bool = visual.procesar_clear_chunk(cells)
	if not terminado:
		return false

	var coord: Vector2i = _unload_task["coord"]
	var datos_variant: Variant = _loaded_chunks.get(coord, {})
	_loaded_chunks.erase(coord)

	if datos_variant is Dictionary and chunk_cache_max > 0:
		_chunk_cache[coord] = datos_variant
		_chunk_cache_order.erase(coord)
		_chunk_cache_order.append(coord)
		while _chunk_cache_order.size() > chunk_cache_max:
			var antiguo: Vector2i = _chunk_cache_order.pop_front()
			_chunk_cache.erase(antiguo)

	_unload_task.clear()
	return true


func tiene_descarga_activa() -> bool:
	return not _unload_task.is_empty()
func _crear_orden_generacion(
	size: int,
	chunk_coord: Vector2i,
	con_padding: bool
) -> Array:
	# Agrupar por distancia Chebyshev mantiene primero las celdas cercanas
	# al jugador y evita el sort_custom O(n log n). Los buckets garantizan
	# exactamente una entrada por celda, incluso cuando el objetivo está
	# pegado a un borde del chunk.
	var total: int = size * size
	var indices: Array = []
	indices.resize(total)

	var posicion_objetivo_tile := Vector2i(
		floori(_prioridad_generacion_posicion.x / float(tile_size)),
		floori(_prioridad_generacion_posicion.y / float(tile_size))
	)

	var offset: int = CHUNK_PADDING if con_padding else 0
	var origen_tile := Vector2i(
		chunk_coord.x * chunk_size_tiles - offset,
		chunk_coord.y * chunk_size_tiles - offset
	)
	var objetivo_local := posicion_objetivo_tile - origen_tile
	objetivo_local.x = clampi(objetivo_local.x, 0, size - 1)
	objetivo_local.y = clampi(objetivo_local.y, 0, size - 1)

	var radio_maximo: int = maxi(
		maxi(objetivo_local.x, size - 1 - objetivo_local.x),
		maxi(objetivo_local.y, size - 1 - objetivo_local.y)
	)
	var buckets: Array[Array] = []
	buckets.resize(radio_maximo + 1)
	for radio in range(radio_maximo + 1):
		buckets[radio] = []

	for y in range(size):
		for x in range(size):
			var dx: int = absi(x - objetivo_local.x)
			var dy: int = absi(y - objetivo_local.y)
			var radio: int = maxi(dx, dy)
			(buckets[radio] as Array).append(y * size + x)

	var cursor: int = 0
	for radio in range(buckets.size()):
		var bucket: Array = buckets[radio]
		for indice_variant in bucket:
			if cursor >= total:
				break
			indices[cursor] = int(indice_variant)
			cursor += 1

	return indices


func _bioma_index_at_tile(tile: Vector2i) -> int:
	if areas == null:
		return -1
	return areas.bioma_index_at_tile(tile)
func _ecosistema_index_at_tile(
	tile: Vector2i,
	bioma_index: int
) -> int:
	if areas == null:
		return -1
	return areas.ecosistema_index_at_tile(
		tile,
		bioma_index
	)
func _zona_base_at_tile(
	tile: Vector2i,
	bioma_index: int,
	ecosistema_index: int
) -> int:
	if areas == null:
		return Zone.GRASS
	return areas.zona_base_at_tile(
		tile,
		bioma_index,
		ecosistema_index
	)
func _zona_final_desde_array(
	zonas: Array,
	x: int,
	y: int,
	zona_base: int
) -> int:
	if areas == null:
		return zona_base
	return areas.zona_final_desde_array(
		zonas,
		x,
		y,
		zona_base
	)
func _agua_toca_tierra_en_array(
	zonas: Array,
	x: int,
	y: int
) -> bool:
	if areas == null:
		return false
	return areas.agua_toca_tierra_en_array(
		zonas,
		x,
		y
	)
func _pintar_tile(
	tile: Vector2i,
	zona: int,
	bioma_index: int
) -> void:
	if visual == null:
		return

	var bioma_nombre := ""
	var bioma_textura := ""

	if bioma_index >= 0 and bioma_index < _bioma_nombres.size():
		bioma_nombre = _bioma_nombres[bioma_index]

		if bioma_index < _bioma_texturas.size():
			bioma_textura = _bioma_texturas[bioma_index]

	visual.set_zone(
		tile,
		zona,
		bioma_nombre,
		bioma_textura
	)
func get_zona_at(
	tile: Vector2i
) -> int:
	var chunk_coord: Vector2i = (
		_tile_to_chunk(tile)
	)

	var datos: Dictionary = (
		_loaded_chunks.get(
			chunk_coord,
			{}
		)
	)

	if not datos.is_empty():
		var zonas: Array = (
			datos.get(
				"zonas",
				[]
			)
		)

		var local := _tile_to_local(tile)

		var x: int = (
			local.x + CHUNK_PADDING
		)

		var y: int = (
			local.y + CHUNK_PADDING
		)

		if (
			y >= 0
			and y < zonas.size()
			and x >= 0
			and x < zonas[y].size()
		):
			return int(
				zonas[y][x]
			)

	return _zona_directa(tile)


func _zona_directa(
	tile: Vector2i
) -> int:
	var bioma_index: int = (
		_bioma_index_at_tile(tile)
	)

	var ecosistema_index: int = (
		_ecosistema_index_at_tile(
			tile,
			bioma_index
		)
	)

	return _zona_base_at_tile(
		tile,
		bioma_index,
		ecosistema_index
	)


func cambiar_zona_at(
	tile: Vector2i,
	nueva_zona: int
) -> bool:
	if nueva_zona < 0 or nueva_zona >= Zone.size():
		return false

	var chunk_coord := _tile_to_chunk(tile)
	if not _loaded_chunks.has(chunk_coord):
		return false

	var datos: Dictionary = _loaded_chunks[chunk_coord]
	var zonas_base_variant: Variant = datos.get("zonas_base", [])
	if not zonas_base_variant is Array:
		return false

	var zonas_base: Array = zonas_base_variant as Array
	var local := _tile_to_local(tile)
	var x := local.x + CHUNK_PADDING
	var y := local.y + CHUNK_PADDING
	if y < 0 or y >= zonas_base.size():
		return false
	if not zonas_base[y] is Array or x < 0 or x >= (zonas_base[y] as Array).size():
		return false

	(zonas_base[y] as Array)[x] = nueva_zona
	datos["zonas_base"] = zonas_base
	_loaded_chunks[chunk_coord] = datos

	# Al cambiar una celda también pueden cambiar las costas de sus vecinos.
	# Recalcular desde el terreno base evita acumular "shore" antiguo.
	var afectadas: Array[Vector2i] = [
		tile,
		tile + Vector2i.RIGHT,
		tile + Vector2i.LEFT,
		tile + Vector2i.UP,
		tile + Vector2i.DOWN,
	]
	for celda in afectadas:
		_actualizar_zona_final_at_tile(celda)

	if visual != null:
		visual.flush()
	return true


func _obtener_zona_base_at_tile(tile: Vector2i) -> int:
	var chunk_coord := _tile_to_chunk(tile)
	var datos: Dictionary = _loaded_chunks.get(chunk_coord, {})
	if not datos.is_empty():
		var zonas_base_variant: Variant = datos.get("zonas_base", [])
		if zonas_base_variant is Array:
			var zonas_base: Array = zonas_base_variant as Array
			var local := _tile_to_local(tile)
			var x := local.x + CHUNK_PADDING
			var y := local.y + CHUNK_PADDING
			if y >= 0 and y < zonas_base.size():
				if zonas_base[y] is Array and x >= 0 and x < (zonas_base[y] as Array).size():
					return int((zonas_base[y] as Array)[x])

	return _zona_directa(tile)


func _actualizar_zona_final_at_tile(tile: Vector2i) -> void:
	var chunk_coord := _tile_to_chunk(tile)
	if not _loaded_chunks.has(chunk_coord):
		return

	var datos: Dictionary = _loaded_chunks[chunk_coord]
	var zonas_variant: Variant = datos.get("zonas", [])
	var zonas_base_variant: Variant = datos.get("zonas_base", [])
	var biomas_variant: Variant = datos.get("biomas", [])
	if not zonas_variant is Array or not zonas_base_variant is Array:
		return

	var zonas: Array = zonas_variant as Array
	var zonas_base: Array = zonas_base_variant as Array
	var local := _tile_to_local(tile)
	var x := local.x + CHUNK_PADDING
	var y := local.y + CHUNK_PADDING
	if y < 0 or y >= zonas.size() or y >= zonas_base.size():
		return
	if not zonas[y] is Array or not zonas_base[y] is Array:
		return
	if x < 0 or x >= (zonas[y] as Array).size() or x >= (zonas_base[y] as Array).size():
		return

	var zona_base := _obtener_zona_base_at_tile(tile)
	var zona_final := zona_base
	if zona_base == Zone.WATER or zona_base == Zone.DEEP_WATER:
		for direccion: Vector2i in WorldTerrainAreas.ORTHOGONAL_DIRECTIONS:
			var zona_vecina := _obtener_zona_base_at_tile(tile + direccion)
			if zona_vecina != Zone.WATER and zona_vecina != Zone.DEEP_WATER:
				zona_final = Zone.SHORE
				break

	(zonas[y] as Array)[x] = zona_final
	datos["zonas"] = zonas
	_loaded_chunks[chunk_coord] = datos

	var bioma_index := -1
	if biomas_variant is Array:
		var biomas: Array = biomas_variant as Array
		if y < biomas.size() and biomas[y] is Array and x < (biomas[y] as Array).size():
			bioma_index = int((biomas[y] as Array)[x])

	_pintar_tile(tile, zona_final, bioma_index)


func is_walkable(
	tile: Vector2i
) -> bool:
	var zona: int = (
		get_zona_at(tile)
	)

	match zona:
		Zone.WATER:
			return false

		Zone.DEEP_WATER:
			return false

		Zone.SHORE:
			return false

		Zone.ICE:
			return false

		_:
			return true


func get_bioma_at(
	tile: Vector2i
) -> Dictionary:
	var chunk_coord: Vector2i = (
		_tile_to_chunk(tile)
	)

	var datos: Dictionary = (
		_loaded_chunks.get(
			chunk_coord,
			{}
		)
	)

	if not datos.is_empty():
		var biomas: Array = (
			datos.get(
				"biomas",
				[]
			)
		)

		var local := _tile_to_local(tile)

		var x: int = (
			local.x + CHUNK_PADDING
		)

		var y: int = (
			local.y + CHUNK_PADDING
		)

		if (
			y >= 0
			and y < biomas.size()
			and x >= 0
			and x < biomas[y].size()
		):
			var indice: int = int(
				biomas[y][x]
			)

			if (
				indice >= 0
				and indice < _biomas.size()
			):
				return _biomas[indice]

	var indice_directo: int = (
		_bioma_index_at_tile(tile)
	)

	if (
		indice_directo >= 0
		and indice_directo < _biomas.size()
	):
		return _biomas[indice_directo]

	return {}


func get_ecosistema_at(
	tile: Vector2i
) -> Dictionary:
	var chunk_coord: Vector2i = (
		_tile_to_chunk(tile)
	)

	var datos: Dictionary = (
		_loaded_chunks.get(
			chunk_coord,
			{}
		)
	)

	if not datos.is_empty():
		var ecosistemas: Array = (
			datos.get(
				"ecosistemas",
				[]
			)
		)

		var local := _tile_to_local(tile)

		var x: int = (
			local.x + CHUNK_PADDING
		)

		var y: int = (
			local.y + CHUNK_PADDING
		)

		if (
			y >= 0
			and y < ecosistemas.size()
			and x >= 0
			and x < ecosistemas[y].size()
		):
			var indice: int = int(
				ecosistemas[y][x]
			)

			if (
				indice >= 0
				and indice < _ecosistemas.size()
			):
				return _ecosistemas[indice]

	var bioma_index: int = (
		_bioma_index_at_tile(tile)
	)

	var indice_directo: int = (
		_ecosistema_index_at_tile(
			tile,
			bioma_index
		)
	)

	if (
		indice_directo >= 0
		and indice_directo < _ecosistemas.size()
	):
		return _ecosistemas[indice_directo]

	return {}


func get_habitats_at(
	tile: Vector2i
) -> Array:
	var ecosistema: Dictionary = (
		get_ecosistema_at(tile)
	)

	if ecosistema.is_empty():
		return []

	var habitats_variant: Variant = (
		ecosistema.get(
			"habitats",
			[]
		)
	)

	if habitats_variant is Array:
		return habitats_variant

	return []


func get_criaturas_at(
	tile: Vector2i
) -> Array:
	var resultado: Array = []

	var habitats: Array = (
		get_habitats_at(tile)
	)

	for i in range(habitats.size()):
		var habitat_variant: Variant = (
			habitats[i]
		)

		if not habitat_variant is Dictionary:
			continue

		var habitat: Dictionary = (
			habitat_variant
		)

		var criaturas_variant: Variant = (
			habitat.get(
				"criaturas",
				[]
			)
		)

		if not criaturas_variant is Array:
			continue

		var criaturas: Array = (
			criaturas_variant
		)

		for j in range(criaturas.size()):
			var criatura_variant: Variant = (
				criaturas[j]
			)

			if criatura_variant is Dictionary:
				resultado.append(
					criatura_variant
				)

	return resultado


func get_spawn_position() -> Vector2:
	var centro := Vector2i(
		chunk_size_tiles / 2,
		chunk_size_tiles / 2
	)

	for radio in range(1, 12):
		for dy in range(-radio, radio + 1):
			for dx in range(-radio, radio + 1):
				var tile := Vector2i(
					centro.x + dx,
					centro.y + dy
				)

				if is_walkable(tile):
					return Vector2(
						(float(tile.x) + 0.5)
						* tile_size,
						(float(tile.y) + 0.5)
						* tile_size
					)

	return Vector2(
		float(tile_size * 2),
		float(tile_size * 2)
	)


func _tile_to_chunk(
	tile: Vector2i
) -> Vector2i:
	return Vector2i(
		floori(
			float(tile.x)
			/ chunk_size_tiles
		),
		floori(
			float(tile.y)
			/ chunk_size_tiles
		)
	)


func _tile_to_local(
	tile: Vector2i
) -> Vector2i:
	var chunk := _tile_to_chunk(tile)

	return Vector2i(
		tile.x
		- chunk.x * chunk_size_tiles,
		tile.y
		- chunk.y * chunk_size_tiles
	)


func obtener_estado_generacion() -> Dictionary:
	if _generation_task.is_empty():
		if not _paused_generation_task.is_empty():
			var etapa_pausada := "DATOS"
			match int(_paused_generation_task.get("stage", 0)):
				1: etapa_pausada = "PINTADO"
				2: etapa_pausada = "FLUSH"
			return {
				"activa": false,
				"pausada": true,
				"etapa": etapa_pausada,
				"cursor": int(_paused_generation_task.get("cursor", 0)),
				"total": chunk_size_tiles * chunk_size_tiles,
				"chunk": _paused_generation_task.get("coord", Vector2i.ZERO),
				"chunks_cargados": _loaded_chunks.size(),
				"biomas": _biomas.size(),
				"ecosistemas": _ecosistemas.size()
			}
		return {"activa": false, "pausada": false, "etapa": "IDLE", "cursor": 0, "total": 0}
	var etapa := "DATOS"
	match int(_generation_task.get("stage", 0)):
		1: etapa = "PINTADO"
		2: etapa = "FLUSH"
	return {
		"activa": true,
		"etapa": etapa,
		"cursor": int(_generation_task.get("cursor", 0)),
		"total": (chunk_size_tiles + CHUNK_PADDING * 2) * (chunk_size_tiles + CHUNK_PADDING * 2) if etapa == "DATOS" else chunk_size_tiles * chunk_size_tiles,
		"chunk": _generation_task.get("coord", Vector2i.ZERO),
		"chunks_cargados": _loaded_chunks.size(),
		"biomas": _biomas.size(),
		"ecosistemas": _ecosistemas.size()
	}

func obtener_diagnostico() -> Dictionary:
	var estado := obtener_estado_generacion()
	estado["visual"] = visual != null
	estado["ultimo_chunk"] = _ultimo_chunk_generado
	estado["descarga_activa"] = tiene_descarga_activa()
	estado["chunk_cache"] = _chunk_cache.size()
	estado["chunk_cache_max"] = chunk_cache_max
	# Diagnóstico explícito del pipeline para que F4 permita localizar el
	# cuello sin depender de los prints de cada chunk.
	estado["profiler_generacion"] = {
		"datos_ms": _profiler_data_ms,
		"datos_max_step_ms": _profiler_data_max_ms,
		"bioma_ms": _profiler_biome_ms,
		"ecosistema_ms": _profiler_ecosystem_ms,
		"zona_ms": _profiler_zone_ms,
		"pintado_ms": _profiler_paint_ms,
		"pintado_max_step_ms": _profiler_paint_max_ms,
		"flush_ms": _profiler_flush_ms,
		"flush_max_step_ms": _profiler_flush_max_ms,
		"datos_llamadas": _profiler_data_calls,
		"pintado_llamadas": _profiler_paint_calls,
		"flush_llamadas": _profiler_flushes,
		"primer_commit_visual_ms": _profiler_first_commit_ms,
		"visible_25_ms": _profiler_visible_25_ms,
		"visible_50_ms": _profiler_visible_50_ms,
		"visible_100_ms": _profiler_visible_100_ms,
		"visible_cells": _profiler_visible_cells
	}
	estado["generacion_pausada"] = tiene_generacion_pausada()
	if tiene_generacion_pausada():
		estado["chunk_pausado"] = _paused_generation_task.get("coord", Vector2i.ZERO)
		estado["etapa_pausada"] = int(_paused_generation_task.get("stage", 0))
		estado["cursor_pausado"] = int(_paused_generation_task.get("cursor", 0))
	if visual != null and visual.has_method("obtener_profiler"):
		estado["visual_profiler"] = visual.obtener_profiler()
	if visual != null and visual.has_method("obtener_estado_flush"):
		estado["flush_estado"] = visual.obtener_estado_flush()
	return estado
